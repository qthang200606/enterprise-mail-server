# Kiến Trúc Hệ Thống Mail Server Doanh Nghiệp (VKU Office)

Tài liệu này mô tả chi tiết kiến trúc tổng thể, mô hình mạng, luồng dữ liệu và cơ chế bảo mật của hệ thống **Enterprise Mail Server** triển khai trên Ubuntu Server trong khuôn khổ đồ án môn Linux mã nguồn mở.

---

## 1. Sơ Đồ Kiến Trúc Tổng Thể

```text
+-------------------------------------------------------------------------------+
|                             MÁY CLIENT (WINDOWS)                              |
|   - Trình duyệt Web (Truy cập Webmail): http://mail.vkuoffice.test            |
|   - Mail Client (Outlook / Thunderbird): SMTP (587/465), IMAP (143/993)       |
|   - File hosts: 127.0.0.1 (hoặc IP Host-Only) -> mail.vkuoffice.test          |
+-------------------------------------------------------------------------------+
                                      |
                      [ VirtualBox Port Forwarding / LAN ]
                                      |
+-------------------------------------v-----------------------------------------+
|                         UBUNTU SERVER (mail.vkuoffice.test)                   |
|                                                                               |
|  [ TƯỜNG LỬA UFW ] - Chính sách: Chặn toàn bộ vào (Default Deny Incoming)     |
|   - Mở các cổng: 22(SSH), 80/443(Web), 25/465/587(SMTP), 143/993(IMAP)       |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  |                            TẦNG ỨNG DỤNG                                |  |
|  |                                                                         |  |
|  |  [ Web Server Apache2 / PHP ]                                          |  |
|  |     |                                                                   |  |
|  |     v                                                                   |  |
|  |  [ Roundcube Webmail ]                                                  |  |
|  |     |                             |                                     |  |
|  |     | (SMTP - Gửi thư)            | (IMAP - Đọc thư)                    |  |
|  |     v                             v                                     |  |
|  |  [ Postfix MTA ]             [ Dovecot MDA ]                            |  |
|  |     - Port 25, 587, 465           - Port 143, 993                       |  |
|  |     - Domain: vkuoffice.test      - Xác thực người dùng hệ thống        |  |
|  |     - Chuyển thư vào Maildir      - Đọc thư từ Maildir                  |  |
|  +-----|-----------------------------|-------------------------------------+  |
|        |                             |                                        |
|  +-----v-----------------------------v-------------------------------------+  |
|  |                    TẦNG LƯU TRỮ HỘP THƯ (MAILDIR)                       |  |
|  |                                                                         |  |
|  |   /home/<user>/Maildir/                                                 |  |
|  |     ├── cur/  (Thư đã đọc)                                              |  |
|  |     ├── new/  (Thư mới nhận chưa đọc)                                   |  |
|  |     └── tmp/  (Thư tạm trong quá trình ghi dữ liệu)                     |  |
|  |                                                                         |  |
|  |   Bảo mật: Phân quyền chmod 700 (drwx------), chown <user>:<user>        |  |
|  +-------------------------------------------------------------------------+  |
+-------------------------------------------------------------------------------+
```

---

## 2. Các Thành Phần Kỹ Thuật Cốt Lõi

### 2.1. Nền Tảng Hạ Tầng & Mạng (Thành viên 1)
* **Hệ điều hành:** Ubuntu Server 20.04 / 22.04 LTS (x86_64).
* **Hostname FQDN:** `mail.vkuoffice.test`.
* **Domain nội bộ:** `vkuoffice.test`.
* **Cấu hình mạng VirtualBox:**
  * **Chế độ 1 (Port Forwarding):** Dùng card NAT với chuyển tiếp cổng Host `2222` $\rightarrow$ Guest `22` (SSH), Host `8080/80` $\rightarrow$ Guest `80` (Webmail).
  * **Chế độ 2 (Host-Only Adapter):** Gán IP tĩnh `192.168.56.10/24` cho card mạng nội bộ qua Netplan.
* **Tường lửa (UFW):**
  * `ufw default deny incoming`
  * `ufw default allow outgoing`
  * Mở các cổng có chú thích: `22/tcp`, `80/tcp`, `443/tcp`, `25/tcp`, `587/tcp`, `465/tcp`, `143/tcp`, `993/tcp`.

### 2.2. Dịch Vụ Gửi Thư SMTP (Thành viên 2 - Postfix)
* **Vai trò:** Mail Transfer Agent (MTA) & Mail Submission Agent (MSA).
* **Cổng phục vụ:** `25` (Server-to-Server SMTP), `587` (Submission xác thực cho Webmail/Client), `465` (SMTPS).
* **Phương thức phân phối:** Giao thư trực tiếp vào định dạng `Maildir/` tại thư mục home của từng tài khoản người dùng (`home_mailbox = Maildir/`).

### 2.3. Dịch Vụ Nhận & Xác Thực Thư IMAP (Thành viên 3 - Dovecot)
* **Vai trò:** Mail Delivery Agent (MDA) & IMAP Server.
* **Cổng phục vụ:** `143` (IMAP STARTTLS), `993` (IMAPS qua SSL/TLS).
* **Cơ chế xác thực (Auth):** Xác thực thông qua tài khoản hệ thống Linux (`PAM` / `/etc/shadow`), tích hợp SASL cho Postfix.
* **Vị trí Mailbox:** `mail_location = maildir:~/Maildir`.

### 2.4. Giao Diện Webmail & Ứng Dụng (Thành viên 4 - Roundcube)
* **Web Server:** Apache2 với module `mod_php`.
* **Cơ sở dữ liệu:** MariaDB / MySQL lưu trữ danh bạ, cài đặt cá nhân và cache phiên làm việc.
* **Kết nối Backend:**
  * Gửi thư: Kết nối SMTP nội bộ tới Postfix qua `127.0.0.1:587` hoặc `127.0.0.1:25`.
  * Nhận thư: Kết nối IMAP nội bộ tới Dovecot qua `127.0.0.1:143`.

---

## 3. Kiến Trúc Lưu Trữ & Mô Hình Bảo Mật Mailbox

### 3.1. So sánh Maildir vs Mbox
Hệ thống lựa chọn định dạng **Maildir** thay vì **Mbox** truyền thống:
* **Mbox:** Lưu toàn bộ email của 1 user vào 1 file duy nhất (`/var/mail/<user>`). Nhược điểm: Dễ bị khóa file (file locking), tốc độ chậm khi hộp thư lớn, nguy cơ hỏng toàn bộ dữ liệu nếu file lỗi.
* **Maildir:** Mỗi email là một file riêng biệt nằm trong các thư mục `cur/`, `new/`, `tmp/`. Ưu điểm: Hiệu năng cao, an toàn tuyệt đối khi ghi đĩa đồng thời, Dovecot và Postfix đọc/ghi độc lập không xung đột.

### 3.2. Cơ Chế Phân Quyền Hộp Thư Nghiêm Ngặt
Mỗi tài khoản sở hữu thư mục Maildir riêng với phân quyền:
```bash
drwx------ (700) /home/<user>/Maildir
```
* **Chủ sở hữu:** `<user>:<user>`
* **Ý nghĩa bảo mật:**
  * Chỉ duy nhất user đó (hoặc root) mới có quyền truy cập, đọc, ghi hoặc xóa email.
  * Ngăn chặn triệt để nguy cơ người dùng `nhanvien` đọc trộm email của `giamdoc` hoặc `ketoan` ngay cả khi có quyền đăng nhập shell vào server.

---

## 4. Danh Sách Tài Khoản Người Dùng Hệ Thống

| Tài khoản | Địa chỉ Email | Vai trò phòng ban | Quyền hạn đặc biệt |
| :--- | :--- | :--- | :---: |
| `admin` | `admin@vkuoffice.test` | Quản trị viên hệ thống | Thành viên nhóm `sudo` |
| `giamdoc` | `giamdoc@vkuoffice.test` | Ban Giám đốc | Người dùng tiêu chuẩn |
| `nhansu` | `nhansu@vkuoffice.test` | Phòng Nhân sự | Người dùng tiêu chuẩn |
| `ketoan` | `ketoan@vkuoffice.test` | Phòng Kế toán | Người dùng tiêu chuẩn |
| `nhanvien` | `nhanvien@vkuoffice.test` | Nhân viên thông thường | Người dùng tiêu chuẩn |
