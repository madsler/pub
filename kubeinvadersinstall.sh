#Install k3s w/o traefik, install kubinvaders, example of scaling in ns1
#pre: DNS entry for ingress to kubeinvaders.io
# 

#!/bin/bash
# install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=v3.13.3 bash

# Helm Repositories
helm repo add kubeinvaders https://lucky-sideburn.github.io/helm-charts/
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Helm Repo Update
helm repo update

# install brew
#/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/server/.bashrc
#eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# install k9s
curl -sS https://webinstall.dev/k9s | bash && source ~/.config/envman/PATH.env
#brew install derailed/k9s/k9s

# Install k3s with Traefik disabled
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -s -
mkdir ~/.kube
sudo k3s kubectl config view --raw | tee ~/.kube/config
chmod 600 ~/.kube/config

# Create Namespaces
sudo kubectl create ns kubeinvaders
sudo kubectl create ns namespace1
sudo kubectl create ns namespace2

# Ingress-Nginx Configuration
cat >/tmp/ingress-nginx.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ingress-nginx
  namespace: kube-system
spec:
  chart: ingress-nginx
  repo: https://kubernetes.github.io/ingress-nginx
  targetNamespace: ingress-nginx
  version: v4.9.0
  set:
  valuesContent: |-
    fullnameOverride: ingress-nginx
    controller:
      kind: DaemonSet
      hostNetwork: true
      hostPort:
        enabled: true
      service:
        enabled: false
      publishService:
        enabled: false
      metrics:
        enabled: false
        serviceMonitor:
          enabled: false
      config:
        use-forwarded-headers: "true"
EOF

# Apply Ingress-Nginx Configuration
sudo kubectl create -f /tmp/ingress-nginx.yaml

# Install KubeInvaders Helm Chart
helm install kubeinvaders --set-string config.target_namespace="namespace1\,namespace2" \
-n kubeinvaders kubeinvaders/kubeinvaders --set ingress.enabled=true --set ingress.hostName=kubeinvaders.io --set deployment.image.tag=v1.9.6

# Nginx Deployment Configuration
cat >deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 20 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.24.0
        ports:
        - containerPort: 81
EOF

# Apply Nginx Deployment in namespace1
sudo kubectl apply -f deployment.yaml -n namespace1
sudo kubectl apply -f deployment.yaml -n namespace2

echo '######################################'
echo '######################################'
echo '## Installation abgeschlossen ########
echo '## DNS Eintrag setzen auf diesen #####'
echo '## Host fuer "kubeinvaders.io" #######'
echo '## folgendes Beispiel skaliert die ###'
echo '## Aliens/Pods für Namespace1: #######'
echo '######################################'
echo '######################################'
echo 'kubectl scale deployment.apps/nginx-deployment --replicas=20 -n namespace1'
