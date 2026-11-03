# Kế Hoạch & Kịch Bản Kiểm Thử Hệ Thống (Testing Guide)

Tài liệu này hướng dẫn chi tiết các trường hợp kiểm thử (Test Cases), phương pháp thực hiện và tiêu chuẩn nghiệm thu cho hệ thống Enterprise Mail Server VKU Office.

---

## 1. Danh Mục Các Trường Hợp Kiểm Thử (Test Cases Matrix)

| Mã TC | Nội dung kiểm thử | Thành viên phụ trách | Phương pháp kiểm tra | Tiêu chuẩn đạt (Expected Result) | Trạng thái |
| :---: | :--- | :---: | :--- | :--- | :---: |
| **TC01** | Kiểm tra Hostname FQDN và IP Server | **TV1** | `hostname -f`, `ip -4 -br addr` | Trả về đúng `mail.vkuoffice.test` và có IP tĩnh. | 🟢 ĐẠT |
| **TC02** | Phân giải tên miền nội bộ (DNS/Hosts) | **TV1** | `ping -c 4 mail.vkuoffice.test` | 0% packet loss, phân giải đúng về IP server. | 🟢 ĐẠT |
| **TC03** | Khởi tạo tài khoản & phân quyền Maildir | **TV1** | `sudo ./scripts/setup-users.sh --check` | 5 user tồn tại, Maildir có quyền `700`, owner đúng. | 🟢 ĐẠT |
| **TC04** | Kiểm tra chính sách tường lửa UFW | **TV1** | `sudo ./firewall/ufw-rules.sh --status` | UFW active, mở đủ 8 cổng tiêu chuẩn. | 🟢 ĐẠT |
| **TC05** | Công cụ giám sát sức khỏe 1-click | **TV1** | `sudo ./scripts/check-system.sh --all` | Hiển thị bảng tổng hợp 5 tầng không có lỗi đỏ. | 🟢 ĐẠT |
| **TC06** | Trạng thái dịch vụ Postfix (SMTP) | **TV2** | `systemctl status postfix`, `ss -tuln` | Port 25, 587 đang lắng nghe (LISTEN). | 🟡 Chờ TV2 |
| **TC07** | Gửi email nội bộ qua dòng lệnh (CLI) | **TV2** | `mail`, `sendmail` hoặc `swaks` | Thư được chuyển vào `~/Maildir/new/` của người nhận. | 🟡 Chờ TV2 |
| **TC08** | Trạng thái dịch vụ Dovecot (IMAP) | **TV3** | `systemctl status dovecot`, `ss -tuln` | Port 143, 993 đang lắng nghe (LISTEN). | 🟡 Chờ TV3 |
| **TC09** | Xác thực đăng nhập hộp thư qua IMAP | **TV3** | `telnet mail.vkuoffice.test 143` | Đăng nhập tài khoản Linux thành công qua lệnh `a LOGIN`. | 🟡 Chờ TV3 |
| **TC10** | Đăng nhập & Đọc/Gửi thư trên Webmail | **TV4** | Trình duyệt truy cập Roundcube | Gửi email giữa `nhanvien` và `nhansu` thành công. | 🟡 Chờ TV4 |

---

## 2. Quy Trình Kiểm Thử Chi Tiết Từng Phần

### 2.1. Kiểm thử Hạ tầng & Người dùng (Phần việc TV1)

#### Bước 1: Kiểm tra Hostname và Phân giải tên miền (TC01, TC02)
```bash
# Kiểm tra FQDN
hostname -f
# Mong đợi: mail.vkuoffice.test

# Kiểm tra phân giải trong /etc/hosts
getent ahosts mail.vkuoffice.test
# Mong đợi: trả về IP 127.0.1.1 hoặc IP server
```

#### Bước 2: Kiểm tra Phân quyền Hộp thư Maildir (TC03)
Chạy script kiểm tra phân quyền độc lập:
```bash
sudo ./scripts/setup-users.sh --check
```
*Tiêu chuẩn nghiệm thu:*
* Cột `TỒN TẠI`: Cả 5 tài khoản đều hiển thị `CÓ` màu xanh.
* Cột `MAILDIR`: Cả 5 tài khoản đều hiển thị `CÓ` màu xanh.
* Cột `PHÂN QUYỀN`: Bắt buộc đạt `700` (`drwx------`).
* Cột `SỞ HỮU`: Khớp chính xác với tên tài khoản (ví dụ: `admin:admin`, `nhanvien:nhanvien`).

#### Bước 3: Kiểm tra Tường lửa UFW (TC04)
```bash
sudo ./firewall/ufw-rules.sh --status
```
*Tiêu chuẩn nghiệm thu:*
* Trạng thái `Status: active`.
* 8 cổng sau phải có luật `ALLOW IN`:
  * `22/tcp` (SSH)
  * `80/tcp`, `443/tcp` (Webmail HTTP/HTTPS)
  * `25/tcp`, `587/tcp`, `465/tcp` (Postfix SMTP)
  * `143/tcp`, `993/tcp` (Dovecot IMAP)

#### Bước 4: Kiểm tra Sức khỏe Toàn Diện 1-Click (TC05)
```bash
sudo ./scripts/check-system.sh --all
```
Script sẽ tự động quét cả 5 tầng hệ thống và xuất ra bảng tổng hợp minh chứng rõ ràng để chụp ảnh đưa vào báo cáo nghiệm thu đồ án.

---

### 2.2. Kiểm thử Dịch Vụ Postfix SMTP (Phần việc TV2)

#### Kiểm tra cổng gửi thư đang lắng nghe (TC06)
```bash
ss -tulnp | grep -E ':25\b|:587\b'
```

#### Kịch bản gửi email thử nghiệm giữa 2 tài khoản (TC07)
Dùng lệnh gửi thư nội bộ từ `nhanvien` sang `nhansu`:
```bash
echo "Kính gửi phòng Nhân sự, tôi gửi báo cáo tuần." | mail -s "Báo cáo công việc tuần 1" -r nhanvien@vkuoffice.test nhansu@vkuoffice.test
```
Kiểm tra xem email đã đến thư mục Maildir của `nhansu` chưa:
```bash
sudo ls -la /home/nhansu/Maildir/new/
```
*Kết quả đạt:* Xuất hiện file email mới trong thư mục `new/`.

---

### 2.3. Kiểm thử Dịch Vụ Dovecot IMAP (Phần việc TV3)

#### Kiểm tra cổng nhận thư đang lắng nghe (TC08)
```bash
ss -tulnp | grep -E ':143\b|:993\b'
```

#### Kịch bản xác thực IMAP trực tiếp bằng dòng lệnh (TC09)
Kết nối vào cổng 143 và đăng nhập thử:
```bash
telnet localhost 143
# Server phản hồi: * OK Dovecot ready.

# Gõ lệnh đăng nhập (thay mật khẩu thực tế):
a LOGIN nhansu Vku@Mail2026!
# Phản hồi mong đợi: a OK Logged in.

# Kiểm tra danh sách thư:
b SELECT INBOX
# Phản hồi: * FLAGS ... b OK [READ-WRITE] Select completed.

# Đăng xuất:
c LOGOUT
```

---

### 2.4. Kiểm thử Tích Hợp Roundcube Webmail (Phần việc TV4)

#### Kịch bản kiểm thử giao diện người dùng (TC10):
1. **Truy cập:** Mở trình duyệt trên máy thật, vào địa chỉ: `http://mail.vkuoffice.test`.
2. **Kiểm tra đăng nhập sai:** Nhập user `nhanvien@vkuoffice.test` với mật khẩu sai $\rightarrow$ Hệ thống phải báo lỗi từ chối đăng nhập.
3. **Đăng nhập hợp lệ:** Nhập user `nhanvien@vkuoffice.test` / `Vku@Mail2026!` $\rightarrow$ Chuyển hướng thành công vào hộp thư đến.
4. **Soạn & gửi thư:** Bấm **Compose**, gửi thư đến `nhansu@vkuoffice.test`.
5. **Đăng nhập người nhận:** Đăng xuất, đăng nhập lại bằng `nhansu@vkuoffice.test` $\rightarrow$ Nhìn thấy email mới trong danh sách thư đến, mở ra đọc nội dung chuẩn xác.

---

## 3. Theo Dõi & Xử Lý Lỗi Qua Log Hệ Thống (Log Troubleshooting)

Khi xảy ra lỗi trong quá trình kiểm thử, chạy các lệnh sau để xác định nguyên nhân:

```bash
# 1. Trích xuất nhanh 25 dòng log mail gần nhất qua script TV1:
sudo ./scripts/check-system.sh --logs

# 2. Theo dõi log Postfix và Dovecot theo thời gian thực (Live):
sudo tail -f /var/log/mail.log

# 3. Theo dõi log Web Server Apache (khi webmail lỗi 500):
sudo tail -f /var/log/apache2/error.log
```
