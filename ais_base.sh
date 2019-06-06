#!/bin/sh

set_defaults()
{
    # Terminal font 
    Bold=$(tput bold)
    Reset=$(tput sgr0)
    Cyan=$(tput setaf 6)

    title="AIS - Archlinux Installation Script - jonatasmedeiros.com/ais.sh"
    ext4_args="-F -m 0 -T big"
    root_label="arch"
    esp_label="ESP"
    home_label="home"
    mount_point="/mnt"
    esp_mp="${mount_point}/boot"
    esp_part="/dev/sda2"
    home_mp="${mount_point}/home"
    win_mp="${mount_point}/win"
    win_part="/dev/sda4"

    country_code="BR"
    mirrorlist="/etc/pacman.d/mirrorlist"
    mirror_url="https://www.archlinux.org/mirrorlist/?country=${country_code}&use_mirror_status=on"

    base_packages="base base-devel amd-ucode ntfs-3g"
    swap_size="512M"

    host_name=""
    time_zone="America/Recife"
    trim_rule="\"ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"deadline\""
    loader_conf="default\tarch\ntimeout\t3\neditor\t0"
    arch_conf="title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/intel-ucode.img\ninitrd\t/initramfs-linux.img\noptions\troot=PARTLABEL=arch rw"
}

print_line()
{
    printf "%$(tput cols)s\n" | tr ' ' '-'
}

print_bold()
{
    printf "${Bold}:: $1${Reset}\n\n"
}

print_title()
{
    clear
    print_line
    printf "  ${Bold}$1${Reset}\n"
    print_line
    printf "\n"
}

read_key()
{
    stty_old=$(stty -g)
    stty raw -echo min 1 time 0
    printf '%s' $(dd bs=1 count=1 2>/dev/null)
    stty $stty_old
}

wait_key()
{
    print_line
    printf "Press any key to continue (q to quit)..."
    continue_key=$(read_key)
    if [ "$continue_key" = "q" ]; then
        printf "\nExiting AIS...\n"
        umount -R ${mount_point}
        exit 1
    fi
    print_title "$title"
}

arch_chroot()
{
    printf "${Bold}\$ arch-chroot:${Reset} ${Cyan}${1}${Reset}\n\n"
    arch-chroot ${mount_point} sh -c "${1}"
    printf "\n"
}

execute()
{
    printf "${Bold}\$${Reset} ${Cyan}${1}${Reset}\n\n"
    $1
    printf "\n"
}

setup()
{
    print_title "$title"

    print_bold "Syncing time"
    execute "timedatectl set-ntp true"
    wait_key

    print_bold "Formating root partition"
    execute "mkfs.ext4 ${ext4_args} -L ${root_label} /dev/disk/by-partlabel/${root_label}"
    wait_key

    print_bold "Formating home partition"
    execute "mkfs.ext4 ${ext4_args} -L ${home_label} /dev/disk/by-partlabel/${home_label}"
    wait_key

    print_bold "Mounting root partition"
    execute "mount -v PARTLABEL=${root_label} ${mount_point}"
    wait_key

    print_bold "Mounting boot partition"
    execute "mkdir -vp ${esp_mp}"
    #execute "mount -v PARTLABEL=${esp_label} ${esp_mp}"
    execute "mount -v ${esp_part} ${esp_mp}"
    wait_key

    print_bold "Mounting home partition"
    execute "mkdir -vp ${home_mp}"
    execute "mount -v PARTLABEL=${home_label} ${home_mp}"
    wait_key

    print_bold "Mounting win partition"
    execute "mkdir -vp ${win_mp}"
    execute "mount -v ${win_part} ${win_mp}"
    wait_key

    print_bold "Updating repositories"
    execute "pacman -Syy"
    wait_key

    print_bold "Installing rankmirrors package"
    execute "pacman --noconfirm --needed -S pacman-contrib"
    wait_key

    print_bold "Backing up mirrorlist"
    execute "cp -v ${mirrorlist} ${mirrorlist}.backup"
    wait_key

    print_bold "Downloading and ranking mirrorlist"
    execute "curl \"${mirror_url}\" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > ${mirrorlist}"
    execute "cat ${mirrorlist}"
    wait_key

    print_bold "Configuring pacman.conf"
    execute "sed -i -e 's/^#Color/Color/;s/^#TotalDownload/TotalDownload/' /etc/pacman.conf"
    wait_key

    print_bold "Installing base system"
    execute "pacstrap ${mount_point} ${base_packages}"
    wait_key

    print_bold "Creating swap file"
    arch_chroot "fallocate -l ${swap_size} /swapfile"
    arch_chroot "chmod 600 /swapfile"
    arch_chroot "mkswap /swapfile"
    arch_chroot "swapon /swapfile"
    wait_key

    print_bold "Generate fstab"
    execute "genfstab -t PARTUUID -p ${mount_point} > ${mount_point}/etc/fstab"
    #echo -e "# Swap File\n/swapfile\tnone\tswap\tdefaults\t0 0\n" >> /mnt/etc/fstab
    execute "cat ${mount_point}/etc/fstab"
    wait_key

    print_bold "Setting hostname"
    execute "echo $host_name > ${mount_point}/etc/hostname"
    execute "cat ${mount_point}/etc/hostname"
    wait_key

    print_bold "Setting time zone"
    arch_chroot "ln -svf /usr/share/zoneinfo/${time_zone} /etc/localtime"
    wait_key

    print_bold "Setting system clock"
    arch_chroot "hwclock -wu"
    wait_key

    print_bold "Setting locale"
    execute "sed -i 's/^#en_US/en_US/' ${mount_point}/etc/locale.gen"
    execute "echo \"LANG=en_US.UTF-8\" > ${mount_point}/etc/locale.conf"
    execute "cat ${mount_point}/etc/locale.conf"
    arch_chroot "locale-gen"
    wait_key

    print_bold "Setting trimming"
    arch_chroot "systemctl enable fstrim.timer"
    execute "printf \"${trim_rule}\" > ${mount_point}/etc/udev/rules.d/60-schedulers.rules"
    execute "cat ${mount_point}/etc/udev/rules.d/60-schedulers.rules"
    wait_key

    print_bold "Copying pacman.conf"
    execute "cp /etc/pacman.conf ${mount_point}/etc/pacman.conf"
    wait_key

    print_bold "Setting root password"
    arch_chroot "passwd"
    #arch_chroot "echo \"root:$root_pass1\" | chpasswd"
    wait_key

    print_bold "Configuring bootloader"
    arch_chroot "bootctl install"
    execute "printf \"${loader_conf}\" > ${mount_point}/boot/loader/loader.conf" 
    execute "printf \"${arch_conf}\" > ${mount_point}/boot/loader/entries/arch.conf"
    wait_key

    print_bold "Refreshing keys"
    arch_chroot "pacman-key --init"
    arch_chroot "pacman-key --populate archlinux"
    arch_chroot "pacman-key --refresh-keys"
    wait_key
}

set_defaults
setup

# vim: fdm=syntax 
