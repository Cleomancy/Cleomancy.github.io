#!/bin/sh

# My custom larbs.xyz setup.
# Originally from Luke Smith, fitted for my purposes.
# - the Cleomancer.
# License: GNU GPLv3

## ASUMING THIS SCRIPT IS RUN AFTER A BARE INSTALL OF ARCH WITH NOTHING ON IT. LOGGED IN AS ROOT, NOT A USER ACCOUNT.
## MAKE SURE TIME IS SET UP PROPERLY! I removed it from the script because I always do that manually.

### OPTIONS AND VARIABLES ###

dotfiles="https://github.com/Cleomancy/dots.git"
prereq="https://cleomancy.github.io/progs.txt"
rssurls="https://landchad.net/rss.xml
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\" "
repo="https://github.com/Cleomancy"

export TERM=ansi
### FUNCTIONS ###

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Welcome!" --msgbox "This script will install arch support for artix, the AUR helper yay and the required dependencies and programs to accompany my forks of the suckless tools dwm, st, dmenu and dwmblocks." 10 70

	whiptail --title "Important Note!" --yes-button "Let's go" --no-button "Cancel" --yesno "Be sure you are on a fresh install of Artix Linux with time set correctly and that you are logged in as root, you will be prompted to create a new user during this script." 10 70
}

getuserandpass() {
	# Prompts user for new username and password.
	name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	whiptail --infobox "Adding user \"$name\"..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
    export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

refreshkeys() {
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		whiptail --infobox "Refreshing Arch Keyring..." 7 40
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		whiptail --infobox "Enabling Arch Repositories for more a more extensive software collection..." 7 40
		pacman --noconfirm --needed -S \
			artix-keyring artix-archlinux-support >/dev/null 2>&1
		grep -q "^\[extra\]" /etc/pacman.conf ||
			echo "[extra]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
		pacman -Sy --noconfirm >/dev/null 2>&1
		pacman-key --populate archlinux >/dev/null 2>&1
		;;
	esac
}

yayinstall() {
	# Installs yay manually. Used only for AUR helper here.
	# Should be run after repodir is created and var is set.
	whiptail --infobox "Installing yay manually." 7 50
	sudo -u "$name" git -C "$repodir" clone https://aur.archlinux.org/yay.git >/dev/null 2>&1 ||
		{
			cd "$repodir/yay" || return 1
			sudo -u "$name" git pull --force origin master >/dev/null 2>&1
		}
	cd "$repodir/yay" || exit 1
	sudo -u "$name" \
		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

installdeps() {
	([ -f "$prereq" ] && cp "$prereq" /tmp/progs.txt) ||
		curl -Ls "$prereq" | sed '/^#/d' >/tmp/progs.txt
	total=$(wc -l </tmp/progs.txt) ## counts the number of lines for file.
	while IFS=, read -r program; do
		n=$((n + 1))
			whiptail --title "installation of dependencies" \
		--infobox "Installing \`$program\` ($n of $total)." 9 70
        sudo -u "$name" yay --needed --noconfirm -S "$program" > /dev/null 2>&1
	done </tmp/progs.txt
}

installdots() {
	# Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	whiptail --infobox "Downloading and installing config files..." 7 60
	dir=$(mktemp -d)
	chown "$name":wheel "$dir"
	sudo -u "$name" git -C "$repodir" clone --depth 1 \
		--single-branch --no-tags -q --recursive -b main \
		--recurse-submodules "$1" "$dir" > /dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2"
}

gitmakeinstall() {
	dir="$repodir/$1"
	whiptail --title "Glorious DWM Installation" \
		--infobox "Installing \`$1\` via \`git\` and \`make\`." 8 70
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch --no-tags -q "$repo/$1" "$dir"
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

finalize() {
	whiptail --title "All done!" \
		--msgbox "Log out and log back in as your new user. If it works, it works. Make sure to set up cron jobs for the scripts in .local/bin/cron." 13 80
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

## Check if user is root on Arch distro. Install whiptail.
pacman --noconfirm --needed -Sy libnewt ||
	error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

### The rest of the script requires no user input.

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl ca-certificates base-devel git zsh; do
	whiptail --title "LARBS Installation" \
		--infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
	pacman --noconfirm --needed -S "$x" > /dev/null 2>&1
done

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/temp

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 3/;/^#Color$/s/#//" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

yayinstall || error "Failed to install AUR helper."

# Make sure .*-git AUR packages get updated automatically.
yay -Y --save --devel

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installdeps

gitmakeinstall "gdwm"
gitmakeinstall "gmenu"
gitmakeinstall "st"
gitmakeinstall "dwmblocks"

# Install the dotfiles in the user's home directory, but remove .git dir and
# other unnecessary files.
installdots "$dotfiles" "/home/$name"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"

chmod -R 777 "/home/$name/.local/bin"

# Write urls for newsboat if it doesn't already exist
[ -s "/home/$name/.config/newsboat/urls" ] ||
	sudo -u "$name" echo "$rssurls" > "/home/$name/.config/newsboat/urls"

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Make bash the default #!/bin/sh symlink.
ln -sfT /bin/bash /bin/sh >/dev/null 2>&1

# dbus UUID must be generated for Artix runit. I usually leave it commented out as I use OpenRC. It is wise to keep it.
#dbus-uuidgen >/var/lib/dbus/machine-id

### LAPTOP STUFF

# Most important command! Get rid of the beep!
#rmmod pcspkr
#echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Enable tap to click
#[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
##        Identifier "libinput touchpad catchall"
#        MatchIsTouchpad "on"
#        MatchDevicePath "/dev/input/event*"
#        Driver "libinput"
	# Enable left mouse button by tapping
#	Option "Tapping" "on"
#EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

# Allow wheel users to sudo with password and allow several system commands
# (like `shutdown` to run without password).
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Cleanup
rm -f /etc/sudoers.d/temp

# Last message! Install complete!
finalize