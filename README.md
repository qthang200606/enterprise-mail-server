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
<WritingBlock id="61382" variant="document">## PHÂN CÔNG NHIỆM VỤ NHÓM

1. Thông tin dự án

Tên đề tài: Enterprise Mail Server System on Linux

Mô hình: Hệ thống mail server triển khai trên Ubuntu Server.

Tên miền nội bộ: vkuoffice.test

Địa chỉ Webmail dự kiến: http://mail.vkuoffice.test

2. Phân công công việc
Thành viên 1 – Nhóm trưởng: Ubuntu Server và tích hợp hệ thống

Nhánh Git: feature/server-setup

Nhiệm vụ:

Cài đặt và cấu hình Ubuntu Server.

Thiết lập hostname, địa chỉ IP và tên miền nội bộ.

Chuẩn bị cấu hình phân giải tên miền hoặc ánh xạ hostname cho các máy client.

Thiết lập người dùng, nhóm, quyền truy cập và firewall.

Viết tài liệu hướng dẫn cài đặt môi trường máy chủ.

Kiểm tra, tích hợp và hỗ trợ các thành viên kết nối dịch vụ.

Thư mục phụ trách chính: scripts/, dns/, firewall/, docs/.

Thành viên 2 – Postfix và SMTP

Nhánh Git: feature/postfix-smtp

Nhiệm vụ:

Cài đặt và cấu hình Postfix.

Thiết lập SMTP cho việc gửi email nội bộ.

Cấu hình tên miền thư phù hợp với vkuoffice.test.

Kiểm tra gửi email và trạng thái hàng đợi thư.

Theo dõi log, xử lý lỗi gửi thư.

Viết tài liệu cài đặt và kiểm thử Postfix.

Thư mục phụ trách chính: postfix/, docs/.

Thành viên 3 – Dovecot và IMAP

Nhánh Git: feature/dovecot-imap

Nhiệm vụ:

Cài đặt và cấu hình Dovecot.

Thiết lập IMAP để người dùng đọc email.

Cấu hình xác thực và nơi lưu mailbox.

Phối hợp với thành viên 2 để kiểm thử luồng gửi và nhận thư.

Kiểm tra trạng thái dịch vụ và log.

Viết tài liệu cài đặt và kiểm thử Dovecot.

Thư mục phụ trách chính: dovecot/, docs/.

Thành viên 4 – Roundcube Webmail

Nhánh Git: feature/roundcube-webmail

Nhiệm vụ:

Cài đặt và cấu hình web server cùng Roundcube.

Kết nối Roundcube với SMTP của Postfix và IMAP của Dovecot.

Thiết lập truy cập webmail qua tên miền nội bộ.

Kiểm thử đăng nhập, đọc thư, gửi thư.

Chụp ảnh kết quả và viết hướng dẫn sử dụng webmail.

Thư mục phụ trách chính: roundcube/, docs/.

3. Quy trình làm việc với GitHub

Mỗi thành viên làm việc trên nhánh được phân công.

Không commit trực tiếp lên nhánh main.

Đặt tên commit rõ ràng, ví dụ: Add Postfix SMTP configuration.

Sau khi hoàn thành một phần, kiểm tra và commit các file liên quan.

Push nhánh lên GitHub.

Tạo Pull Request từ nhánh cá nhân vào main.

Nhóm trưởng kiểm tra nội dung, kết quả kiểm thử rồi mới gộp.

Không đưa mật khẩu, khóa riêng hoặc thông tin xác thực vào GitHub.

4. Quy tắc phối hợp

Thành viên 1 chuẩn bị môi trường Ubuntu Server và thống nhất cấu hình mạng.

Thành viên 2 và 3 phối hợp để kiểm thử gửi, nhận email.

Thành viên 4 tích hợp webmail sau khi SMTP và IMAP đã được cấu hình.

Các thành viên phải cập nhật tài liệu và ghi lại kết quả kiểm thử.

Các file cấu hình mẫu trong repo cần được kiểm tra và điều chỉnh theo môi trường Ubuntu thực tế trước khi sử dụng.

5. Tiêu chí hoàn thành

Ubuntu Server hoạt động và các client có thể kết nối.

Postfix gửi email nội bộ thành công.

Dovecot cho phép người dùng xác thực và đọc thư.

Roundcube đăng nhập, đọc và gửi thư thông qua các dịch vụ đã cấu hình.

Nhóm có tài liệu triển khai, hướng dẫn sử dụng và ảnh chụp kiểm thử. </WritingBlock>

Lưu ý: tên nhánh ở trên là tên nhóm dự kiến sử dụng. Nếu thành viên chưa tạo nhánh thì chưa có nghĩa là phần việc đã được thực hiện.

Bước 3. Lưu README và đẩy lên GitHub

Sau khi thêm nội dung, nhấn Ctrl + S để lưu file.

Trong Terminal, chạy:

Nếu thành công, GitHub sẽ có nhánh docs/team-task-guide chứa bản README đã cập nhật.

Bước 4. Gộp README vào nhánh main

<box gap={3}> <row align="start" gap={3}> <AsyncImage query="GitHub repository pull requests tab interface" aspectRatio="4:3" width="112px" radius="lg" /> <box flex="1" gap={1}> **1. Mở Pull requests**

Vào 
repo của nhóm
, chọn Pull requests → New pull request. </box> </row> <divider color="subtle" /> <row align="start" gap={3}> <AsyncImage query="GitHub compare changes base main compare branch dropdown pull request interface" aspectRatio="4:3" width="112px" radius="lg" /> <box flex="1" gap={1}> 2. Chọn đúng hai nhánh

- Base: main - Compare: docs/team-task-guide

Sau đó nhấn Create pull request. </box> </row> <divider color="subtle" /> <row align="start" gap={3}> <AsyncImage query="GitHub pull request merge pull request button interface" aspectRatio="4:3" width="112px" radius="lg" /> <box flex="1" gap={1}> 3. Gộp thay đổi

Kiểm tra nội dung README rồi nhấn Merge pull request và xác nhận gộp. </box> </row> </box>

Sau khi merge, README mới sẽ xuất hiện trên nhánh main. Các thành viên có thể mở repo và đọc phần phân công mà không cần tự tìm nhánh của bạn.

Bước 5. Báo cho các thành viên bắt đầu

Bạn gửi nhóm thông báo này:

<WritingBlock id="61383" variant="chat_message">Mọi người vào repo GitHub của nhóm đọc file README.md để xem nhiệm vụ được phân công nhé.

Repo: 
https://github.com/qthang200606/enterprise-mail-server

Mỗi người tạo và làm việc trên nhánh riêng:

TV1: feature/server-setup

TV2: feature/postfix-smtp

TV3: feature/dovecot-imap

TV4: feature/roundcube-webmail

Mọi người không code trực tiếp trên main. Khi hoàn thành từng phần thì commit, push nhánh lên GitHub và tạo Pull Request để mình kiểm tra, sau đó mới merge vào main.

Nhớ cập nhật tài liệu và kết quả kiểm thử trong quá trình thực hiện nhé.</WritingBlock>
