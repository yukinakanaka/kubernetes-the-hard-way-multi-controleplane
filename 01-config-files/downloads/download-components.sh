#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

function download() {
  url=$1
  if [ ! -e $(basename ${url}) ]; then
    curl -fSL --remote-name-all --ssl-reqd ${url}
  fi
}

# Download kubernetes components once then distribute them to controller(s) and
# agents
msg_info 'Downloading kubernetes components'

download "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/arm64/kube-apiserver"
download "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/arm64/kube-controller-manager"
download "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/arm64/kube-scheduler"
download "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/arm64/kubectl"
download "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-arm64.tar.gz"
download "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-arm64-v${CNI_PLUGINS_VERSION}.tgz"
download "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-${CONTAINERD_VERSION}-linux-arm64.tar.gz"
download "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/arm64/kube-proxy"
download "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/arm64/kubelet"