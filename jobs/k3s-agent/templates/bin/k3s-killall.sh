#!/bin/sh
[ $(id -u) -eq 0 ] || exec sudo $0 $@

for bin in /var/lib/rancher/k3s/data/**/bin/; do
    [ -d $bin ] && export PATH=$PATH:$bin:$bin/aux
done

set -x

for service in /etc/systemd/system/k3s*.service; do
    [ -s $service ] && systemctl stop $(basename $service)
done

for service in /etc/init.d/k3s*; do
    [ -x $service ] && $service stop
done

pschildren() {
    ps -e -o ppid= -o pid= | \
    sed -e 's/^\s*//g; s/\s\s*/\t/g;' | \
    grep -w "^$1" | \
    cut -f2
}

pstree() {
    for pid in $@; do
        echo $pid
        for child in $(pschildren $pid); do
            pstree $child
        done
    done
}

killtree() {
    kill -9 $(
        { set +x; } 2>/dev/null;
        pstree $@;
        set -x;
    ) 2>/dev/null
}

getshims() {
    lsof | sed -e 's/^[^0-9]*//g; s/  */\t/g' | grep -w 'k3s/data/[^/]*/bin/containerd-shim' | cut -f1 | sort -n -u
}

killtree $({ set +x; } 2>/dev/null; getshims; set -x)

do_unmount_and_remove() {
    set +x
    while read -r _ path _; do
        case "$path" in $1*) echo "$path" ;; esac
    done < /proc/self/mounts | sort -r | xargs -r -t -n 1 sh -c 'umount "$0" && rm -rf "$0"'
    set -x
}

do_unmount_and_remove '/run/k3s'
do_unmount_and_remove '/var/lib/rancher/k3s'
do_unmount_and_remove '/var/vcap/data/k3s-agent/kubelet/pods' #bosh fs layout adaptation
do_unmount_and_remove '/var/vcap/data/k3s-agent/kubelet/plugins'
do_unmount_and_remove '/var/vcap/data/k3s-agent/kubelet/plugins/kubernetes.io/csi' #bosh fs adaptation for csi mount (eg: longhorn)
do_unmount_and_remove '/run/netns/cni-'

# Remove CNI namespaces
ip netns show 2>/dev/null | grep cni- | xargs -r -t -n 1 ip netns delete

# Delete network interface(s) that match 'master cni0'
ip link show 2>/dev/null | grep 'master cni0' | while read ignore iface ignore; do
    iface=${iface%%@*}
    [ -z "$iface" ] || ip link delete $iface
done
ip link delete cni0
ip link delete flannel.1
ip link delete flannel-v6.1
rm -rf /var/lib/cni/
iptables-save | grep -v KUBE- | grep -v CNI- | iptables-restore
ip6tables-save | grep -v KUBE- | grep -v CNI- | ip6tables-restore
