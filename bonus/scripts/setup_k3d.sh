#!/bin/bash

# ==============================================================================
# K3s & Argo CD Automation Script
#
# This script automates:
#   1. Installation of dependencies (k3d, kubectl).
#   2. Creation of a k3d cluster.
#   3. Installation of Argo CD.
#   4. Configuration of a private Git repository secret.
#   5. Deployment of a sample application via an Argo CD manifest.
#   6. Port-forwarding for UI access and printing credentials.
# ==============================================================================

NAMESPACE="argocd"
FORWARD_PORT=5555

ENV_FILE="./myapp/.env" 

set -e

if [ -f "$ENV_FILE" ]; then
    echo "[*] Loading GitLab credentials from $ENV_FILE..."
    source "$ENV_FILE"
    
    GITLAB_USER=$GITLAB_USER
    GITLAB_TOKEN=$TOKEN_GITLAB
    IP=$IP
    echo $IP $GITLAB_TOKEN $GITLAB_USER
else
    echo "FATAL: .env file not found. Please run the GitLab setup scripts first. Exiting."
    exit 1
fi
echo "   - Using GitLab User: $GITLAB_USER"

if ! command -v k3d &> /dev/null; then
    echo "--> Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash &> /dev/null
else
    echo "--> k3d is already installed."
fi

if ! command -v kubectl &> /dev/null; then
    echo "--> Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo "--> kubectl is already installed."
fi

if ! k3d cluster get iot-cluster &> /dev/null; then
    echo "--> Creating k3d cluster 'iot-cluster'..."
    k3d cluster create iot-cluster --port 8080:80@loadbalancer &> /dev/null
else
    echo "--> k3d cluster 'iot-cluster' already exists."
fi

export KUBECONFIG=$(k3d kubeconfig write iot-cluster)


echo "--> Installing Argo CD..."
kubectl create namespace $NAMESPACE || echo "Namespace 'argocd' already exists."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml &> /dev/null


kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"timeout.reconciliation":"60s"}}'

echo "--> Apply private repo secret"

kubectl create secret generic private-repo-credentials \
  --namespace=argocd \
  --from-literal=username=$GITLAB_USER \
  --from-literal=password=$GITLAB_TOKEN \
  --from-literal=url="http://$IP:9080/root/amounadi.git" 

kubectl label secret private-repo-credentials \
  --namespace=argocd 'argocd.argoproj.io/secret-type=repository'


echo "--> Applying Argo CD Application..."
kubectl apply -f ../config/deploy.yaml

while [[ $(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o 'jsonpath={.items[0].status.phase}') != "Running" ]]; do
  echo "[*] Waiting for argocd-server ..."
  sleep 8
done

kubectl port-forward svc/argocd-server -n argocd $FORWARD_PORT:443 > /dev/null &
PF_PID=$!


PASSWORD=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)


echo ""
echo "=========================================================="
echo " ✅ ALL SETUP STAGES COMPLETED SUCCESSFULLY! 🎉"
echo "=========================================================="
echo "Your GitOps environment is ready. Check the output above for Argo CD login details."
echo ""
echo "  ArgoCD is ready 🎉"
echo "  Login with:"
echo "    Username: admin"
echo "    Password: $PASSWORD"
echo "  URL: https://localhost:$FORWARD_PORT"
echo "  [*] Port-forward running in background in pid=$PF_PID)"
echo "======================================================="