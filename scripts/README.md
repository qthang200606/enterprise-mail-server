# Quản Lý Scripts Hệ Thống (Scripts Directory)

Thư mục này chứa các script Bash tự động hóa phục vụ cài đặt, cấu hình, kiểm tra và quản trị Mail Server trên Ubuntu Server.

---

## 1. Danh Sách Script

| Tên File | Người Phụ Trách | Mục Đích |
| :--- | :---: | :--- |
| [setup-users.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/setup-users.sh) | **TV1** | Tự động tạo 5 tài khoản demo, cấu trúc `Maildir` và phân quyền bảo mật `700`. |
| [check-system.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/check-system.sh) | **TV1** | Script 1-click kiểm tra toàn diện sức khỏe hệ thống (Mạng, UFW, Dịch vụ, Cổng, Maildir, Log). |
| [install-postfix.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/install-postfix.sh) | **TV2** | Cài đặt và cấu hình Postfix (SMTP). |
| [install-dovecot.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/install-dovecot.sh) | **TV3** | Cài đặt và cấu hình Dovecot (IMAP). |
| [install-roundcube.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/install-roundcube.sh) | **TV4** | Cài đặt Roundcube Webmail và Web Server. |

---

## 2. Hướng Dẫn Sử Dụng `check-system.sh` (Health Check 1-Click)

Script [check-system.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/check-system.sh) là công cụ chuyên biệt để TV1 bàn giao hệ sinh thái hoặc trình chiếu trực tiếp cho giảng viên.

### A. Chạy kiểm tra toàn diện (`--all`)
Kiểm tra tuần tự cả 5 hạng mục (Mạng $\rightarrow$ UFW $\rightarrow$ Dịch vụ $\rightarrow$ Cổng lắng nghe $\rightarrow$ Maildir):
```bash
sudo ./scripts/check-system.sh --all
```

### B. Chỉ kiểm tra dịch vụ và cổng lắng nghe (`--services`)
```bash
sudo ./scripts/check-system.sh --services
```

### C. Chỉ kiểm tra tài khoản người dùng và Maildir (`--users`)
```bash
sudo ./scripts/check-system.sh --users
```

### D. Trích xuất log mail mới nhất (`--logs`)
```bash
sudo ./scripts/check-system.sh --logs
```

---

## 3. Hướng Dẫn Sử Dụng `setup-users.sh`

Script [setup-users.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/scripts/setup-users.sh) hỗ trợ các cờ hiệu (flags) dòng lệnh linh hoạt:

### A. Khởi tạo người dùng và Maildir (`--setup`)
Mặc định tạo 5 user: `admin`, `giamdoc`, `nhansu`, `ketoan`, `nhanvien` với mật khẩu mặc định an toàn:
```bash
sudo ./scripts/setup-users.sh --setup
```

*Tùy chọn thiết lập mật khẩu riêng qua biến môi trường:*
```bash
DEMO_PASSWORD='MatKhauRieng@2026' sudo -E ./scripts/setup-users.sh --setup
```

### B. Kiểm tra trạng thái và phân quyền (`--check`)
In bảng trạng thái kiểm tra xem tài khoản đã có chưa, thư mục `~/Maildir` đã được tạo chưa, quyền có đúng `700` (`drwx------`) và đúng chủ sở hữu (`user:user`) hay không:
```bash
sudo ./scripts/setup-users.sh --check
```

### C. Xóa sạch người dùng demo để reset (`--reset`)
Dùng khi bạn muốn dọn dẹp sạch sẽ để biểu diễn demo lại từ đầu cho giảng viên:
```bash
sudo ./scripts/setup-users.sh --reset
```

---

## 4. Quy Chuẩn Kỹ Thuật Bắt Buộc Đối Với Maildir
1. **Cấu trúc:** Mỗi user đều phải có đủ 3 thư mục con:
   * `~/Maildir/cur/`: Thư đã đọc.
   * `~/Maildir/new/`: Thư mới nhận chưa đọc.
   * `~/Maildir/tmp/`: Thư tạm trong quá trình truyền tải.
2. **Bảo mật:** Quyền `700` (`rwx------`) ngăn chặn việc một người dùng Linux bất kỳ truy cập hoặc đọc trộm thư mục `Maildir` của người dùng khác.
