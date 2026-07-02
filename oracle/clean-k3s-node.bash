sudo bash -c '
set -euxo pipefail

echo "==> Parando servicios"
systemctl stop rancher-system-agent 2>/dev/null || true
systemctl stop k3s 2>/dev/null || true
systemctl stop k3s-agent 2>/dev/null || true
systemctl disable rancher-system-agent 2>/dev/null || true
systemctl disable k3s 2>/dev/null || true
systemctl disable k3s-agent 2>/dev/null || true

echo "==> Ejecutando desinstaladores oficiales si existen"
/usr/local/bin/k3s-killall.sh 2>/dev/null || true
/usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
/usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true

echo "==> Eliminando servicios systemd"
rm -f /etc/systemd/system/rancher-system-agent.service
rm -f /etc/systemd/system/k3s.service
rm -f /etc/systemd/system/k3s-agent.service
rm -f /etc/systemd/system/multi-user.target.wants/rancher-system-agent.service
rm -f /etc/systemd/system/multi-user.target.wants/k3s.service
rm -f /etc/systemd/system/multi-user.target.wants/k3s-agent.service

echo "==> Eliminando binarios"
rm -f /usr/local/bin/k3s
rm -f /usr/local/bin/kubectl
rm -f /usr/local/bin/crictl
rm -f /usr/local/bin/ctr
rm -f /usr/local/bin/rancher-system-agent
rm -f /usr/local/bin/k3s-killall.sh
rm -f /usr/local/bin/k3s-uninstall.sh
rm -f /usr/local/bin/k3s-agent-uninstall.sh

echo "==> Eliminando configuración y estado de Rancher/K3s"
rm -rf /etc/rancher
rm -rf /var/lib/rancher
rm -rf /var/log/rancher
rm -rf /run/k3s
rm -rf /run/flannel
rm -rf /var/lib/kubelet
rm -rf /var/lib/cni
rm -rf /etc/cni
rm -rf /opt/cni
rm -rf /var/lib/calico
rm -rf /var/run/calico

echo "==> Eliminando restos Kubernetes"
rm -rf /etc/kubernetes
rm -rf /var/lib/etcd
rm -rf /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots 2>/dev/null || true

echo "==> Eliminando interfaces de red CNI si existen"
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
ip link delete flannel-v6.1 2>/dev/null || true

echo "==> Limpiando reglas iptables típicas de K3s/CNI"
iptables-save | grep -v KUBE- | grep -v CNI- | grep -v FLANNEL- | iptables-restore || true
ip6tables-save | grep -v KUBE- | grep -v CNI- | grep -v FLANNEL- | ip6tables-restore || true

echo "==> Recargando systemd"
systemctl daemon-reload
systemctl reset-failed

echo "==> Limpieza terminada. Recomendado reiniciar ahora."
'