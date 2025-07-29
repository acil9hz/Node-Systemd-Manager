#!/bin/bash

# header
show_header() {
    echo "====================================================="
    echo "      Node.js Service Manager V.1.2 By Datalogger@2025     "
    echo "====================================================="
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
        status_text="RUNNING"
    else
        status_text="STOPPED"
    fi
    
    if [[ $enabled == "enabled" ]]; then
        enabled_text="AUTO"
    else
        enabled_text="MANUAL"
    fi
    
    printf "%-30s | %-10s | %-10s\n" \
        "$service_name" \
        "$status_text" \
        "$enabled_text"
}

# list services
list_services() {
    echo "Daftar Service Node.js:"
    echo "========================================================================="
    printf "%-3s | %-30s | %-10s | %-10s\n" "NO" "SERVICE NAME" "STATUS" "AUTOSTART"
    echo "-------------------------------------------------------------------------"
    
    local services=$(get_node_services)
    if [[ -z "$services" ]]; then
        echo "Tidak ada service Node.js yang ditemukan"
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
        
        printf "%-3s | %-30s | %-10s | %-10s\n" \
            "$counter" "$service" \
            "$status_text" \
            "$enabled_text"
        
        ((counter++))
    done
    echo
}

# show detail service
show_service_detail() {
    local service_name=$(clean_string "$1")
    
    echo "Detail Service: $service_name"
    echo "============================================================"
    
    # Status dasar
    echo "Status:"
    systemctl status "$service_name" --no-pager -l
    echo
    
    # Lokasi file service
    echo "Lokasi file service:"
    systemctl show "$service_name" -p FragmentPath --no-pager
    echo
    
    # Log terakhir
    echo "Log terakhir (10 baris):"
    journalctl -u "$service_name" -n 10 --no-pager
    echo
}

# manage service
manage_service() {
    local action=$1
    local service_name=$(clean_string "$2")
    
    # validasi input
    if [[ -z "$service_name" ]]; then
        echo "Error: Nama service tidak valid"
        return 1
    fi
    
    # Debug: tampilkan nama service yang akan diproses
    echo "Debug: Processing service: '$service_name'"
    
    case $action in
        "start")
            echo "Memulai service $service_name..."
            sudo systemctl start "$service_name"
            ;;
        "stop")
            echo "Menghentikan service $service_name..."
            sudo systemctl stop "$service_name"
            ;;
        "restart")
            echo "Merestart service $service_name..."
            sudo systemctl restart "$service_name"
            ;;
        "enable")
            echo "Mengaktifkan autostart untuk $service_name..."
            sudo systemctl enable "$service_name"
            ;;
        "disable")
            echo "Menonaktifkan autostart untuk $service_name..."
            sudo systemctl disable "$service_name"
            ;;
        "reload")
            echo "Mereload konfigurasi service $service_name..."
            sudo systemctl daemon-reload
            sudo systemctl reload-or-restart "$service_name"
            ;;
        *)
            echo "Aksi tidak dikenal: $action"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "✓ Berhasil"
    else
        echo "✗ Gagal (exit code: $result)"
    fi
    echo
}

# Fungsi untuk menampilkan log realtime
show_logs() {
    local service_name=$(clean_string "$1")
    echo "Log realtime untuk $service_name (Ctrl+C untuk keluar):"
    echo "============================================================"
    journalctl -u "$service_name" -f
}

# Fungsi untuk menampilkan log dengan filter waktu
show_logs_since() {
    local service_name=$(clean_string "$1")
    
    echo "Pilihan waktu untuk log $service_name:"
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
            echo "Pilihan tidak valid"
            return 1
            ;;
    esac
    
    echo "Log untuk $service_name sejak: $since_param"
    echo "============================================================"
    
    # Tampilkan log dengan parameter --since
    journalctl -u "$service_name" --since "$since_param" --no-pager
    
    echo
    echo "--- End of logs ---"
    echo
}

# Fungsi untuk membuat service baru
create_service() {
    echo "Membuat Service Baru"
    echo "============================================================"
    
    read -p "Nama service: " service_name
    read -p "Path ke aplikasi Node.js: " app_path
    read -p "Deskripsi service: " description 
    
    # Validasi input
    if [[ -z "$service_name" ]] || [[ -z "$app_path" ]] ; then
        echo "Error: Semua field harus diisi"
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
    
    echo "✓ Service $service_name berhasil dibuat"
    echo "Untuk mengaktifkan: sudo systemctl enable $service_name"
    echo "Untuk memulai: sudo systemctl start $service_name"
    echo
}

# Fungsi untuk menghapus service
remove_service() {
    local service_name=$(clean_string "$1")
    
    echo "Apakah Anda yakin ingin menghapus service $service_name? (y/N)"
    read -r confirmation
    
    if [[ $confirmation == "y" ]] || [[ $confirmation == "Y" ]]; then
        sudo systemctl stop "$service_name" 2>/dev/null
        sudo systemctl disable "$service_name" 2>/dev/null
        sudo rm -f "/lib/systemd/system/$service_name"
        sudo systemctl daemon-reload
        echo "✓ Service $service_name berhasil dihapus"
    else
        echo "Penghapusan dibatalkan"
    fi
    echo
}

# Menu utama
show_menu() {
    echo "Pilih aksi:"
    echo "1. List systemd service"
    echo "2. Manage service (start/stop/restart/enable/disable)"
    echo "3. Show status systemd service"
    echo "4. Show log systemd realtime"
    echo "5. Show log journalctl"
    echo "6. Create new systemd service"
    echo "7. Delete systemd service"
    echo "8. Reload all service"
    echo "9. Exit"
    echo
}

# select service - OPTIMIZED VERSION
select_service() {
    # Gunakan fungsi get_node_services yang sudah ada
    local services_raw=$(get_node_services)
    
    if [[ -z "$services_raw" ]]; then
        echo "Tidak ada service yang ditemukan" >&2
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
        echo "Tidak ada service yang valid ditemukan" >&2
        return 1
    fi
    
    # Tampilkan pilihan service ke stderr agar tidak tercampur dengan return value
    echo "Pilih service:" >&2
    for i in "${!service_array[@]}"; do
        # Tampilkan juga status service untuk memudahkan pemilihan
        local status=$(systemctl is-active "${service_array[i]}" 2>/dev/null)
        local status_text=""
        if [[ $status == "active" ]]; then
            status_text="[RUNNING]"
        else
            status_text="[STOPPED]"
        fi
        printf "%2d. %-30s %s\n" "$((i+1))" "${service_array[i]}" "$status_text" >&2
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
        echo "Pilihan tidak valid. Masukkan nomor 1-$count" >&2
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
                echo "=== KELOLA SERVICE ==="
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    echo
                    echo "Service yang dipilih: $selected_service"
                    echo "Pilih aksi:"
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
                        *) echo "Pilihan tidak valid. Masukkan nomor 1-6" ;;
                    esac
                else
                    echo "Service tidak dipilih atau tidak valid"
                fi
                ;;
            3)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    show_service_detail "$selected_service"
                else
                    echo "Service tidak dipilih atau tidak valid"
                fi
                ;;
            4)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    show_logs "$selected_service"
                else
                    echo "Service tidak dipilih atau tidak valid"
                fi
                ;;
            5)
                selected_service=$(select_service)
                selection_result=$?
                if [[ $selection_result -eq 0 ]] && [[ -n "$selected_service" ]]; then
                    show_logs_since "$selected_service"
                else
                    echo "Service tidak dipilih atau tidak valid"
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
                    echo "Service tidak dipilih atau tidak valid"
                fi
                ;;
            8)
                echo "Mereload semua service..."
                sudo systemctl daemon-reload
                echo "✓ Berhasil"
                echo
                ;;
            9)
                echo "Terima kasih telah menggunakan Node.js Service Manager!"
                exit 0
                ;;
            *)
                echo "Pilihan tidak valid"
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