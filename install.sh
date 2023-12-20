#!/usr/bin/zsh

OMZ_INSTALL="sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""

printf "Enter username: "
read NEW_USERNAME
printf "\nUsername: '$NEW_USERNAME'"

printf "\nEnter root password: "
read -s ROOT_P1
printf "\n(Confirm) Enter root password: "
read -s ROOT_P2

if [[ $ROOT_P1 != $ROOT_P2 ]]; then
	printf "\nRoot passwords do not match. Aborting...\n"
	exit 1
fi

printf "\nEnter password for '$NEW_USERNAME': "
read -s USER_P1
printf "\n(Confirm) Enter password for '$NEW_USERNAME': "
read -s USER_P2

if [[ $USER_P1 != $USER_P2 ]]; then
	printf "\nUser passwords do not match. Aborting...\n"
	exit 1
fi

printf "\nEnter disk name: "
read BLOCK_DEVICE
printf "\nDisk: '$BLOCK_DEVICE'"

printf "\nEnter LUKS passphrase: "
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
echo "Partitioning done."
mkfs.fat -F32 ${BLOCK_SUB}1

printf "Updating pacman servers list...\n"
systemctl start reflector.service
printf "Done.\n"

sed -i '/#Color/s/^#//' /etc/pacman.conf
sed -i '/#Parallel/s/^#//' /etc/pacman.conf
sed -i '/Parallel/s/\b[0-9]\{1,\}$/15\nILoveCandy/' /etc/pacman.conf
sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
sed -i '/\[multilib\]/{n;s/^#//;}' /etc/pacman.conf
echo "pacman config done"
cryptsetup luksFormat --batch-mode $ROOTP <<< $LUKS_P2
cryptsetup luksOpen $ROOTP root <<< $LUKS_P2
mkfs.btrfs /dev/mapper/root -L Arch\ Linux
echo "filesystems done"
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
echo fstab done
pacstrap -P /mnt base linux linux-firmware linux-headers plasma plasma-wayland-session firefox dolphin ark ffmpegthumbs git vim gwenview mpv libva-mesa-driver vulkan-radeon lib32-mesa lib32-libva-mesa-driver lib32-vulkan-radeon noto-fonts noto-fonts-cjk ttf-roboto ttf-jetbrains-mono-nerd zsh starship alacritty btrfs-progs snapper htop radeontop kate kamoso qt6-wayland amd-ucode base-devel opendoas networkmanager bluez bluez-utils reflector pacman-contrib sbctl power-profiles-daemon

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -s /usr/share/zoneinfo/Asia/Baku /etc/localtime
echo "locale generated"
sed -i '/#az_AZ/s/^#//' /mnt/etc/locale.gen
sed -i '0,/#en_GB/s/^#//' /mnt/etc/locale.gen
sed -i '0,/#en_US/s/^#//' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

printf $HOSTNAME >> /mnt/etc/hostname
printf "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain\t${HOSTNAME}\n" >> /mnt/etc/hosts
echo "host names done"
printf "LANG=\"en_US.UTF-8\"\nLC_TIME=\"en_GB.UTF-8\"\n" >> /mnt/etc/locale.conf
printf "KEYMAP=us\n" >> /mnt/etc/vconsole.conf
echo "lang and keymap done"
sed -i '0,/#\s%wheel/s/^#\s//' /mnt/etc/sudoers
printf "permit persist :wheel\n" >> /mnt/etc/doas.conf
chmod -c 0400 /mnt/etc/doas.conf
echo "sudo/doas done"
sed -i '/^HOOKS/s/\budev\b/systemd/' /mnt/etc/mkinitcpio.conf
sed -i '/^HOOKS/s/\bkeymap\sconsolefont/sd-vconsole/' /mnt/etc/mkinitcpio.conf
sed -i '/^HOOKS/s/\bblock\b/block sd-encrypt/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P
echo "mkinitcpio done"
printf "${ROOT_P2}\n${ROOT_P2}\n" | arch-chroot /mnt passwd
arch-chroot /mnt useradd -m $NEW_USERNAME
printf "${USER_P2}\n${USER_P2}\n" | arch-chroot /mnt passwd $NEW_USERNAME
arch-chroot /mnt usermod -aG wheel,audio,video,optical,storage $NEW_USERNAME
echo "users done"
arch-chroot /mnt sbctl create-keys
arch-chroot /mnt sbctl enroll-keys -m
arch-chroot /mnt sbctl sign -s -o /mnt/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /mnt/usr/lib/systemd/boot/efi/systemd-bootx64.efi
arch-chroot /mnt sbctl sign -s /mnt/boot/vmlinuz-linux
echo "secure boot done"
ROOTP_UUID=$(ls -l /dev/disk/by-uuid | grep ${ROOTP:4} | grep -o -E "[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}")
arch-chroot /mnt bootctl install
printf "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/amd-ucode.img\ninitrd\t/initramfs-linux.img\noptions\trd.luks.name=$ROOTP_UUID=root root=/dev/mapper/root rootflags=subvol=@ rw asus_wmi.fnlock_default=0 zswap.enabled=0 quiet loglevel=3 splash\n" >> /mnt/boot/loader/entries/arch.conf
printf "default arch.conf\neditor no\nconsole-mode max\ntimeout 0\n" >> /mnt/boot/loader/loader.conf
echo "bootloader done"
arch-chroot /mnt systemctl enable NetworkManager bluetooth sddm power-profiles-daemon fstrim.timer paccache.timer
echo "services enabled"
printf "${LUKS_P2}\n" | systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 $ROOTP
echo "tpm done"
umount /mnt/var/log
umount /mnt/home
umount /mnt/boot
umount /mnt
cryptsetup luksClose root
echo "installation done"

