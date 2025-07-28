#!/bin/bash

# warna - Fixed for Debian 12
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
NC='\e[0m' # No Color

# Fungsi untuk output berwarna yang lebih kompatibel
print_color() {
    local color=$1
    local text=$2
    # Cek apakah terminal mendukung warna
    if [[ -t 1 ]] && { command -v tput >/dev/null 2>&1; } && { tput colors >/dev/null 2>&1; } && [[ $(tput colors) -ge 8 ]]; then
        case $color in
            "red") tput setaf 1; echo -n "$text"; tput sgr0 ;;
            "green") tput setaf 2; echo -n "$text"; tput sgr0 ;;
            "yellow") tput setaf 3; echo -n "$text"; tput sgr0 ;;
            "blue") tput setaf 4; echo -n "$text"; tput sgr0 ;;
            *) echo -n "$text" ;;
        esac
    else
        # Fallback: gunakan ANSI escape codes
        case $color in
            "red") printf '\e[0;31m%s\e[0m' "$text" ;;
            "green") printf '\e[0;32m%s\e[0m' "$text" ;;
            "yellow") printf '\e[0;33m%s\e[0m' "$text" ;;
            "blue") printf '\e[0;34m%s\e[0m' "$text" ;;
            *) printf '%s' "$text" ;;
        esac
    fi
}

# header
show_header() {
    print_color "green" "====================================================="
    echo
    echo "      Node.js Service Manager V.1.1 By Datalogger@2025     "
    print_color "green" "====================================================="
    echo
    echo
}

# get list service
get_node_services() {
    systemctl list-unit-files --type=service --no-pager --plain --no-legend | grep -E "parsing" | grep -v "@" | awk '{print $1}' | sort
}

# clean string ansi
clean_string() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\n\r'
}

# show status services
show_service_status() {
    local service_name=$1
    local status=$(systemctl is-active "$service_name" 2>/dev/null)
    local enabled=$(systemctl is-enabled "$service_name" 2>/dev/null)
    
    if [[ $status == "active" ]]; then
        status_color=$GREEN
        status_text="RUNNING"
    else
        status_color=$RED
        status_text="STOPPED"
    fi
    
    if [[ $enabled == "enabled" ]]; then
        enabled_color=$GREEN
        enabled_text="AUTO"
    else
        enabled_color=$YELLOW
        enabled_text="MANUAL"
    fi
    
    printf "%-30s | %-10s%s | %-10s\n" \
        "$service_name" \
        "$status_color" "$status_text" "$NC" \
        "$enabled_color" "$enabled_text" "$NC"
}

# list services
list_services() {
    print_color "green" "Daftar Service Node.js:"
    echo
    echo "==================================================================================================="
    printf "%-3s | %-30s | %-10s | %-10s\n" "NO" "SERVICE NAME" "STATUS" "AUTOSTART"
    echo "---------------------------------------------------------------------------------------------------"
    
    local services=$(get_node_services)
    if [[ -z "$services" ]]; then
        print_color "yellow" "Tidak ada service Node.js yang ditemukan"
        echo
        return
    fi
    
    local counter=1
    echo "$services" | while read -r service; do
        [[ -z "$service" ]] && continue
        
        local status=$(systemctl is-active "$service" 2>/dev/null)
        local enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        
        local status_text=""
        local enabled_text=""
        
        if [[ $status == "active" ]]; then
            status_text="RUNNING"
        else
            status_text="STOPPED"
        fi
        
        if [[ $enabled == "enabled" ]]; then
            enabled_text="AUTO"
        else
            enabled_text="MANUAL"
        fi
        
        # Print basic info first
        printf "%-3s | %-30s | " "$counter" "$service"
        
        # Print colored status
        if [[ $status == "active" ]]; then
            print_color "green" "$status_text"
        else
            print_color "red" "$status_text"
        fi
        
        printf " | "
        
        # Print colored autostart
        if [[ $enabled == "enabled" ]]; then
            print_color "green" "$enabled_text"
        else
            print_color "yellow" "$enabled_text"
        fi
        
        echo
        ((counter++))
    done
    echo
}

# show detail service
show_service_detail() {
    local service_name=$(clean_string "$1")
    
    echo -e "${GREEN}Detail Service: $service_name${NC}"
    echo "============================================================"
    
    # Status dasar
    echo -e "${YELLOW}Status:${NC}"
    systemctl status "$service_name" --no-pager -l
    echo
    
    # Lokasi file service
    echo -e "${YELLOW}Lokasi file service:${NC}"
    systemctl show "$service_name" -p FragmentPath --no-pager
    echo
    
    # Log terakhir
    echo -e "${YELLOW}Log terakhir (10 baris):${NC}"
    journalctl -u "$service_name" -n 10 --no-pager
    echo
}

# manage service
manage_service() {
    local action=$1
    local service_name=$(clean_string "$2")
    
    # validasi input
    if [[ -z "$service_name" ]]; then
        print_color "red" "Error: Nama service tidak valid"
        echo
        return 1
    fi
    
    # Debug: tampilkan nama service yang akan diproses
    print_color "yellow" "Debug: Processing service: '$service_name'"
    echo
    
    case $action in
        "start")
            print_color "green" "Memulai service $service_name..."
            echo
            sudo systemctl start "$service_name"
            ;;
        "stop")
            print_color "red" "Menghentikan service $service_name..."
            echo
            sudo systemctl stop "$service_name"
            ;;
        "restart")
            print_color "yellow" "Merestart service $service_name..."
            echo
            sudo systemctl restart "$service_name"
            ;;
        "enable")
            print_color "green" "Mengaktifkan autostart untuk $service_name..."
            echo
            sudo systemctl enable "$service_name"
            ;;
        "disable")
            print_color "red" "Menonaktifkan autostart untuk $service_name..."
            echo
            sudo systemctl disable "$service_name"
            ;;
        "reload")
            print_color "yellow" "Mereload konfigurasi service $service_name..."
            echo
            sudo systemctl daemon-reload
            sudo systemctl reload-or-restart "$service_name"
            ;;
        *)
            print_color "red" "Aksi tidak dikenal: $action"
            echo
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        print_color "green" "? Berhasil"
        echo
    else
        print_color "red" "? Gagal (exit code: $result)"
        echo
    fi
    echo
}

# Fungsi untuk menampilkan log realtime
show_logs() {
    local service_name=$(clean_string "$1")
    echo -e "${GREEN}Log realtime untuk $service_name (Ctrl+C untuk keluar):${NC}"
    echo "============================================================"
    journalctl -u "$service_name" -f
}

# Fungsi untuk menampilkan log dengan filter waktu
show_logs_since() {
    local service_name=$(clean_string "$1")
    
    echo -e "${GREEN}Pilihan waktu untuk log $service_name:${NC}"
    echo "1. 1 jam terakhir"
    echo "2. 3 jam terakhir" 
    echo "3. 6 jam terakhir"
    echo "4. 12 jam terakhir"
    echo "5. 24 jam terakhir (1 hari)"
    echo "6. 3 hari terakhir"
    echo "7. 7 hari terakhir (1 minggu)"
    echo "8. Custom (format: YYYY-MM-DD HH:MM:SS atau today, yesterday)"
    echo
    
    read -p "Pilih opsi (1-8): " time_choice
    echo
    
    local since_param=""
    case $time_choice in
        1) since_param="1 hour ago" ;;
        2) since_param="3 hours ago" ;;
        3) since_param="6 hours ago" ;;
        4) since_param="12 hours ago" ;;
        5) since_param="1 day ago" ;;
        6) since_param="3 days ago" ;;
        7) since_param="1 week ago" ;;
        8) 
            read -p "Masukkan waktu custom (contoh: '2025-01-01 10:00:00' atau 'today' atau 'yesterday'): " custom_time
            since_param="$custom_time"
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Log untuk $service_name sejak: $since_param${NC}"
    echo "============================================================"
    
    # Tampilkan log dengan parameter --since
    journalctl -u "$service_name" --since "$since_param" --no-pager
    
    echo
    echo -e "${BLUE}--- End of logs ---${NC}"
    echo
}

# Fungsi untuk membuat service baru
create_service() {
    echo -e "${GREEN}Membuat Service Baru${NC}"
    echo "============================================================"
    
    read -p "Nama service: " service_name
    read -p "Path ke aplikasi Node.js: " app_path
    read -p "Deskripsi service: " description 
    
    # Validasi input
    if [[ -z "$service_name" ]] || [[ -z "$app_path" ]] ; then
        echo -e "${RED}Error: Semua field harus diisi${NC}"
        return 1
    fi
    
    # Buat file service
    cat > /tmp/${service_name}.service << EOF
[Unit]
Description=$description
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/node $app_path
RemainAfterExit=no
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Copy ke direktori systemd
    sudo cp /tmp/${service_name}.service /lib/systemd/system/
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}? Service $service_name berhasil dibuat${NC}"
    echo -e "${YELLOW}Untuk mengaktifkan: sudo systemctl enable $service_name${NC}"
    echo -e "${YELLOW}Untuk memulai: sudo systemctl start $service_name${NC}"
    echo
}

# Fungsi untuk menghapus service
remove_service() {
    local service_name=$(clean_string "$1")
    
    echo -e "${YELLOW}Apakah Anda yakin ingin menghapus service $service_name? (y/N)${NC}"
    read -r confirmation
    
    if [[ $confirmation == "y" ]] || [[ $confirmation == "Y" ]]; then
        sudo systemctl stop "$service_name" 2>/dev/null
        sudo systemctl disable "$service_name" 2>/dev/null
        sudo rm -f "/lib/systemd/system/$service_name"
        sudo systemctl daemon-reload
        echo -e "${GREEN}? Service $service_name berhasil dihapus${NC}"
    else
        echo -e "${BLUE}Penghapusan dibatalkan${NC}"
    fi
    echo
}

# Menu utama
show_menu() {
    print_color "green" "Pilih aksi:"
    echo
    echo "1. Show service"
    echo "2. Manage service (start/stop/restart/enable/disable)"
    echo "3. Show detail service"
    echo "4. Show log realtime"
    echo "5. Show log dengan filter waktu"
    echo "6. Create new service"
    echo "7. Delete service"
    echo "8. Reload all service"
    echo "9. Exit"
    echo
}

# select service - OPTIMIZED VERSION
select_service() {
    # Gunakan fungsi get_node_services yang sudah ada
    local services_raw=$(get_node_services)
    
    if [[ -z "$services_raw" ]]; then
        echo -e "${RED}Tidak ada service yang ditemukan${NC}" >&2
        return 1
    fi
    
    # Buat array untuk menyimpan service
    local service_array=()
    
    # Baca setiap baris ke dalam array
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Trim whitespace dan pastikan bersih
            line=$(echo "$line" | xargs)
            if [[ -n "$line" ]]; then
                service_array+=("$line")
            fi
        fi
    done <<< "$services_raw"
    
    if [[ ${#service_array[@]} -eq 0 ]]; then
        echo -e "${RED}Tidak ada service yang valid ditemukan${NC}" >&2
        return 1
    fi
    
    # Tampilkan pilihan service ke stderr agar tidak tercampur dengan return value
    print_color "green" "Pilih service:" >&2
    for i in "${!service_array[@]}"; do
        # Tampilkan juga status service untuk memudahkan pemilihan
        local status=$(systemctl is-active "${service_array[i]}" 2>/dev/null)
        local status_text=""
        if [[ $status == "active" ]]; then
            status_text="[RUNNING]"
            printf "%2d. %-30s " "$((i+1))" "${service_array[i]}" >&2
            print_color "green" "$status_text" >&2
        else
            status_text="[STOPPED]"
            printf "%2d. %-30s " "$((i+1))" "${service_array[i]}" >&2
            print_color "red" "$status_text" >&2
        fi
        echo >&2
    done
    echo >&2
    
    local count=${#service_array[@]}
    read -p "Masukkan nomor (1-$count): " choice >&2
    
    # Validasi input - hanya angka
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le $count ]]; then
        # Output HANYA nama service ke stdout (untuk capture)
        echo "${service_array[$((choice-1))]}"
        return 0
    else
        print_color "red" "Pilihan tidak valid. Masukkan nomor 1-$count" >&2
        return 1
    fi
}

# Loop utama
main() {
    show_header
    
    while true; do
        show_menu
        read -p "Pilihan : " choice
        echo
        
        case $choice in
            1)
                list_services
                ;;
            2)
                echo -e "${GREEN}=== KELOLA SERVICE ===${NC}"
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    echo
                    echo -e "${GREEN}Service yang dipilih: ${GREEN}$selected_service${NC}"
                    echo -e "${GREEN}Pilih aksi:${NC}"
                    echo "1. Start   2. Stop   3. Restart   4. Enable   5. Disable   6. Reload"
                    read -p "Pilih aksi (1-6): " action_choice
                    echo
                    
                    case $action_choice in
                        1) manage_service "start" "$selected_service" ;;
                        2) manage_service "stop" "$selected_service" ;;
                        3) manage_service "restart" "$selected_service" ;;
                        4) manage_service "enable" "$selected_service" ;;
                        5) manage_service "disable" "$selected_service" ;;
                        6) manage_service "reload" "$selected_service" ;;
                        *) echo -e "${RED}Pilihan tidak valid. Masukkan nomor 1-6${NC}" ;;
                    esac
                else
                    echo -e "${RED}Service tidak dipilih atau tidak valid${NC}"
                fi
                ;;
            3)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    show_service_detail "$selected_service"
                else
                    echo -e "${RED}Service tidak dipilih atau tidak valid${NC}"
                fi
                ;;
            4)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    show_logs "$selected_service"
                else
                    echo -e "${RED}Service tidak dipilih atau tidak valid${NC}"
                fi
                ;;
            5)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    show_logs_since "$selected_service"
                else
                    echo -e "${RED}Service tidak dipilih atau tidak valid${NC}"
                fi
                ;;
            6)
                create_service
                ;;
            7)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    remove_service "$selected_service"
                else
                    echo -e "${RED}Service tidak dipilih atau tidak valid${NC}"
                fi
                ;;
            8)
                echo -e "${BLUE}Mereload semua service...${NC}"
                sudo systemctl daemon-reload
                echo -e "${GREEN}? Berhasil${NC}"
                echo
                ;;
            9)
                echo -e "${BLUE}Terima kasih telah menggunakan Node.js Service Manager!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid${NC}"
                echo
                ;;
        esac
        
        read -p "Tekan Enter untuk melanjutkan..."
        clear
        show_header
    done
}

# Jalankan script
main