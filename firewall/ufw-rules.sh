#!/usr/bin/env bash
# ==============================================================================
# Script: ufw-rules.sh
# Tác giả: Thành viên 1 - Kỹ sư Hạ tầng và Quản trị Hệ thống (SysAdmin)
# Mục đích: Thiết lập chính sách tường lửa UFW chuẩn mực cho Enterprise Mail Server.
#           Chỉ mở các cổng tối thiểu cần thiết cho SSH, Webmail, SMTP và IMAP.
# ==============================================================================

set -euo pipefail

# Màu sắc thông báo
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm kiểm tra quyền root
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[LỖI] Script yêu cầu quyền root. Vui lòng chạy lại với sudo: sudo $0 $*${NC}" >&2
        exit 1
    fi
}

# In hướng dẫn sử dụng (Help)
show_help() {
    echo -e "${BLUE}=== QUẢN LÝ TƯỜNG LỬA UFW - ENTERPRISE MAIL SERVER ===${NC}"
    echo "Cách dùng: sudo $0 [TÙY CHỌN]"
    echo ""
    echo "Tùy chọn (Flags):"
    echo "  --apply       (Mặc định) Áp dụng toàn bộ quy tắc UFW, mở các cổng cần thiết và kích hoạt."
    echo "  --status      Hiển thị trạng thái chi tiết và danh sách cổng đã mở trong UFW."
    echo "  --reset       Đặt lại (reset) toàn bộ cấu hình UFW về mặc định ban đầu và tắt UFW."
    echo "  -h, --help    Hiển thị thông tin trợ giúp này."
    echo ""
    echo "Danh sách các cổng sẽ được cấu hình khi dùng --apply:"
    echo "  - 22/tcp       : SSH (Quản trị từ xa - Mở đầu tiên để chống mất kết nối)"
    echo "  - 80, 443/tcp  : Web Server / Roundcube Webmail (HTTP / HTTPS)"
    echo "  - 25/tcp       : Postfix SMTP (Chuyển tiếp thư giữa các máy chủ mail)"
    echo "  - 587/tcp      : Postfix Submission (Gửi thư từ Mail Client)"
    echo "  - 465/tcp      : Postfix SMTPS (SMTP qua SSL/TLS)"
    echo "  - 143/tcp      : Dovecot IMAP (Đọc và đồng bộ hộp thư)"
    echo "  - 993/tcp      : Dovecot IMAPS (IMAP qua SSL/TLS)"
}

# 1. Hàm áp dụng quy tắc tường lửa
apply_rules() {
    echo -e "${BLUE}[+] Bắt đầu cấu hình chính sách tường lửa UFW...${NC}"

    # Cài đặt UFW nếu chưa có
    if ! command -v ufw &>/dev/null; then
        echo -e "  - Đang cài đặt ufw..."
        apt-get update -qq && apt-get install -y -qq ufw
    fi

    # Thiết lập chính sách mặc định: Chặn toàn bộ kết nối đến, cho phép kết nối ra
    echo -e "  - Thiết lập chính sách mặc định (Default Incoming Deny, Outgoing Allow)..."
    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null

    # BƯỚC QUAN TRỌNG NHẤT: Mở cổng SSH trước tiên để không bị văng khỏi phiên làm việc
    echo -e "  - Mở cổng ${GREEN}22/tcp${NC} (SSH - Quản trị từ xa)..."
    ufw allow 22/tcp comment 'SSH Remote Access' >/dev/null

    # Mở các cổng Webmail (Roundcube)
    echo -e "  - Mở cổng ${GREEN}80/tcp, 443/tcp${NC} (Webmail - Roundcube / Apache / Nginx)..."
    ufw allow 80/tcp comment 'HTTP Webmail' >/dev/null
    ufw allow 443/tcp comment 'HTTPS Webmail' >/dev/null

    # Mở các cổng SMTP (Postfix)
    echo -e "  - Mở cổng ${GREEN}25/tcp, 587/tcp, 465/tcp${NC} (Postfix SMTP & Submission)..."
    ufw allow 25/tcp comment 'Postfix SMTP' >/dev/null
    ufw allow 587/tcp comment 'Postfix Submission' >/dev/null
    ufw allow 465/tcp comment 'Postfix SMTPS' >/dev/null

    # Mở các cổng IMAP (Dovecot)
    echo -e "  - Mở cổng ${GREEN}143/tcp, 993/tcp${NC} (Dovecot IMAP & IMAPS)..."
    ufw allow 143/tcp comment 'Dovecot IMAP' >/dev/null
    ufw allow 993/tcp comment 'Dovecot IMAPS' >/dev/null

    # Kích hoạt UFW không cần tương tác (dùng cờ --force)
    echo -e "  - Kích hoạt UFW..."
    ufw --force enable >/dev/null

    echo -e "\n${GREEN}[✓] Thiết lập tường lửa UFW thành công!${NC}"
    echo -e "${BLUE}=== TRẠNG THÁI TƯỜNG LỬA HIỆN TẠI ===${NC}"
    ufw status verbose
}

# 2. Hàm kiểm tra trạng thái
show_status() {
    echo -e "${BLUE}=== KIỂM TRA TRẠNG THÁI UFW ===${NC}"
    if ! command -v ufw &>/dev/null; then
        echo -e "${RED}[!] UFW chưa được cài đặt trên hệ thống.${NC}"
        exit 1
    fi
    ufw status verbose
    echo ""
    echo -e "${BLUE}Danh sách quy tắc theo số thứ tự:${NC}"
    ufw status numbered
}

# 3. Hàm đặt lại cấu hình (Reset)
reset_rules() {
    echo -e "${RED}[!] CẢNH BÁO: Thao tác này sẽ xóa toàn bộ quy tắc UFW và tắt tường lửa!${NC}"
    read -rp "Bạn có chắc chắn muốn reset UFW về mặc định? (y/N): " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        ufw --force reset >/dev/null
        ufw disable >/dev/null
        echo -e "${GREEN}[✓] Đã reset và tắt UFW thành công.${NC}"
    else
        echo -e "${BLUE}Đã hủy thao tác reset.${NC}"
    fi
}

# Điều hướng tham số (Flags handling)
ACTION="${1:---apply}"

case "${ACTION}" in
    --apply)
        check_root "$@"
        apply_rules
        ;;
    --status)
        check_root "$@"
        show_status
        ;;
    --reset)
        check_root "$@"
        reset_rules
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
