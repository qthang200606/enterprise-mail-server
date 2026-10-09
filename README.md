# Enterprise Mail Server System on Linux

## 1. Giới thiệu
Đồ án môn Linux mã nguồn mở: xây dựng hệ thống mail server doanh nghiệp trên Ubuntu, giả lập công ty VKU Office.

## 2. Mô hình
- Doanh nghiệp giả lập: VKU Office
- Mail domain nội bộ: `vkuoffice.test`
- Webmail: `mail.vkuoffice.test`
- Mail Transfer Agent: Postfix
- Mail access: Dovecot
- Webmail: Roundcube
- Máy chủ: Ubuntu Server
- Người dùng: các máy trong cùng mạng với server

## 3. Tài khoản demo
- `admin@vkuoffice.test` — Quản trị viên
- `giamdoc@vkuoffice.test` — Giám đốc
- `nhansu@vkuoffice.test` — Phòng nhân sự
- `ketoan@vkuoffice.test` — Phòng kế toán
- `nhanvien@vkuoffice.test` — Nhân viên

> Không commit mật khẩu thật, private key hoặc thông tin bí mật vào repository.

## 4. Phân công
- TV1: Ubuntu, Network, User/Permission, Firewall, tích hợp
- TV2: Postfix, SMTP, gửi mail
- TV3: Dovecot, IMAP, Authentication, Mailbox
- TV4: Roundcube, Webmail, kiểm thử, Demo

## 5. Cấu trúc repository
```text
enterprise-mail-server/
├── README.md
├── .gitignore
├── scripts/
├── postfix/
├── dovecot/
├── roundcube/
├── dns/
├── firewall/
└── docs/
```

## 6. Quy tắc làm việc
Mỗi thành viên làm trên branch riêng:
```bash
git checkout -b feature/ten-phan-viec
```

Sau khi hoàn thành:
```bash
git add .
git commit -m "Mô tả thay đổi"
git push -u origin feature/ten-phan-viec
```

Sau đó tạo Pull Request vào `main`.

## 7. Lưu ý
Các file cấu hình trong repository là file mẫu. Khi triển khai trên Ubuntu, kiểm tra lại đường dẫn, IP, hostname và phiên bản package trước khi áp dụng.
