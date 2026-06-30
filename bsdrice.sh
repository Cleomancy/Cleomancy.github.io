#!/bin/sh

# My custom larbs.xyz setup.
# Originally from Luke Smith, fitted for my purposes.
# - the Cleomancer.
# MAKE SURE YOU SET YOUR SYSTEM TIME MANUALLY AND CORRECTLY, I REMOVED THE AUTOMATION BECAUSE I DON'T USE NTP.
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

dotfilesrepo="https://github.com/Cleomancy/dots.git"
progsfile="https://cleomancy.github.io/progsbsd.csv"
repobranch="bsd"
export TERM=ansi

rssurls="https://lukesmith.xyz/rss.xml
https://videos.lukesmith.xyz/feeds/videos.xml?videoChannelId=2 \"~Luke Smith (Videos)\"
https://notrelated.xyz/rss
https://www.youtube.com/feeds/videos.xml?channel_id=UCD6VugMZKRhSyzWEWA9W2fg
https://www.youtube.com/feeds/videos.xml?channel_id=UClOGLGPOqlAiLmOvXW5lKbw
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\"
https://news.opensuse.org/feed.xml \"tech\
https://www.alpinelinux.org/atom.xml \"tech\" "

### FUNCTIONS ###

installpkg() {
	pkg install -y "$1" >/dev/null 2>&1
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Welcome!" \
		--msgbox "Welcome to Luke's Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-Cleo" 10 60

	whiptail --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nMAKE SURE TIME IS SET UP CORRECTLY! I removed it from the script." 8 70
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

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user \`$name\` already exists on this system. LARBS can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account.\\n\\nLARBS will NOT overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LARBS will change $name's password to the one you just gave." 14 70
}

preinstallmsg() {
	whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "No, nevermind!" \
		--yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	whiptail --infobox "Adding user \"$name\"..." 7 50
	pw useradd -m -G wheel -n "$name" >/dev/null 2>&1 ||
		pw usermod "$name" -G wheel && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"

	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$pass1" | pw usermod -n "$name" -h 0
	unset pass1 pass2
}


maininstall() {
	# Installs all needed programs from main repo.
	whiptail --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	installpkg "$1"
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
	dir="$repodir/$progname"
	[ -z "$3" ] && branch="main" || branch="$repobranch"
	whiptail --title "LARBS Installation" \
		--infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch -b "$branch" \
		--no-tags -q "$1" "$dir" ||
		{
			cd "$dir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

installationloop() {
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	while IFS=, read -r tag program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"G") gitmakeinstall "$program" "$comment" ;;
		"P") pipinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

nvidiamsg() {
	whiptail --title "Graphics" --yes-button "I do !" \
		--no-button "Ew..." \
		--yesno "Do you have an nvidia card as your primary video card device? If so, this script installs the NEWEST drivers for freeBSD upon confirmation." 8 70
	nvidiainstall
}

nvidiainstall() {
	# Installs Nvidia Drivers if asked (assuming latest)

	for x in nvidia-driver; do
		whiptail --title "LARBS Installation" \
			--infobox "Installing \`$x\`." 8 70
		installpkg "$x"
	done

	cat > /usr/local/etc/X11/xorg.conf.d/20-nvidia.conf << EOF
	Section "Device"
		Identifier "Card0"
		Driver "nvidia"
	EndSection
EOF
cat >> /etc/rc.conf << EOF
kld_list="nvidia-modeset"
EOF

}

putgitrepo() {
	# Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	whiptail --infobox "Downloading and installing config files..." 7 60
	branch="$repobranch" || branch="main"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$name":wheel "$dir" "$2"
	sudo -u "$name" git -C "$repodir" clone --depth 1 \
		--single-branch --no-tags -q --recursive -b "$branch" \
		--recurse-submodules "$1" "$dir"
	sudo -u "$name" cp -r "$dir/" "$2"
}

finalize() {
	whiptail --title "All done!" \
		--msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nYou should reboot if you have installed nvidia drivers. Start your graphical environment with \"startx\" (it will start automatically in tty1).\\n\\n.t Cleo" 13 80
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install whiptail.
pkg install -y newt zsh dash ||
	error "Are you sure you're running this as the root user, are on a BSD distribution and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

for x in sudo curl linux-rl9-ca-certificates git; do
	whiptail --title "LARBS Installation" \
		--infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
	installpkg "$x"
done

adduserandpass || error "Error adding username and/or password."

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
trap 'rm -f /usr/local/etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/usr/local/etc/sudoers.d/larbs-temp

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

nvidiamsg

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop
# Install the dotfiles in the user's home directory, but remove .git dir and
# other unnecessary files.
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -rf "/home/$name/.git/" "/home/$name/LICENSE" "/home/$name/README.md"

# Write urls for newsboat if it doesn't already exist
[ -s "/home/$name/.config/newsboat/urls" ] ||
	echo "$rssurls" | sudo -u "$name" tee "/home/$name/.config/newsboat/urls" >/dev/null

# Make zsh the default shell for the user.
chsh -s zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Make dash the default #!/bin/sh symlink.
ln -sfT /usr/local/bin/dash /usr/local/bin/sh >/dev/null 2>&1

# Make sure user is in the right groups to use x
pw usermod "$name" -G video,wheel

# Use system notifications for Brave on Artix
# Only do it when systemd is not present
[ "$(readlink -f /sbin/init)" != "/usr/lib/systemd/systemd" ] && echo "export \$(dbus-launch)" >/usr/local/etc/profile.d/dbus.sh

# Enable tap to click commented out since I don't use a laptop all the time
<<COMMENT
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf
COMMENT

cat >> /etc/rc.conf << EOF
dbus_enabled="YES"
pf_enabled="YES"
EOF

# All this below to get Librewolf installed with add-ons and non-bad settings.

whiptail --infobox "Setting browser privacy settings and add-ons..." 7 60

browserdir="/home/$name/.librewolf"
profilesini="$browserdir/profiles.ini"

# Start librewolf headless so it generates a profile. Then get that profile in a variable.
sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
sleep 1
profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"

[ -d "$pdir" ]

# Kill the now unnecessary librewolf instance.
pkill -u "$name" librewolf

# Allow wheel users to sudo with password and allow several system commands
# (like `shutdown` to run without password).
echo "%wheel ALL=(ALL:ALL) ALL" > /usr/local/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "Defaults editor=/usr/bin/nvim" > /usr/local/etc/sudoers.d/02-larbs-visudo-editor
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/poweroff,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount*,/usr/bin/umount,/usr/bin/pkg install,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/usr/local/etc/sudoers.d/01-larbs-cmds-without-password

mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Cleanup
rm -f /usr/local/etc/sudoers.d/larbs-temp

# Last message! Install complete!
finalize
