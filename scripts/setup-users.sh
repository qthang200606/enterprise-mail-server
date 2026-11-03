#!/usr/bin/env bash
# ==============================================================================
# Script: setup-users.sh
# Tác giả: Thành viên 1 - Kỹ sư Hạ tầng và Quản trị Hệ thống (SysAdmin)
# Mục đích: Tự động hóa khởi tạo tài khoản demo, cấu trúc hộp thư Maildir
#           và phân quyền bảo mật nghiêm ngặt (700) cho hệ thống Mail Server.
# ==============================================================================

set -euo pipefail

# Màu sắc thông báo
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Danh sách tài khoản demo theo đồ án (README.md)
USERS=("admin" "giamdoc" "nhansu" "ketoan" "nhanvien")

# Mật khẩu demo mặc định (Có thể ghi đè bằng biến môi trường DEMO_PASSWORD)
DEFAULT_PASS="${DEMO_PASSWORD:-Vku@Mail2026!}"

# Hàm kiểm tra quyền root
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[LỖI] Script yêu cầu quyền root. Vui lòng chạy lại với sudo: sudo $0 $*${NC}" >&2
        exit 1
    fi
}

# In hướng dẫn sử dụng (Help)
show_help() {
    echo -e "${BLUE}=== HỆ THỐNG QUẢN LÝ TÀI KHOẢN MAIL SERVER - VKU OFFICE ===${NC}"
    echo "Cách dùng: sudo $0 [TÙY CHỌN]"
    echo ""
    echo "Tùy chọn (Flags):"
    echo "  --setup       (Mặc định) Tạo 5 tài khoản demo, cấu trúc Maildir và phân quyền 700."
    echo "  --check       Kiểm tra trạng thái người dùng, thư mục Maildir và quyền hạn hiện tại."
    echo "  --reset       Xóa toàn bộ 5 tài khoản demo và dữ liệu hộp thư (dùng để reset demo)."
    echo "  -h, --help    Hiển thị thông tin trợ giúp này."
    echo ""
    echo "Ví dụ thiết lập mật khẩu tùy chỉnh:"
    echo "  DEMO_PASSWORD='MySecretPass123!' sudo $0 --setup"
}

# 1. Hàm tạo tài khoản và hộp thư Maildir
setup_users() {
    echo -e "${BLUE}[+] Bắt đầu thiết lập người dùng và hộp thư Maildir...${NC}"
    echo -e "${YELLOW}[!] Mật khẩu khởi tạo được sử dụng: ${DEFAULT_PASS}${NC}"

    for user in "${USERS[@]}"; do
        # 1. Kiểm tra và tạo tài khoản Linux
        if id "${user}" &>/dev/null; then
            echo -e "  - User ${YELLOW}${user}${NC} đã tồn tại. Bỏ qua bước tạo mới."
        else
            useradd -m -s /bin/bash "${user}"
            echo "${user}:${DEFAULT_PASS}" | chpasswd
            echo -e "  - Đã tạo user ${GREEN}${user}${NC} thành công."
        fi

        # Cấp quyền sudo cho user 'admin'
        if [[ "${user}" == "admin" ]]; then
            usermod -aG sudo "${user}"
            echo -e "    * Đã thêm ${GREEN}admin${NC} vào nhóm ${BLUE}sudo${NC}."
        fi

        # 2. Khởi tạo cấu trúc Maildir theo chuẩn Dovecot/Postfix
        user_home="/home/${user}"
        maildir="${user_home}/Maildir"

        mkdir -p "${maildir}/cur" "${maildir}/new" "${maildir}/tmp"

        # 3. Phân quyền bảo mật nghiêm ngặt
        # Quyền 700: Chỉ chủ sở hữu mới có quyền đọc, ghi và truy cập
        chmod -R 700 "${maildir}"
        chown -R "${user}:${user}" "${maildir}"

        echo -e "    * Maildir: ${GREEN}${maildir}${NC} (Quyền: 700, Chủ sở hữu: ${user}:${user})"
    done

    echo -e "\n${GREEN}[✓] Hoàn thành thiết lập toàn bộ người dùng!${NC}"
    echo -e "Các thành viên (TV2 Postfix, TV3 Dovecot) đã có thể sử dụng cấu trúc Maildir trên."
}

# 2. Hàm kiểm tra trạng thái người dùng và Maildir
check_users() {
    echo -e "${BLUE}=== KIỂM TRA TRẠNG THÁI NGƯỜI DÙNG & HỘP THƯ MAILDIR ===${NC}"
    printf "%-12s | %-10s | %-10s | %-12s | %-10s\n" "TÀI KHOẢN" "TỒN TẠI" "MAILDIR" "PHÂN QUYỀN" "SỞ HỮU"
    echo "------------------------------------------------------------------"

    for user in "${USERS[@]}"; do
        user_exists="KHÔNG"
        maildir_exists="KHÔNG"
        perms="N/A"
        owner="N/A"

        if id "${user}" &>/dev/null; then
            user_exists="CÓ"
            maildir_path="/home/${user}/Maildir"
            if [[ -d "${maildir_path}" ]]; then
                maildir_exists="CÓ"
                perms=$(stat -c "%a" "${maildir_path}" 2>/dev/null || echo "N/A")
                owner=$(stat -c "%U:%G" "${maildir_path}" 2>/dev/null || echo "N/A")
            fi
        fi

        # Định dạng màu sắc
        user_col="${RED}${user_exists}${NC}"
        [[ "${user_exists}" == "CÓ" ]] && user_col="${GREEN}${user_exists}${NC}"

        maildir_col="${RED}${maildir_exists}${NC}"
        [[ "${maildir_exists}" == "CÓ" ]] && maildir_col="${GREEN}${maildir_exists}${NC}"

        perm_col="${RED}${perms}${NC}"
        [[ "${perms}" == "700" ]] && perm_col="${GREEN}${perms}${NC}"

        owner_col="${RED}${owner}${NC}"
        [[ "${owner}" == "${user}:${user}" ]] && owner_col="${GREEN}${owner}${NC}"

        printf "%-12s | %-19b | %-19b | %-21b | %-19b\n" "${user}" "${user_col}" "${maildir_col}" "${perm_col}" "${owner_col}"
    done
    echo "------------------------------------------------------------------"
    echo -e "${YELLOW}Ghi chú: Maildir chuẩn phải có Quyền: 700 và Sở hữu khớp với tên tài khoản.${NC}"
}

# 3. Hàm xóa sạch tài khoản demo (Reset)
reset_users() {
    echo -e "${RED}[!] CẢNH BÁO: Thao tác này sẽ xóa vĩnh viễn 5 tài khoản demo và toàn bộ hộp thư!${NC}"
    read -rp "Bạn có chắc chắn muốn tiếp tục? (y/N): " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        for user in "${USERS[@]}"; do
            if id "${user}" &>/dev/null; then
                userdel -r -f "${user}" 2>/dev/null || true
                echo -e "  - Đã xóa người dùng và thư mục home: ${RED}${user}${NC}"
            else
                echo -e "  - Người dùng ${user} không tồn tại. Bỏ qua."
            fi
        done
        echo -e "${GREEN}[✓] Đã dọn dẹp sạch sẽ 5 tài khoản demo.${NC}"
    else
        echo -e "${BLUE}Đã hủy thao tác reset.${NC}"
    fi
}

# Điều hướng tham số (Flags handling)
ACTION="${1:---setup}"

case "${ACTION}" in
    --setup)
        check_root "$@"
        setup_users
        ;;
    --check)
        check_root "$@"
        check_users
        ;;
    --reset)
        check_root "$@"
        reset_users
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
