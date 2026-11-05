#!/usr/bin/env bash
# Read-only guest health report. Exit 0 = ready, 1 = pending/unhealthy, 2 = usage.
set -u
if [[ $# != 0 || $EUID != 0 ]]; then echo 'Usage: sudo /opt/x2a/status.sh' >&2; exit 2; fi
export KUBECONFIG=/var/lib/kind/kubeconfig
export LC_ALL=C
result=0
section() { printf '\n=== %s ===\n' "$*"; }
section 'Guest'
hostname
uptime
df -h /var
free -h
section 'Cloud-init (running can mean cloud-final is waiting for RHDH)'
cloud-init status --long
cloud_result=$?
# Cloud-init returns 2 for recoverable warnings, not necessarily failed provisioning.
[[ $cloud_result != 1 ]] || result=1
section 'System services'
for unit in sshd firewalld kind rhdh x2a-port-forward x2a-https; do
    state=$(systemctl is-active "$unit" 2>/dev/null) || true
    printf '%-22s %s\n' "$unit" "$state"
    [[ "$state" == active ]] || result=1
done
systemctl --failed --no-pager
section 'Listening ports'
ss -lntup
section 'Firewall'
firewall-cmd --list-all || result=1
section 'Kubernetes'
if [[ ! -s $KUBECONFIG ]]; then
    echo "Kubeconfig not yet available: $KUBECONFIG (check journalctl -u kind-create)."
    result=1
elif kubectl --request-timeout=10s get nodes -o wide; then
    if ! nodes=$(kubectl --request-timeout=10s get nodes -o json) ||
       ! printf '%s' "$nodes" | jq -e '.items | length > 0 and all(.[]; any(.status.conditions[]; .type == "Ready" and .status == "True"))' >/dev/null; then
        echo 'One or more Kubernetes nodes are not Ready.'
        result=1
    fi
    kubectl --request-timeout=10s get pods -A -o wide || result=1
    kubectl --request-timeout=10s -n rhdh get services,endpointslices -o wide || result=1
    # Endpoint presence alone does NOT mean the endpoint is ready.
    for workload in deployment/rhdh-developer-hub statefulset/rhdh-postgresql; do
        if ! data=$(kubectl --request-timeout=10s -n rhdh get "$workload" -o json); then
            result=1
            continue
        fi
        if printf '%s' "$data" | jq -e '(.spec.replicas // 1) > 0 and (.status.observedGeneration // 0) >= .metadata.generation and (.status.readyReplicas // 0) == (.spec.replicas // 1)' >/dev/null; then
            printf '%s: READY\n' "$workload"
        else
            printf '%s: NOT READY (initialization, image pulls, or readiness checks pending)\n' "$workload"
            result=1
        fi
    done
else
    result=1
fi
section 'HTTPS through nginx to RHDH'
# -k is intentional only for the generated self-signed development certificate.
if code=$(curl --noproxy '*' -ksS --max-time 10 -o /dev/null -w '%{http_code}' https://127.0.0.1/); then
    printf 'Guest HTTPS response: %s\n' "$code"
    case "$code" in 2??|3??) ;; *) result=1 ;; esac
else
    result=1
fi
if [[ $result != 0 ]]; then
    section 'Startup jobs and proxy failure details'
    systemctl list-jobs --no-pager
    for unit in rhdh x2a-port-forward x2a-selinux x2a-https; do
        printf '\n--- %s ---\n' "$unit"
        systemctl show "$unit" -p ActiveState -p SubState -p Result \
            -p ExecMainStatus -p NRestarts --no-pager
        journalctl -b --no-pager -n 25 -u "$unit"
    done
    section 'TLS file permissions and SELinux context (not key contents)'
    ls -lZ /etc/pki/tls/private/x2a.key /etc/pki/tls/certs/x2a.crt /etc/nginx/x2a.conf
    getenforce
    if selinuxenabled; then
        getsebool httpd_can_network_connect
    else
        echo 'SELinux is disabled; the nginx network boolean does not apply.'
    fi
    section 'Recent SELinux denials'
    journalctl -b --no-pager -n 15 -g 'avc:.*denied'
    section 'Backstage readiness response through HTTPS'
    curl --noproxy '*' -ksS --max-time 10 -w '\nHTTP %{http_code}\n' \
        https://127.0.0.1/.backstage/health/v1/readiness
    section 'Backstage init-container progress'
    if [[ -s $KUBECONFIG ]] && pods=$(kubectl --request-timeout=10s -n rhdh get pods -l app.kubernetes.io/component=backstage -o json); then
        while IFS= read -r pod; do
            [[ -n "$pod" ]] || continue
            printf '\n--- %s / install-dynamic-plugins ---\n' "$pod"
            kubectl --request-timeout=10s -n rhdh logs "$pod" -c install-dynamic-plugins --tail=20
            printf '\n--- %s / backstage-backend ---\n' "$pod"
            kubectl --request-timeout=10s -n rhdh logs "$pod" -c backstage-backend --tail=40
        done < <(printf '%s' "$pods" | jq -r '.items[:3][] | .metadata.name')
    fi
fi
section 'Summary'
if [[ $result == 0 ]]; then
    echo 'READY: guest HTTPS and application readiness checks passed.'
else
    echo 'NOT READY: inspect the checks above; an active service is not proof of application readiness.'
    echo 'Logs: journalctl -u rhdh -u x2a-port-forward -u x2a-https'
fi
echo 'Host port forwarding/firewall must be checked on the host separately.'
exit "$result"
