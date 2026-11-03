# Báo Cáo Nhiệm Vụ & Hướng Dẫn Nghiệm Thu — Thành Viên 1 (SysAdmin / DevOps)

* **Vai trò:** Kỹ sư Hạ tầng & Quản trị Hệ thống (Nền móng hệ thống Mail Server)
* **Người thực hiện:** Thành viên 1
* **Đơn vị mô phỏng:** Doanh nghiệp VKU Office
* **Môi trường:** Ubuntu Server 20.04/22.04 LTS trên Oracle VM VirtualBox
* **Hostname FQDN:** `mail.vkuoffice.test` | **Domain nội bộ:** `vkuoffice.test`

---

## 1. Tổng Hợp Các Task Đã Hoàn Thành (100% DONE)

| STT | Mã Task | Tên Task & Nội dung kỹ thuật | Sản phẩm bàn giao trong Repo | Trạng thái |
| :---: | :---: | :--- | :--- | :---: |
| 1 | **TASK-01** | **Cấu hình Hạ tầng Mạng, Hostname & IP**<br>• Thiết lập Hostname FQDN: `mail.vkuoffice.test`<br>• File mẫu Netplan 2 card mạng (NAT + Host-only `192.168.56.10`)<br>• File mẫu ánh xạ tên miền cục bộ trên Ubuntu Server và Windows Client. | • `dns/01-netcfg.yaml.example`<br>• `dns/hosts.example`<br>• `dns/README.md` | 🟢 **HOÀN THÀNH** |
| 2 | **TASK-02** | **Tự động hóa Khởi tạo 5 User & Hộp thư Maildir**<br>• Tạo 5 tài khoản: `admin`, `giamdoc`, `nhansu`, `ketoan`, `nhanvien`<br>• Cấp quyền `sudo` cho tài khoản `admin`<br>• Khởi tạo cấu trúc `~/Maildir/{cur,new,tmp}` với phân quyền nghiêm ngặt `chmod 700` (`drwx------`) chống đọc trộm thư.<br>• Tích hợp cờ hiệu CLI: `--setup`, `--check`, `--reset`. | • `scripts/setup-users.sh`<br>• `scripts/README.md` | 🟢 **HOÀN THÀNH** |
| 3 | **TASK-03** | **Cấu hình Bộ Quy Tắc Tường Lửa Bảo Mật (UFW)**<br>• Thiết lập chính sách mặc định: `default deny incoming`, `default allow outgoing`<br>• Ưu tiên mở SSH (`22/tcp`) trước tiên để chống mất kết nối từ xa<br>• Mở toàn bộ cổng Mail & Web: Webmail (`80, 443`), Postfix SMTP (`25, 587, 465`), Dovecot IMAP (`143, 993`)<br>• Tích hợp cờ hiệu CLI: `--apply`, `--status`, `--reset`. | • `firewall/ufw-rules.sh`<br>• `firewall/README.md` | 🟢 **HOÀN THÀNH** |
| 4 | **TASK-04** | **Xây dựng Script Giám Sát Sức Khỏe Hệ Thống 1-Click**<br>• Tự động quét 5 tầng: FQDN & IP, Tường lửa UFW, Dịch vụ systemd, Cổng lắng nghe `ss -tulnp`, 5 User Maildir, và trích xuất Mail Log. | • `scripts/check-system.sh`<br>• `scripts/README.md` | 🟢 **HOÀN THÀNH** |
| 5 | **TASK-05** | **Hoàn Thiện Bộ Tài Liệu Kỹ Thuật Đồ Án**<br>• Biên soạn tài liệu kiến trúc hệ thống, cơ chế lưu trữ Maildir, ma trận kiểm thử 10 ca (TC01-TC10) và cẩm nang triển khai Step-by-Step. | • `docs/installation.md`<br>• `docs/architecture.md`<br>• `docs/testing.md` | 🟢 **HOÀN THÀNH** |

---

## 2. Quy Trình 5 Bước Check Test Nghiệm Thu Thực Tế (Step-by-Step)

Quy trình chuẩn dành cho TV1 khi trình bày kiểm thử trước giảng viên hoặc bàn giao hệ sinh thái cho các thành viên trong nhóm:

### 🔹 BƯỚC 1: Kiểm Tra Hostname & Phân Giải Tên Miền
* **Lệnh thực thi trên Ubuntu:**
  ```bash
  hostname -f
  getent ahosts mail.vkuoffice.test
  ```
* **Mục đích:** Đảm bảo máy chủ nhận diện đúng tên miền FQDN, phục vụ Postfix HELO/EHLO.
* **Tiêu chuẩn nghiệm thu:** 
  * `hostname -f` in ra: `mail.vkuoffice.test`.
  * `getent` phân giải thành công ra IP nội bộ (`127.0.1.1` hoặc IP server).

---

### 🔹 BƯỚC 2: Kiểm Tra 5 Người Dùng & Phân Quyền Hộp Thư Maildir
* **Lệnh thực thi trên Ubuntu:**
  ```bash
  sudo ./scripts/setup-users.sh --check
  ```
* **Mục đích:** Chứng minh 5 tài khoản đã sẵn sàng và hộp thư `Maildir` được bảo vệ tuyệt đối.
* **Tiêu chuẩn nghiệm thu:** Toàn bộ bảng hiển thị màu xanh lá cây:
  ```text
  TÀI KHOẢN    | TỒN TẠI    | MAILDIR    | PHÂN QUYỀN   | SỞ HỮU
  ------------------------------------------------------------------
  admin        | CÓ         | CÓ         | 700          | admin:admin
  giamdoc      | CÓ         | CÓ         | 700          | giamdoc:giamdoc
  nhansu       | CÓ         | CÓ         | 700          | nhansu:nhansu
  ketoan       | CÓ         | CÓ         | 700          | ketoan:ketoan
  nhanvien     | CÓ         | CÓ         | 700          | nhanvien:nhanvien
  ```
  *(Quyền `700` đảm bảo không người dùng nào đọc trộm được email của người dùng khác).*

---

### 🔹 BƯỚC 3: Kiểm Tra Tường Lửa Bảo Mật UFW
* **Lệnh thực thi trên Ubuntu:**
  ```bash
  sudo ./firewall/ufw-rules.sh --status
  ```
* **Mục đích:** Chứng minh máy chủ chỉ mở những cổng được phép, khóa các cổng không sử dụng.
* **Tiêu chuẩn nghiệm thu:**
  * Trạng thái: `Status: active`.
  * 8 cổng sau có luật `ALLOW IN`:
    * Quản trị từ xa: `22/tcp` (SSH).
    * Webmail Roundcube: `80/tcp` (HTTP), `443/tcp` (HTTPS).
    * Mail gửi Postfix: `25/tcp` (SMTP), `587/tcp` (Submission), `465/tcp` (SMTPS).
    * Mail nhận Dovecot: `143/tcp` (IMAP), `993/tcp` (IMAPS).

---

### 🔹 BƯỚC 4: Kiểm Tra Toàn Diện Hệ Thống 1-Click (Health Check)
* **Lệnh thực thi trên Ubuntu:**
  ```bash
  sudo ./scripts/check-system.sh --all
  ```
* **Mục đích:** Xuất báo cáo tổng quan toàn bộ hệ thống trên một màn hình duy nhất để giảng viên đánh giá.
* **Tiêu chuẩn nghiệm thu:**
  * **Mục 1 (Hạ tầng & Mạng):** Hostname `[OK]`, Phân giải `/etc/hosts` `[OK]`.
  * **Mục 2 (Tường lửa UFW):** `active`, đủ 8 cổng `ALLOW`.
  * **Mục 3 (Dịch vụ Systemd):** `ufw` đang chạy (`active`); `postfix`, `dovecot`, `apache2` hiển thị trạng thái sẵn sàng chờ TV2, TV3, TV4 cấu hình.
  * **Mục 4 (Cổng lắng nghe):** Cổng `22/tcp` đang lắng nghe (`sshd`).
  * **Mục 5 (5 Tài khoản):** 100% tài khoản đạt quyền `700`.

---

### 🔹 BƯỚC 5: Kiểm Tra Kết Nối Từ Máy Thật Client (Windows)
* **Lệnh thực thi trên Windows PowerShell:**
  ```powershell
  # 1. Kiểm tra thông mạng đến Mail Server
  ping mail.vkuoffice.test

  # 2. Kiểm tra thông cổng SSH (hoặc cổng Port Forwarding)
  Test-NetConnection -ComputerName 127.0.0.1 -Port 2222
  ```
* **Tiêu chuẩn nghiệm thu:** `TcpTestSucceeded : True`, `0% packet loss`.

---

## 3. Cờ Hiệu Bàn Giao Xương Sống Cho Nhóm (Green Flags)

1. 🟢 **Bàn giao cho TV2 (Postfix - SMTP):**
   * Hostname FQDN đã chuẩn: `mail.vkuoffice.test`.
   * Cổng SMTP `25`, `587`, `465` đã được UFW cho phép.
   * Cấu trúc `~/Maildir` đã sẵn sàng để Postfix ghi thư (`home_mailbox = Maildir/`).

2. 🟢 **Bàn giao cho TV3 (Dovecot - IMAP):**
   * 5 user Linux đã khởi tạo với mật khẩu chuẩn test: `Vku@Mail2026!`.
   * Cấu trúc hộp thư `~/Maildir/{cur,new,tmp}` với quyền `700` đã hoàn tất để Dovecot cấu hình `mail_location = maildir:~/Maildir`.
   * Cổng IMAP `143`, `993` đã mở sẵn trên tường lửa.

3. 🟢 **Bàn giao cho TV4 (Roundcube - Webmail):**
   * Cổng `80`, `443` đã mở trên UFW.
   * Tên miền `mail.vkuoffice.test` đã ánh xạ sẵn sàng trên cả Server và máy Client.

