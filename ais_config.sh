#!/bin/sh

set_defaults()
{
    # Terminal font 
    Bold=$(tput bold)
    Reset=$(tput sgr0)
    Cyan=$(tput setaf 6)

    title="AIS Configuration - Archlinux Installation Script - jonatasmedeiros.com/ais.sh"
    dotfiles_repo="https://github.com/jonatasmedeiros/dotfiles.git"
    mozzilarbs_repo="https://github.com/LukeSmithxyz/mozillarbs.git"
    progs_file="https://raw.githubusercontent.com/jonatasmedeiros/ais/master/progs.csv"
    aur_helper="yay"
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
    printf "  ${Bold}${title}${Reset}\n"
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
    sleep 1
    printf "\n"
    print_line
    if [ "$1" = "" ]; then
        printf "Press any key to continue (q to quit)..."
    else
        printf "$1"
    fi
    continue_key=$(read_key)
    if [ "$continue_key" = "q" ]; then
        printf "\nExiting AIS...\n"
        exit 1
    fi
    print_title "$title"
}

create_user()
{
    print_bold ":: Create user"
    while true
    do
        printf "Enter the name of the user: "
        read user_name

        if [ "${user_name}" != "" ]; then
            break
        fi
    done
    printf "\n"

    print_command "useradd -m -g wheel ${user_name}"
    useradd -m -g wheel "${user_name}"
    wait_key
}

set_user_password()
{
    while true
    do
        print_bold ":: Set ${user_name} password"
        print_command "passwd ${user_name}"
        passwd ${user_name}
        if [ $? -eq 0 ]; then
            break
        fi
        wait_key "Press any key to retry (q to quit)..."
    done
    wait_key
}

refresh_keys()
{
    print_bold ":: Refreshing Arch keyring"
    print_command "pacman --noconfirm -Sy archlinux-keyring"
	pacman --noconfirm -Sy archlinux-keyring
    wait_key
}

install_git()
{
    print_bold ":: Installing git"
    print_command "pacman --noconfirm --needed -S git"
    pacman --noconfirm --needed -S git
    wait_key
}

new_perms()
{ # Set special sudoers settings for install (or after).
	sed -i "/#AIS/d" /etc/sudoers
	echo "$* #AIS" >> /etc/sudoers
}

update_makepkg()
{
    print_bold ":: Updating makepkg"
    print_command "sed -i \"s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/\" /etc/makepkg.conf"
    sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
    wait_key
}

install_aur_helper()
{
    print_bold ":: Install ${aur_helper}, an AUR helper."
    print_command "cd /tmp"
    cd /tmp
    printf "\n"

    print_command "rm -rfv /tmp/${aur_helper}*"
	rm -rfv /tmp/${aur_helper}*
    printf "\n"

    print_command "curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/${aur_helper}.tar.gz"
	curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/${aur_helper}.tar.gz
    printf "\n"

    print_command "sudo -u ${user_name} tar -xvf ${aur_helper}.tar.gz"
	sudo -u ${user_name} tar -xvf ${aur_helper}.tar.gz
    printf "\n"

    print_command "cd ${aur_helper}"
	cd ${aur_helper}
    printf "\n"

    print_command "sudo -u ${user_name} makepkg --noconfirm -si"
	sudo -u ${user_name} makepkg --noconfirm -si
    wait_key
}

main_install()
{
    print_bold ":: Install \`${1}\` (${n} of ${total})."
    printf "\t${1} ${2}\n\n"
    sleep 1

    print_command "pacman --noconfirm --needed -S ${1}"
	pacman --noconfirm --needed -S ${1}
    printf "\n"
    sleep 2
}

aur_install()
{
    print_bold ":: Install \`${1}\` (${n} of ${total}) from the AUR."
    printf "\t${1} ${2}\n\n"
    sleep 1

    print_command "sudo -u ${user_name} $aur_helper -S --noconfirm ${1}"
	sudo -u ${user_name} $aur_helper -S --noconfirm ${1}
    printf "\n"
    sleep 2
}

git_make_install()
{
	dir=$(mktemp -d)
    print_bold ":: Install \`$(basename "${1}")\` ($n of ${total}) with \`git\` and \`make\`."
    printf "\t$(basename "${1}") $2\n\n"
    sleep 1

    print_command "git clone --depth 1 ${1} ${dir}"
	git clone --depth 1 ${1} ${dir}
    printf "\n"
    
    print_command "cd ${dir}"
	cd ${dir}
    printf "\n"

    print_command "make"
	make
    printf "\n"

    print_command "make install"
	make install
    printf "\n"

    print_command "cd /tmp"
	cd /tmp
    sleep 2
}

pip_install()
{	
    print_bold ":: Install the Python package \`${1}\` ($n of $total)."
    printf "\t${1} ${2}\n\n"
    sleep 1

    if ! command -v pip; then
        print_bold ":: Install python-pip"
        print_command "pacman -S --noconfirm --needed python-pip"
        pacman -S --noconfirm --needed python-pip
        printf "\n"
    fi
    print_command "yes | pip install ${1}"
	yes | pip install ${1}
    printf "\n"
    sleep 2
}

installation_loop()
{
    print_bold ":: Install programs"
    print_command "cd /tmp"
    cd /tmp
    printf "\n"

    print_command "curl ${progs_file} | sed \'/^#/d\' > /tmp/progs.csv"
    curl ${progs_file} | sed '/^#/d' > /tmp/progs.csv
    printf "\n"

	total=$(wc -l < /tmp/progs.csv)
	aur_installed=$(pacman -Qm | awk '{print $1}')
    n=0
	while IFS=, read -r tag program comment
    do
		n=$((n + 1))
		echo "${comment}" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"") main_install "$program" "$comment" ;;
			"A") aur_install "$program" "$comment" ;;
			"G") git_make_install "$program" "$comment" ;;
			"P") pip_install "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv
    wait_key
}

put_git_repo()
{
    print_bold ":: Downloading config files"
	dir=$(mktemp -d)
    if [ ! -d ${2} ]; then
        print_command "mkdir -pv ${2}"
        mkdir -pv ${2}
        printf "\n"

        print_command "chown -R ${user_name}:wheel ${2}"
        chown -R ${user_name}:wheel ${2}
        printf "\n"
    fi
    print_command "chown -R ${user_name}:wheel ${dir}"
	chown -R ${user_name}:wheel ${dir}
    printf "\n"

    print_command "sudo -u ${user_name} git clone --depth 1 ${1} ${dir}/gitrepo"
	sudo -u ${user_name} git clone --depth 1 ${1} ${dir}/gitrepo
    printf "\n"

    print_command "sudo -u ${user_name} cp -rfT ${dir}/gitrepo ${2}"
	sudo -u ${user_name} cp -rfT ${dir}/gitrepo ${2}
    wait_key
}

system_beep_off()
{
    print_bold ":: Disabling beep sound"
    print_command "rmmod pcspkr"
	rmmod pcspkr
    printf "\n"

    print_command "echo \"blacklist pcspkr\" > /etc/modprobe.d/nobeep.conf"
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
    sleep 1
}

finalize()
{
    print_bold ":: Finalizing"

    print_command "rm -fv /home/${user_name}/README.md /home/${user_name}/LICENSE"
    rm -fv "/home/${user_name}/README.md" "/home/${user_name}/LICENSE"
    printf "\n"
    
    system_beep_off

    new_perms "%wheel ALL=(ALL) ALL #AIS\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

    prin_bold ":: Configuration finished"
    wait_key "Press any key to exit..."
    clear
}

setup()
{
    print_title
    create_user
    set_user_password
    refresh_keys
    install_git
    new_perms "%wheel ALL=(ALL) NOPASSWD: ALL"
    update_makepkg
    install_aur_helper

    installation_loop

    put_git_repo "$dotfiles_repo" "/home/${user_name}"
    put_git_repo "$mozzilarbs_repo" "/home/${user_name}/.mozilla/firefox"

    finalize
}

set_defaults
setup
