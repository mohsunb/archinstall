#!/usr/bin/zsh

timedatectl set-ntp true

wipefs --all /dev/nvme0n1
printf "g\nn\n\n\n+1G\nt\n1\nn\n\n\n\nw\n" | fdisk /dev/nvme0n1

mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -L Arch\ Linux /dev/nvme0n1p2

systemctl start reflector.service

sed -i '/#Color/s/^#//' /etc/pacman.conf
sed -i '/#Parallel/s/^#//' /etc/pacman.conf
sed -i '/Parallel/s/\b[0-9]\{1,\}$/15\nILoveCandy/' /etc/pacman.conf
sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
sed -i '/\[multilib\]/{n;s/^#//;}' /etc/pacman.conf

