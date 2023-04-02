#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

COUNTRY="${1:-US}"
CITY="${2:-Austin}"
STATE="${3:-Texas}"
VERSION_REGEX='([0-9]*)\.'

declare -a COMPUTER_IPV4_ADDRESSES=() COMPUTER_IP_ADDRESSES=()

while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    COMPUTER_IP_ADDRESSES+=("${ip}")
  fi
done < <(get_ips)

# This works because we only have 1 controller
# logic will have to change if we have more than 1
# TODO: ロジックはどのように変わるべきなのか？
while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    COMPUTER_IP_ADDRESSES+=("${ip}")
  fi
done < <(multipass list | grep '\-k8s' | awk '{ print $3 }')

# TODO: IPアドレスのフォーマットチェックをしているだけ？
for ip in "${COMPUTER_IP_ADDRESSES[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

IPV4_ADDRESSES=$(join_by ',' "${COMPUTER_IPV4_ADDRESSES[@]}")
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/ca.pem \
  -ca-key=../00-Certificate-Authority/ca-key.pem \
  -config=../00-Certificate-Authority/ca-config.json \
  -hostname="${IPV4_ADDRESSES}",127.0.0.1,"${KUBE_API_CLUSTER_IP}","${KUBERNETES_HOSTNAMES}" \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
