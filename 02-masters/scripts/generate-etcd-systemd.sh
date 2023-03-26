#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ETCD_VERSION="${1}"

if ! grep 'worker-1-k8s' /etc/hosts &> /dev/null; then
  # shellcheck disable=SC2002
  cat multipass-hosts | sudo tee -a /etc/hosts
fi

if [[ ! -x $(command -v etcd) || ! -x $(command -v etcdctl) ]]; then
  tar -xvf etcd-v"${ETCD_VERSION}"-linux-arm64.tar.gz
  sudo mv etcd-v"${ETCD_VERSION}"-linux-arm64/etcd* /usr/local/bin/
  rm -rf etcd-v"${ETCD_VERSION}"-linux-arm64.tar.gz etcd-v"${ETCD_VERSION}"-linux-arm64/
fi

if [[ ! -f /etc/etcd/kubernetes.pem || ! -f /etc/etcd/kubernetes-key.pem ]]; then
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo chmod -R 0700 /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
fi

declare -a INTERNAL_IPS=() COMPUTER_IPV4_ADDRESSES=()
while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    INTERNAL_IPS+=("${ip}")
  fi
done < <(hostname -I | tr '[:space:]' '\n')
ETCD_NAME="$(hostname -s)"
VERSION_REGEX='([0-9]*)\.'

for ip in "${INTERNAL_IPS[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

echo 'Creating etcd systemd unit'

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --listen-peer-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --listen-client-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${ETCD_NAME}=https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo 'Reloading systemd, enabling and starting etcd systemd service'

sudo systemctl daemon-reload
sudo systemctl enable --now etcd

echo 'Listing etcd members'

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
