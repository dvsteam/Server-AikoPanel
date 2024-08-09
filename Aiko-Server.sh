#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Kiểm tra quyền root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain}Bạn phải chạy script này với quyền root!\n" && exit 1

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

CONFIG_FILE="/etc/Aiko-Server/aiko.yml"

# Phiên bản hệ điều hành
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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [mặc định $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có chắc chắn muốn khởi động lại Aiko-Server không?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}


before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn Enter để quay lại menu chính:${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/dvsteam/Server-AikoPanel/main/AikoServer-install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản cụ thể (mặc định là phiên bản mới nhất): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/AikoPanel/AikoServer/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cập nhật đã hoàn tất, Aiko-Server đã được khởi động lại tự động, vui lòng sử dụng lệnh “Aiko-Server log” để xem nhật ký hoạt động${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "Aiko-Server sẽ tự động cố gắng khởi động lại sau khi thay đổi cấu hình"
    nano /etc/Aiko-Server/aiko.yml
    sleep 1
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko-Server: ${green}Đang chạy${plain}"
            ;;
        1)
            echo -e "Aiko-Server không chạy hoặc không thể khởi động lại tự động. Bạn có muốn xem tệp nhật ký không? [Y/n]" && echo
            read -e -rp "(mặc định: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Trạng thái Aiko-Server: ${red}Chưa cài đặt${plain}"
    esac
}


uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt Aiko-Server không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop Aiko-Server
    systemctl disable Aiko-Server
    rm /etc/systemd/system/Aiko-Server.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/Aiko-Server/ -rf
    rm /usr/local/Aiko-Server/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công. Nếu bạn muốn xóa kịch bản này, hãy chạy ${green}rm /usr/bin/Aiko-Server -f${plain} sau khi thoát khỏi kịch bản"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Aiko-Server đã đang chạy, không cần khởi động lại. Để khởi động lại, vui lòng chọn Khởi động lại${plain}"
    else
        systemctl start Aiko-Server
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko-Server đã khởi động thành công, vui lòng sử dụng lệnh Aiko-Server log để xem nhật ký hoạt động${plain}"
        else
            echo -e "${red}Aiko-Server có thể đã không khởi động được. Vui lòng kiểm tra thông tin nhật ký sau với lệnh Aiko-Server log${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Aiko-Server
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Aiko-Server đã được dừng${plain}"
    else
        echo -e "${red}Aiko-Server không thể dừng, có thể vì thời gian dừng vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart Aiko-Server
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server đã khởi động lại thành công, vui lòng sử dụng lệnh Aiko-Server log để xem nhật ký hoạt động${plain}"
    else
        echo -e "${red}Aiko-Server có thể đã không khởi động lại được. Vui lòng kiểm tra thông tin nhật ký sau với lệnh Aiko-Server log${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status Aiko-Server --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Aiko-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server đã được đặt để khởi động tự động${plain}"
    else
        echo -e "${red}Không thể đặt Aiko-Server để khởi động tự động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Aiko-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server đã được đặt để không khởi động tự động${plain}"
    else
        echo -e "${red}Không thể đặt Aiko-Server để không khởi động tự động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Aiko-Server.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontents.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/Aiko-Server -N --no-check-certificate https://raw.githubusercontents.com/AikoPanel/AikoServer/master/Aiko-Server.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Tải xuống kịch bản không thành công. Vui lòng kiểm tra xem máy cục bộ có thể kết nối với Github không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Aiko-Server
        echo -e "${green}Nâng cấp kịch bản hoàn tất. Vui lòng chạy lại kịch bản${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
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

check_enabled() {
    temp=$(systemctl is-enabled Aiko-Server)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Aiko-Server đã được cài đặt. Vui lòng không cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt Aiko-Server trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko-Server: ${green}Đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái Aiko-Server: ${yellow}Không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái Aiko-Server: ${red}Chưa cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có khởi động tự động: ${green}Có${plain}"
    else
        echo -e "Có khởi động tự động: ${red}Không${plain}"
    fi
}

show_Aiko-Server_version() {
   echo -n "Phiên bản Aiko-Server: "
    /usr/local/Aiko-Server/Aiko-Server version
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_config_file() {
    echo -e "${yellow}Trình hướng dẫn tạo tệp cấu hình Aiko-Server${plain}"
    echo -e "${red}Vui lòng đọc các lưu ý sau:${plain}"
    echo -e "${red}1. Tính năng này hiện đang trong giai đoạn thử nghiệm${plain}"
    echo -e "${red}2. Tệp cấu hình được tạo sẽ được lưu tại /etc/Aiko-Server/aiko.yml${plain}"
    echo -e "${red}3. Tệp cấu hình gốc sẽ được lưu tại /etc/Aiko-Server/aiko.yml.bak${plain}"
    echo -e "${red}4. TLS hiện không được hỗ trợ${plain}"
    read -rp "Bạn có muốn tiếp tục tạo tệp cấu hình không? (y/n) " generate_config_file_continue

    if [[ $generate_config_file_continue =~ ^[yY]$ ]]; then
        read -rp "Nhập số lượng nút cần cấu hình: " num_nodes

        cd /etc/Aiko-Server
        echo "Nodes:" > /etc/Aiko-Server/aiko.yml

        for (( i=1; i<=num_nodes; i++ )); do
            echo "Cấu hình Nút $i..."
            read -rp "Nhập tên miền của máy chủ: " ApiHost
            read -rp "Nhập khóa API của bảng điều khiển: " ApiKey
            read -rp "Nhập ID nút: " NodeID

            echo -e "${yellow}Vui lòng chọn giao thức truyền tải của nút, nếu không có trong danh sách thì không được hỗ trợ:${plain}"
            echo -e "${green}1. Shadowsocks${plain}"
            echo -e "${green}2. V2ray${plain}"
            echo -e "${green}3. Trojan${plain}"
            echo -e "${green}4. Vless${plain}"
            read -rp "Nhập giao thức truyền tải (1-4, mặc định 2): " NodeType
            case "$NodeType" in
                1 ) NodeType="Shadowsocks"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
                2 ) NodeType="V2ray"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
                3 ) NodeType="Trojan"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
                4 ) NodeType="V2ray"; DisableLocalREALITYConfig="true"; EnableVless="true"; EnableREALITY="true" ;;
                * ) NodeType="V2ray"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
            esac

            cat <<EOF >> /etc/Aiko-Server/aiko.yml
  - PanelType: "AikoPanel"
    ApiConfig:
      ApiHost: "${ApiHost}"
      ApiKey: "${ApiKey}"
      NodeID: ${NodeID}
      NodeType: ${NodeType}
      Timeout: 30
      EnableVless: ${EnableVless}
      RuleListPath:
    ControllerConfig:
      EnableProxyProtocol: false
      DisableLocalREALITYConfig: ${DisableLocalREALITYConfig}
      EnableREALITY: ${EnableREALITY}
      REALITYConfigs:
        Show: true
      CertConfig:
        CertMode: none
        CertFile: /etc/Aiko-Server/cert/aiko_server.cert
        KeyFile: /etc/Aiko-Server/cert/aiko_server.key
EOF
        done
    else
        echo -e "${red}Đã hủy việc tạo tệp cấu hình Aiko-Server${plain}"
        before_show_menu
    fi
}

generate_x25519(){
    echo "Aiko-Server sẽ tự động cố gắng khởi động lại sau khi tạo cặp khóa"
    /usr/local/Aiko-Server/Aiko-Server x25519
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_certificate(){
    CONFIG_FILE="/etc/Aiko-Server/aiko.yml"
    echo "Aiko-Server sẽ tự động cố gắng khởi động lại sau khi tạo chứng chỉ"
    read -p "Nhập tên miền của chứng chỉ (mặc định: aikopanel.com): " domain
    read -p "Nhập số ngày hết hạn của chứng chỉ (mặc định: 90 ngày): " expire

    # Thiết lập giá trị mặc định
    if [ -z "$domain" ]; then
        domain="aikopanel.com"
    fi

    if [ -z "$expire" ]; then
        expire="90"
    fi
    
    # Gọi binary Go với các giá trị đầu vào
    /usr/local/Aiko-Server/Aiko-Server cert --domain "$domain" --expire "$expire"
    sed -i "s|CertMode:.*|CertMode: file|" $CONFIG_FILE
    sed -i "s|CertDomain:.*|CertDomain: ${domain}|" $CONFIG_FILE
    sed -i "s|CertFile:.*|CertFile: /etc/Aiko-Server/cert/aiko_server.cert|" $CONFIG_FILE
    sed -i "s|KeyFile:.*|KeyFile: /etc/Aiko-Server/cert/aiko_server.key|" $CONFIG_FILE
    echo -e "${green}Cấu hình thành công!${plain}"
    read -p "Nhấn bất kỳ phím nào để quay lại menu..."
    show_menu
}
generate_config_default() {
    echo -e "${yellow}Trình hướng dẫn tạo tệp cấu hình mặc định của Aiko-Server${plain}"
    # kiểm tra /etc/Aiko-Server/aiko.yml
    if [[ -f /etc/Aiko-Server/aiko.yml ]]; then
        echo -e "${red}Tệp cấu hình đã tồn tại, vui lòng xóa nó trước${plain}"
        read -p "${green} Bạn có muốn xóa nó ngay bây giờ không? (y/n) ${plain}" delete_config
        if [[ $delete_config =~ ^[yY]$ ]]; then
            rm -rf /etc/Aiko-Server/aiko.yml
            echo -e "${green}Tệp cấu hình đã được xóa${plain}"
            /usr/local/Aiko-Server/Aiko-Server config
            echo -e "${green}Tệp cấu hình mặc định đã được tạo${plain}"
        else
            echo -e "${red}Vui lòng xóa tệp cấu hình trước${plain}"
            before_show_menu
        fi 
        before_show_menu
    fi
}

install_rule_list() {
    read -p "Bạn có muốn cài đặt rulelist không? [y/n] " answer_1
    if [[ "$answer_1" == "y" ]]; then
        RuleListPath="/etc/Aiko-Server/rulelist"
        mkdir -p /etc/Aiko-Server/  # Tạo thư mục nếu chưa tồn tại
        
        if wget https://raw.githubusercontent.com/AikoPanel/AikoServer/master/config/rulelist -O "$RuleListPath"; then
            sed -i "s|RuleListPath:.*|RuleListPath: ${RuleListPath}|" "$CONFIG_FILE"
            echo -e "${green}rulelist đã được cài đặt!${plain}\n"
        else
            echo -e "${red}Không thể tải xuống rulelist. Vui lòng kiểm tra kết nối internet của bạn hoặc thử lại sau.${plain}\n"
        fi
    elif [[ "$answer_1" == "n" ]]; then
        echo -e "${green}[rulelist]${plain} Không được cài đặt"
    else
        echo -e "${yellow}Cảnh báo:${plain} Lựa chọn không hợp lệ. Vui lòng chọn 'y' để đồng ý hoặc 'n' để từ chối."
        install_rule_list  # Gọi đệ quy để yêu cầu lại
    fi
    show_menu
}

# Mở cổng tường lửa
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}Tất cả các cổng mạng trên VPS hiện đã được mở!${plain}"
}

show_usage() {
    echo "Hướng dẫn sử dụng Kịch bản Quản lý Aiko-Server: "
    echo "------------------------------------------"
    echo "Aiko-Server               - Hiển thị menu quản lý (với nhiều chức năng hơn)"
    echo "Aiko-Server start         - Khởi động Aiko-Server"
    echo "Aiko-Server stop          - Dừng Aiko-Server"
    echo "Aiko-Server restart       - Khởi động lại Aiko-Server"
    echo "Aiko-Server status        - Kiểm tra trạng thái Aiko-Server"
    echo "Aiko-Server enable        - Đặt Aiko-Server khởi động cùng hệ thống"
    echo "Aiko-Server disable       - Vô hiệu hóa Aiko-Server khởi động cùng hệ thống"
    echo "Aiko-Server log           - Xem nhật ký Aiko-Server"
    echo "Aiko-Server generate      - Tạo tệp cấu hình Aiko-Server"
    echo "Aiko-Server defaultconfig - Thay đổi tệp cấu hình Aiko-Server"
    echo "Aiko-Server x25519        - Tạo cặp khóa x25519"
    echo "Aiko-Server cert          - Tạo chứng chỉ cho Aiko-Server"
    echo "Aiko-Server MultiNode     - Tạo MultiNode cho Aiko-Server với 1 cổng"
    echo "Aiko-Server update        - Cập nhật Aiko-Server"
    echo "Aiko-Server update x.x.x  - Cài đặt phiên bản cụ thể của Aiko-Server"
    echo "Aiko-Server install       - Cài đặt Aiko-Server"
    echo "Aiko-Server uninstall     - Gỡ cài đặt Aiko-Server"
    echo "Aiko-Server version       - Hiển thị phiên bản Aiko-Server"
    echo "------------------------------------------"
}


show_menu() {
    echo -e "
  ${green}Kịch bản quản lý Backend Aiko-Server, ${plain}${red}không dành cho docker${plain}
--- https://github.com/AikoPanel/Aiko-Server ---
  ${green}0.${plain} Thay đổi cấu hình
————————————————
  ${green}1.${plain} Cài đặt Aiko-Server
  ${green}2.${plain} Cập nhật Aiko-Server
  ${green}3.${plain} Gỡ cài đặt Aiko-Server
————————————————
  ${green}4.${plain} Khởi động Aiko-Server
  ${green}5.${plain} Dừng Aiko-Server
  ${green}6.${plain} Khởi động lại Aiko-Server
  ${green}7.${plain} Kiểm tra trạng thái Aiko-Server
  ${green}8.${plain} Xem nhật ký Aiko-Server
————————————————
  ${green}9.${plain} Đặt Aiko-Server khởi động cùng hệ thống
 ${green}10.${plain} Vô hiệu hóa Aiko-Server khởi động cùng hệ thống
————————————————
 ${green}11.${plain} Cài đặt BBR (nhân mới nhất) chỉ với một cú nhấp chuột
 ${green}12.${plain} Hiển thị phiên bản Aiko-Server
 ${green}13.${plain} Cập nhật kịch bản bảo trì Aiko-Server
 ${green}14.${plain} Tạo tệp cấu hình Aiko-Server
 ${green}15.${plain} Mở tất cả các cổng mạng trên VPS
 ${green}16.${plain} Tạo cặp khóa x25519
 ${green}17.${plain} Tạo chứng chỉ cho Aiko-Server
 ${green}18.${plain} Tạo tệp cấu hình mặc định của Aiko-Server
 ${green}19.${plain} Chặn Speedtest
"
    show_status
    echo && read -rp "Vui lòng nhập tùy chọn [0-19]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_Aiko-Server_version ;;
        13) update_shell ;;
        14) generate_config_file ;;
        15) open_ports ;;
        16) generate_x25519 ;;
        17) generate_certificate ;;
        18) generate_config_default ;;
        19) install_rule_list ;;
        *) echo -e "${red}Vui lòng nhập số chính xác [0-19]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "defaultconfig") generate_config_default ;;
        "blockspeedtest") install_rule_list ;;
        "x25519") generate_x25519 ;;
        "cert") generate_certificate ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_Aiko-Server_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
