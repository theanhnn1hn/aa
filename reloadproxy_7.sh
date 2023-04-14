#!/bin/sh
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
main_interface=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong
users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})
$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "yag/anhbiencong/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

update_proxy_ipv6() {
    # Stop 3proxy service
    service 3proxy stop

    # Generate new data
    gen_data >$WORKDIR/data.txt
    gen_iptables >$WORKDIR/boot_iptables.sh
    gen_ifconfig >$WORKDIR/boot_ifconfig.sh
    chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

    # Update 3proxy configuration
    gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

    # Update iptables and ifconfig
    bash ${WORKDIR}/boot_iptables.sh
    bash ${WORKDIR}/boot_ifconfig.sh

    # Start 3proxy service
    ulimit -n 10048
    service 3proxy start

    # Generate new proxy file for user
    gen_proxy_file_for_user
}

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_proxies>"
    exit 1
fi
num_proxies=$1
FIRST_PORT=23000
LAST_PORT=$(($FIRST_PORT + $num_proxies - 1))

update_proxy_ipv6
