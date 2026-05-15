#!/usr/bin/env bash
set -e

echo "=== XRAY HIGHLOAD TUNER START ==="

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

########################################
# install required packages
########################################
apt update
apt install -y irqbalance

systemctl enable irqbalance
systemctl restart irqbalance

########################################
# sysctl
########################################
cat >/etc/sysctl.d/99-xray-highload.conf <<'EOF'
######################################################################
# XRAY HIGHLOAD / ANTI-FLOOD / QUIC OPTIMIZED
######################################################################

fs.file-max = 2097152
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1048576

vm.swappiness = 10
vm.max_map_count = 262144
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

net.core.somaxconn = 1048576
net.core.netdev_max_backlog = 262144
net.core.optmem_max = 67108864

net.core.rmem_default = 262144
net.core.wmem_default = 262144

net.core.rmem_max = 134217728
net.core.wmem_max = 134217728

net.core.default_qdisc = fq

net.ipv4.tcp_congestion_control = bbr

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_max_syn_backlog = 1048576

net.ipv4.tcp_fin_timeout = 10

net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1

net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1

net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

net.ipv4.ip_local_port_range = 1024 65535

net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 15
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 120

net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

net.ipv4.conf.all.log_martians = 1

net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ratelimit = 100

net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
EOF

sysctl --system

########################################
# limits
########################################
cat >/etc/security/limits.d/99-xray.conf <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

########################################
# systemd override
########################################
mkdir -p /etc/systemd/system/xray.service.d/

cat >/etc/systemd/system/xray.service.d/override.conf <<'EOF'
[Service]
LimitNOFILE=1048576
LimitNPROC=1048576
EOF

systemctl daemon-reload

if systemctl list-unit-files | grep -q xray.service; then
    systemctl restart xray
fi

########################################
# verify
########################################
echo
echo "===== VERIFY ====="
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.somaxconn
sysctl net.netfilter.nf_conntrack_max
ulimit -n

echo
echo "Done."
echo "Recommended: reboot once"