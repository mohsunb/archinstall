#!/usr/bin/zsh

printf "Enter disk name: "
read BLOCK_DEVICE
printf "Disk: '$BLOCK_DEVICE'\n"

printf "Enter LUKS passphrase: "
read -s LUKS_P1
printf "\n(Confirm) Enter LUKS passphrase: "
read -s LUKS_P2

if [[ $LUKS_P1 != $LUKS_P2 ]]; then
	printf "\nLUKS passphrases do not match. Aborting...\n"
	exit 1
fi

printf "\nEnter hostname: "
read HOSTNAME
printf "\nHostname: '$HOSTNAME'"

printf "\nEnter 'Confirm' to continue: "
read CONTINUE

if [[ $CONTINUE != "Confirm" ]]; then
	printf "Not confirmed. Aborting...\n"
	exit 1
fi

if [[ $BLOCK_DEVICE == *"nvme"* ]]; then
	BLOCK_SUB="${BLOCK_DEVICE}p"
else
	BLOCK_SUB="$BLOCK_DEVICE"
fi

ESP="${BLOCK_SUB}1"
ROOTP="${BLOCK_SUB}2"

timedatectl set-ntp true

wipefs --all $BLOCK_DEVICE
printf "g\nn\n\n\n+1G\nt\n1\nn\n\n\n\nw\n" | fdisk $BLOCK_DEVICE

mkfs.fat -F32 ${BLOCK_SUB}1

printf "Updating pacman servers list...\n"
systemctl start reflector.service
printf "Done.\n"

sed -i '/#Color/s/^#//' /etc/pacman.conf
sed -i '/#Parallel/s/^#//' /etc/pacman.conf
sed -i '/Parallel/s/\b[0-9]\{1,\}$/15\nILoveCandy/' /etc/pacman.conf
sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
sed -i '/\[multilib\]/{n;s/^#//;}' /etc/pacman.conf

cryptsetup luksFormat --batch-mode $ROOTP <<< $LUKS_P2
cryptsetup luksOpen $ROOTP root <<< $LUKS_P2
mkfs.btrfs /dev/mapper/root -L Arch\ Linux

mount /dev/mapper/root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
umount /mnt
mount -o subvol=@ /dev/mapper/root /mnt
mkdir -p /mnt/boot /mnt/home /mnt/var/log
mount -o subvol=@home /dev/mapper/root /mnt/home
mount -o subvol=@var_log /dev/mapper/root /mnt/var/log
mount $ESP /mnt/boot

pacstrap -P /mnt base linux linux-firmware linux-headers plasma plasma-wayland-session firefox dolphin ark ffmpegthumbs git vim gwenview mpv libva-mesa-driver vulkan-radeon lib32-mesa lib32-libva-mesa-driver lib32-vulkan-radeon noto-fonts noto-fonts-cjk ttf-roboto ttf-jetbrains-mono-nerd zsh starship alacritty btrfs-progs snapper htop radeontop kate kamoso qt6-wayland amd-ucode base-devel opendoas

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -s /usr/share/zoneinfo/Asia/Baku /etc/localtime

sed -i '/#az_AZ/s/^#//' /mnt/etc/locale.gen
sed -i '/#en_GB/s/^#//' /mnt/etc/locale.gen
sed -i '/#en_US/s/^#//' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

printf $HOSTNAME >> /mnt/etc/hostname
printf "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain\t${HOSTNAME}\n" >> /mnt/etc/hosts

printf "LANG=\"en_US.UTF-8\"\nLC_TIME=\"en_GB.UTF-8\"\n" >> /mnt/etc/locale.conf
printf "KEYMAP=us\n" >> /mnt/etc/vconsole.conf

sed -i '/^HOOKS/s/\budev\b/systemd/' /mnt/etc/mkinitcpio.conf
sed -i '/^HOOKS/s/\bkeymap\sconsolefont/sd-vconsole/' /mnt/etc/mkinitcpio.conf
sed -i '/^HOOKS/s/\bblock\b/block sd-encrypt/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

