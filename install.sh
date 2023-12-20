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

mount $ROOTP /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
umount /mnt
mount -o subvol=@ $ROOTP /mnt
mkdir -p /mnt/boot /mnt/home /mnt/var/log
mount -o subvol=@home $ROOTP /mnt/home
mount -o subvol=@var_log $ROOTP /mnt/var/log
mount $ESP /mnt/boot

