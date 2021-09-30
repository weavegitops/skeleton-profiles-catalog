#!/usr/bin/env bash

if [ -n "${DEBUG}" ]; then
    set -x
fi

set -eu
set -o pipefail

unset KUBECONFIG

GITOPS_VERSION="0.3.0"
PCTL_VERSION="0.11.0"
K8S_VERSION="1.21.1"

KIND_CLUSTER=testing

CONFDIR="${PWD}/.conf"
BINDIR="${PWD}/.bin"

#Install WeaveGitops:
# - check if installed, if not install from GH release:
if [[ ! -x $(which gitops) ]]; then
    echo "gitops binary not found, installing ..."
    curl -L "https://github.com/weaveworks/weave-gitops/releases/download/v${GITOPS_VERSION}/gitops-$(uname)-$(uname -m)" -o gitops
    chmod +x gitops
    sudo mv ./gitops /usr/local/bin/gitops
    gitops version
fi

#Install ProfileCTL:
# - check if installed, if not install from GH release:
if [[ ! -x $(which pctl) ]]; then
    echo "pctl binary not found, installing ..."
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    wget "https://github.com/weaveworks/pctl/releases/download/v${PCTL_VERSION}/pctl_${OS}_amd64.tar.gz"
    tar xvfz pctl_${OS}_amd64.tar.gz
    sudo mv ./pctl /usr/local/bin/pctl
    pctl --version
fi

echo "Creating kind cluster ..."
echo "Creating kind management cluster ..."
kind get clusters | grep ${KIND_CLUSTER} || kind create cluster --name ${KIND_CLUSTER}

echo "Check if config folder exists ..."
[[ -d ${CONFDIR} ]] || mkdir ${CONFDIR}

echo "Exporting kind management cluster kubeconfig ..."
kind get kubeconfig --name ${KIND_CLUSTER} > ${CONFDIR}/${KIND_CLUSTER}.kubeconfig

export KUBECONFIG=${CONFDIR}/${KIND_CLUSTER}.kubeconfig

echo "Pulling profiles controller from docker hub"
docker pull weaveworks/profiles-controller:v0.2.0

echo "Loading profile controller images into workload cluster nodes"
kind load docker-image --name ${KIND_CLUSTER} weaveworks/profiles-controller:v0.2.0

echo "Installing WeaveGitops"
gitops install

echo "Installing profile-controller"
pctl install --flux-namespace wego-system