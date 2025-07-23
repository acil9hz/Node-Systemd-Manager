#!/bin/bash

# warna
RED=''
GREEN=''
YELLOW=''
BLUE='\033[0;34m'
NC='' # No Color

# header
show_header() {
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}      Node.js Service Manager By Datalogger@2025     ${NC}"
    echo -e "${BLUE}=====================================================${NC}"
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
    
    printf "%-30s | %s%-10s%s | %s%-10s%s\n" \
        "$service_name" \
        "$status_color" "$status_text" "$NC" \
        "$enabled_color" "$enabled_text" "$NC"
}

# list services
list_services() {
    echo -e "${BLUE}Daftar Service Node.js:${NC}"
    echo "==================================================================================================="
    printf "%-3s | %-30s | %-10s | %-10s\n" "NO" "SERVICE NAME" "STATUS" "AUTOSTART"
    echo "---------------------------------------------------------------------------------------------------"
    
    local services=$(get_node_services)
    if [[ -z "$services" ]]; then
        echo -e "${YELLOW}Tidak ada service Node.js yang ditemukan${NC}"
        return
    fi
    
    local counter=1
    echo "$services" | while read -r service; do
        [[ -z "$service" ]] && continue
        
        local status=$(systemctl is-active "$service" 2>/dev/null)
        local enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        
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
        
        printf "%-3s | %-30s | %s%-10s%s | %s%-10s%s\n" \
            "$counter" "$service" \
            "$status_color" "$status_text" "$NC" \
            "$enabled_color" "$enabled_text" "$NC"
        
        ((counter++))
    done
    echo
}

# show detail service
show_service_detail() {
    local service_name=$(clean_string "$1")
    
    echo -e "${BLUE}Detail Service: $service_name${NC}"
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
        echo -e "${RED}Error: Nama service tidak valid${NC}"
        return 1
    fi
    
    # Debug: tampilkan nama service yang akan diproses
    echo -e "${YELLOW}Debug: Processing service: '$service_name'${NC}"
    
    case $action in
        "start")
            echo -e "${BLUE}Memulai service $service_name...${NC}"
            sudo systemctl start "$service_name"
            ;;
        "stop")
            echo -e "${BLUE}Menghentikan service $service_name...${NC}"
            sudo systemctl stop "$service_name"
            ;;
        "restart")
            echo -e "${BLUE}Merestart service $service_name...${NC}"
            sudo systemctl restart "$service_name"
            ;;
        "enable")
            echo -e "${BLUE}Mengaktifkan autostart untuk $service_name...${NC}"
            sudo systemctl enable "$service_name"
            ;;
        "disable")
            echo -e "${BLUE}Menonaktifkan autostart untuk $service_name...${NC}"
            sudo systemctl disable "$service_name"
            ;;
        "reload")
            echo -e "${BLUE}Mereload konfigurasi service $service_name...${NC}"
            sudo systemctl daemon-reload
            sudo systemctl reload-or-restart "$service_name"
            ;;
        *)
            echo -e "${RED}Aksi tidak dikenal: $action${NC}"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}? Berhasil${NC}"
    else
        echo -e "${RED}? Gagal (exit code: $result)${NC}"
    fi
    echo
}

# Fungsi untuk menampilkan log realtime
show_logs() {
    local service_name=$(clean_string "$1")
    echo -e "${BLUE}Log realtime untuk $service_name (Ctrl+C untuk keluar):${NC}"
    echo "============================================================"
    journalctl -u "$service_name" -f
}

# Fungsi untuk membuat service baru
create_service() {
    echo -e "${BLUE}Membuat Service Baru${NC}"
    echo "============================================================"
    
    read -p "Nama service: " service_name
    read -p "Path ke aplikasi Node.js: " app_path
#    read -p "Working directory: " work_dir
#    read -p "User untuk menjalankan service: " service_user
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
    echo -e "${BLUE}Pilih aksi:${NC}"
    echo "1. Show service"
    echo "2. Manage service (start/stop/restart/enable/disable)"
    echo "3. Show detail service"
    echo "4. Show log realtime"
    echo "5. Create new service"
    echo "6. Delete service"
    echo "7. Reload all service"
    echo "8. Exit"
    echo
}

# select service
select_service() {
    # Dapatkan daftar service yang bersih
    local services_raw
    services_raw=$(systemctl list-unit-files --type=service --no-pager --plain --no-legend | grep -E "node|parsing" | grep -v "@" | awk '{print $1}' | sort)
    
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
    echo -e "${BLUE}Pilih service:${NC}" >&2
    for i in "${!service_array[@]}"; do
        printf "%2d. %s\n" "$((i+1))" "${service_array[i]}" >&2
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
        echo -e "${RED}Pilihan tidak valid. Masukkan nomor 1-$count${NC}" >&2
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
                echo -e "${BLUE}=== KELOLA SERVICE ===${NC}"
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    echo
                    echo -e "${BLUE}Service yang dipilih: ${GREEN}$selected_service${NC}"
                    echo -e "${BLUE}Pilih aksi:${NC}"
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
                create_service
                ;;
            6)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    remove_service "$selected_service"
                else
                    echo -e "${RED}Service tidak dipilih atau tidak valid${NC}"
                fi
                ;;
            7)
                echo -e "${BLUE}Mereload semua service...${NC}"
                sudo systemctl daemon-reload
                echo -e "${GREEN}? Berhasil${NC}"
                echo
                ;;
            8)
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
