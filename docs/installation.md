# Hướng Dẫn Cài Đặt & Triển Khai Hệ Thống Mail Server (Step-by-Step)

Tài liệu này hướng dẫn chi tiết quy trình triển khai máy chủ email doanh nghiệp VKU Office trên **Ubuntu Server** trong môi trường ảo hóa VirtualBox, từ bước thiết lập hạ tầng mạng đến cấu hình dịch vụ và kiểm thử.

---

## 1. Yêu Cầu Môi Trường (Prerequisites)

* **Phần mềm ảo hóa:** Oracle VM VirtualBox (phiên bản 6.1 hoặc 7.x).
* **Hệ điều hành máy chủ:** Ubuntu Server 20.04 LTS hoặc 22.04 LTS (64-bit).
* **Cấu hình máy ảo khuyến nghị:**
  * **RAM:** Tối thiểu 2 GB (khuyến nghị 3 - 4 GB để chạy mượt mà Apache, MySQL/MariaDB, Postfix, Dovecot).
  * **CPU:** 2 vCPU.
  * **Ổ đĩa cứng (Disk):** Tối thiểu 25 GB.
  * **Mạng (Network):** 2 Card mạng (NAT + Host-only) hoặc NAT kèm Port Forwarding.
* **Máy Client:** Máy tính thật (Windows 10/11) dùng làm client gửi/nhận email và truy cập Webmail.

---

## 2. Giai Đoạn 1: Cấu Hình Mạng Máy Ảo VirtualBox

Để máy ảo vừa có Internet để tải package (`apt update`) vừa cho phép máy thật (Client) kết nối vào, chọn **1 trong 2 phương án mạng** sau:

### Phương Án A: Sử dụng Port Forwarding trên card NAT (Phương án nhanh)
Nếu VirtualBox đang dùng card mạng NAT (`10.0.2.15`), cấu hình Port Forwarding trong Settings máy ảo:
* **SSH:** Host Port `2222` $\rightarrow$ Guest Port `22` (Kết nối qua: `ssh -p 2222 vantan@127.0.0.1`).
* **Webmail:** Host Port `8080` (hoặc `80`) $\rightarrow$ Guest Port `80`.
* **SMTP Submission:** Host Port `587` $\rightarrow$ Guest Port `587`.
* **IMAP:** Host Port `143` $\rightarrow$ Guest Port `143`.

### Phương Án B: Sử dụng 2 Card Mạng (NAT + Host-Only Adapter)
1. Tắt máy ảo (Power Off).
2. Vào **Settings** -> Mục **Network**:
   * **Adapter 1:** NAT (để máy ảo ra Internet).
   * **Adapter 2:** Host-only Adapter -> Chọn `VirtualBox Host-Only Ethernet Adapter` (dải mạng mặc định: `192.168.56.x/24`).
3. Khởi động lại máy ảo và áp dụng cấu hình IP tĩnh qua Netplan.

---

## 3. Giai Đoạn 2: Thiết Lập Hạ Tầng Mạng, Hostname & Phân Giải Tên Miền

> [!IMPORTANT]
> Đây là phần việc nền tảng do **Thành viên 1** phụ trách. Nếu bước này chưa hoàn tất, các dịch vụ mail sẽ không thể gửi/nhận thư đúng tên miền.

### Bước 2.1: Đặt Hostname chuẩn FQDN
Chạy lệnh đặt hostname chính thức cho máy chủ:
```bash
sudo hostnamectl set-hostname mail.vkuoffice.test
```
Kiểm tra lại bằng lệnh:
```bash
hostname -f
# Kết quả mong đợi: mail.vkuoffice.test
```

### Bước 2.2: Cấu hình IP tĩnh với Netplan (Nếu dùng phương án Host-Only)
1. Kiểm tra tên card mạng thực tế:
   ```bash
   ip link show
   ```
2. Sao chép và phân quyền file cấu hình mạng mẫu:
   ```bash
   sudo cp dns/01-netcfg.yaml.example /etc/netplan/01-netcfg.yaml
   sudo chmod 600 /etc/netplan/01-netcfg.yaml
   ```
3. Áp dụng cấu hình:
   ```bash
   sudo netplan apply
   ```

### Bước 2.3: Ánh xạ tên miền trên Ubuntu Server (`/etc/hosts`)
Mở file `/etc/hosts` trên server:
```bash
sudo nano /etc/hosts
```
Thêm các dòng sau vào file:
```text
127.0.1.1       mail.vkuoffice.test mail
10.0.2.15       mail.vkuoffice.test mail
10.0.2.15       vkuoffice.test
```
*(Lưu ý: Thay `10.0.2.15` bằng IP thực tế của máy chủ nếu dùng dải IP khác như `192.168.56.10`)*.

### Bước 2.4: Ánh xạ tên miền trên máy Client (Windows)
1. Mở **Notepad** với quyền **Run as administrator**.
2. Mở file: `C:\Windows\System32\drivers\etc\hosts`.
3. Thêm ánh xạ trỏ về máy chủ Mail (dùng IP `127.0.0.1` nếu qua Port Forwarding hoặc `192.168.56.10` nếu qua Host-only):
   ```text
   127.0.0.1       mail.vkuoffice.test
   127.0.0.1       vkuoffice.test
   ```
4. Lưu file và mở **PowerShell** trên Windows chạy:
   ```powershell
   ipconfig /flushdns
   ping mail.vkuoffice.test
   ```

---

## 4. Giai Đoạn 3: Tạo Tài Khoản Demo & Hộp Thư Maildir

Chạy script tự động hóa do **Thành viên 1** phát triển để khởi tạo 5 tài khoản phòng ban và hộp thư bảo mật:

```bash
# Cấp quyền thực thi
chmod +x scripts/*.sh

# Chạy tạo tài khoản và hộp thư Maildir (quyền 700)
sudo ./scripts/setup-users.sh --setup
```

Kiểm tra lại bảng phân quyền và trạng thái:
```bash
sudo ./scripts/setup-users.sh --check
```

**Danh sách tài khoản được tạo:**
* `admin@vkuoffice.test` (có quyền sudo)
* `giamdoc@vkuoffice.test`
* `nhansu@vkuoffice.test`
* `ketoan@vkuoffice.test`
* `nhanvien@vkuoffice.test`
*(Mật khẩu khởi tạo mặc định: `Vku@Mail2026!`)*.

---

## 5. Giai Đoạn 4: Thiết Lập Tường Lửa Bảo Mật (UFW)

Áp dụng chính sách tường lửa mở đúng các cổng phục vụ Mail, Webmail và SSH:

```bash
# Cấp quyền thực thi và áp dụng rules
chmod +x firewall/ufw-rules.sh
sudo ./firewall/ufw-rules.sh --apply
```

Kiểm tra danh sách quy tắc đang hoạt động:
```bash
sudo ./firewall/ufw-rules.sh --status
```
*Đảm bảo các cổng sau đang ở trạng thái `ALLOW IN`: `22` (SSH), `80, 443` (Webmail), `25, 587, 465` (Postfix SMTP), `143, 993` (Dovecot IMAP).*

---

## 6. Giai Đoạn 5: Cài Đặt Các Dịch Vụ Ứng Dụng (TV2, TV3, TV4)

Sau khi nền tảng hạ tầng hoàn tất, các thành viên tiếp theo tiến hành cài đặt:

### 1. Cài đặt Postfix (TV2 - SMTP)
```bash
sudo ./scripts/install-postfix.sh
# Áp dụng cấu hình mẫu: postfix/main.cf.example và postfix/master.cf.example
sudo systemctl restart postfix
```

### 2. Cài đặt Dovecot (TV3 - IMAP & Maildir)
```bash
sudo ./scripts/install-dovecot.sh
# Áp dụng cấu hình mẫu: dovecot/dovecot.conf.example và 10-mail.conf
sudo systemctl restart dovecot
```

### 3. Cài đặt Roundcube Webmail (TV4 - Web Interface)
```bash
sudo ./scripts/install-roundcube.sh
# Áp dụng cấu hình Apache VirtualHost và config.inc.php.example
sudo systemctl restart apache2
```

---

## 7. Giai Đoạn 6: Kiểm Thử Toàn Diện & Nghiệm Thu Hệ Thống

Chạy công cụ 1-click kiểm tra toàn diện sức khỏe hệ thống:
```bash
sudo ./scripts/check-system.sh --all
```

### Tiêu chí nghiệm thu hoàn thành:
1. **Truy cập Webmail:** Mở trình duyệt trên máy thật, vào `http://mail.vkuoffice.test` hiển thị trang đăng nhập Roundcube.
2. **Đăng nhập:** Đăng nhập thành công với `nhanvien@vkuoffice.test` / `Vku@Mail2026!`.
3. **Gửi/Nhận thư:** Soạn email gửi đến `nhansu@vkuoffice.test`, đăng xuất và đăng nhập vào tài khoản `nhansu` để thấy email mới trong hộp thư `Inbox` (`~/Maildir/new`).
4. **Bảo mật hộp thư:** Thư mục `/home/<user>/Maildir` giữ nguyên quyền `700`, không user nào đọc trộm được dữ liệu của nhau.

---

## 8. Bảng Xử Lý Sự Cố Thường Gặp (Troubleshooting)

| Lỗi gặp phải | Nguyên nhân khả dĩ | Hướng khắc phục |
| :--- | :--- | :--- |
| **Không ping được `mail.vkuoffice.test` từ máy thật** | Chưa sửa file `hosts` trên Windows hoặc sai IP Host-only | Kiểm tra `C:\Windows\System32\drivers\etc\hosts` và chạy `ipconfig /flushdns`. |
| **Bị văng khỏi SSH khi cấu hình tường lửa** | Kích hoạt UFW trước khi cho phép cổng 22 | Luôn dùng `./firewall/ufw-rules.sh --apply` vì script đã mở sẵn port 22 trước khi bật firewall. |
| **Dovecot báo lỗi `Permission denied` vào Maildir** | Quyền thư mục Maildir bị gán cho `root` | Chạy lại `sudo ./scripts/setup-users.sh --setup` để script tự sửa lại ownership `user:user` và `chmod 700`. |
| **Postfix không gửi được thư nội bộ** | Sai tham số `myhostname` hoặc `mydestination` | Kiểm tra file `/etc/postfix/main.cf` đảm bảo có `vkuoffice.test` và `mail.vkuoffice.test`. |
| **Không mở được giao diện Roundcube** | Apache2 chưa chạy hoặc chưa mở cổng 80 trên UFW | Chạy `sudo systemctl status apache2` và kiểm tra `sudo ufw status`. |
