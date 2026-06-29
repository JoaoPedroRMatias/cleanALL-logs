<div align="center">
    <img src="assets/image.psd.png" width="600">
</div>

<div align="center">

**Post-pentest log cleanup for Linux — leaves no trace of access.**

</div>

---

## What It Does

Removes evidence of access from a Linux VM after an authorized pentest. Runs as root, cleans everything, and self-destructs.

| Category | What's Cleaned |
|---|---|
| Shell history | bash, zsh, fish, sh — all users |
| Session records | wtmp, btmp, utmp, lastlog (binary-safe) |
| System logs | auth, syslog, kern, secure, sudo, ufw, iptables |
| Web servers | apache2, nginx, httpd — access + error + rotated |
| Databases | mysql, postgresql, mongodb, redis |
| Pentest tools | .msf4, .nmap, .pcap, .xml, .gnmap outputs |
| Cloud artifacts | AWS CLI cache, Azure, GCP logs |
| Containers | Docker JSON logs, /var/log/containers, /var/log/pods |
| Kernel | dmesg ring buffer, ARP cache, DNS cache |
| Systemd | journal, core dumps, AccountsService |
| Rotated logs | *.log.1, *.gz, *.old — removed |
| Timestamps | mtime/atime of /var/log normalized to 7 days ago |
| Post-logout | auth.log + wtmp zeroed 10s after disconnect (catches sshd logout event) |

---

## Usage

### Option A — Pipe (never writes to disk)

```bash
curl -s https://github.com/JoaoPedroRMatias/cleanALL-logs/raw/refs/heads/main/cleanALL.sh | sudo bash
```

### Option B — Heredoc (never writes to disk)

```bash
sudo bash << 'EOF'
# paste script content here
EOF
```

### Option C — File

```bash
curl -O https://github.com/JoaoPedroRMatias/cleanALL-logs/raw/refs/heads/main/cleanALL.sh
sudo bash cleanALL.sh
# script self-deletes after running
```

After the script finishes it prints:

```
[!] Deslogue agora. Limpeza final em 10 segundos.
```

**Disconnect immediately.** A background process zeroes auth.log, wtmp and btmp 10 seconds later — after sshd writes the logout event.

---

## Requirements

- Linux (Debian/Ubuntu/RHEL/CentOS)
- Root (`sudo`)

---

## What It Does NOT Touch

- `~/.ssh/authorized_keys` — owner SSH access preserved
- Running applications and services — nothing is killed permanently
- Remote syslog (rsyslog/syslog-ng) — cannot be cleaned locally

---

## Known Limitations

| Limitation | Reason |
|---|---|
| `ctime` not fakeable | Linux kernel limitation — userspace cannot alter inode change time |
| Remote logs | If syslog forwards off-host, local cleanup has no effect |
| Filesystem journal | ext4/xfs journal is not clearable without unmounting |
| Swap | Skipped by default to avoid OOM on low-memory systems |

---

## Manual Checks After Running

```
/etc/hosts         — remove entries added during pentest
/etc/passwd        — confirm no new users were created
/var/spool/cron/   — confirm no cron jobs were added
/var/spool/at/     — confirm no at jobs are scheduled
iptables/nftables  — confirm redirect rules were removed
```
