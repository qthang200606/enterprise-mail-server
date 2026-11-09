#!/usr/bin/env bash
# ==============================================================================
# Script: install-dovecot.sh
# Tác giả: Thành viên 3 (TV3) - IMAP / Authentication / Mailbox
# Mục đích: Tự động hóa cài đặt, triển khai cấu hình Dovecot, kiểm tra cú pháp,
#           kiểm tra TLS hiệu lực (OpenSSL -checkhost, RSA & EC) và rollback an toàn.
# ==============================================================================

set -euo pipefail

# Màu sắc hiển thị
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Đường dẫn thư mục hệ thống
DOVECOT_CONF_DIR="/etc/dovecot"
DOVECOT_CONF_D="/etc/dovecot/conf.d"
BACKUP_DIR=""
EXPECTED_HOSTNAME="mail.vkuoffice.test"

# Xác định thư mục chứa script để lấy các file cấu hình tương ứng trong repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DOVECOT_DIR="$(cd "${SCRIPT_DIR}/../dovecot" && pwd)"

# Biến theo dõi trạng thái hệ thống trước khi thay đổi
INITIALLY_EXISTED=0
HAS_BACKUP=0
INITIAL_SERVICE_ACTIVE=0
INITIAL_SERVICE_ENABLED=0
PACKAGE_ATTEMPTED=0
MODIFIED_CONFIG=0

# Hàm kiểm tra quyền root
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}[LỖI] Script yêu cầu quyền root. Vui lòng thực thi bằng: sudo $0${NC}" >&2
        exit 1
    fi
}

# Hàm kiểm tra quyền truy cập tệp private key (xét traversal thư mục cha, quyền đọc và openssl parse)
check_private_key_access() {
    local key_file="$1"

    if [[ ! -e "${key_file}" ]]; then
        echo -e "  - ${RED}[LỖI KHÓA] Tệp khóa riêng tư không tồn tại: ${key_file}${NC}"
        return 1
    fi

    # Phân giải symlink nếu có
    local resolved_path
    resolved_path="$(readlink -f "${key_file}" 2>/dev/null || realpath "${key_file}" 2>/dev/null || echo "${key_file}")"

    if [[ ! -f "${resolved_path}" ]]; then
        echo -e "  - ${RED}[LỖI KHÓA] Đường dẫn khóa không phải tệp thông thường (regular file): ${resolved_path}${NC}"
        return 1
    fi

    # 1. Kiểm tra traversal các thư mục cha từ root đến thư mục chứa key
    local parent_dir
    parent_dir="$(dirname "${resolved_path}")"

    while [[ "${parent_dir}" != "/" && -n "${parent_dir}" ]]; do
        if ! stat -L -c "%A" "${parent_dir}" 2>/dev/null | grep -q "x"; then
            echo -e "  - ${RED}[LỖI QUYỀN THƯ MỤC] Thư mục cha ${parent_dir} không có quyền thực thi/traversal.${NC}"
            return 1
        fi
        parent_dir="$(dirname "${parent_dir}")"
    done

    # 2. Kiểm tra quyền đọc của chính tệp key (Dovecot master chạy bằng root uid=0)
    # Lưu ý: Không tự ý áp đặt chính sách owner/group tùy tiện vì private key có thể được chia sẻ
    # hoặc quản lý bởi các gói dịch vụ khác (như Postfix, Certbot, ssl-cert). Script không tự ý chmod/chown.
    local k_mode
    k_mode="$(stat -c "%a" "${resolved_path}" 2>/dev/null || echo "000")"

    if [[ "${k_mode}" == "000" ]] || ! stat -L -c "%A" "${resolved_path}" 2>/dev/null | grep -q "r"; then
        echo -e "  - ${RED}[LỖI QUYỀN KHÓA] Tệp khóa ${resolved_path} không có bất kỳ quyền đọc nào (mode ${k_mode}).${NC}"
        return 1
    fi

    # Cảnh báo an ninh nếu private key mở quyền đọc cho world (other >= 4)
    local k_other="${k_mode: -1}"
    if [[ "${k_other}" -ge 4 ]]; then
        echo -e "  - ${YELLOW}[CẢNH BÁO BẢO MẬT] Tệp khóa ${resolved_path} đang mở quyền đọc cho world (mode ${k_mode})!${NC}"
        echo -e "    Lưu ý: Không tự ý thay đổi quyền/chủ sở hữu tệp này để tránh ảnh hưởng dịch vụ khác."
    fi

    # 3. Kiểm tra khả năng nạp và giải mã cú pháp của Private Key bằng OpenSSL
    if ! openssl pkey -in "${resolved_path}" -noout 2>/dev/null; then
        echo -e "  - ${RED}[LỖI KHÓA] Không thể phân tích hoặc giải mã khóa riêng tư bằng OpenSSL.${NC}"
        return 1
    fi

    return 0
}

# Hàm thực hiện khôi phục cấu hình (Rollback) an toàn tuyệt đối
rollback() {
    local exit_reason="$1"
    echo -e "\n${RED}[!] KÍCH HOẠT QUÁ TRÌNH ROLLBACK: ${exit_reason}${NC}"

    local rollback_files_ok=0
    local package_warning=""

    # 1. Xử lý trạng thái package nếu lệnh apt đã bắt đầu thực thi
    if [[ "${PACKAGE_ATTEMPTED}" -eq 1 ]]; then
        package_warning="Quá trình cài đặt gói apt có thể dở dang. Vui lòng kiểm tra lại 'dpkg --audit' hoặc 'apt-get -f install'."
    fi

    # 2. Xử lý khôi phục tệp cấu hình
    if [[ "${MODIFIED_CONFIG}" -eq 1 || -d "${DOVECOT_CONF_DIR}" ]]; then
        if [[ "${INITIALLY_EXISTED}" -eq 1 && "${HAS_BACKUP}" -eq 1 && -d "${BACKUP_DIR}" ]]; then
            echo -e "${YELLOW}[*] Đang khôi phục lại cấu hình gốc từ bản sao lưu: ${BACKUP_DIR}...${NC}"

            # Bước 2.1: Sao chép từ backup vào thư mục staging tạm
            local restore_staging
            restore_staging="$(mktemp -d -p "/etc" dovecot_staging.XXXXXX)"

            if cp -a "${BACKUP_DIR}/." "${restore_staging}/"; then
                # Bước 2.2: Tạo thư mục chứa an toàn bằng mktemp -d (giữ chỗ thư mục thực sự, tránh race condition)
                local failed_holder
                failed_holder="$(mktemp -d -p "/etc" dovecot_failed_holder.XXXXXX)"
                local target_failed_dir="${failed_holder}/dovecot"

                # Xác nhận failed_holder tồn tại và là directory
                if [[ ! -d "${failed_holder}" ]]; then
                    echo -e "${RED}[LỖI KHẨN CẤP] Không thể tạo thư mục tạm failed_holder tại /etc! Dừng khôi phục.${NC}"
                    rm -rf "${restore_staging}"
                    rollback_files_ok=0
                else
                    # Di chuyển /etc/dovecot sang target_failed_dir nếu tồn tại
                    local mv_current_ok=1
                    if [[ -d "${DOVECOT_CONF_DIR}" ]]; then
                        if ! mv "${DOVECOT_CONF_DIR}" "${target_failed_dir}"; then
                            echo -e "${RED}[LỖI] Không thể di chuyển ${DOVECOT_CONF_DIR} sang ${target_failed_dir}! Dừng khôi phục để tránh ghi đè lồng nhau.${NC}"
                            mv_current_ok=0
                        elif [[ ! -d "${target_failed_dir}" || -e "${DOVECOT_CONF_DIR}" ]]; then
                            echo -e "${RED}[LỖI TRẠNG THÁI] Di chuyển ${DOVECOT_CONF_DIR} không đạt trạng thái mong muốn!${NC}"
                            mv_current_ok=0
                        fi
                    fi

                    # Bước 2.3: Chỉ di chuyển restore_staging vào /etc/dovecot khi di chuyển cấu hình cũ thành công
                    if [[ "${mv_current_ok}" -eq 1 ]]; then
                        if mv "${restore_staging}" "${DOVECOT_CONF_DIR}"; then
                            # Bước 2.4: Xác minh nội dung khôi phục toàn diện bằng so sánh diff -r với bản backup
                            local verification_ok=1
                            if [[ ! -d "${DOVECOT_CONF_DIR}" || ! -f "${DOVECOT_CONF_DIR}/dovecot.conf" ]]; then
                                echo -e "${RED}[LỖI] Thư mục ${DOVECOT_CONF_DIR} sau khi khôi phục thiếu tệp dovecot.conf!${NC}"
                                verification_ok=0
                            elif ! diff -r -q "${DOVECOT_CONF_DIR}" "${BACKUP_DIR}" >/dev/null 2>&1; then
                                echo -e "${RED}[LỖI XÁC MINH] Nội dung ${DOVECOT_CONF_DIR} sau khôi phục không khớp 100% với bản backup ${BACKUP_DIR}!${NC}"
                                verification_ok=0
                            fi

                            if [[ "${verification_ok}" -eq 1 ]]; then
                                echo -e "${GREEN}[✓] Đã khôi phục và xác minh an toàn cấu hình cũ từ backup thành công (khớp 100% bản backup).${NC}"
                                rm -rf "${failed_holder}"
                                rollback_files_ok=1
                            else
                                echo -e "${RED}[LỖI NGUY HIỂM] Xác minh khôi phục thất bại! Đang hoàn tác lại thư mục cấu hình trước đó...${NC}"
                                local verify_failed_holder
                                verify_failed_holder="$(mktemp -d -p "/etc" dovecot_verify_failed.XXXXXX)"
                                local isolate_mv_ok=0
                                if [[ -d "${DOVECOT_CONF_DIR}" ]]; then
                                    if mv "${DOVECOT_CONF_DIR}" "${verify_failed_holder}/dovecot_corrupted"; then
                                        isolate_mv_ok=1
                                    else
                                        echo -e "${RED}[LỖI NGHIÊM TRỌNG] Không thể di chuyển cấu hình lỗi sang thư mục cách ly!${NC}"
                                        echo -e "${RED}DỪNG THAO TÁC NGAY LẬP TỨC: Không di chuyển failed_dir để tránh bị ghi đè lồng vào /etc/dovecot!${NC}"
                                    fi
                                fi

                                # Chỉ đưa target_failed_dir trở lại khi /etc/dovecot đã được cách ly hoàn toàn và không còn tồn tại
                                if [[ "${isolate_mv_ok}" -eq 1 && ! -e "${DOVECOT_CONF_DIR}" && -d "${target_failed_dir}" ]]; then
                                    if mv "${target_failed_dir}" "${DOVECOT_CONF_DIR}"; then
                                        # Yêu cầu 1: Xác minh toàn diện sau khi phục hồi target_failed_dir
                                        local restored_target_ok=1
                                        if [[ ! -d "${DOVECOT_CONF_DIR}" || ! -f "${DOVECOT_CONF_DIR}/dovecot.conf" ]]; then
                                            echo -e "${RED}[LỖI XÁC MINH PHỤC HỒI] Thư mục ${DOVECOT_CONF_DIR} sau khi hoàn tác thiếu tệp dovecot.conf!${NC}"
                                            restored_target_ok=0
                                        elif [[ -e "${target_failed_dir}" ]]; then
                                            echo -e "${RED}[LỖI TRẠNG THÁI] target_failed_dir vẫn còn tồn tại ở vị trí cũ sau lệnh mv!${NC}"
                                            restored_target_ok=0
                                        fi

                                        if [[ "${restored_target_ok}" -eq 1 ]]; then
                                            echo -e "${YELLOW}[*] Đã trả lại và xác minh thành công thư mục cấu hình trước đó (${DOVECOT_CONF_DIR}).${NC}"
                                            echo -e "    Giữ nguyên failed_holder và bản backup gốc để SysAdmin kiểm tra."
                                        else
                                            echo -e "${RED}[LỖI KHẨN CẤP] Xác minh cấu hình sau khi hoàn tác target_failed_dir không đạt yêu cầu!${NC}"
                                        fi
                                    else
                                        echo -e "${RED}[LỖI KHẨN CẤP] Không thể đưa target_failed_dir trở lại ${DOVECOT_CONF_DIR}! Dữ liệu cũ đang nằm tại: ${target_failed_dir}${NC}"
                                    fi
                                else
                                    echo -e "${RED}[CẢNH BÁO BẢO TOÀN] Giữ nguyên thư mục ${DOVECOT_CONF_DIR} hiện tại và dữ liệu sao lưu cũ tại ${target_failed_dir}.${NC}"
                                fi
                            fi
                        else
                            echo -e "${RED}[LỖI NGUY HIỂM] Không thể di chuyển staging vào ${DOVECOT_CONF_DIR}! Đang hoàn tác lại...${NC}"
                            if [[ -d "${target_failed_dir}" && ! -e "${DOVECOT_CONF_DIR}" ]]; then
                                if mv "${target_failed_dir}" "${DOVECOT_CONF_DIR}"; then
                                    local restore_target_ok=1
                                    if [[ ! -d "${DOVECOT_CONF_DIR}" || ! -f "${DOVECOT_CONF_DIR}/dovecot.conf" ]]; then
                                        echo -e "${RED}[LỖI XÁC MINH HOÀN TÁC] Thư mục ${DOVECOT_CONF_DIR} sau khi hoàn tác thiếu dovecot.conf!${NC}"
                                        restore_target_ok=0
                                    elif [[ -e "${target_failed_dir}" ]]; then
                                        echo -e "${RED}[LỖI TRẠNG THÁI] target_failed_dir vẫn còn tồn tại ở vị trí cũ!${NC}"
                                        restore_target_ok=0
                                    fi

                                    if [[ "${restore_target_ok}" -eq 1 ]]; then
                                        echo -e "${YELLOW}[*] Đã trả lại và xác minh thành công thư mục cấu hình trước đó (${DOVECOT_CONF_DIR}).${NC}"
                                    else
                                        echo -e "${RED}[LỖI KHẨN CẤP] Xác minh cấu hình sau hoàn tác target_failed_dir không đạt yêu cầu!${NC}"
                                    fi
                                else
                                    echo -e "${RED}[LỖI KHẨN CẤP] Không thể hoàn tác target_failed_dir về ${DOVECOT_CONF_DIR}! Dữ liệu cũ tại: ${target_failed_dir}${NC}"
                                fi
                            fi
                            rm -rf "${restore_staging}"
                        fi
                    else
                        # Không di chuyển được thư mục hiện tại: dọn dẹp staging và giữ nguyên bản backup gốc
                        rm -rf "${restore_staging}"
                    fi
                fi
            else
                echo -e "${RED}[LỖI NGHIÊM TRỌNG] Quá trình sao chép từ backup vào staging thất bại! Giữ nguyên thư mục hiện tại và bản backup gốc.${NC}"
                rm -rf "${restore_staging}"
            fi

            # Yêu cầu 2: Chuẩn hóa báo cáo lỗi rollback trong mọi nhánh không thể khôi phục hoàn chỉnh
            if [[ "${rollback_files_ok}" -eq 0 ]]; then
                echo -e "\n${RED}================================================================${NC}"
                echo -e "${RED}             BÁO CÁO CHI TIẾT TRẠNG THÁI ROLLBACK THẤT BẠI       ${NC}"
                echo -e "${RED}================================================================${NC}"
                echo -e "  - DOVECOT_CONF_DIR:     ${DOVECOT_CONF_DIR} (Tồn tại: $([[ -e "${DOVECOT_CONF_DIR}" ]] && echo "CÓ" || echo "KHÔNG"))"
                echo -e "  - BACKUP_DIR:           ${BACKUP_DIR} (Tồn tại: $([[ -e "${BACKUP_DIR}" ]] && echo "CÓ" || echo "KHÔNG"))"
                echo -e "  - failed_holder:        ${failed_holder:-N/A} (Tồn tại: $([[ -n "${failed_holder:-}" && -e "${failed_holder}" ]] && echo "CÓ" || echo "KHÔNG"))"
                echo -e "  - target_failed_dir:    ${target_failed_dir:-N/A} (Tồn tại: $([[ -n "${target_failed_dir:-}" && -e "${target_failed_dir}" ]] && echo "CÓ" || echo "KHÔNG"))"
                echo -e "  - restore_staging:      ${restore_staging:-N/A} (Tồn tại: $([[ -n "${restore_staging:-}" && -e "${restore_staging}" ]] && echo "CÓ" || echo "KHÔNG"))"
                echo -e "  - verify_failed_holder: ${verify_failed_holder:-N/A} (Tồn tại: $([[ -n "${verify_failed_holder:-}" && -e "${verify_failed_holder}" ]] && echo "CÓ" || echo "KHÔNG"))"
                echo -e "${YELLOW}[!] Toàn bộ tệp sao lưu và dữ liệu lỗi đã được BẢO TOÀN NGUYÊN VẸN để SysAdmin kiểm tra.${NC}"
                echo -e "${RED}================================================================${NC}\n"
            fi
        elif [[ "${INITIALLY_EXISTED}" -eq 0 ]]; then
            echo -e "${YELLOW}[*] Ban đầu hệ thống chưa có ${DOVECOT_CONF_DIR}. Đang dọn dẹp thư mục cấu hình mới tạo...${NC}"
            rm -rf "${DOVECOT_CONF_DIR}"
            if [[ ! -d "${DOVECOT_CONF_DIR}" ]]; then
                echo -e "${GREEN}[✓] Đã dọn dẹp sạch sẽ cấu hình mới tạo về đúng trạng thái ban đầu (không tồn tại).${NC}"
                rollback_files_ok=1
            else
                echo -e "${RED}[LỖI] Không thể xóa thư mục ${DOVECOT_CONF_DIR}.${NC}"
            fi
        else
            echo -e "${RED}[LỖI] Không có bản sao lưu hợp lệ (${BACKUP_DIR} không tồn tại). Không thể rollback tự động.${NC}"
        fi
    else
        echo -e "${YELLOW}[*] Cấu hình hệ thống chưa bị can thiệp. Không cần khôi phục tệp cấu hình.${NC}"
        rollback_files_ok=1
    fi

    # 3. Khôi phục trạng thái dịch vụ ban đầu và kiểm tra trạng thái thực tế
    local service_restored=0
    local unit_exists=0
    local load_state
    load_state="$(systemctl show -p LoadState dovecot.service 2>/dev/null | cut -d= -f2 || true)"
    if [[ "${load_state}" == "loaded" ]]; then
        unit_exists=1
    elif [[ -z "${load_state}" ]]; then
        # Khi systemctl show không khả dụng (ví dụ systemd bus lỗi), kiểm tra danh sách unit-files
        # Phải lọc trực tiếp tên unit trong stdout, không chỉ dựa vào mã thoát của lệnh
        if systemctl list-unit-files 2>/dev/null | grep -q -E '^[[:space:]]*dovecot\.service[[:space:]]'; then
            unit_exists=1
        fi
    fi

    if [[ "${unit_exists}" -eq 1 ]]; then
        systemctl daemon-reload &>/dev/null || true

        local enable_action_ok=1
        if [[ "${INITIAL_SERVICE_ENABLED}" -eq 1 ]]; then
            if ! systemctl enable dovecot &>/dev/null; then
                enable_action_ok=0
                echo -e "${RED}[CẢNH BÁO DỊCH VỤ] Lệnh 'systemctl enable dovecot' thất bại.${NC}"
            fi
        else
            if ! systemctl disable dovecot &>/dev/null; then
                enable_action_ok=0
                echo -e "${RED}[CẢNH BÁO DỊCH VỤ] Lệnh 'systemctl disable dovecot' thất bại.${NC}"
            fi
        fi

        if [[ "${INITIAL_SERVICE_ACTIVE}" -eq 1 ]]; then
            echo -e "${YELLOW}[*] Đang thử khởi động lại dịch vụ Dovecot về trạng thái ban đầu...${NC}"
            if systemctl restart dovecot &>/dev/null && systemctl is-active dovecot &>/dev/null; then
                echo -e "${GREEN}[✓] Dịch vụ Dovecot đã chạy lại bình thường với cấu hình cũ.${NC}"
                if [[ "${enable_action_ok}" -eq 1 ]]; then
                    service_restored=1
                fi
            else
                echo -e "${RED}[CẢNH BÁO] Không thể khởi động lại dịch vụ Dovecot sau khi rollback tệp.${NC}"
                echo -e "${YELLOW}Vui lòng kiểm tra log: journalctl -u dovecot -n 20 --no-pager${NC}"
            fi
        else
            echo -e "${YELLOW}[*] Trạng thái ban đầu của dịch vụ là không hoạt động (inactive). Đang dừng dịch vụ...${NC}"
            if systemctl stop dovecot &>/dev/null && ! systemctl is-active dovecot &>/dev/null; then
                echo -e "${GREEN}[✓] Dịch vụ Dovecot đã dừng đúng trạng thái ban đầu.${NC}"
                if [[ "${enable_action_ok}" -eq 1 ]]; then
                    service_restored=1
                fi
            else
                echo -e "${RED}[CẢNH BÁO] Lệnh dừng dịch vụ Dovecot thất bại hoặc dịch vụ vẫn đang active.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}[*] Dịch vụ dovecot.service chưa tồn tại trong hệ thống (chưa cài đặt unit). Không cần khôi phục service.${NC}"
        service_restored=1
    fi

    # 4. Tổng kết đánh giá kết quả rollback
    if [[ -n "${package_warning}" ]]; then
        echo -e "${YELLOW}[CẢNH BÁO PACKAGE] ${package_warning}${NC}"
    fi

    if [[ "${rollback_files_ok}" -eq 1 && "${service_restored}" -eq 1 && -z "${package_warning}" ]]; then
        echo -e "${GREEN}[ROLLBACK HOÀN TẤT] Hệ thống đã được đưa về đúng trạng thái ban đầu an toàn.${NC}"
    else
        echo -e "${RED}[CẢNH BÁO ROLLBACK] Rollback chỉ hoàn thành một phần hoặc cần lưu ý package. Cần sự can thiệp của SysAdmin.${NC}"
    fi

    echo -e "${RED}[THẤT BẠI] Quá trình triển khai Dovecot không thành công.${NC}"
    exit 1
}

# Bẫy tín hiệu (Trap ERR) để đảm bảo không bị set -e làm thoát âm thầm
trap 'rollback "Lệnh gặp lỗi ngoài dự kiến (ERR trap)"' ERR

# Hàm kiểm tra cấu hình TLS hiệu lực và quyết định kích hoạt IMAPS 993
check_and_configure_tls() {
    echo -e "\n${BLUE}[+] Kiểm tra cấu hình và chứng chỉ TLS/SSL hiệu lực...${NC}"

    local effective_ssl="no"
    local cert_file=""
    local key_file=""

    # 1. Trích xuất giá trị TLS hiệu lực bằng `doveconf` (xử lý toàn bộ các include và ghi đè)
    if doveconf -a >/dev/null 2>&1; then
        effective_ssl="$(doveconf -h ssl 2>/dev/null || echo "no")"
        cert_file="$(doveconf -h ssl_cert 2>/dev/null | sed -E 's/^<//' || true)"
        key_file="$(doveconf -h ssl_key 2>/dev/null | sed -E 's/^<//' || true)"
    fi

    # Fallback nếu doveconf chưa đọc được (ví dụ chưa nạp đủ module)
    if [[ -z "${cert_file}" ]]; then
        local ssl_conf="${DOVECOT_CONF_D}/10-ssl.conf"
        if [[ -f "${ssl_conf}" ]]; then
            effective_ssl="$(grep -E '^[[:space:]]*ssl[[:space:]]*=' "${ssl_conf}" | sed -E 's/^[[:space:]]*ssl[[:space:]]*=[[:space:]]*//; s/[[:space:]]*$//' | tail -n 1 || echo "no")"
            cert_file="$(grep -E '^[[:space:]]*ssl_cert[[:space:]]*=' "${ssl_conf}" | sed -E 's/^[[:space:]]*ssl_cert[[:space:]]*=[[:space:]]*<?//; s/[[:space:]]*$//' | tail -n 1 || true)"
            key_file="$(grep -E '^[[:space:]]*ssl_key[[:space:]]*=' "${ssl_conf}" | sed -E 's/^[[:space:]]*ssl_key[[:space:]]*=[[:space:]]*<?//; s/[[:space:]]*$//' | tail -n 1 || true)"
        fi
    fi

    if [[ -z "${cert_file}" ]]; then
        cert_file="/etc/dovecot/private/dovecot.pem"
        key_file="/etc/dovecot/private/dovecot.key"
    fi

    echo -e "  - Chỉ thị ssl hiệu lực: ${YELLOW}${effective_ssl}${NC}"
    echo -e "  - Tệp Certificate hiệu lực: ${YELLOW}${cert_file}${NC}"
    echo -e "  - Tệp Private Key hiệu lực: ${YELLOW}${key_file}${NC}"

    local tls_valid=1
    local unreadable_or_missing_file=0

    # Kiểm tra chỉ thị ssl hiệu lực
    if [[ "${effective_ssl}" == "no" ]]; then
        echo -e "  - ${YELLOW}[TLS TẮT] Dovecot đang cấu hình ssl = no.${NC}"
        tls_valid=0
    fi

    # 2. Kiểm tra sự tồn tại và quyền truy cập thực tế của tệp certificate và private key
    if [[ "${tls_valid}" -eq 1 ]]; then
        if [[ ! -f "${cert_file}" ]] || [[ ! -r "${cert_file}" ]]; then
            echo -e "  - ${YELLOW}[THIẾU/QUYỀN] Không thể đọc tệp chứng chỉ: ${cert_file}${NC}"
            tls_valid=0
            unreadable_or_missing_file=1
        fi

        # Kiểm tra chi tiết quyền truy cập private key (thư mục cha, mode, owner và cú pháp OpenSSL)
        if ! check_private_key_access "${key_file}"; then
            tls_valid=0
            unreadable_or_missing_file=1
        fi
    fi

    # 3. Kiểm tra tính hợp lệ bằng OpenSSL: notBefore, Hạn dùng, Hostname, Khớp Public Key (RSA/EC)
    if [[ "${tls_valid}" -eq 1 ]]; then
        # Kiểm tra định dạng X.509
        if ! openssl x509 -in "${cert_file}" -noout 2>/dev/null; then
            echo -e "  - ${RED}[LỖI ĐỊNH DẠNG] Tệp ${cert_file} không phải chứng chỉ X.509 hợp lệ.${NC}"
            tls_valid=0
        else
            # 3.1. Kiểm tra thời điểm bắt đầu hiệu lực (notBefore) - chính sách fail-closed
            local not_before_str not_before_epoch now_epoch
            not_before_str="$(openssl x509 -in "${cert_file}" -noout -startdate 2>/dev/null | cut -d= -f2 || true)"
            now_epoch="$(date +%s)"

            if [[ -z "${not_before_str}" ]]; then
                echo -e "  - ${RED}[LỖI X.509] Không thể trích xuất ngày bắt đầu hiệu lực (notBefore rỗng).${NC}"
                tls_valid=0
            elif ! not_before_epoch="$(date -d "${not_before_str}" +%s 2>/dev/null)" || [[ -z "${not_before_epoch}" ]]; then
                echo -e "  - ${RED}[LỖI X.509] Không thể phân tích ngày bắt đầu hiệu lực (notBefore: '${not_before_str}').${NC}"
                tls_valid=0
            elif [[ "${now_epoch}" -lt "${not_before_epoch}" ]]; then
                echo -e "  - ${RED}[CHƯA CÓ HIỆU LỰC] Chứng chỉ chưa đến thời điểm hiệu lực (notBefore: ${not_before_str}).${NC}"
                tls_valid=0
            # 3.2. Kiểm tra thời hạn chứng chỉ (không hết hạn)
            elif ! openssl x509 -in "${cert_file}" -checkend 0 -noout 2>/dev/null; then
                echo -e "  - ${RED}[HẾT HẠN] Chứng chỉ ${cert_file} đã hết hạn sử dụng.${NC}"
                tls_valid=0
            else
                # 3.3. Kiểm tra Hostname bằng `openssl x509 -checkhost` chuẩn tắc
                if openssl x509 -in "${cert_file}" -checkhost "${EXPECTED_HOSTNAME}" -noout 2>/dev/null | grep -q "does match certificate"; then
                    echo -e "  - ${GREEN}[KHỚP HOSTNAME] Chứng chỉ khớp chính xác hostname ${EXPECTED_HOSTNAME}.${NC}"
                else
                    echo -e "  - ${RED}[SAI HOSTNAME] Chứng chỉ KHÔNG khớp hostname ${EXPECTED_HOSTNAME}.${NC}"
                    echo -e "    Không thể kích hoạt IMAPS 993 an toàn khi hostname không hợp lệ."
                    tls_valid=0
                fi

                # 3.4. Kiểm tra so khớp Public Key tổng quát (hỗ trợ cả RSA và EC, không dùng pipeline dễ sót lỗi)
                if [[ "${tls_valid}" -eq 1 ]]; then
                    local cert_pub_tmp
                    local key_pub_tmp
                    cert_pub_tmp="$(mktemp)"
                    key_pub_tmp="$(mktemp)"

                    local extract_cert_ok=0
                    local extract_key_ok=0

                    if openssl x509 -in "${cert_file}" -noout -pubkey > "${cert_pub_tmp}" 2>/dev/null; then
                        extract_cert_ok=1
                    fi

                    if openssl pkey -in "${key_file}" -pubout > "${key_pub_tmp}" 2>/dev/null; then
                        extract_key_ok=1
                    fi

                    if [[ "${extract_cert_ok}" -eq 1 && "${extract_key_ok}" -eq 1 ]]; then
                        if cmp -s "${cert_pub_tmp}" "${key_pub_tmp}"; then
                            local exp_date
                            exp_date="$(openssl x509 -in "${cert_file}" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "N/A")"
                            echo -e "  - ${GREEN}[TLS HỢP LỆ] Cặp Certificate và Private Key khớp Public Key hoàn toàn.${NC}"
                            echo -e "  - Hiệu lực từ: ${not_before_str}"
                            echo -e "  - Hạn dùng đến: ${exp_date}"
                        else
                            echo -e "  - ${RED}[KHÔNG KHỚP KHÓA] Public Key của Certificate và Private Key không trùng khớp!${NC}"
                            tls_valid=0
                        fi
                    else
                        echo -e "  - ${RED}[LỖI KHÓA] Không thể trích xuất Public Key từ cặp cert/key.${NC}"
                        tls_valid=0
                    fi

                    rm -f "${cert_pub_tmp}" "${key_pub_tmp}"
                fi

                # 3.5. Kiểm tra nguồn gốc tin cậy (CA Trust / Chain / Self-Signed)
                if [[ "${tls_valid}" -eq 1 ]]; then
                    local s_subj s_issuer
                    s_subj="$(openssl x509 -in "${cert_file}" -noout -subject 2>/dev/null | sed -E 's/^[[:space:]]*subject=[[:space:]]*//' || true)"
                    s_issuer="$(openssl x509 -in "${cert_file}" -noout -issuer 2>/dev/null | sed -E 's/^[[:space:]]*issuer=[[:space:]]*//' || true)"

                    echo -e "  - Subject chứng chỉ: ${s_subj}"
                    echo -e "  - Issuer chứng chỉ:  ${s_issuer}"

                    # Quy tắc xử lý CA Trust:
                    # - Nếu người quản trị chỉ định VKU_CA_CERT (và tùy chọn VKU_INTERMEDIATE_CERT):
                    #   BẮT BUỘC file tồn tại và đọc được; nếu lỗi -> rollback ngay, không fallback âm thầm.
                    # - Dùng openssl verify -CAfile "${VKU_CA_CERT}" [-untrusted "${VKU_INTERMEDIATE_CERT}"] "${cert_file}".
                    # - Chỉ dùng truststore hệ thống khi VKU_CA_CERT không được chỉ định.
                    if [[ -n "${VKU_CA_CERT:-}" ]]; then
                        local ca_bundle="${VKU_CA_CERT}"
                        echo -e "  - Người quản trị chỉ định Root CA: ${ca_bundle}"

                        if [[ ! -f "${ca_bundle}" ]] || [[ ! -r "${ca_bundle}" ]]; then
                            echo -e "  - ${RED}[LỖI CA BUNDLE] Tệp Root CA được chỉ định (${ca_bundle}) không tồn tại hoặc không thể đọc!${NC}"
                            echo -e "    Không fallback âm thầm sang truststore hệ thống để đảm bảo tính chặt chẽ của chính sách CA."
                            tls_valid=0
                        else
                            local verify_args=(-CAfile "${ca_bundle}")
                            local intermediate_err=0

                            if [[ -n "${VKU_INTERMEDIATE_CERT:-}" ]]; then
                                echo -e "  - Người quản trị chỉ định Intermediate CA: ${VKU_INTERMEDIATE_CERT}"
                                if [[ ! -f "${VKU_INTERMEDIATE_CERT}" ]] || [[ ! -r "${VKU_INTERMEDIATE_CERT}" ]]; then
                                    echo -e "  - ${RED}[LỖI INTERMEDIATE CA] Tệp Intermediate CA (${VKU_INTERMEDIATE_CERT}) không tồn tại hoặc không thể đọc!${NC}"
                                    intermediate_err=1
                                    tls_valid=0
                                else
                                    verify_args+=(-untrusted "${VKU_INTERMEDIATE_CERT}")
                                fi
                            fi

                            if [[ "${intermediate_err}" -eq 0 ]]; then
                                if openssl verify "${verify_args[@]}" "${cert_file}" &>/dev/null; then
                                    echo -e "  - ${GREEN}[CA HỢP LỆ] Chứng chỉ được xác thực chuỗi tin cậy thành công bởi CA chỉ định (${ca_bundle}).${NC}"
                                else
                                    echo -e "  - ${RED}[LỖI CA TRUST/CHAIN] Chứng chỉ KHÔNG thể xác minh với CA chỉ định!${NC}"
                                    echo -e "    Chuỗi chứng chỉ có thể bị thiếu trung gian (intermediate), intermediate sai hoặc CA không ký cho chứng chỉ này."
                                    tls_valid=0
                                fi
                            fi
                        fi
                    elif openssl verify -CApath /etc/ssl/certs "${cert_file}" &>/dev/null; then
                        echo -e "  - ${GREEN}[CA HỢP LỆ] Chứng chỉ được xác thực chuỗi tin cậy bởi truststore hệ thống (/etc/ssl/certs).${NC}"
                    else
                        # Khi không chỉ định CA bundle riêng và không có trong truststore hệ thống
                        if [[ "${s_subj}" == "${s_issuer}" && -n "${s_subj}" ]]; then
                            echo -e "  - ${YELLOW}[SELF-SIGNED CERTIFICATE] Đây là chứng chỉ tự ký (Self-signed).${NC}"
                            echo -e "    Lưu ý kiến trúc: Trong mạng nội bộ thử nghiệm (vkuoffice.test), chứng chỉ tự ký có thể"
                            echo -e "    hoạt động cho mã hóa TLS/STARTTLS nhưng các ứng dụng mail client (Roundcube, Thunderbird)"
                            echo -e "    sẽ yêu cầu cấu hình tin cậy hoặc nạp Root CA để tránh cảnh báo bảo mật."
                        else
                            echo -e "  - ${YELLOW}[CA NỘI BỘ/CHƯA CẤU HÌNH CA BUNDLE] Chứng chỉ được cấp bởi: '${s_issuer}'.${NC}"
                            echo -e "    Chưa chỉ định biến VKU_CA_CERT. Đảm bảo Root CA tương ứng được cài đặt trên client để tin cậy."
                        fi
                        echo -e "  - [GIỚI HẠN XÁC MINH] Script đã xác minh định dạng X.509, thời hạn (notBefore & notAfter), hostname và cặp khóa,"
                        echo -e "    nhưng chưa thể khẳng định certificate được client tin cậy hoàn toàn khi chưa có CA policy rõ ràng."
                    fi
                fi
            fi
        fi
    fi

    # 4. Quyết định kích hoạt TLS / IMAPS và đảm bảo an ninh hệ thống
    if [[ "${tls_valid}" -eq 1 ]]; then
        echo -e "  - ${GREEN}[TLS HOÀN TOÀN HỢP LỆ] Đã cấu hình chỉ thị TLS và listener IMAP 143 (STARTTLS) / IMAPS 993 trong file cấu hình.${NC}"
        echo -e "    Lưu ý: Script đã xác minh hợp lệ cấu hình static (cert, key, hostname, chain). Bắt tay mạng IMAPS thật sẽ được kiểm thử sau khi dịch vụ khởi động."
    else
        echo -e "\n${RED}[!] CẢNH BÁO AN NINH TLS:${NC}"
        echo -e "    Chứng chỉ TLS không tồn tại, hết hạn, sai hostname hoặc private key không đọc được."
        echo -e "    Hệ thống đang cấu hình chính sách bắt buộc: 'disable_plaintext_auth = yes'."
        echo -e "    Nếu không có TLS hợp lệ, client IMAP sẽ KHÔNG thể xác thực/đăng nhập và STARTTLS không an toàn."
        echo -e "    Script ưu tiên dừng cài đặt và khôi phục cấu hình (rollback) để tránh đưa dịch vụ không bảo mật vào hoạt động."
        echo -e "    Vui lòng thiết lập chứng chỉ hợp lệ cho ${EXPECTED_HOSTNAME} trước khi triển khai."
        rollback "Kiểm tra cấu hình TLS thất bại (chứng chỉ/khóa không hợp lệ hoặc không an toàn)"
    fi
}

main() {
    check_root

    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}     TRIỂN KHAI DỊCH VỤ DOVECOT IMAP - VKU OFFICE (TV3)         ${NC}"
    echo -e "${BLUE}================================================================${NC}"

    # 1. Kiểm tra sự tồn tại của các file cấu hình nguồn trong repository
    echo -e "\n${BLUE}[1/6] Kiểm tra tệp cấu hình nguồn trong repository...${NC}"
    for file in "dovecot.conf" "10-mail.conf" "10-auth.conf" "10-master.conf"; do
        if [[ ! -f "${REPO_DOVECOT_DIR}/${file}" ]]; then
            echo -e "${RED}[LỖI] Không tìm thấy tệp nguồn ${REPO_DOVECOT_DIR}/${file}${NC}"
            exit 1
        fi
        echo -e "  - Đã tìm thấy: ${GREEN}${file}${NC}"
    done

    # 2. Ghi nhận trạng thái dịch vụ và tệp trước khi can thiệp
    if [[ -d "${DOVECOT_CONF_DIR}" ]]; then
        INITIALLY_EXISTED=1
    fi

    if systemctl is-active dovecot &>/dev/null; then
        INITIAL_SERVICE_ACTIVE=1
    fi

    if systemctl is-enabled dovecot &>/dev/null; then
        INITIAL_SERVICE_ENABLED=1
    fi

    # 3. Sao lưu cấu hình hiện tại trước khi chạy apt update/install
    echo -e "\n${BLUE}[2/6] Sao lưu thư mục cấu hình hiện tại (trước khi cài gói)...${NC}"
    if [[ "${INITIALLY_EXISTED}" -eq 1 ]]; then
        local backup_holder
        backup_holder="$(mktemp -d -p "/etc" dovecot_bak.XXXXXXXX)"
        if [[ -z "${backup_holder}" || ! -d "${backup_holder}" ]]; then
            echo -e "${RED}[LỖI] Không thể tạo thư mục sao lưu duy nhất tại /etc. Dừng triển khai.${NC}"
            exit 1
        fi
        BACKUP_DIR="${backup_holder}"

        if cp -a "${DOVECOT_CONF_DIR}/." "${BACKUP_DIR}/"; then
            HAS_BACKUP=1
            echo -e "  - Đã tạo bản sao lưu an toàn tại: ${GREEN}${BACKUP_DIR}${NC}"
        else
            echo -e "${RED}[LỖI] Không thể sao chép dữ liệu sang thư mục sao lưu ${BACKUP_DIR}. Dừng triển khai.${NC}"
            rm -rf "${BACKUP_DIR}"
            exit 1
        fi
    else
        echo -e "  - Thư mục ${DOVECOT_CONF_DIR} chưa tồn tại trước đó, bỏ qua sao lưu ban đầu."
    fi

    # 4. Cài đặt các gói phần mềm cần thiết (chỉ IMAP và core, không cài POP3)
    echo -e "\n${BLUE}[3/6] Cài đặt gói dovecot-imapd và dovecot-core...${NC}"
    PACKAGE_ATTEMPTED=1
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || rollback "Lỗi apt-get update"
    apt-get install -y -qq dovecot-imapd dovecot-core || rollback "Lỗi apt-get install dovecot"

    # 5. Bắt đầu giai đoạn thay đổi cấu hình hệ thống
    MODIFIED_CONFIG=1
    echo -e "\n${BLUE}[4/6] Sao chép cấu hình vào ${DOVECOT_CONF_DIR}...${NC}"
    mkdir -p "${DOVECOT_CONF_D}" || rollback "Lỗi mkdir -p ${DOVECOT_CONF_D}"

    cp "${REPO_DOVECOT_DIR}/dovecot.conf" "${DOVECOT_CONF_DIR}/dovecot.conf" || rollback "Lỗi sao chép dovecot.conf"
    cp "${REPO_DOVECOT_DIR}/10-mail.conf" "${DOVECOT_CONF_D}/10-mail.conf" || rollback "Lỗi sao chép 10-mail.conf"
    cp "${REPO_DOVECOT_DIR}/10-auth.conf" "${DOVECOT_CONF_D}/10-auth.conf" || rollback "Lỗi sao chép 10-auth.conf"
    cp "${REPO_DOVECOT_DIR}/10-master.conf" "${DOVECOT_CONF_D}/10-master.conf" || rollback "Lỗi sao chép 10-master.conf"

    # Kiểm tra chứng chỉ TLS hiệu lực và quyết định bật/tắt cổng IMAPS 993
    check_and_configure_tls

    # 6. Kiểm tra cú pháp cấu hình bằng lệnh `doveconf -n`
    echo -e "\n${BLUE}[5/6] Kiểm tra cú pháp cấu hình Dovecot (doveconf)...${NC}"
    if doveconf -n >/dev/null 2>&1; then
        echo -e "  - ${GREEN}[THÀNH CÔNG] Cú pháp cấu hình Dovecot hợp lệ!${NC}"
    else
        echo -e "  - ${RED}[LỖI] Cú pháp cấu hình Dovecot không hợp lệ:${NC}"
        doveconf -n || true
        rollback "Lỗi cú pháp cấu hình khi chạy doveconf -n"
    fi

    # 7. Khởi động và kích hoạt dịch vụ Dovecot
    echo -e "\n${BLUE}[6/6] Khởi động và kích hoạt dịch vụ Dovecot...${NC}"
    systemctl daemon-reload || rollback "Lỗi systemctl daemon-reload"
    systemctl enable dovecot || rollback "Lỗi systemctl enable dovecot"

    if systemctl restart dovecot && systemctl is-active dovecot &>/dev/null; then
        echo -e "  - ${GREEN}[THÀNH CÔNG] Dịch vụ Dovecot đã khởi động lại và hoạt động ổn định!${NC}"
    else
        echo -e "  - ${RED}[LỖI] Không thể khởi động dịch vụ Dovecot.${NC}"
        journalctl -u dovecot -n 20 --no-pager || true
        rollback "Không thể restart dịch vụ dovecot sau khi cập nhật cấu hình"
    fi

    echo -e "\n${GREEN}================================================================${NC}"
    echo -e "${GREEN}    HOÀN TẤT TRIỂN KHAI DOVECOT THÀNH CÔNG TRÊN HỆ THỐNG        ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    if [[ "${HAS_BACKUP}" -eq 1 ]]; then
        echo -e "Bản sao lưu an toàn lưu tại: ${YELLOW}${BACKUP_DIR}${NC}"
    fi
    echo -e "Sử dụng lệnh sau để kiểm tra trạng thái dịch vụ:"
    echo -e "  ${BLUE}sudo systemctl status dovecot${NC}"
    echo -e "  ${BLUE}sudo doveconf -n${NC}"
    echo -e "  ${BLUE}sudo ss -tulpn | grep -E '143|993'${NC}"
}

main "$@"
