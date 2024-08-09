#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# Kiểm tra quyền root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} Script này phải được chạy với quyền root!\n" && exit 1

# Kiểm tra hệ điều hành
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả của script!${plain}\n" && exit 1
fi

# Kiểm tra kiến trúc hệ thống
arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Phát hiện kiến trúc thất bại, sử dụng kiến trúc mặc định: ${arch}${plain}"
fi

echo "Kiến trúc: ${arch}"

# Kiểm tra nếu hệ thống không phải là 64-bit
if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ trên hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64). Nếu có lỗi trong việc phát hiện, vui lòng liên hệ với tác giả."
    exit 2
fi

# Kiểm tra phiên bản hệ điều hành
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
fi

# Cài đặt các gói cơ bản
install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# Kiểm tra trạng thái của dịch vụ
# 0: đang chạy, 1: không chạy, 2: không cài đặt
check_status() {
    if [[ ! -f /etc/systemd/system/Aiko-Server.service ]]; then
        return 2
    fi
    temp=$(systemctl status Aiko-Server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}
install_Aiko-Server() {
    # Nếu thư mục /usr/local/Aiko-Server/ đã tồn tại, xóa nó
    if [[ -e /usr/local/Aiko-Server/ ]]; then
        rm -rf /usr/local/Aiko-Server/
    fi

    # Tạo thư mục cài đặt và di chuyển đến đó
    mkdir /usr/local/Aiko-Server/ -p
    cd /usr/local/Aiko-Server/

    # Nếu không có tham số nào được truyền vào
    if [ $# == 0 ] ;then
        # Lấy phiên bản mới nhất từ GitHub
        last_version=$(curl -Ls "https://api.github.com/repos/AikoPanel/AikoServer/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể kiểm tra phiên bản Aiko-Server. Có thể do vượt quá giới hạn API của Github. Vui lòng thử lại sau hoặc chỉ định phiên bản Aiko-Server để cài đặt.${plain}"
            exit 1
        fi
        echo -e "Phát hiện phiên bản mới nhất của Aiko-Server: ${last_version}, bắt đầu cài đặt"
        # Tải xuống phiên bản mới nhất
        wget -q -N --no-check-certificate -O /usr/local/Aiko-Server/Aiko-Server-linux.zip https://github.com/AikoPanel/AikoServer/releases/download/${last_version}/Aiko-Server-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không thể tải xuống Aiko-Server. Vui lòng đảm bảo máy chủ của bạn có thể tải tệp từ Github.${plain}"
            exit 1
        fi
    else
        # Nếu có tham số phiên bản cụ thể
        last_version=$1
        url="https://github.com/AikoPanel/AikoServer/releases/download/${last_version}/Aiko-Server-linux-${arch}.zip"
        echo -e "Bắt đầu cài đặt Aiko-Server v$1"
        wget -q -N --no-check-certificate -O /usr/local/Aiko-Server/Aiko-Server-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không thể tải xuống Aiko-Server v$1. Vui lòng đảm bảo phiên bản tồn tại.${plain}"
            exit 1
        fi
    fi

    # Giải nén tệp zip và thiết lập quyền thực thi
    unzip Aiko-Server-linux.zip
    rm Aiko-Server-linux.zip -f
    chmod +x Aiko-Server

    # Tạo thư mục cấu hình và thiết lập dịch vụ systemd
    mkdir /etc/Aiko-Server/ -p
    rm /etc/systemd/system/Aiko-Server.service -f
    file="https://github.com/AikoPanel/AikoServer/raw/master/Aiko-Server.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/Aiko-Server.service ${file}
    systemctl daemon-reload
    systemctl stop Aiko-Server
    systemctl enable Aiko-Server
    echo -e "${green}Cài đặt Aiko-Server ${last_version}${plain} hoàn tất và đã được thiết lập để khởi động cùng hệ thống"
    
    # Sao chép các tệp cấu hình
    cp geoip.dat /etc/Aiko-Server/
    cp geosite.dat /etc/Aiko-Server/

    if [[ ! -f /etc/Aiko-Server/aiko.yml ]]; then
        cp aiko.yml /etc/Aiko-Server/
        echo -e ""
        echo -e "Đối với cài đặt mới, vui lòng tham khảo hướng dẫn: https://github.com/AikoPanel/AikoServer và cấu hình các nội dung cần thiết"
    else
        systemctl start Aiko-Server
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko-Server khởi động lại thành công${plain}"
        else
            echo -e "${red}Aiko-Server có thể đã không khởi động, vui lòng sử dụng nhật ký Aiko-Server để xem thông tin. Nếu không thể khởi động, có thể định dạng cấu hình đã thay đổi, vui lòng xem wiki để biết thêm thông tin: https://github.com/Aiko-Server-project/Aiko-Server/wiki${plain}"
        fi
    fi

    # Sao chép thêm các tệp cấu hình khác
    if [[ ! -f /etc/Aiko-Server/dns.json ]]; then
        cp dns.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/route.json ]]; then
        cp route.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/AikoBlock ]]; then
        cp AikoBlock /etc/Aiko-Server/
    fi

    curl -o /usr/bin/Aiko-Server -Ls https://raw.githubusercontent.com/dvsteam/Server-AikoPanel/main/Aiko-Server.sh
    chmod +x /usr/bin/Aiko-Server
    ln -s /usr/bin/Aiko-Server /usr/bin/aiko-server
    chmod +x /usr/bin/aiko-server

    # Quay lại thư mục hiện tại và xóa tập tin cài đặt
    cd $cur_dir
    rm -f install.sh

    # Hiển thị thông tin sử dụng script quản lý
    echo -e ""
    echo "Cách sử dụng script quản lý Aiko-Server (tương thích với Aiko-Server, không phân biệt chữ hoa chữ thường):"
    echo "------------------------------------------"
    echo "Aiko-Server              - Hiển thị menu quản lý (nhiều chức năng hơn)"
    echo "Aiko-Server start        - Khởi động Aiko-Server"
    echo "Aiko-Server stop         - Dừng Aiko-Server"
    echo "Aiko-Server restart      - Khởi động lại Aiko-Server"
    echo "Aiko-Server status       - Kiểm tra trạng thái Aiko-Server"
    echo "Aiko-Server enable       - Thiết lập Aiko-Server khởi động cùng hệ thống"
    echo "Aiko-Server disable      - Vô hiệu hóa Aiko-Server khởi động cùng hệ thống"
    echo "Aiko-Server log          - Kiểm tra nhật ký Aiko-Server"
    echo "Aiko-Server generate     - Tạo tệp cấu hình Aiko-Server"
    echo "Aiko-Server update       - Cập nhật Aiko-Server"
    echo "Aiko-Server update x.x.x - Cập nhật Aiko-Server lên phiên bản chỉ định"
    echo "Aiko-Server install      - Cài đặt Aiko-Server"
    echo "Aiko-Server uninstall    - Gỡ cài đặt Aiko-Server"
    echo "Aiko-Server version      - Kiểm tra phiên bản Aiko-Server"
    echo "------------------------------------------"
}

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
install_Aiko-Server $1
