# Tài Liệu Cấu Hình & Triển Khai Dịch Vụ Dovecot IMAP (TV3)

Tài liệu kỹ thuật chịu trách nhiệm bởi **Thành viên 3 (TV3)**: phụ trách Dịch vụ truy xuất thư IMAP, Cơ chế xác thực người dùng (Authentication), Định dạng hộp thư (Mailbox) và Tích hợp SASL cho Postfix.

---

## 1. Tổng Quan Kiến Trúc & Quyết Định Kỹ Thuật

| Thành phần | Cấu hình lựa chọn | Lý do kỹ thuật |
| :--- | :--- | :--- |
| **Giao thức phục vụ** | **IMAP duy nhất** (Port 143; Port 993 có điều kiện) | Phù hợp truy cập đa thiết bị (Webmail, di động, desktop). Không mở POP3/LMTP thừa để giảm thiểu bề mặt tấn công. |
| **Định dạng Mailbox** | **Maildir** (`maildir:~/Maildir`) | Đồng bộ tuyệt đối với script `scripts/setup-users.sh` của TV1 (`chmod 700`, owner `<user>:<user>`). Mỗi email là một file riêng biệt, triệt tiêu nguy cơ khóa file (file locking) của Mbox. |
| **Cơ chế xác thực** | **Linux System / PAM** (`auth-system.conf.ext`) | Xác thực trực tiếp qua `/etc/shadow` cho 5 tài khoản demo: `admin`, `giamdoc`, `nhansu`, `ketoan`, `nhanvien`. |
| **Chính sách bảo mật** | `disable_plaintext_auth = yes` | Bảo vệ an toàn mạng LAN, cấm truyền thông tin đăng nhập dạng rõ không mã hóa. Bắt buộc TLS/STARTTLS khi xác thực. Không sử dụng `login_trusted_networks`. |
| **Tích hợp Postfix** | UNIX Socket `/var/spool/postfix/private/auth` | Cung cấp backend SASL cho Postfix SMTP gửi thư xác thực an toàn trong môi trường chroot (`mode 0660`, `postfix:postfix`). |

---

## 2. Danh Sách Tệp Cấu Hình Dovecot

Toàn bộ cấu hình Dovecot trong thư mục `dovecot/` được thiết kế theo cấu trúc module hóa chuẩn của Ubuntu (khi triển khai vào `/etc/dovecot/`):

1. **`dovecot/dovecot.conf`**:
   - Cấu hình chính của hệ thống.
   - Chỉ định `protocols = imap` (chỉ bật IMAP).
   - Nạp toàn bộ các file module thông qua `!include conf.d/*.conf`.
2. **`dovecot/10-mail.conf`**:
   - Thiết lập `mail_location = maildir:~/Maildir`.
   - `mail_privileged_group = mail` và `first_valid_uid = 1000` (chuẩn phân quyền người dùng Linux trên Ubuntu Server).
   - Cấu hình namespace `inbox = yes` và kích hoạt tự động (`auto = create`) các thư mục chuẩn: `Drafts`, `Sent`, `Trash`, `Junk`.
   - Thống nhất duy nhất thư mục `Sent` (không khai báo trùng lặp `Sent Messages`) để đồng bộ hoàn toàn với Roundcube Webmail.
3. **`dovecot/10-auth.conf`**:
   - Bật chính sách nghiêm ngặt `disable_plaintext_auth = yes`.
   - Không cấu hình `login_trusted_networks` để miễn trừ xác thực.
   - Cơ chế xác thực: `auth_mechanisms = plain login`.
   - Nạp module PAM hệ thống `!include auth-system.conf.ext`.
4. **`dovecot/10-master.conf`**:
   - Thiết lập listener IMAP port 143 (hỗ trợ STARTTLS khi có cert) và listener IMAPS port 993 (đòi hỏi SSL/TLS hợp lệ).
   - Đóng các listener POP3 (port 0) và Submission (port 0).
   - Khởi tạo socket SASL cho Postfix tại `/var/spool/postfix/private/auth` với `mode = 0660`, sở hữu bởi `postfix:postfix`.
   - Giữ nguyên socket nội bộ `auth-userdb` theo mặc định an toàn của Ubuntu package.

---

## 3. Khuyến Nghị Phối Hợp Giữa Các Thành Viên

### 3.1. Đề xuất cho TV2 (Postfix - SMTP)
Để Postfix phân phối thư trực tiếp vào đúng hộp thư Maildir mà Dovecot đang đọc, TV2 cần đảm bảo trong tệp cấu hình `/etc/postfix/main.cf` có chỉ thị sau:
```text
home_mailbox = Maildir/
```
*Lưu ý:* Nếu thiếu cấu hình này, Postfix sẽ lưu thư vào file Mbox tại `/var/mail/<username>`, khiến Dovecot không thể nhìn thấy email mới trong `~/Maildir/`. TV3 không can thiệp hay thay đổi chứng chỉ của Postfix.

### 3.2. Đề xuất cho TV4 (Roundcube Webmail)
- Trong tệp `roundcube/config.inc.php`, cấu hình kết nối IMAP an toàn:
  - Nếu kết nối qua cổng 143: Đảm bảo sử dụng STARTTLS (`$config['default_host'] = 'tls://mail.vkuoffice.test'; $config['default_port'] = 143;`).
  - Nếu kết nối qua cổng 993: Chỉ sử dụng khi máy chủ đã cấu hình chứng chỉ TLS hợp lệ (`$config['default_host'] = 'ssl://mail.vkuoffice.test'; $config['default_port'] = 993;`).
  - Thư mục thư đã gửi được thống nhất là `Sent`.

---

## 4. Hướng Dẫn Cài Đặt & Triển Khai Trên Ubuntu Server

### Cách 1: Triển khai tự động bằng Script (Khuyến nghị)
Script `scripts/install-dovecot.sh` đã tích hợp đầy đủ quy trình sao lưu (backup) trước khi cài đặt gói, kiểm tra TLS hiệu lực (OpenSSL `-checkhost`, khớp Public Key RSA & EC, hạn dùng) và cơ chế tự động khôi phục (rollback tráo đổi thư mục an toàn) nếu phát hiện lỗi:
```bash
cd enterprise-mail-server
sudo ./scripts/install-dovecot.sh
```

### Cách 2: Triển khai thủ công từng bước
1. Sao lưu cấu hình mặc định nếu đã tồn tại:
   ```bash
   sudo cp -a /etc/dovecot /etc/dovecot.bak.$(date +%Y%m%d)
   ```
2. Cài đặt các gói phần mềm (chỉ cài IMAP, không cài POP3):
   ```bash
   sudo apt update
   sudo apt install -y dovecot-imapd dovecot-core
   ```
3. Sao chép các tệp cấu hình từ repository:
   ```bash
   sudo cp dovecot/dovecot.conf /etc/dovecot/dovecot.conf
   sudo cp dovecot/10-mail.conf /etc/dovecot/conf.d/10-mail.conf
   sudo cp dovecot/10-auth.conf /etc/dovecot/conf.d/10-auth.conf
   sudo cp dovecot/10-master.conf /etc/dovecot/conf.d/10-master.conf
   ```
4. Kiểm tra chứng chỉ SSL/TLS trong `/etc/dovecot/conf.d/10-ssl.conf`:
   - Đảm bảo file cert và key tồn tại, khớp public key và có quyền đọc hợp lệ.
   - Nếu chưa có TLS hợp lệ, cần vô hiệu hóa port 993 (`port = 0`) trong `10-master.conf` để tránh crash dịch vụ.
5. Kiểm tra cú pháp trước khi nạp vào dịch vụ:
   ```bash
   sudo doveconf -n
   ```
6. Khởi động lại dịch vụ Dovecot:
   ```bash
   sudo systemctl restart dovecot
   sudo systemctl enable dovecot
   ```

---

## 5. Phân Biệt Các Bước Kiểm Thử (Sandbox Dev vs Ubuntu Server Thật)

### 5.1. Các kiểm thử đã thực hiện thành công trên môi trường phát triển (Sandbox)
- **Kiểm tra cú pháp Shell Script**: Đã chạy `bash -n scripts/install-dovecot.sh` (Mã thoát 0).
- **Kiểm tra định dạng mã nguồn Git**: Đã chạy `git diff --check` (Mã thoát 0).
- **Kiểm tra cú pháp cấu hình Dovecot (`doveconf`)**:
  - Đã kiểm thử xác thực cấu hình đầy đủ bằng `doveconf -c <staging>/dovecot.conf -n` (Mã thoát 0).
  - Kết quả xác minh: Dovecot nạp chính xác các chỉ thị `protocols = imap`, `mail_location = maildir:~/Maildir`, `first_valid_uid = 1000`, `auth_mechanisms = plain login` và socket SASL `/var/spool/postfix/private/auth`.
- **Kiểm tra logic TLS tổng quát (OpenSSL)**:
  - Cặp RSA hợp lệ và khớp: Thành công (`cmp -s` public key).
  - Cặp RSA lệch nhau: Bị phát hiện chính xác.
  - Cặp EC (prime256v1) hợp lệ và khớp: Thành công (`cmp -s` public key).
  - Cặp EC lệch nhau: Bị phát hiện chính xác.
  - Chứng chỉ hết hạn (`-checkend 0`): Bị phát hiện chính xác.
  - Hostname kiểm tra bằng `openssl x509 -checkhost mail.vkuoffice.test`: Khớp thành công; phát hiện cert sai hostname chính xác.
- **Kiểm tra logic Rollback tráo đổi thư mục an toàn**:
  - Cơ chế di chuyển, cách ly và phục hồi theo từng bước có hậu kiểm và an toàn race condition (giữ chỗ bằng `mktemp -d`, chuyển cấu hình hiện tại vào thư mục con `${failed_holder}/dovecot`).
  - Đảm bảo tên thư mục backup duy nhất qua `mktemp -d -p "/etc" dovecot_bak.XXXXXXXX`, tránh nguy cơ trùng lặp hay ghi đè backup cũ dù chạy liên tiếp.
  - Cơ chế cách ly và khôi phục hai chiều: nếu xác minh `diff -r` thất bại sau khi phục hồi, script sẽ cách ly thư mục lỗi trước khi đưa cấu hình cũ trở lại. Nếu cách ly thất bại, script dừng ngay lập tức để chống ghi đè lồng nhau và bảo toàn dữ liệu gốc.
  - Sau khi hoàn tác `target_failed_dir`, script thực hiện hậu kiểm nghiêm ngặt (kiểm tra `/etc/dovecot` tồn tại, tệp chính `dovecot.conf` hiện diện, và vị trí cũ `target_failed_dir` không còn tồn tại).
  - Khôi phục trạng thái dịch vụ (systemd) dựa trên kiểm tra mã thoát thực tế của `systemctl enable/disable` và `systemctl start/stop/restart`, không bỏ qua lỗi âm thầm.
  - Tình huống ban đầu chưa có `/etc/dovecot/` được dọn dẹp sạch sẽ.
  - Tình huống sao chép từ backup thất bại không làm mất thư mục cấu hình hiện tại.
  - *Lưu ý về phạm vi xác minh*: Lệnh `diff -r -q` xác minh tính toàn vẹn 100% nội dung và cấu trúc tệp dữ liệu, không bao gồm toàn bộ quyền nâng cao (extended ACLs/SELinux context).
- **Thẩm định TLS & CA Trust**:
  - Kiểm tra tính toàn vẹn X.509, thời điểm bắt đầu hiệu lực (`notBefore`) với chính sách fail-closed (lỗi nếu rỗng hoặc không thể parse), hạn dùng (`notAfter`), hostname `mail.vkuoffice.test` và so khớp Public Key giữa cert và key (hỗ trợ RSA và EC).
  - Kiểm tra quyền truy cập tệp khóa riêng tư: xét quyền duyệt thư mục cha (traversal), quyền đọc tệp khóa và khả năng parse khóa bằng OpenSSL. Script **không tự ý áp đặt chính sách owner/group hoặc chmod/chown** lên tệp chứng chỉ để bảo vệ các dịch vụ khác (như Postfix).
  - Đánh giá chuỗi tin cậy CA đầy đủ: hỗ trợ chỉ định Root CA qua `VKU_CA_CERT` và Intermediate CA qua `VKU_INTERMEDIATE_CERT`. Bắt buộc tệp phải tồn tại và đọc được, nghiêm cấm fallback âm thầm sang truststore hệ thống khi cấu hình CA riêng thất bại.
  - Dừng cài đặt và rollback nếu TLS không đạt yêu cầu nhằm bảo vệ chính sách `disable_plaintext_auth = yes`. Thông báo kích hoạt IMAPS chỉ phản ánh việc thiết lập listener trong cấu hình, việc bắt tay mạng thực tế cần được kiểm thử sau khi khởi chạy dịch vụ.

### 5.2. Các bước bắt buộc phải thực hiện trên máy chủ Ubuntu Server thật

#### A. Kiểm tra cú pháp & trạng thái dịch vụ trên OS thật
```bash
# 1. Kiểm tra cấu hình Dovecot đang nạp
sudo doveconf -n

# 2. Kiểm tra trạng thái hoạt động của systemd service
sudo systemctl status dovecot

# 3. Kiểm tra cổng 143 đang lắng nghe (và 993 nếu có TLS hợp lệ)
sudo ss -tulpn | grep -E '143|993'
```

#### B. Kiểm tra Socket Postfix SASL
Xác nhận socket được sinh ra đúng quyền hạn cho Postfix:
```bash
ls -la /var/spool/postfix/private/auth
# Kết quả mong đợi: srw-rw---- 1 postfix postfix ... /var/spool/postfix/private/auth
```

#### C. Kiểm thử xác thực người dùng (Authentication Test)
Sử dụng công cụ `doveadm` để kiểm tra xác thực trực tiếp với tài khoản Linux demo:
```bash
# Kiểm tra thông tin người dùng và mailbox location
sudo doveadm user nhanvien

# Kiểm tra xác thực mật khẩu qua PAM (nhập mật khẩu khi được hỏi)
sudo doveadm auth test nhanvien
```

#### D. Kiểm thử kết nối IMAP qua mạng
Sử dụng `openssl` để kiểm tra kết nối mã hóa an toàn (lưu ý: chỉ test cổng 993 nếu đã có chứng chỉ TLS hợp lệ):
```bash
# 1. Kiểm thử kết nối STARTTLS trên cổng 143
openssl s_client -connect mail.vkuoffice.test:143 -starttls imap

# 2. Kiểm thử kết nối IMAPS trên cổng 993 (khi máy chủ đã cấu hình TLS thành công)
openssl s_client -connect mail.vkuoffice.test:993
```
Sau khi kết nối STARTTLS thành công, thực hiện phiên IMAP với tag hợp lệ:
```text
a1 LOGIN nhanvien <mat_khau>
a2 LIST "" "*"
a3 LOGOUT
```

---

## 6. Xử Lý Các Lỗi Thường Gặp (Troubleshooting)

1. **Lỗi: `Authentication failed` hoặc không đăng nhập được plaintext:**
   - **Nguyên nhân:** Dovecot bật `disable_plaintext_auth = yes`, client cố gắng gửi mật khẩu mà không bật TLS.
   - **Cách xử lý:** Cấu hình client sử dụng STARTTLS (port 143) hoặc IMAPS (port 993).
2. **Lỗi: Không tìm thấy thư mục hòm thư (`Mailbox doesn't exist`):**
   - **Nguyên nhân:** TV1 chưa chạy script khởi tạo tài khoản hoặc chưa tạo cấu trúc `Maildir`.
   - **Cách xử lý:** Chạy `sudo ./scripts/setup-users.sh --setup` để tạo đầy đủ thư mục `cur`, `new`, `tmp` với quyền 700.
3. **Lỗi: Port 993 không hoạt động hoặc Dovecot lỗi SSL:**
   - **Nguyên nhân:** Tệp chứng chỉ SSL được khai báo trong `10-ssl.conf` không tồn tại, hết hạn, sai hostname `mail.vkuoffice.test`, private key không khớp public key hoặc Dovecot không có quyền đọc private key.
   - **Cách xử lý:** Kiểm tra tệp `/etc/dovecot/conf.d/10-ssl.conf`, kiểm tra tính hợp lệ của cert bằng `openssl x509 -in <cert_file> -text -noout` và so khớp public key bằng `openssl x509 -in <cert_file> -pubkey` với `openssl pkey -in <key_file> -pubout`.
