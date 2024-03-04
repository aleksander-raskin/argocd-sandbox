#!/bin/bash

# Exit script on first error
set -e

# Check if minikube is installed
if ! command -v minikube &> /dev/null
then
    echo "Minikube is not installed"
    brew install minikube
else
    echo "Minikube is already installed"
fi

# Check if minikube is running
if minikube status | grep -q "Running"
then
    echo "Minikube is already running"
else
    echo "Minikube is not running, starting"
    minikube start
fi

# Check if kubectl is installed and install it
if ! command -v kubectl &> /dev/null
then
    echo "Kubectl is not installed"
    brew install kubectl
else
    echo "Kubectl is already installed"
fi

# Check if helm is installed and install it
if ! command -v helm &> /dev/null
then
    echo "Helm is not installed"
    brew install helm
else
    echo "Helm is already installed"
fi

# Check if cluster is running
if kubectl get nodes | grep -q "minikube"
then
    echo "Cluster is running"
else
    echo "Cluster is not running"
    exit 1
fi

# Check if argocd is installed in k8s cluster
if kubectl get ns | grep -q "argo-cd"
then
    echo "ArgoCD is already installed"
else
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update argo
    helm install --namespace=argo-cd --create-namespace argo-cd argo/argo-cd

    # Wait for ArgoCD to be ready
    while [[ $(kubectl get deployments argo-cd-argocd-server -n argo-cd -o 'jsonpath={.status.conditions[?(@.type=="Available")].status}') != "True" ]]; do echo "waiting for argocd-server" && sleep 1; done

    # Change default password to letmein
    kubectl patch secret -n argo-cd argocd-secret -p '{"stringData": { "admin.password": "'$(htpasswd -bnBC 10 "" letmein | tr -d ':\n')'"}}'
    kubectl delete secret -n argo-cd argocd-initial-admin-secret
    
    # Add github repo to argocd
    kubectl apply -f ./repo.yaml
fi


# Port forward to argocd server
kubectl port-forward svc/argo-cd-argocd-server -n argo-cd 8080:443

