#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-US}"
CITY="${2:-Austin}"
STATE="${3:-Texas}"

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../CA/ca.pem \
  -ca-key=../CA/ca-key.pem \
  -config=../CA/ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
