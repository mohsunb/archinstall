#!/usr/bin/zsh

printf "Enter disk name: "
read BLOCK_DEVICE
printf "Disk: '$BLOCK_DEVICE\n'"

printf "Enter 'Confirm' to continue: "
read CONTINUE

if [[ $CONTINUE != "Confirm" ]]; then
	printf "Aborting...\n"
	exit 1
fi

if [[ $BLOCK_DEVICE == *"nvme"* ]]; then
	BLOCK_SUB="${BLOCK_DEVICE}p"
else
	BLOCK_SUB="$BLOCK_DEVICE"
fi

timedatectl set-ntp true

wipefs --all $BLOCK_DEVICE
printf "g\nn\n\n\n+1G\nt\n1\nn\n\n\n\nw\n" | fdisk $BLOCK_DEVICE

mkfs.fat -F32 ${BLOCK_SUB}1
mkfs.btrfs -f ${BLOCK_SUB}2 -L Arch\ Linux

systemctl start reflector.service

sed -i '/#Color/s/^#//' /etc/pacman.conf
sed -i '/#Parallel/s/^#//' /etc/pacman.conf
sed -i '/Parallel/s/\b[0-9]\{1,\}$/15\nILoveCandy/' /etc/pacman.conf
sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
sed -i '/\[multilib\]/{n;s/^#//;}' /etc/pacman.conf

