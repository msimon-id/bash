# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 10-aliases.sh
#  Beschreibung  : Alias-Sammlung fuer AlmaLinux-/Debian-Admin-Workflows
#                  (System, Systemd, Firewall, Docker/Podman/Kubernetes,
#                  Backup, Security-Tools, ...).
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

# ----[ 5. ALIASE – SYSTEM ]--------------------------------
alias dfh='df -hT --total'
alias duh='du -h --max-depth=1'
alias free='free -h'
alias cpuinfo='lscpu | egrep "Model name|Socket|Thread|Core|CPU\(s\)"'
alias meminfo='grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree" /proc/meminfo'
alias psu='ps aux --sort=-%mem,-%cpu | head -20'
alias uptime='uptime -p'
alias sysinfo='hostnamectl; echo; lscpu | grep "Model name"; free -h; df -hT /'

# ----[ 6. SYSTEMD / SERVICE MGMT ]--------------------------
alias sc='sudo systemctl'
alias enable='sudo systemctl enable'
alias disable='sudo systemctl disable'
alias restart='sudo systemctl restart'
alias status='sudo systemctl status'
alias start='sudo systemctl start'
alias stop='sudo systemctl stop'
alias sclrun='sudo systemctl list-units --type=service --state=running'
alias sclstopped='sudo systemctl list-units --type=service --state=inactive --all'
alias sclfailed='sudo systemctl list-units --type=service --state=failed'
alias scl='sudo systemctl list-units --type=service'
alias reboot='sudo systemctl reboot'
alias shutdown='sudo systemctl poweroff'
# Bewusste Komfort-Entscheidung: reboot/shutdown starten ohne Rueckfrage.
# Wer stattdessen lieber eine Sicherheitsabfrage moechte, muss unten nur
# das '#' vor der jeweiligen Zeile entfernen (keine weitere Anpassung
# noetig) - die spaeter geladene Zeile ueberschreibt den Alias von oben:
#alias reboot='read -rp "System jetzt neu starten? [y/N] " a && [[ $a == [yY] ]] && sudo systemctl reboot'
#alias shutdown='read -rp "System jetzt herunterfahren? [y/N] " a && [[ $a == [yY] ]] && sudo systemctl poweroff'

# ----[ 7. PACKAGE MGMT (Debian/apt & AlmaLinux/dnf) ]--------
if command -v dnf >/dev/null 2>&1; then
    alias update='sudo dnf check-update'
    alias upgrade='sudo dnf upgrade -y'
    alias install='sudo dnf install -y'
    alias remove='sudo dnf remove -y'
    alias autoremove='sudo dnf autoremove -y'
    alias cleanpkg='sudo dnf clean all'
    alias search='dnf search'
    alias repo='dnf repolist all'
elif command -v apt >/dev/null 2>&1; then
    alias update='sudo apt update -y'
    alias upgrade='sudo apt upgrade -y'
    alias install='sudo apt install -y'
    alias remove='sudo apt remove -y'
    alias autoremove='sudo apt autoremove -y'
    alias cleanpkg='sudo apt clean'
    alias search='apt search'
    alias repo='apt policy'
fi

# ----[ 8. NETZWERK & CONNECTIVITY ]-------------------------
alias netstat='ss -tuln'
alias ports='ss -tulpen'
# Als Funktion statt Alias: ShellCheck (SC2142) lehnt bei Aliasen ein
# scheinbares '$1' im Wert ab, weil es dort mit einem Positionsparameter des
# Alias-Aufrufs verwechselt werden koennte - hier ist es aber awks eigenes
# Feld-'$1', das erst beim Ausfuehren der Funktion gebraucht wird.
myip() { hostname -I | awk '{print $1}'; }
alias pingg='ping -c 5 8.8.8.8'
alias trace='traceroute 8.8.8.8'
alias ifc='ip -brief address'
alias macs='ip link | grep ether'
alias gw='ip route | grep default'
alias dnsflush='sudo resolvectl flush-caches 2>/dev/null || sudo systemd-resolve --flush-caches 2>/dev/null || echo "kein systemd-resolved gefunden"'
alias dnsservers='resolvectl status 2>/dev/null || grep ^nameserver /etc/resolv.conf'
alias dnsa='dig +short A'
alias dnsaaaa='dig +short AAAA'
alias dnsmx='dig +short MX'
alias dnsns='dig +short NS'
alias dnstxt='dig +short TXT'
alias dnscname='dig +short CNAME'
alias dnsany='dig +nocmd +multiline +noall +answer any'
alias dnsptr='dig -x'
alias dnstrace='dig +trace'

# ----[ 9. FIREWALL & SECURITY ]-----------------------------
alias nftlist='sudo nft list ruleset'
alias nftlog='sudo grc dmesg -w | grep "Dropped *"'
alias nftr='sudo nft list ruleset | less'
alias nftflush='sudo nft flush ruleset'
alias nftreload='sudo systemctl reload nftables'
alias nftcheck='sudo nft -c -f /etc/nftables.conf'

# fail2ban -> f2b-* (Abschnitt 21), ClamAV -> cav-* (Abschnitt 21)
alias checkports='sudo lsof -i -P -n | grep LISTEN'
alias ipt='sudo iptables -L -v -n'
alias iptflush='sudo iptables -F'
alias iptsave='sudo iptables-save'

alias ufwstatus='sudo ufw status verbose'
alias ufwenable='sudo ufw enable'
alias ufwdisable='sudo ufw disable'
alias ufwreload='sudo ufw reload'
alias ufwallow='sudo ufw allow'
alias ufwdeny='sudo ufw deny'

# firewalld (AlmaLinux/RHEL Standard)
alias fwstatus='sudo firewall-cmd --state'
alias fwreload='sudo firewall-cmd --reload'
alias fwreloadfull='sudo firewall-cmd --complete-reload'
alias fwzone='sudo firewall-cmd --get-default-zone'
alias fwzones='sudo firewall-cmd --get-zones'
alias fwactivezones='sudo firewall-cmd --get-active-zones'
alias fwlist='sudo firewall-cmd --list-all'
alias fwlistall='sudo firewall-cmd --list-all-zones'
alias fwinterfaces='sudo firewall-cmd --list-interfaces'
alias fwservices='sudo firewall-cmd --list-services'
alias fwgetservices='sudo firewall-cmd --get-services'
alias fwports='sudo firewall-cmd --list-ports'
alias fwrich='sudo firewall-cmd --list-rich-rules'
alias fwaddport='sudo firewall-cmd --permanent --add-port'
alias fwremoveport='sudo firewall-cmd --permanent --remove-port'
alias fwaddservice='sudo firewall-cmd --permanent --add-service'
alias fwremoveservice='sudo firewall-cmd --permanent --remove-service'
alias fwmasqon='sudo firewall-cmd --permanent --add-masquerade'
alias fwmasqoff='sudo firewall-cmd --permanent --remove-masquerade'
alias fwpanic='sudo firewall-cmd --panic-on'
alias fwpanicoff='sudo firewall-cmd --panic-off'
alias fwpanicstatus='sudo firewall-cmd --query-panic'
alias fwruntime2perm='sudo firewall-cmd --runtime-to-permanent'

# ----[ 10. DOCKER & CONTAINER MGMT ]------------------------
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias di='docker images'
alias dlog='docker logs -f'
alias dexec='docker exec -it'
alias drm='docker rm $(docker ps -aq) -f'
alias drmi='docker rmi $(docker images -q) -f'
alias dstop='docker stop $(docker ps -q)'
alias dclean='docker system prune -af --volumes'
alias dnet='docker network ls'
alias dvol='docker volume ls'
alias dcompose-restart='docker compose down && docker compose up -d'
alias dprune='docker system prune -a --volumes'

# Podman
alias p='podman'
alias pc='podman-compose'
alias pps='podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias pi='podman images'
alias plog='podman logs -f'
alias pexec='podman exec -it'
alias prm='podman rm $(podman ps -aq) -f'
alias prmi='podman rmi $(podman images -q) -f'
alias pstop='podman stop $(podman ps -q)'
alias pclean='podman system prune -af --volumes'
alias pnet='podman network ls'
alias pvol='podman volume ls'
alias pcompose-restart='podman-compose down && podman-compose up -d'
alias pprune='podman system prune -a --volumes'
alias podls='podman pod ls'
alias podstart='podman pod start'
alias podstop='podman pod stop'

# Kubernetes (kubectl)
alias k='kubectl'
alias kga='kubectl get all'
alias kgp='kubectl get pods -o wide'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'
alias kdp='kubectl describe pod'
alias kdel='kubectl delete'
alias klog='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'
alias ktop='kubectl top pods'

# ----[ 11. VIRTUALISIERUNG / VM MGMT ]----------------------
alias virsh='sudo virsh'
alias vmlist='sudo virsh list --all'
alias vmstart='sudo virsh start'
alias vmstop='sudo virsh shutdown'
alias vmreboot='sudo virsh reboot'
alias vmdestroy='sudo virsh destroy'
alias vmundefine='sudo virsh undefine'
alias vmconsole='sudo virsh console'
alias vminfo='sudo virsh dominfo'
alias vmxml='sudo virsh dumpxml'
alias vmedit='sudo virsh edit'
alias vmsuspend='sudo virsh suspend'
alias vmresume='sudo virsh resume'
alias vmautostart='sudo virsh autostart'
alias vmautostartoff='sudo virsh autostart --disable'
alias vmclone='sudo virt-clone'
alias vmiface='sudo virsh domifaddr'
alias vmnetlist='sudo virsh net-list --all'
alias vmpoollist='sudo virsh pool-list --all'
alias vmsnaplist='sudo virsh snapshot-list'
alias vmsnapcreate='sudo virsh snapshot-create-as'
alias vmsnaprevert='sudo virsh snapshot-revert'

# Proxmox VE - VMs (qm)
alias qm='sudo qm'
alias qmlist='sudo qm list'
alias qmstart='sudo qm start'
alias qmstop='sudo qm stop'
alias qmshutdown='sudo qm shutdown'
alias qmreboot='sudo qm reboot'
alias qmstatus='sudo qm status'
alias qmconsole='sudo qm terminal'
alias qmconfig='sudo qm config'
alias qmclone='sudo qm clone'
alias qmsnaplist='sudo qm listsnapshot'
alias qmsnapcreate='sudo qm snapshot'

# Proxmox VE - Container (pct/LXC)
alias pct='sudo pct'
alias pctlist='sudo pct list'
alias pctstart='sudo pct start'
alias pctstop='sudo pct stop'
alias pctenter='sudo pct enter'
alias pctexec='sudo pct exec'
alias pctconfig='sudo pct config'

# Proxmox VE - Storage/Cluster/Backup
alias pvestorage='sudo pvesm status'
alias pvenodes='sudo pvecm nodes'
alias pvestatus='sudo pvecm status'
alias pvebackup='sudo vzdump'
alias pvetasklog='sudo tail -f /var/log/pve/tasks/active'

# ----[ 12. GIT & DEVOPS ]----------------------------------
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff'
alias greset='git reset --hard'
alias gtag='git tag -l'
alias gbranch='git branch'

# ----[ 13. BACKUP / ARCHIVIERUNG ]--------------------------
alias tarc='tar -czvf'
alias tarx='tar -xzvf'
alias rsyncp='rsync -avhP'
alias backup-etc='sudo rsync -avhP /etc /root/backup/etc-$(date +%F)/'
alias backup-home='rsync -avhP --exclude=.cache ~ /mnt/backup/home-$(date +%F)/'

# rsnapshot
alias rsnap='sudo rsnapshot'
alias rsnaptest='sudo rsnapshot configtest'
alias rsnapdry='sudo rsnapshot -t daily'
alias rsnapdaily='sudo rsnapshot daily'
alias rsnapweekly='sudo rsnapshot weekly'
alias rsnapmonthly='sudo rsnapshot monthly'
alias rsnapdu='sudo rsnapshot du'

# Borg (BorgBackup)
alias borglist='borg list'
alias borginfo='borg info'
alias borgcreate='borg create --stats --progress'
alias borgcheck='borg check'
alias borgprune='borg prune --stats'
alias borgcompact='borg compact'
alias borgextract='borg extract'
alias borgmount='borg mount'
alias borgumount='borg umount'

# Bareos
alias bconsole='sudo bconsole'
alias bareosstatus='echo "status dir" | sudo bconsole'
alias bareosjobs='echo "list jobs" | sudo bconsole'
alias bareosclients='echo "list clients" | sudo bconsole'
alias bareospools='echo "list pools" | sudo bconsole'
alias bareos-dir-restart='sudo systemctl restart bareos-director'
alias bareos-dir-log='sudo tail -f /var/log/bareos/bareos.log'

# Archivierung / Kompression
alias tarcj='tar -cjvf'
alias tarxj='tar -xjvf'
alias tarcJ='tar -cJvf'
alias tarxJ='tar -xJvf'
alias tarl='tar -tvf'
alias zipc='zip -r'
alias zipx='unzip'
alias 7zc='7z a'
alias 7zx='7z x'
alias 7zl='7z l'
alias gzc='gzip -k'
alias gzx='gunzip -k'
alias xzc='xz -k'
alias xzx='unxz -k'
alias checksum='sha256sum'
alias checkverify='sha256sum -c'

# ----[ 14. MONITORING & DIAGNOSE ]--------------------------
alias topcpu='ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head'
alias topmem='ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head'
alias iotop='sudo iotop -oPa'
alias nettop='sudo nload'
alias top='sudo htop || top'
alias diskuse='sudo ncdu /'
alias watchcpu='watch -n1 "ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -20"'
alias watchmem='watch -n1 free -h'
alias watchdisk='watch -n2 df -hT'
alias vmstat1='vmstat 1'
alias iostat1='iostat -xz 1'
alias sar1='sar 1 5'
alias dmesglive='sudo dmesg -w'
alias dmesgerr='sudo dmesg --level=err,crit,alert,emerg'
alias load='cat /proc/loadavg'
# Als Funktion statt Alias, aus demselben Grund wie 'myip' oben (SC2142).
zombies() { ps aux | awk '$8=="Z"'; }
alias temps='sensors'
alias smart='sudo smartctl -a'
alias disks='lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE'
alias pstree='pstree -p'
alias glances='sudo glances'

# ----[ 15. LOGS & AUDIT ]----------------------------------
#alias logsys='sudo journalctl -xe'
alias logboot='sudo journalctl -b'
alias logf='sudo tail -f /var/log/messages 2>/dev/null || sudo tail -f /var/log/syslog'
alias logauth='sudo tail -f /var/log/secure || sudo tail -f /var/log/auth.log'
alias logdocker='sudo journalctl -u docker.service -f'
alias logslive='sudo journalctl -f'
alias logpri='sudo journalctl -p err..alert'
alias logtoday='sudo journalctl --since today'
alias logkernel='sudo journalctl -k'
alias logunit='sudo journalctl -u'
alias logdisk='sudo journalctl --disk-usage'
alias logvacuum='sudo journalctl --vacuum-time=7d'
alias logcron='sudo journalctl -u cron -f 2>/dev/null || sudo journalctl -u crond -f'
alias logmail='sudo tail -f /var/log/maillog 2>/dev/null || sudo tail -f /var/log/mail.log'
alias logaccess='sudo tail -f /var/log/nginx/access.log 2>/dev/null || sudo tail -f /var/log/httpd/access_log'
alias logerror='sudo tail -f /var/log/nginx/error.log 2>/dev/null || sudo tail -f /var/log/httpd/error_log'
alias lastlogins='last -a | head -20'
alias faillogins='sudo lastb | head -20'
# auditd-* (Abschnitt 21): auditd-today, auditd-subsystem
alias tailf='tail -f'


# ----[ 16. SHORTCUTS & NAVIGATION ]-------------------------
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias cls='clear'
alias reload='source ~/.bashrc'
alias root='sudo -i'
alias home='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias scripts='cd /root/scripts'
alias etc='cd /etc'
alias opt='cd /opt'
alias logs='cd /var/log'
alias sss='sleep 8 && grim -g "$(slurp)" /home/$USER/Pictures/screenshots/$(date +%F_%H-%M-%S).png'
alias ssc='grim -g "$(slurp)" - | wl-copy'

# ----[ 17. ADMIN TOOLS ]-----------------------------------
alias sshconfig='sudo nano /etc/ssh/sshd_config'
alias nettest='curl -Is https://example.com | head -n1'
# speedtest: kein Alias mehr - kollidiert sonst mit der Funktion aus
# bashrc.d/80-tools.sh (Bash expandiert Aliase vor dem Parsen einer
# Funktionsdefinition gleichen Namens -> Syntaxfehler beim Laden). Das
# eigentliche Tool liegt unter tools/speedtest/speedtest.sh und ersetzt
# bewusst den frueheren ungeprueften curl-\|-python-Download.
# Doppelte Anfuehrungszeichen fuer den gesamten Alias-Wert (statt
# verschachtelter einfacher Quotes wie 'openssl ... | tr -d '=+/' | ...'):
# letzteres funktioniert nur zufaellig richtig, weil Bash die drei
# Quote-Fragmente wieder zu einem String zusammensetzt - liest sich aber
# wie ein Quoting-Fehler und bricht bei jeder Bearbeitung leicht.
alias passwort="openssl rand -base64 24 | tr -d '=+/' | head -c 32"

# SSH-Key-Management
alias sshkeygen='ssh-keygen -t ed25519 -a 100'
alias sshcopyid='ssh-copy-id'
alias sshauthkeys='cat ~/.ssh/authorized_keys'
alias sshknown='cat ~/.ssh/known_hosts'
alias sshactive='ss -tnp | grep :22'
alias sessions='who'
alias sessions-full='w'

# ----[ 18. FARBE IN GREP, DIFF, ETC. ]---------------------
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias diff='diff --color=auto'
# -color wird erst ab iproute2 5.14 unterstuetzt (fehlt z.B. auf Debian 11 / AlmaLinux 8)
if ip -c a >/dev/null 2>&1; then
    alias ip='ip -color=auto'
fi

# ----[ 19. PERSISTENZ ]------------------------------------
alias bashsave='cat ~/.bashrc > ~/.bashrc.backup.$(date +%F)'
alias bashdiff='diff ~/.bashrc "$(ls -t ~/.bashrc.backup.* 2>/dev/null | head -n1)"'
if command -v firefox >/dev/null 2>&1; then
    alias firefox='systemd-run --user --slice=firefox.slice /usr/bin/firefox'
fi

# ----[ 20. SECURITY PIPELINE (/opt/ansible/roles/security_pipeline) ]---
# Ad-hoc-Aufrufe der dort installierten Tools, mit denselben Configs und
# demselben Report-Verzeichnis wie in den tasks/*.yml der Rolle - become
# nur dort, wo die Rolle selbst become:true nutzt (lynis, trivy-image,
# sbom), der Rest laeuft bewusst ohne sudo (Least Privilege).
export SEC_REPORT_DIR=/opt/ansible/docs/security-reports
export SEC_TARGET=/opt/ansible

if [ -f /etc/debian_version ]; then
    SEC_ENGINE=docker
else
    SEC_ENGINE=podman
fi

alias sec-reports='cd "$SEC_REPORT_DIR"'

# SAST / IaC / Policy / Lint (ohne become)
alias bandit-scan='bandit -r "$SEC_TARGET" -f json -o "$SEC_REPORT_DIR/bandit-report.json" -c /opt/ansible/.bandit.yml'
alias checkov-scan='/usr/local/bin/checkov -d "$SEC_TARGET" --framework ansible --compact --output json --output-file-path "$SEC_REPORT_DIR"'
alias conftest-scan='/usr/local/bin/conftest test --policy /opt/ansible/policy --all-namespaces --output json "$SEC_TARGET"'
alias yamllint-scan='/usr/local/bin/yamllint --format parsable -c /opt/ansible/.yamllint "$SEC_TARGET"'
alias ansible-lint-scan='/usr/local/bin/ansible-lint --project-dir /opt/ansible -c /opt/ansible/.ansible-lint --format json "$SEC_TARGET"'

# Secrets (ohne become)
alias gitleaks-scan='/usr/local/bin/gitleaks dir "$SEC_TARGET" --config /opt/ansible/.gitleaks.toml --report-format json --report-path "$SEC_REPORT_DIR/gitleaks-dir-report.json" --exit-code 1 --no-banner --redact'
alias gitleaks-history='/usr/local/bin/gitleaks detect --source "$SEC_TARGET" --config /opt/ansible/.gitleaks.toml --report-format json --report-path "$SEC_REPORT_DIR/gitleaks-history-report.json" --exit-code 1 --no-banner --redact'

# CVE-Scans (trivy fs ohne become, trivy image mit - siehe Rollenkommentar)
alias trivy-fs='/usr/local/bin/trivy fs --scanners vuln --severity CRITICAL,HIGH --timeout 30m --format json --exit-code 1'
alias trivy-image='sudo /usr/local/bin/trivy image --severity CRITICAL,HIGH --timeout 5m --format json'
alias trivy-images-list='$SEC_ENGINE images --format "{{.Repository}}:{{.Tag}}"'

# SBOM / Systemhaertung (mit become, wie in der Rolle)
alias sbom-host='sudo /usr/local/bin/syft scan dir:/ --exclude ./proc/** --exclude ./sys/** --exclude ./dev/** --exclude ./run/** --exclude ./tmp/** --exclude ./var/tmp/** --exclude ./var/lib/docker/** --exclude ./var/lib/containers/** -o cyclonedx-json="$SEC_REPORT_DIR/sbom/host-sbom.json"'
alias sbom-image='sudo /usr/local/bin/syft scan $SEC_ENGINE:'
alias lynis-scan='sudo lynis audit system --quiet'
alias lynis-score='grep "hardening_index=" /var/log/lynis-report.dat | cut -d= -f2'

# ----[ 21. CIS / SECURITY HARDENING TOOLS ]------------------

# auditd (Linux Audit Framework)
# Paketname unterscheidet sich: Debian/Ubuntu -> auditd, AlmaLinux/RHEL -> audit
if command -v dnf >/dev/null 2>&1; then
    alias auditd-install='sudo dnf install -y audit audit-libs'
elif command -v apt >/dev/null 2>&1; then
    alias auditd-install='sudo apt install -y auditd audispd-plugins'
fi
alias auditd-status='sudo systemctl status auditd'
alias auditd-restart='sudo systemctl restart auditd'
alias auditd-rules='sudo auditctl -l'
alias auditd-reload='sudo augenrules --load'
alias auditd-report='sudo aureport --summary'
alias auditd-failed='sudo aureport -au --failed'
alias auditd-log='sudo tail -f /var/log/audit/audit.log'
alias auditd-subsystem='sudo auditctl -s'
alias auditd-today='sudo ausearch -ts today 2>/dev/null || echo "keine Audit-Events heute (oder auditd inaktiv - siehe auditd-subsystem)"'

# ClamAV
alias cav-status='sudo systemctl status clamav-daemon 2>/dev/null || sudo systemctl status clamd@scan'
alias cav-scan-home='clamscan -r --bell -i ~'
alias cav-scan-full='sudo clamscan -r --bell -i /'
alias cav-quarantine='sudo clamscan -r --move=/var/quarantine -i /'
alias cav-version='clamscan -V'
alias cav-log='sudo tail -f /var/log/clamav/clamav.log 2>/dev/null || sudo tail -f /var/log/clamd.scan'

# Freshclam (ClamAV Signatur-Updates)
alias freshclam-update='sudo freshclam'
alias freshclam-status='sudo systemctl status clamav-freshclam 2>/dev/null || sudo systemctl status freshclam'
alias freshclam-restart='sudo systemctl restart clamav-freshclam 2>/dev/null || sudo systemctl restart freshclam'
alias freshclam-log='sudo tail -f /var/log/clamav/freshclam.log'

# Suricata (IDS/IPS)
alias suricata-status='sudo systemctl status suricata'
alias suricata-restart='sudo systemctl restart suricata'
alias suricata-reload='sudo systemctl reload suricata'
alias suricata-test='sudo suricata -T -c /etc/suricata/suricata.yaml'
alias suricata-update='sudo suricata-update'
alias suricata-log='sudo tail -f /var/log/suricata/fast.log'
alias suricata-eve='sudo tail -f /var/log/suricata/eve.json'

# Wazuh Agent
alias wazuh-status='sudo systemctl status wazuh-agent'
alias wazuh-restart='sudo systemctl restart wazuh-agent'
alias wazuh-control='sudo /var/ossec/bin/wazuh-control status'
alias wazuh-configtest='sudo /var/ossec/bin/wazuh-control configtest'
alias wazuh-log='sudo tail -f /var/ossec/logs/ossec.log'

# SELinux
alias selinux-status='sestatus'
alias selinux-getenforce='getenforce'
alias selinux-enforce='sudo setenforce 1'
alias selinux-permissive='sudo setenforce 0'
alias selinux-denials='sudo ausearch -m avc -ts recent'
alias selinux-booleans='getsebool -a'
alias selinux-restorecon='sudo restorecon -Rv'

# rsyslog
alias rsyslog-status='sudo systemctl status rsyslog'
alias rsyslog-restart='sudo systemctl restart rsyslog'
alias rsyslog-test='sudo rsyslogd -N1'
alias rsyslog-conf='sudo nano /etc/rsyslog.conf'

# psacct / acct (Process Accounting)
alias psacct-status='sudo systemctl status psacct 2>/dev/null || sudo systemctl status acct'
alias psacct-enable='sudo systemctl enable --now psacct 2>/dev/null || sudo systemctl enable --now acct'
alias psacct-users='sudo lastcomm | head -20'
alias psacct-summary='sudo sa -m'

# logrotate
alias logrotate-test='sudo logrotate -d /etc/logrotate.conf'
alias logrotate-force='sudo logrotate -vf /etc/logrotate.conf'
alias logrotate-conf='sudo nano /etc/logrotate.conf'

# fail2ban
alias f2b-status='sudo fail2ban-client status'
alias f2b-restart='sudo systemctl restart fail2ban'
alias f2b-reload='sudo fail2ban-client reload'
alias f2b-log='sudo tail -f /var/log/fail2ban.log'

# chrony (NTP)
alias chrony-status='chronyc tracking'
alias chrony-sources='chronyc sources -v'
alias chrony-sync='sudo chronyc makestep'
alias chrony-restart='sudo systemctl restart chronyd'
alias chrony-clients='chronyc clients'

# systemd-timesyncd (Alternative zu chrony, u.a. auf Debian-Minimalsystemen)
alias timesyncd-status='timedatectl timesync-status 2>/dev/null || timedatectl status'
alias timesyncd-restart='sudo systemctl restart systemd-timesyncd'

# OpenSCAP / CIS-Compliance-Scan
alias oscap-info='oscap info'
alias oscap-datastreams='ls /usr/share/xml/scap/ssg/content/ 2>/dev/null'
alias oscap-eval-cis='sudo oscap xccdf eval --profile cis'

# chkrootkit
alias rootkit-scan='sudo chkrootkit'
alias rootkit-quiet='sudo chkrootkit -q'
alias rootkit-log='sudo chkrootkit | sudo tee /var/log/chkrootkit.log'

# AIDE (Advanced Intrusion Detection Environment)
alias aide-init='sudo aide --init'
alias aide-check='sudo aide --check'
alias aide-update='sudo aide --update'
alias aide-applydb='sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz'
alias aide-log='sudo tail -f /var/log/aide/aide.log'

# ----[ 22. USER- & GRUPPENVERWALTUNG ]-----------------------
alias useradd='sudo useradd'
alias userdel='sudo userdel -r'
alias usermod='sudo usermod'
alias groupadd='sudo groupadd'
alias groupdel='sudo groupdel'
alias groupmod='sudo groupmod'
alias lockuser='sudo usermod -L'
alias unlockuser='sudo usermod -U'
alias chage='sudo chage'
alias visudo='sudo visudo'
alias sudoers-check='sudo visudo -c'
alias userlist='cut -d: -f1 /etc/passwd'
alias grouplist='cut -d: -f1 /etc/group'
alias mygroups='id'
alias sudo-log='sudo journalctl _COMM=sudo -f 2>/dev/null || sudo tail -f /var/log/auth.log'

# ----[ 23. CRON / ZEITGESTEUERTE AUFGABEN ]-------------------
alias crontab-edit='crontab -e'
alias crontab-list='crontab -l'
alias crontab-root='sudo crontab -e'
alias crontab-root-list='sudo crontab -l'
alias cronsys='sudo nano /etc/crontab'
alias cronstatus='sudo systemctl status cron 2>/dev/null || sudo systemctl status crond'
alias cronrestart='sudo systemctl restart cron 2>/dev/null || sudo systemctl restart crond'
# Live-Log fuer Cron-Jobs: siehe 'logcron' (Abschnitt 15)

# ==========================================================
#   ENDE DER ALIASE
# ==========================================================
