#!/bin/bash

# SHAN BOOST 21.7
### 0. Initialization
clear
echo "🚀 SHAN BOOST 21.7..."
sleep 1
mkdir -p /var/log/cosmic_logs
echo "[$(date)] Starting COSMIC BOOST v21.7" > /var/log/cosmic_errors.log

### 1. System Essentials
if ! sudo pacman -Syu --noconfirm; then
  echo "[$(date)] ERROR: System update failed" >> /var/log/cosmic_errors.log
  exit 1
fi
if ! sudo pacman -S --needed --noconfirm i3 tmux neovim zoxide bat btop ripgrep fd fzf htop \
  curl wget rsync xarchiver unzip zstd zram-generator tlp git cpupower; then
  echo "[$(date)] ERROR: Package installation failed" >> /var/log/cosmic_errors.log
  exit 1
fi

### 2. Enable Core Services
sudo systemctl enable --now tlp
sudo systemctl enable --now systemd-zram-setup@zram0.service

### 3. zRAM Tuning
sudo bash -c 'cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF'
sudo systemctl daemon-reexec

### 4. Network Tuning
sudo bash -c 'cat > /etc/sysctl.d/99-cosmic-network.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
EOF'
sudo sysctl --system

### 5. Shell Aliases
cat <<EOF >> ~/.bashrc
alias cat='bat'
alias top='btop'
alias vim='nvim'
alias gs='git status'
EOF

### 6. COSMIC Directory Setup
mkdir -p ~/.cosmic && cd ~/.cosmic

### 7. Thermal Guardian
cat <<EOF > cosmic-tempguard.sh
#!/bin/bash
THERMAL_ZONE=\$(find /sys/class/thermal/thermal_zone* -name temp 2>/dev/null | head -n 1)
if [ -z "\$THERMAL_ZONE" ]; then
  echo "[$(date)] ERROR: No thermal zone found" >> /var/log/cosmic_logs/temp.log
  exit 1
fi
while true; do
  TEMP=\$(cat "\$THERMAL_ZONE" 2>/dev/null)
  if [ \$? -ne 0 ]; then
    echo "[$(date)] ERROR: Failed to read temperature" >> /var/log/cosmic_logs/temp.log
    sleep 30
    continue
  fi
  TEMP=\$((TEMP / 1000))
  echo "[$(date)] CPU Temp: \$TEMP°C" >> /var/log/cosmic_logs/temp.log
  if [ "\$TEMP" -ge 90 ]; then
    echo "⚠️ High Temp: Switching to Power Save" >> /var/log/cosmic_logs/temp.log
    sudo cpupower frequency-set -g powersave 2>/dev/null || echo "[$(date)] ERROR: cpupower failed" >> /var/log/cosmic_logs/temp.log
  elif [ "\$TEMP" -le 70 ]; then
    echo "✅ Temp Normal: Performance Mode" >> /var/log/cosmic_logs/temp.log
    sudo cpupower frequency-set -g performance 2>/dev/null || echo "[$(date)] ERROR: cpupower failed" >> /var/log/cosmic_logs/temp.log
  fi
  sleep 30
done
EOF
chmod +x cosmic-tempguard.sh
(crontab -l 2>/dev/null; echo "@reboot tmux new-session -d -s cosmic_temp '~/.cosmic/cosmic-tempguard.sh'") | crontab -

### 8. AI-Aware Scheduler
cat <<EOF > cosmic-scheduler.py
#!/usr/bin/env python3
import os, time, psutil
boost = ['nvim', 'python', 'zsh', 'tmux', 'metasploit', 'nmap', 'wireshark-cli']
while True:
  for p in psutil.process_iter(['pid', 'name']):
    try:
      if p.info['name'] in boost:
        p.nice(-10)
      else:
        p.nice(5)
    except: continue
  time.sleep(60)
EOF
chmod +x cosmic-scheduler.py
(crontab -l 2>/dev/null; echo "@reboot python3 ~/.cosmic/cosmic-scheduler.py &") | crantab -

### 9. RAM Preloader
cat <<EOF > cosmic-preload.sh
#!/bin/bash
[ ! -f ~/.cosmic_preload ] && exit
for app in \$(cat ~/.cosmic_preload); do
  if command -v "\$app" >/dev/null; then
    "\$app" &
  else
    echo "[$(date)] Warning: \$app not found" >> ~/.cosmic/preload.log
  fi
done
EOF
chmod +x cosmic-preload.sh
echo "nvim tmux metasploit nmap" > ~/.cosmic_preload
(crontab -l 2>/dev/null; echo "@reboot ~/.cosmic/cosmic-preload.sh") | crontab -

### 10. COSMIC Mode Selector
cat <<EOF > ~/.cosmic/cosmic-mode.sh
#!/bin/bash
echo "1) Balanced\n2) Performance\n3) Powersave"
read -p "Select Mode: " mode
case \$mode in
  1) echo "Balanced"; sudo tlp start;;
  2) sudo cpupower frequency-set -g performance;;
  3) sudo cpupower frequency-set -g powersave;;
esac
EOF
chmod +x ~/.cosmic/cosmic-mode.sh

### 11. Smart I/O Scheduler (Optimized for HDD)
cat <<EOF | sudo tee /etc/udev/rules.d/60-cosmic-ioscheduler.rules
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

### 12. Kernel Watchdog Tuning
cat <<EOF | sudo tee -a /etc/sysctl.d/99-cosmic-watchdog.conf
kernel.panic=10
kernel.panic_on_oops=1
EOF
sudo sysctl --system

### 13. Auto Log Pruner
cat <<EOF > ~/.cosmic/log-pruner.sh
#!/bin/bash
find /var/log/cosmic_logs -type f -name "*.log" -mtime +5 -exec gzip {} \;
echo "🧹 Log cleanup done at \$(date)" >> ~/.cosmic/log-prune.log
EOF
chmod +x ~/.cosmic/log-pruner.sh
(crontab -l 2>/dev/null; echo "0 3 * * * ~/.cosmic/log-pruner.sh") | crontab -

### 14. Cosmic Logs Link
ln -sf /var/log/cosmic_logs/temp.log /var/log/cosmic_temp.log

### 15. Disable Unused Services (Preserve BlackArch-critical services)
# Commenting out to avoid disabling BlackArch-critical services like sshd
# sudo systemctl disable bluetooth.service cups.service lvm2-monitor.service

### Final Output
echo "✅ COSMIC BOOST v21.7 IS NOW ACTIVE!"
echo "🧠 Use ~/.cosmic/cosmic-mode.sh to adjust power mode manually."
echo "📊 Monitor temps: tail -f /var/log/cosmic_logs/temp.log"
echo "🧹 Auto log cleanup and thermal switching enabled."
echo "⚡ REBOOT RECOMMENDED for full activation."
