#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

#THIS_SCRIPT=$(basename "${0}")
#PADDING=$(printf %-${#THIS_SCRIPT}s " ")

function check_dependencies() {
  declare -a DEPS=(
    'git'
    'multipass'
    'cfssl'
    'cfssljson'
    'kubectl'
    'ipcalc'
  )
  declare -a MISSING=()
  # Ensure dependencies are present
  for i in "${DEPS[@]}"; do
    if ! command -v "${i}" &> /dev/null ; then
      MISSING+=("${i}")
    fi
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Dependencies unmet. Please verify that the following are installed and in the PATH: " "${MISSING[@]}"
  fi
}

check_dependencies

export \
  KUBERNETES_VERSION='1.25.4' \
  ETCD_VERSION='3.5.5' \
  CONTAINERD_VERSION='1.6.10' \
  CNI_PLUGINS_VERSION='1.1.1' \
  COREDNS_CHART_VERSION='1.19.7' \
  CILIUM_CHART_VERSION='1.12.4' \
  SERVICE_CLUSTER_IP_RANGE='172.17.0.0/24' \
  SERVICE_NODE_PORT_RANGE='30000-32767' \
  CLUSTER_CIDR='172.16.0.0/16' \
  DNS_CLUSTER_IP='172.17.0.10'

export KUBE_API_CLUSTER_IP
KUBE_API_CLUSTER_IP="$(ipcalc "${SERVICE_CLUSTER_IP_RANGE}" | grep 'HostMin' | awk '{ print $2 }')"

# To Be Determined
# - Service IP range: 10.32.0.0/24
# - Node Port range: 30000-32767

msg_info 'Creating multipass instances'

for i in 'load-balancer-k8s' 'master-1-k8s' 'master-2-k8s' 'worker-1-k8s' 'worker-2-k8s' ; do
  multipass launch --name "${i}" --cpus 2 --mem 2048M --disk 11G 22.04
done

msg_info 'Creating and distributing certificates'

cd 00-certificates/ || exit
bash distribute-certificates.sh
cd - || exit

msg_info 'Creating and distributing config files'

cd 01-config-files/ || exit
bash distribute-config-files.sh
cd - || exit

msg_info 'Push master and worker setup scripts'

cd 02-masters/ || exit
bash transfer-shell-scripts.sh
cd - || exit
cd 03-workers/ || exit
bash transfer-shell-scripts.sh
cd - || exit

msg_info 'Configuring the Kubernetes control plane'

for i in 'master-1-k8s' 'master-2-k8s'; do
  msg_info "Provisioning ${i}"
  multipass exec ${i} -- bash generate-etcd-systemd.sh "${ETCD_VERSION}"
  multipass exec ${i} -- bash generate-kubernetes-control-plane-systemd.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}"
  multipass exec ${i} -- bash generate-kubelet-rbac-authorization.sh
done

msg_info 'Configuring the Kubernetes workers'

for i in 'worker-1-k8s' 'worker-2-k8s'; do
  msg_info "Provisioning ${i}"
  multipass exec "${i}" -- bash bootstrap-workers.sh "${CONTAINERD_VERSION}" "${CNI_PLUGINS_VERSION}" "${DNS_CLUSTER_IP}"
done

msg_info 'Setting up kubectl to use your newly created cluster'

cd 04-kubectl/ || exit
bash generate-kubectl-config.sh
kubectl get componentstatuses
cd - || exit

msg_info 'Setting up coredns and cilium'

cd 05-networking/ || exit
bash configure-cilium-coredns.sh
cd - || exit

msg_info 'Your cluster should be ready in a couple of minutes!'
msg_info 'You can check the status running: kubectl get all --all-namespaces'
