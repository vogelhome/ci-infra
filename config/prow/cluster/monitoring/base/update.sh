#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2024 SAP SE or an SAP affiliate company and Gardener contributors
#
# SPDX-License-Identifier: Apache-2.0


set -o errexit
set -o nounset
set -o pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$script_dir"

kube_prometheus_version="v0.13.0"
echo "> Fetching kube-prometheus@$kube_prometheus_version"

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

# GNU tar deals differently with wildcard as bsdtar
if tar --version | grep -q "GNU tar"; then
    wildcards="--wildcards"
else
    wildcards=""
fi

tarball="$tmp_dir/archive.tar.gz"
curl -sSLo "$tarball" https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags/$kube_prometheus_version.tar.gz

prometheus_operator_version=$(tar -O -xzf "$tarball" $wildcards "kube-prometheus-*/manifests/prometheusOperator-deployment.yaml" | grep app.kubernetes.io/version | head -1 | awk '{print $2}')

echo "Included prometheus-operator version: $prometheus_operator_version"

echo "> Removing old yaml files"
find "$script_dir" -name "*.yaml" -exec rm -rf {} \;

echo "> Updating kube-prometheus"

tar -xzf "$tarball" --strip-components=2 $wildcards "kube-prometheus-*/manifests/*.yaml"

cat <<EOF > README.md
The manifests in this directory were downloaded from
https://github.com/prometheus-operator/kube-prometheus/tree/$kube_prometheus_version/manifests.

Bump the version in [\`$(basename $0)\`](../$(basename $0)) and run the script to update the CRDs.
EOF

cat <<EOF > kustomization.yaml
# Code generated by $(basename $0), DO NOT EDIT.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ./setup

resources:
$(ls *.yaml | sed 's/^/- /')
EOF

echo "> Updating kube-prometheus/setup"

tar -xzf "$tarball" --strip-components=2 $wildcards "kube-prometheus-*/manifests/setup/*.yaml"
cd "$script_dir/setup"

cat <<EOF > README.md
The CRDs in this directory were downloaded from
https://github.com/prometheus-operator/kube-prometheus/tree/$kube_prometheus_version/manifests/setup.

Bump the version in [\`$(basename $0)\`](../$(basename $0)) and run the script to update the CRDs.
EOF

cat <<EOF > kustomization.yaml
# Code generated by $(basename $0), DO NOT EDIT.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

commonLabels:
  app.kubernetes.io/name: prometheus-operator
  app.kubernetes.io/part-of: kube-prometheus
  app.kubernetes.io/version: $prometheus_operator_version

resources:
$(ls *.yaml | sed 's/^/- /')
EOF

