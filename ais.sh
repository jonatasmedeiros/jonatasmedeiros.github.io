#!/bin/sh

# Arch Install Script
# by jonatasmedeiros
# License: GNU GPLv3

# array funcs {{{
array()
{
    for i
    do
        echo "$i"
    done
}

array_len()
{
    wc -l
}

array_nth()
{
    [ "$1" -ge 0 ] && sed -n $(($1 + 1))p
}

array_change() #{{{
{
    _cnt=-1
    echo "$1" | while IFS= read element
    do
        _cnt=$((_cnt + 1))
        [ $_cnt -eq $2 ] && echo "$3" || echo "$element"
    done
} #}}}

array_print_indexed() #{{{
{
    _cnt=0
    echo "$1" | while IFS= read element
    do
        _cnt=$((_cnt + 1))
        echo "${_cnt}) $element"
    done
} #}}}
#}}}

# GLOBAL VARIABLES {{{
EDITOR="vim"

keymap_list=$(array 'br-abnt2' 'us')
# coutries_code {{{
countries_code=$(array "AU" "AT" "BY" "BE" "BR" "BG" "CA" "CL" "CN" "CO" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HK" "HU" "ID" "IN" "IR" "IE" "IL" "IT" "JP" "KZ" "KR" "LV" "LU" "MK" "NL" "NC" "NZ" "NO" "PL" "PT" "RO" "RU" "RS" "SG" "SK" "ZA" "ES" "LK" "SE" "CH" "TW" "TR" "UA" "GB" "US" "UZ" "VN")
#}}}
# countries_name {{{
countries_name=$(array "Australia" "Austria" "Belarus" "Belgium" "Brazil" "Bulgaria" "Canada" "Chile" "China" "Colombia" "Czech Republic" "Denmark" "Estonia" "Finland" "France" "Germany" "Greece" "Hong Kong" "Hungary" "Indonesia" "India" "Iran" "Ireland" "Israel" "Italy" "Japan" "Kazakhstan" "Korea" "Latvia" "Luxembourg" "Macedonia" "Netherlands" "New Caledonia" "New Zealand" "Norway" "Poland" "Portugal" "Romania" "Russia" "Serbia" "Singapore" "Slovakia" "South Africa" "Spain" "Sri Lanka" "Sweden" "Switzerland" "Taiwan" "Turkey" "Ukraine" "United Kingdom" "United States" "Uzbekistan" "Viet Nam")
#}}}

# COLORS {{{
Bold=$(tput bold)
Underline=$(tput sgr 0 1)
Reset=$(tput sgr0)
# Regular Colors
Red=$(tput setaf 1)
Green=$(tput setaf 2)
Yellow=$(tput setaf 3)
Blue=$(tput setaf 4)
Purple=$(tput setaf 5)
Cyan=$(tput setaf 6)
White=$(tput setaf 7)
# Bold
BRed=${Bold}${Red}
BGreen=${Bold}${Green}
BYellow=${Bold}${Yellow}
BBlue=${Bold}${Blue}
BPurple=${Bold}${Purple}
BCyan=${Bold}${Cyan}
BWhite=${Bold}${White}
#}}}

# DESKTOP ENVIRONMENT{{{
CINNAMON=0
GNOME=0
KDE=0
#}}}

# MOUNTPOINTS {{{
EFI_MOUNTPOINT="/boot"
ROOT_MOUNTPOINT="/dev/sda1"
BOOT_MOUNTPOINT="/dev/sda"
MOUNTPOINT="/mnt"
#}}}

prompt1="Enter your option: "
checklist=$(array '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0' '0')
XPINGS=0 # CONNECTION CHECK
AUTOMATIC_MODE=0
TRIM=0
SPIN="/-\|" #SPINNER POSITION
ARCHI=`uname -m` # ARCHITECTURE
AUR=`echo "(${BPurple}aur${Reset})"`
EXTERNAL=`echo "(${BYellow}external${Reset})"`
AUI_DIR=`pwd` #CURRENT DIRECTORY
# LOGGING {{{
([ "$1" = "-v" ] || [ "$1" = "--verbose" ]) && VERBOSE_MODE=1 || VERBOSE_MODE=0 # VERBOSE MODE
LOG="${AUI_DIR}/${0}.log" # LOG FILE
[ -f $LOG ] && rm -f $LOG
PKG=""
PKG_FAIL="${AUI_DIR}/${0}_fail_install.log"
[ -f $PKG_FAIL ] && rm -f $PKG_FAIL
#}}}
#}}}

# UI functions {{{
print_line()
{
    printf "%$(tput cols)s\n" | tr ' ' '-'
}

print_title()
{
    clear
    print_line
    echo "# ${Bold}$1${Reset}"
    print_line
    echo
}

print_header()
{
    T_COLS=`tput cols`
    echo "${Bold}$1${Reset}" | fold -sw $(( $T_COLS - 18 )) | sed 's/^/\t/'
    echo
}

print_info()
{
    echo "${BBlue}$1${Reset}"
    echo
}

print_warning()
{
    T_COLS=`tput cols`
    echo "${BYellow}$1${Reset}" | fold -sw $(( $T_COLS - 1 ))
    echo
}

print_danger()
{
    T_COLS=`tput cols`
    echo "${BRed}$1${Reset}" | fold -sw $(( $T_COLS - 1 ))
    echo
}

checkbox()
{
    #display [X] or [ ]
    [ "$1" = "1" ] && echo "${BBlue}[${Reset}${Bold}X${BBlue}]${Reset}" || echo "${BBlue}[ ${BBlue}]${Reset}";
}

mainmenu_item()
{
    if [ "$1" = "1" -a "$3" != "" ]; then
        state="${BGreen}[${Reset}$3${BGreen}]${Reset}"
    fi
    echo "$(checkbox "$1") ${Bold}$2${Reset} ${state}"
}

read_key()
{
    stty_old=$(stty -g)
    if [ $1 -eq 0 ]; then
        stty raw -echo min 1 time 0
    else
        stty raw -echo min 0 time $1
    fi
    printf '%s' $(dd bs=1 count=1 2>/dev/null)
    stty $stty_old
}

pause_function()
{
    print_line
    if [ $AUTOMATIC_MODE -eq 0 ]; then
        printf "Press any key to continue..."
        continue_key=$(read_key 0)
    else
        printf "Press any key to continue (or wait 3s)..."
        continue_key=$(read_key 30)
    fi
    echo
    echo
}

invalid_option()
{
    print_warning "Invalid option. Try another one."
    pause_function
}

check_for_valid_input()
{
    case $1 in
        *[!0-9]*|'')
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}
#}}}

check_connection() #{{{
{
    while true # will exit when: ping is successfull, or user chooses option 3(Skip), or ping fails 3 times
    do
        XPINGS=$(($XPINGS + 1))
        WIRED_DEV=`ip link | grep "ens\|eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d'`
        WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`

        if ! ping -q -w 1 -c 1 `ip r | grep default | awk 'NR==1 {print $3}'`; then
            echo
            connection_opts=$(array 'Wired Automatic' 'Wireless' 'Skip')
            while true # will exit when: user inputs valid option
            do
                print_warning "ERROR! Connection not Found."
                print_header ":: Network Setup ::"
                array_print_indexed "$connection_opts"
                echo
                printf "$prompt1"
                read choice
                echo
                case "$choice" in
                    1)
                        systemctl start dhcpcd@${WIRED_DEV}.service
                        break
                        ;;
                    2)
                        wifi-menu ${WIRELESS_DEV}
                        break
                        ;;
                    3)
                        break
                        ;;
                    *)
                        invalid_option
                        ;;
                esac
            done
            if [ $XPINGS -gt 2 ]; then
                print_warning "Can't establish connection. exiting..."
                exit 1
            fi
            [ $choice -eq 3 ] && break
        else
            print_info "Connected!"
            break
        fi
    done
} #}}}

check_trim() #{{{
{
    if [ -n $(hdparm -I /dev/sda | grep TRIM ) ]; then
        TRIM=1
        echo
        print_info "Trimming supported!"
    else
        echo
        print_info "Trimming not supported!"
    fi
} #}}}

select_keymap() #{{{
{
    number_of_options=$(echo "$keymap_list" | array_len)
    while true # will exit when user inputs valid option
    do
        print_title "KEYMAP - https://wiki.archlinux.org/index.php/KEYMAP"
        print_header "The KEYMAP variable is specified in the /etc/rc.conf file. It defines what keymap the keyboard is in the virtual consoles. Keytable files are provided by the kbd package."

        echo "List of keymaps:"
        array_print_indexed "$keymap_list"
        echo
        echo "0) Go back"
        echo

        printf "$prompt1"
        read choice
        
        if check_for_valid_input "$choice"; then # input is valid
            if [ $choice -ge 1 -a $choice -le $number_of_options ]; then
                KEYMAP=$(echo "$keymap_list" | array_nth $((choice - 1)))
                loadkeys "$KEYMAP"
                print_info "Selected: $KEYMAP"
                pause_function
                break
            elif [ $choice -eq 0 ]; then
                break
            fi
        fi
        invalid_option
    done
} #}}}

configure_mirrorlist() #{{{
{
    number_of_options=$(echo "$countries_name" | array_len)
    while true # will exit when user inputs valid option
    do
        print_title "MIRRORLIST - https://wiki.archlinux.org/index.php/Mirrors"
        print_header "This option is a guide to selecting and configuring your mirrors, and a listing of current available mirrors."

        echo "Select your country:"
        array_print_indexed "$countries_name" | column
        echo
        echo "0) Go back"
        echo

        printf "$prompt1"
        read choice
        
        if check_for_valid_input "$choice"; then # input is valid
            if [ $choice -ge 1 -a $choice -le $number_of_options ]; then
                country_code="$(echo "$countries_code" | array_nth $((choice - 1)))"
                country_name="$(echo "$countries_name" | array_nth $((choice - 1)))"
                print_info "Selected: $country_name ($country_code)"
                pause_function
                break
            elif [ $choice -eq 0 ]; then
                break
            fi
        fi
        invalid_option
    done

    [ $choice -eq 0 ] && return

    url="https://www.archlinux.org/mirrorlist/?country=${country_code}&use_mirror_status=on"
    tmpfile=$(mktemp --suffix=-mirrorlist)

    # Get latest mirror list and save to tmpfile
    print_header ":: Downloading latest mirror list ::"
    curl -o ${tmpfile} ${url}
    echo
    sed -i 's/^#Server/Server/g' ${tmpfile}

    # Backup and replace current mirrorlist file (if new file is non-zero)
    if [ -s ${tmpfile} ]; then
        mv -i /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig &&
        mv -i ${tmpfile} /etc/pacman.d/mirrorlist &&
        print_info "Mirrorlist updated"
    else
        print_warning "Unable to update! Could not download list."
    fi
    
    # better repo should go first
    print_header ":: Downloading rankmirrors package ::"
    pacman --noconfirm --needed -S pacman-contrib
    echo
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.tmp
    print_header ":: Ranking mirrors ::"
    rankmirrors /etc/pacman.d/mirrorlist.tmp > /etc/pacman.d/mirrorlist
    rm /etc/pacman.d/mirrorlist.tmp
    # allow global read access (required for non-root yaourt execution)
    chmod +r /etc/pacman.d/mirrorlist
    echo
    print_info "Mirror list:"
    cat /etc/pacman.d/mirrorlist
    echo
    pause_function
}
#}}}

finish() #{{{
{
    print_title "INSTALL COMPLETED"
    #COPY AUI TO ROOT FOLDER IN THE NEW SYSTEM
    echo
    print_warning "A copy of the AUI will be placed in /root directory of your new system"
    #cp -R `pwd` ${MOUNTPOINT}/root
    #read_input_text "Reboot system"
    #if [[ $OPTION == y ]]; then
        #umount_partitions
        #reboot
    #fi
    exit 0
} #}}}

# inital checks {{{
print_title "Arch Install Scripts - by Jonatas Medeiros"
print_header "The AIS are a custom set of shell scripts that provide a tailored Arch installation."
pause_function
print_header ":: Checking connection ::"
check_connection
print_header ":: Checking disk ::"
check_trim
print_header ":: Updating repositories ::"
pacman -Sy
echo
pause_function
#}}}

# main loop {{{
while true
do
    print_title "ARCHLINUX INSTALL SCRIPT- https://github.com/jontasmedeiros/ais"
    echo " 1) $(mainmenu_item "$(echo "$checklist" | array_nth 0)"  "Select Keymap"            "${KEYMAP}" )"
    echo " 2) $(mainmenu_item "$(echo "$checklist" | array_nth 1)"  "Configure Mirrorlist"     "${country_name} (${country_code})" )"
    echo " 4) $(mainmenu_item "$(echo "$checklist" | array_nth 3)"  "Partition Scheme"         "${partition_layout}: ${partition}(${filesystem}) swap(${swap_type})" )"
    echo " 5) $(mainmenu_item "$(echo "$checklist" | array_nth 4)"  "Install Base System")"
    echo " 6) $(mainmenu_item "$(echo "$checklist" | array_nth 5)"  "Configure Fstab"          "${fstab}" )"
    echo " 7) $(mainmenu_item "$(echo "$checklist" | array_nth 6)"  "Configure Hostname"       "${host_name}" )"
    echo " 8) $(mainmenu_item "$(echo "$checklist" | array_nth 7)"  "Configure Timezone"       "${ZONE}/${SUBZONE}" )"
    echo " 9) $(mainmenu_item "$(echo "$checklist" | array_nth 8)"  "Configure Hardware Clock" "${hwclock}" )"
    echo "10) $(mainmenu_item "$(echo "$checklist" | array_nth 9)" "Configure Locale"         "${LOCALE}" )"
    echo "11) $(mainmenu_item "$(echo "$checklist" | array_nth 10)" "Configure Mkinitcpio")"
    echo "12) $(mainmenu_item "$(echo "$checklist" | array_nth 11)" "Install Bootloader"       "${bootloader}" )"
    echo "13) $(mainmenu_item "$(echo "$checklist" | array_nth 12)" "Root Password")"
    echo ""
    echo " d) Done"
    echo ""

    printf "$prompt1"
    read OPT
    case "$OPT" in
        1)
            select_keymap
            checklist=$(array_change "$checklist" 0 "1")
            ;;
        2)
            configure_mirrorlist
            checklist=$(array_change "$checklist" 1 "1")
            ;;
        3)
            checklist=$(array_change "$checklist" 2 "1")
            ;;
        4)
#        umount_partitions
#        create_partition_scheme
#        format_partitions
            checklist=$(array_change "$checklist" 3 "1")
            ;;
        5)
#        install_base_system
#        configure_keymap
            checklist=$(array_change "$checklist" 4 "1")
            ;;
        6)
#        configure_fstab
            checklist=$(array_change "$checklist" 5 "1")
            ;;
        7)
#        configure_hostname
            checklist=$(array_change "$checklist" 6 "1")
            ;;
        8)
#        configure_timezone
            checklist=$(array_change "$checklist" 7 "1")
            ;;
        9)
#        configure_hardwareclock
            checklist=$(array_change "$checklist" 8 "1")
            ;;
        10)
#        configure_locale
            checklist=$(array_change "$checklist" 9 "1")
            ;;
        11)
#        configure_mkinitcpio
            checklist=$(array_change "$checklist" 10 "1")
            ;;
        12)
#        install_bootloader
#        configure_bootloader
            checklist=$(array_change "$checklist" 11 "1")
            ;;
        13)
#        root_password
            checklist=$(array_change "$checklist" 12 "1")
            ;;
        "d")
            finish
            ;;
        *)
            invalid_option
            ;;
    esac
done
##}}}
