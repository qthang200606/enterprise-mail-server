#!/usr/bin/env bash
# ==============================================================================
# Script: check-system.sh
# Mục đích: Script 1-click kiểm tra toàn diện sức khỏe hệ thống Mail Server:
#           - Hostname & IP tĩnh
#           - Tình trạng tường lửa UFW
#           - Trạng thái các dịch vụ (Postfix, Dovecot, Apache2, UFW)
#           - Các cổng mạng đang lắng nghe (Listening Ports)
#           - Danh sách 5 người dùng và quyền Maildir (700)
#           - Trích xuất log mới nhất của hệ thống mail
# ==============================================================================

set -euo pipefail

# Màu sắc hiển thị
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Hàm in tiêu đề mục
section_header() {
    echo -e "\n${BOLD}${BLUE}==============================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${BLUE}==============================================================================${NC}"
}

# Kiểm tra quyền root
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${YELLOW}[LƯU Ý] Một số kiểm tra (ss -p, ufw, log) yêu cầu quyền root để hiện đầy đủ thông tin.${NC}"
        echo -e "${YELLOW}Khuyến nghị chạy lại với: sudo $0 $*${NC}\n"
    fi
}

# In trợ giúp
show_help() {
    echo -e "${BLUE}=== CÔNG CỤ KIỂM TRA SỨC KHỎE HỆ THỐNG MAIL SERVER ===${NC}"
    echo "Cách dùng: sudo $0 [TÙY CHỌN]"
    echo ""
    echo "Tùy chọn (Flags):"
    echo "  --all         (Mặc định) Chạy toàn bộ các bước kiểm tra từ A-Z."
    echo "  --services    Chỉ kiểm tra trạng thái dịch vụ (systemd) và các cổng lắng nghe (ss)."
    echo "  --users       Chỉ kiểm tra 5 tài khoản demo và phân quyền Maildir."
    echo "  --logs        Trích xuất 25 dòng log mới nhất của mail server."
    echo "  -h, --help    Hiển thị thông tin trợ giúp này."
}

# 1. Kiểm tra Mạng, Hostname & IP
check_network() {
    section_header "1. KIỂM TRA THÔNG TIN HẠ TẦNG & MẠNG"

    echo -n "• Hostname máy chủ: "
    current_hostname=$(hostname)
    current_fqdn=$(hostname -f 2>/dev/null || echo "Chưa nhận")
    if [[ "${current_fqdn}" == "mail.vkuoffice.test" ]]; then
        echo -e "${GREEN}${current_fqdn}${NC} [OK]"
    else
        echo -e "${YELLOW}${current_hostname}${NC} (FQDN: ${RED}${current_fqdn}${NC} - Cần là mail.vkuoffice.test)"
    fi

    echo -e "• Danh sách card mạng & địa chỉ IP IPv4:"
    ip -4 -br addr show | awk '{printf "   - %-10s %-8s %-20s\n", $1, $2, $3}'

    echo -n "• Kiểm tra phân giải nội bộ (/etc/hosts) đến mail.vkuoffice.test: "
    if grep -q "mail.vkuoffice.test" /etc/hosts 2>/dev/null; then
        resolved_ip=$(getent ahosts mail.vkuoffice.test 2>/dev/null | awk '{print $1}' | head -n1 || echo "")
        echo -e "${GREEN}Đã cấu hình -> IP: ${resolved_ip}${NC} [OK]"
    else
        echo -e "${RED}Chưa tìm thấy mail.vkuoffice.test trong /etc/hosts!${NC}"
    fi
}

# 2. Kiểm tra Tường lửa UFW
check_firewall() {
    section_header "2. KIỂM TRA TƯỜNG LỬA (UFW)"

    if ! command -v ufw &>/dev/null; then
        echo -e "${RED}[X] UFW chưa được cài đặt trên hệ thống.${NC}"
        return
    fi

    ufw_status=$(ufw status 2>/dev/null | head -n 1 || echo "Status: unknown")
    if [[ "${ufw_status}" =~ "active" ]]; then
        echo -e "• Trạng thái UFW: ${GREEN}${ufw_status}${NC}"
        echo "• Các cổng mở tiêu chuẩn:"
        expected_ports=("22" "25" "80" "143" "443" "465" "587" "993")
        for port in "${expected_ports[@]}"; do
            if ufw status | grep -E "^${port}(/tcp)?[[:space:]]+ALLOW" &>/dev/null; then
                echo -e "   - Cổng ${port}/tcp: ${GREEN}ĐÃ MỞ (ALLOW)${NC}"
            else
                echo -e "   - Cổng ${port}/tcp: ${YELLOW}CHƯA MỞ HOẶC BỊ CHẶN${NC}"
            fi
        done
    else
        echo -e "• Trạng thái UFW: ${RED}${ufw_status}${NC} (Khuyến nghị chạy: sudo ./firewall/ufw-rules.sh --apply)"
    fi
}

# 3. Kiểm tra Dịch vụ Hệ thống
check_services() {
    section_header "3. KIỂM TRA TRẠNG THÁI DỊCH VỤ (SYSTEMD)"

    services=("ufw" "postfix" "dovecot" "apache2")
    printf " %-15s | %-15s | %-30s\n" "DỊCH VỤ" "TRẠNG THÁI" "VAI TRÒ"
    echo "------------------------------------------------------------------"

    for svc in "${services[@]}"; do
        role="N/A"
        case "$svc" in
            ufw) role="Tường lửa hệ thống" ;;
            postfix) role="Dịch vụ gửi thư SMTP" ;;
            dovecot) role="Dịch vụ nhận thư IMAP" ;;
            apache2) role="Web server Webmail Roundcube" ;;
        esac

        if systemctl is-active --quiet "${svc}" 2>/dev/null; then
            status_text="${GREEN}ĐANG CHẠY (active)${NC}"
        elif systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
            status_text="${YELLOW}TẮT (inactive)${NC}"
        else
            status_text="${RED}CHƯA CÀI / KHÔNG CÓ${NC}"
        fi

        printf " %-15s | %-24b | %-30s\n" "${svc}" "${status_text}" "${role}"
    done
}

# 4. Kiểm tra Cổng Mạng Lắng Nghe (Listening Sockets)
check_ports() {
    section_header "4. KIỂM TRA CỔNG MẠNG ĐANG LẮNG NGHE (LISTENING PORTS)"

    ports_to_check=("22:SSH" "25:Postfix(SMTP)" "80:Webmail(HTTP)" "143:Dovecot(IMAP)" "443:Webmail(HTTPS)" "587:Postfix(Submission)" "993:Dovecot(IMAPS)")
    printf " %-10s | %-22s | %-15s | %-20s\n" "CỔNG" "DỊCH VỤ DỰ KIẾN" "TRẠNG THÁI" "TIẾN TRÌNH THỰC TẾ"
    echo "-----------------------------------------------------------------------------------"

    for item in "${ports_to_check[@]}"; do
        port="${item%%:*}"
        desc="${item##*:}"
        
        # Kiểm tra socket với ss
        proc_info=$(ss -tulnp 2>/dev/null | grep -E ":${port}\b" | head -n1 || echo "")

        if [[ -n "${proc_info}" ]]; then
            status="${GREEN}LẮNG NGHE${NC}"
            proc_name=$(echo "${proc_info}" | grep -oP 'users:\(\("\K[^"]+' 2>/dev/null || echo "active")
        else
            status="${YELLOW}ĐÓNG / CHƯA CHẠY${NC}"
            proc_name="-"
        fi

        printf " %-10s | %-22s | %-24b | %-20s\n" "${port}/tcp" "${desc}" "${status}" "${proc_name}"
    done
}

# 5. Kiểm tra Danh Sách User & Phân Quyền Maildir
check_users() {
    section_header "5. KIỂM TRA 5 TÀI KHOẢN DEMO & HỘP THƯ MAILDIR"

    users=("admin" "giamdoc" "nhansu" "ketoan" "nhanvien")
    printf " %-12s | %-10s | %-12s | %-12s | %-15s\n" "TÀI KHOẢN" "TỒN TẠI" "MAILDIR" "PHÂN QUYỀN" "SỞ HỮU"
    echo "----------------------------------------------------------------------------"

    for user in "${users[@]}"; do
        user_ok=false
        maildir_ok=false
        perms="N/A"
        owner="N/A"

        if id "${user}" &>/dev/null; then
            user_ok=true
            maildir_path="/home/${user}/Maildir"
            if [[ -d "${maildir_path}" ]]; then
                maildir_ok=true
                perms=$(stat -c "%a" "${maildir_path}" 2>/dev/null || echo "N/A")
                owner=$(stat -c "%U:%G" "${maildir_path}" 2>/dev/null || echo "N/A")
            fi
        fi

        # Định dạng màu
        u_str=$([ "$user_ok" = true ] && echo -e "${GREEN}CÓ${NC}" || echo -e "${RED}KHÔNG${NC}")
        m_str=$([ "$maildir_ok" = true ] && echo -e "${GREEN}CÓ${NC}" || echo -e "${RED}KHÔNG${NC}")
        p_str=$([ "$perms" = "700" ] && echo -e "${GREEN}${perms}${NC}" || echo -e "${RED}${perms}${NC}")
        o_str=$([ "$owner" = "${user}:${user}" ] && echo -e "${GREEN}${owner}${NC}" || echo -e "${RED}${owner}${NC}")

        printf " %-12s | %-19b | %-21b | %-21b | %-24b\n" "${user}" "${u_str}" "${m_str}" "${p_str}" "${o_str}"
    done
    echo "----------------------------------------------------------------------------"
    echo -e "${YELLOW}Ghi chú: Quyền Maildir bắt buộc phải là 700 để bảo vệ quyền riêng tư hộp thư.${NC}"
}

# 6. Trích xuất Log Mail Server
check_logs() {
    section_header "6. TRÍCH XUẤT 25 DÒNG LOG MAIL MỚI NHẤT"

    if [[ -f "/var/log/mail.log" ]]; then
        echo -e "${CYAN}--- Trích xuất từ /var/log/mail.log ---${NC}"
        tail -n 25 /var/log/mail.log
    elif command -v journalctl &>/dev/null; then
        echo -e "${CYAN}--- Trích xuất từ journalctl (postfix & dovecot) ---${NC}"
        journalctl -u postfix -u dovecot -n 25 --no-pager 2>/dev/null || echo "Không có log."
    else
        echo -e "${YELLOW}Không tìm thấy file log mail chuẩn trên hệ thống.${NC}"
    fi
}

# Điều hướng tham số
ACTION="${1:---all}"

check_root "$@"

case "${ACTION}" in
    --all)
        check_network
        check_firewall
        check_services
        check_ports
        check_users
        echo -e "\n${GREEN}[✓] Hoàn thành kiểm tra toàn diện hệ thống!${NC}"
        ;;
    --services)
        check_services
        check_ports
        ;;
    --users)
        check_users
        ;;
    --logs)
        check_logs
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo -e "${RED}[LỖI] Tham số không hợp lệ: ${ACTION}${NC}"
        show_help
        exit 1
        ;;
esac

