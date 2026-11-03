# Hướng Dẫn Cấu Hình Mạng, Hostname & Phân Giải Tên Miền (DNS / Hosts)

Tài liệu này thuộc trách nhiệm của **Thành viên 1 (Kỹ sư Hạ tầng & Quản trị Hệ thống)**, hướng dẫn thiết lập nền tảng mạng, địa chỉ IP tĩnh và phân giải tên miền nội bộ cho hệ thống Mail Server doanh nghiệp VKU Office.

---

## 1. Mục Tiêu Kỹ Thuật

* Đặt FQDN (Fully Qualified Domain Name) cho máy chủ: `mail.vkuoffice.test`.
* Cấu hình địa chỉ IP tĩnh cho Ubuntu Server trên VirtualBox (mặc định khuyến nghị: `192.168.56.10/24`).
* Thiết lập phân giải tên miền cục bộ trên cả **Ubuntu Server** và **Máy Client (Windows)** mà không cần dựng cụm DNS Server phức tạp.
* Đảm bảo các thành viên khác (TV2 Postfix, TV3 Dovecot, TV4 Roundcube) có địa chỉ mạng cố định để cấu hình dịch vụ.

---

## 2. Thiết Lập Card Mạng VirtualBox

Để máy ảo vừa có Internet để tải package (`apt update`, `apt install`) vừa giao tiếp được với máy thật (Client) qua IP tĩnh, cấu hình 2 card mạng trong VirtualBox:

1. **Adapter 1 (NAT):**
   * *Attached to:* NAT
   * *Mục đích:* Cho phép máy ảo ra ngoài Internet.
2. **Adapter 2 (Host-only Adapter):**
   * *Attached to:* Host-only Adapter
   * *Name:* `VirtualBox Host-Only Ethernet Adapter` (dải mạng mặc định: `192.168.56.1/24`)
   * *Mục đích:* Tạo mạng LAN nội bộ giữa máy thật và máy ảo, dùng để gán IP tĩnh `192.168.56.10`.

---

## 3. Các Bước Cấu Hình Trên Ubuntu Server

### Bước 1: Đặt Hostname chuẩn FQDN

Chạy lệnh đặt hostname chính thức cho máy chủ:
```bash
sudo hostnamectl set-hostname mail.vkuoffice.test
```

Kiểm tra lại hostname:
```bash
hostname
# Kết quả mong đợi: mail.vkuoffice.test

hostname -f
# Kết quả mong đợi: mail.vkuoffice.test
```

---

### Bước 2: Cấu hình IP tĩnh với Netplan

1. Kiểm tra danh sách card mạng hiện có:
   ```bash
   ip link show
   ```
   *(Xác định tên 2 card mạng, ví dụ: `enp0s3` là NAT, `enp0s8` là Host-only)*.

2. Sao chép file cấu hình mẫu [01-netcfg.yaml.example](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/dns/01-netcfg.yaml.example) vào thư mục Netplan:
   ```bash
   sudo cp dns/01-netcfg.yaml.example /etc/netplan/01-netcfg.yaml
   ```

3. Mở file và điều chỉnh IP/tên card mạng nếu cần:
   ```bash
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

4. **Phân quyền bảo mật bắt buộc** (Netplan sẽ cảnh báo hoặc từ chối chạy nếu file cấu hình mở quyền quá rộng):
   ```bash
   sudo chmod 600 /etc/netplan/01-netcfg.yaml
   ```

5. Áp dụng cấu hình mạng:
   ```bash
   sudo netplan apply
   ```

6. Kiểm tra lại địa chỉ IP:
   ```bash
   ip -4 -br addr show
   ```
   *Kết quả mong đợi: Card mạng Host-only (`enp0s8`) có IP `192.168.56.10/24`.*

---

### Bước 3: Ánh xạ tên miền trên Ubuntu Server (`/etc/hosts`)

Mở file hosts trên server:
```bash
sudo nano /etc/hosts
```

Cập nhật nội dung theo mẫu [hosts.example](file:///C:/Users/bread/.gemini/antigravity/worktrees/enterprise-mail-server/infrastructure_setup_mail_server/dns/hosts.example):
```text
127.0.0.1       localhost
127.0.1.1       mail.vkuoffice.test mail

# IP tĩnh Server VKU Office
192.168.56.10   mail.vkuoffice.test mail
192.168.56.10   vkuoffice.test
```

Lưu lại (`Ctrl + O`, `Enter`, `Ctrl + X`).

---

## 4. Cấu Hình Trên Máy Client (Windows)

Để trình duyệt và phần mềm mail client trên máy thật kết nối được tới `http://mail.vkuoffice.test`:

1. Mở Notepad với quyền **Run as Administrator**.
2. Mở file: `C:\Windows\System32\drivers\etc\hosts`.
3. Thêm 2 dòng sau vào cuối file:
   ```text
   192.168.56.10   mail.vkuoffice.test
   192.168.56.10   vkuoffice.test
   ```
4. Lưu file (`Ctrl + S`).
5. Mở PowerShell hoặc Command Prompt trên Windows và xóa cache DNS:
   ```cmd
   ipconfig /flushdns
   ```

---

## 5. Kiểm Thử & Nghiệm Thu (Verification)

### Kiểm tra từ Ubuntu Server:
```bash
# 1. Kiểm tra phân giải tên miền chính nó:
ping -c 4 mail.vkuoffice.test

# 2. Kiểm tra truy cập domain gốc:
ping -c 4 vkuoffice.test
```
*Yêu cầu: 0% packet loss, phản hồi từ `192.168.56.10` hoặc `127.0.1.1`.*

### Kiểm tra từ Máy Client Windows:
```cmd
ping mail.vkuoffice.test
```
*Yêu cầu: Nhận phản hồi (Reply from `192.168.56.10: bytes=32 time<1ms TTL=64`).*

---

## 6. Xử Lý Sự Cố Thường Gặp (Troubleshooting)

| Hiện tượng | Nguyên nhân | Cách khắc phục |
| :--- | :--- | :--- |
| `netplan apply` báo lỗi cú pháp | File YAML chứa phím Tab (`\t`) | Dùng phím Space (khoảng trắng) để thụt lề, kiểm tra lại thụt dòng thẳng hàng. |
| Netplan cảnh báo `Permissions for /etc/netplan/... are too open` | Quyền file chưa chuẩn | Chạy lệnh `sudo chmod 600 /etc/netplan/01-netcfg.yaml`. |
| Client ping báo `Request timed out` | Sai dải IP VirtualBox Host-Only | Mở VirtualBox -> File -> Tools -> Network Manager, kiểm tra dải IP adapter Host-Only có đúng là `192.168.56.1/24` không. |
| Client không nhận domain sau khi sửa hosts | Cache DNS Windows chưa cập nhật | Chạy `ipconfig /flushdns` và khởi động lại trình duyệt web. |
