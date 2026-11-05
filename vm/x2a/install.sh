#!/usr/bin/env bash
# VM entry point: cloud-init supplies /etc/x2a; Helm owns application config.
set -Eeuo pipefail
umask 077

# Called independently by the HTTPS unit so proxy startup never waits for Helm.
if [[ ${1:-} == --tls-only && $# == 1 ]]; then
    key=/etc/pki/tls/private/x2a.key
    cert=/etc/pki/tls/certs/x2a.crt
    if [[ -s "$key" && -s "$cert" ]]; then exit 0; fi
    if [[ -e "$key" || -e "$cert" ]]; then
        echo 'Incomplete TLS certificate pair; provide both x2a.key and x2a.crt.' >&2
        exit 1
    fi
    umask 077
    mkdir -p /etc/pki/tls/private /etc/pki/tls/certs
    openssl req -x509 -newkey rsa:3072 -nodes -days 30 \
        -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
        -keyout "$key" -out "$cert"
    # Ephemeral bootc guests may have SELinux disabled by their launcher.
    if selinuxenabled; then
        restorecon "$key" "$cert"
    fi

    exit 0
fi
[[ $# == 0 ]] || { echo 'Usage: /opt/x2a/install.sh' >&2; exit 2; }

export KUBECONFIG=/var/lib/kind/kubeconfig

kubectl create namespace rhdh
kubectl -n rhdh create secret generic x2a-llm --from-env-file=/etc/x2a/llm.env
kubectl -n rhdh create secret generic x2a-aap --from-env-file=/etc/x2a/aap.env
kubectl -n rhdh create secret generic x2a-auth --from-env-file=/etc/x2a/auth.env

helm install rhdh /usr/share/x2a/chart --namespace rhdh
