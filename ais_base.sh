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

    host_name="archlinux"
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

print_command()
{
    printf "${Bold}\$${Reset} ${Cyan}${1}${Reset}\n\n"
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
    printf "\n"
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
    arch-chroot ${mount_point} sh -c "${1}"
}

sync_time()
{
    print_bold "Syncing time"
    print_command "timedatectl set-ntp true"
    timedatectl set-ntp true
    wait_key
}

format_partitions()
{
    print_bold "Formating partitions"
    print_command "mkfs.ext4 ${ext4_args} -L ${root_label} /dev/disk/by-partlabel/${root_label}"
    mkfs.ext4 ${ext4_args} -L ${root_label} /dev/disk/by-partlabel/${root_label}
    printf "\n"

    print_command "mkfs.ext4 ${ext4_args} -L ${home_label} /dev/disk/by-partlabel/${home_label}"
    mkfs.ext4 ${ext4_args} -L ${home_label} /dev/disk/by-partlabel/${home_label}
    wait_key
}

mount_partitions()
{
    print_bold "Mounting partitions"
    print_command "mount -v PARTLABEL=${root_label} ${mount_point}"
    mount -v PARTLABEL=${root_label} ${mount_point}
    printf "\n"

    print_command "mkdir -vp ${esp_mp}"
    mkdir -vp ${esp_mp}
    printf "\n"

    print_command "mount -v ${esp_part} ${esp_mp}"
    mount -v ${esp_part} ${esp_mp}
    printf "\n"
    #mount -v PARTLABEL=${esp_label} ${esp_mp}

    print_command "mkdir -vp ${home_mp}"
    mkdir -vp ${home_mp}
    printf "\n"

    print_command "mount -v PARTLABEL=${home_label} ${home_mp}"
    mount -v PARTLABEL=${home_label} ${home_mp}
    printf "\n"

    print_command "mkdir -vp ${win_mp}"
    mkdir -vp ${win_mp}
    printf "\n"

    print_command "mount -v ${win_part} ${win_mp}"
    mount -v ${win_part} ${win_mp}
    wait_key
}

config_mirrorlist()
{
    print_bold "Config mirrorlist"
    print_command "pacman -Syy"
    pacman -Syy
    printf "\n"

    print_command "pacman --noconfirm --needed -S pacman-contrib"
    pacman --noconfirm --needed -S pacman-contrib
    printf "\n"

    print_command "cp -v ${mirrorlist} ${mirrorlist}.backup"
    cp -v ${mirrorlist} ${mirrorlist}.backup
    printf "\n"

    print_command "curl \"${mirror_url}\" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > ${mirrorlist}"
    curl ${mirror_url} | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > ${mirrorlist}
    printf "\n"

    print_command "cat ${mirrorlist}"
    cat ${mirrorlist}
    wait_key
}

install_base()
{
    print_bold "Installing base system"
    print_command "sed -i -e 's/^#Color/Color/;s/^#TotalDownload/TotalDownload/' /etc/pacman.conf"
    sed -i -e 's/^#Color/Color/;s/^#TotalDownload/TotalDownload/' /etc/pacman.conf

    print_command "pacstrap ${mount_point} ${base_packages}"
    pacstrap ${mount_point} ${base_packages}
    wait_key
}

create_swap()
{
    print_bold "Creating swap file"
    print_command "(chroot) fallocate -l ${swap_size} /swapfile"
    arch_chroot "fallocate -l ${swap_size} /swapfile"
    printf "\n"

    print_command "chmod 600 /swapfile"
    arch_chroot "chmod 600 /swapfile"
    printf "\n"

    print_command "mkswap /swapfile"
    arch_chroot "mkswap /swapfile"
    printf "\n"

    print_command "swapon /swapfile"
    arch_chroot "swapon /swapfile"
    wait_key
}

generate_fstab()
{
    print_bold "Generate fstab"
    print_command "genfstab -t PARTUUID -p ${mount_point} > ${mount_point}/etc/fstab"
    genfstab -t PARTUUID -p ${mount_point} > ${mount_point}/etc/fstab
    printf "\n"

    #echo -e "# Swap File\n/swapfile\tnone\tswap\tdefaults\t0 0\n" >> /mnt/etc/fstab
    print_command "cat ${mount_point}/etc/fstab"
    cat ${mount_point}/etc/fstab
    wait_key
}

set_hostname()
{
    print_bold "Setting hostname"
    print_command "echo $host_name > ${mount_point}/etc/hostname"
    echo $host_name > ${mount_point}/etc/hostname

    print_command "cat ${mount_point}/etc/hostname"
    cat ${mount_point}/etc/hostname
    wait_key
}

set_timezone()
{
    print_bold "Setting time zone"
    print_command "(chroot) ln -svf /usr/share/zoneinfo/${time_zone} /etc/localtime"
    arch_chroot "ln -svf /usr/share/zoneinfo/${time_zone} /etc/localtime"
    wait_key
}

set_clock()
{
    print_bold "Setting system clock"
    print_command "hwclock -wu"
    arch_chroot "hwclock -wu"
    wait_key
}

set_locale()
{
    print_bold "Setting locale"
    print_command "sed -i 's/^#en_US/en_US/' ${mount_point}/etc/locale.gen"
    sed -i 's/^#en_US/en_US/' ${mount_point}/etc/locale.gen

    print_command "echo \"LANG=en_US.UTF-8\" > ${mount_point}/etc/locale.conf"
    echo "LANG=en_US.UTF-8" > ${mount_point}/etc/locale.conf

    print_command "cat ${mount_point}/etc/locale.conf"
    cat ${mount_point}/etc/locale.conf
    printf "\n"

    print_command "locale-gen"
    arch_chroot "locale-gen"
    wait_key
}

set_trimming()
{
    print_bold "Setting trimming"
    print_command "systemctl enable fstrim.timer"
    arch_chroot "systemctl enable fstrim.timer"
    printf "\n"

    print_command "printf \"${trim_rule}\" > ${mount_point}/etc/udev/rules.d/60-schedulers.rules"
    printf "${trim_rule}" > ${mount_point}/etc/udev/rules.d/60-schedulers.rules

    print_command "cat ${mount_point}/etc/udev/rules.d/60-schedulers.rules"
    cat ${mount_point}/etc/udev/rules.d/60-schedulers.rules
    wait_key
}

copy_pacmanconf()
{
    print_bold "Copying pacman.conf"
    print_command "cp /etc/pacman.conf ${mount_point}/etc/pacman.conf"
    cp /etc/pacman.conf ${mount_point}/etc/pacman.conf
    wait_key
}

set_root_pass()
{
    print_bold "Setting root password"
    print_command "passwd"
    arch_chroot "passwd"
    #arch_chroot "echo \"root:$root_pass1\" | chpasswd"
    wait_key
}

config_bootloader()
{
    print_bold "Configuring bootloader"
    print_command "bootctl install"
    arch_chroot "bootctl install"
    printf "\n"

    print_command "printf \"${loader_conf}\" > ${mount_point}/boot/loader/loader.conf"
    printf "${loader_conf}" > ${mount_point}/boot/loader/loader.conf 

    print_command "cat ${mount_point}/boot/loader/loader.conf"
    cat ${mount_point}/boot/loader/loader.conf
    printf "\n"

    print_command "printf \"${arch_conf}\" > ${mount_point}/boot/loader/entries/arch.conf"
    printf "${arch_conf}" > ${mount_point}/boot/loader/entries/arch.conf

    print_command "cat ${mount_point}/boot/loader/entries/arch.conf"
    cat ${mount_point}/boot/loader/entries/arch.conf
    wait_key
}

refresh_keys()
{
    print_bold "Refreshing keys"
    print_command "pacman-key --init"
    arch_chroot "pacman-key --init"
    printf "\n"

    print_command "pacman-key --populate archlinux"
    arch_chroot "pacman-key --populate archlinux"
    printf "\n"

    print_command "pacman-key --refresh-keys"
    arch_chroot "pacman-key --refresh-keys"
    wait_key
}

setup()
{
    print_title "$title"

    sync_time
    format_partitions
    mount_partitions
    config_mirrorlist
    install_base
    create_swap
    generate_fstab
    set_hostname
    set_timezone
    set_clock
    set_locale
    set_trimming
    copy_pacmanconf
    set_root_pass
    config_bootloader
    refresh_keys
}

set_defaults
setup

# vim: fdm=syntax 
