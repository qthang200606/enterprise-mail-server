# Cấu Hình Tường Lửa (UFW - Uncomplicated Firewall)

Tài liệu này thuộc trách nhiệm của **Thành viên 1 (Kỹ sư Hạ tầng & Quản trị Hệ thống)**, quy định chính sách bảo mật mạng và kiểm soát lưu lượng truy cập cho máy chủ Enterprise Mail Server VKU Office.

---

## 1. Nguyên Tắc An Toàn Hạ Tầng

* **Quy tắc phòng thủ tối thiểu (Principle of Least Privilege):** Chỉ mở các cổng thực sự cần thiết cho các dịch vụ đang hoạt động; đóng toàn bộ các cổng còn lại (`default deny incoming`).
* **Ưu tiên sống còn (Anti-lockout):** Luôn mở cổng SSH (`22/tcp`) đầu tiên trước khi bật tường lửa để tránh việc quản trị viên bị ngắt kết nối từ xa.
* **Tự động hóa an toàn:** Sử dụng script [ufw-rules.sh](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/firewall/ufw-rules.sh) với cờ `--force` để có thể tích hợp vào quy trình CI/CD hoặc chạy tự động mà không bị treo chờ xác nhận tương tác.

---

## 2. Bảng Danh Mục Các Cổng Cần Mở

| Cổng (Port) | Giao thức | Dịch vụ tương ứng | Vai trò trong hệ thống Mail Server | Người phụ trách dịch vụ |
| :---: | :---: | :--- | :--- | :---: |
| **`22`** | TCP | OpenSSH | Quản trị máy chủ Linux từ xa qua giao diện dòng lệnh. | **TV1** |
| **`80`** | TCP | Apache / Nginx | Truy cập giao diện Roundcube Webmail qua HTTP. | **TV4** |
| **`443`** | TCP | Apache / Nginx | Truy cập giao diện Roundcube Webmail bảo mật qua HTTPS. | **TV4** |
| **`25`** | TCP | Postfix (SMTP) | Tiếp nhận và chuyển tiếp email giữa các máy chủ (MTA to MTA). | **TV2** |
| **`587`** | TCP | Postfix (Submission)| Tiếp nhận email gửi lên từ Client/Webmail (MSA to MTA). | **TV2** |
| **`465`** | TCP | Postfix (SMTPS) | Gửi email bảo mật qua SSL/TLS trực tiếp. | **TV2** |
| **`143`** | TCP | Dovecot (IMAP) | Cho phép Webmail hoặc Mail Client đọc và đồng bộ hộp thư. | **TV3** |
| **`993`** | TCP | Dovecot (IMAPS) | Đọc và đồng bộ hộp thư qua kênh mã hóa SSL/TLS. | **TV3** |

---

## 3. Hướng Dẫn Sử Dụng Script `ufw-rules.sh`

### A. Cấp quyền thực thi
```bash
chmod +x firewall/ufw-rules.sh
```

### B. Áp dụng quy tắc tường lửa (`--apply`)
Mặc định mở toàn bộ các cổng trong bảng danh mục và kích hoạt tường lửa:
```bash
sudo ./firewall/ufw-rules.sh --apply
```

### C. Kiểm tra trạng thái tường lửa (`--status`)
Hiển thị danh sách các quy tắc chi tiết và thứ tự đánh số:
```bash
sudo ./firewall/ufw-rules.sh --status
```

### D. Đặt lại mặc định và tắt UFW (`--reset`)
Dùng khi cần xóa sạch quy tắc để cấu hình lại từ đầu:
```bash
sudo ./firewall/ufw-rules.sh --reset
```

### E. Xem trợ giúp cú pháp (`--help`)
```bash
./firewall/ufw-rules.sh --help
```

---

## 4. Kiểm Thử & Nghiệm Thu (Verification)

Sau khi chạy script, kiểm tra bằng các lệnh sau:

### 1. Kiểm tra trạng thái UFW
```bash
sudo ufw status verbose
```
*Kết quả mong đợi:*
```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # SSH Remote Access
80/tcp                     ALLOW IN    Anywhere                   # HTTP Webmail
443/tcp                    ALLOW IN    Anywhere                   # HTTPS Webmail
25/tcp                     ALLOW IN    Anywhere                   # Postfix SMTP
587/tcp                    ALLOW IN    Anywhere                   # Postfix Submission
465/tcp                    ALLOW IN    Anywhere                   # Postfix SMTPS
143/tcp                    ALLOW IN    Anywhere                   # Dovecot IMAP
993/tcp                    ALLOW IN    Anywhere                   # Dovecot IMAPS
```

### 2. Kiểm tra từ máy Client (Windows)
Từ PowerShell trên máy thật, kiểm tra kết nối tới các cổng bằng `Test-NetConnection`:
```powershell
Test-NetConnection -ComputerName mail.vkuoffice.test -Port 22
Test-NetConnection -ComputerName mail.vkuoffice.test -Port 80
Test-NetConnection -ComputerName mail.vkuoffice.test -Port 25
Test-NetConnection -ComputerName mail.vkuoffice.test -Port 143
```
*Yêu cầu:* `TcpTestSucceeded : True` (đối với các cổng mà dịch vụ tương ứng đã được khởi chạy).
