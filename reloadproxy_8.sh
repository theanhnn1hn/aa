#!/bin/sh
get_network_interface() {
  ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'
}

INTERFACE=$(get_network_interface | head -n 1 | tr -d ' ')
# Định nghĩa các hàm từ script ban đầu
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
# Thêm các hàm gen_data và gen_ifconfig từ script gốc
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig ${INTERFACE} inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}
gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
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
# Phần thực thi của script mới
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

# Đọc số lượng proxy từ dòng đầu tiên của data.txt
COUNT=$(cat ${WORKDATA} | wc -l)
FIRST_PORT=23000    
LAST_PORT=$(($FIRST_PORT + $COUNT))

# Tạo lại IPv6 cho proxy
gen_data >$WORKDIR/data.txt
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_ifconfig.sh

# Cập nhật cấu hình 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Khởi động lại 3proxy và cấu hình IPv6 mới
systemctl stop 3proxy
bash ${WORKDIR}/boot_ifconfig.sh
systemctl start 3proxy

# Xuất thông tin proxy mới
gen_proxy_file_for_user
