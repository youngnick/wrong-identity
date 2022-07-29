
# helm repo add cilium https://helm.cilium.io/
set -x

kindConfig="
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
networking:
  disableDefaultCNI: true
"

kind create cluster --config=- <<<"${kindConfig[@]}"

docker pull quay.io/cilium/cilium:v1.12.0
kind load docker-image quay.io/cilium/cilium:v1.12.0

helm install cilium cilium/cilium --version 1.12.0 \
  --namespace kube-system \
  --set socketLB.enabled=false \
  --set externalIPs.enabled=true \
  --set bpf.masquerade=false \
  --set image.pullPolicy=IfNotPresent \
  --set ipam.mode=kubernetes \
  --set l7Proxy=false \
  --set encryption.enabled=true \
  --set encryption.type=wireguard

# cilium connectivity test
