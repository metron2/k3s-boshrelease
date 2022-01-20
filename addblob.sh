#!/bin/bash
set -x
bosh add-blob src/github.com/k3s-io/k3s/k3s k3s/k3s
bosh add-blob src/github.com/k3s-io/k3s/k3s-airgap-images-amd64.tar k3s-images/k3s-airgap-images-amd64.tar

pushd src/github.com/derailed/k9s/
tar xfv ./k9s_Linux_x86_64.tar.gz
popd
bosh add-blob src/github.com/derailed/k9s/k9s k9s/k9s

pushd src
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" --output ./src/kubectl
chmod ugo+x kubectl
popd
bosh add-blob src/kubectl kubectl/kubectl


