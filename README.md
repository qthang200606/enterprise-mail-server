# Enterprise Mail Server System on Linux

## 1. Giới thiệu đề tài

Đồ án môn Linux mã nguồn mở: **Xây dựng hệ thống Mail Server doanh nghiệp trên Ubuntu Server**, mô phỏng hệ thống email nội bộ của doanh nghiệp VKU Office.

Hệ thống cho phép người dùng sử dụng tài khoản email theo tên miền nội bộ, gửi và nhận thư trong mạng LAN thông qua giao diện webmail.

Mục tiêu của đồ án là tìm hiểu cách triển khai, cấu hình, quản lý và kiểm thử các dịch vụ mail server trên hệ điều hành Linux; đồng thời thực hành quản lý mã nguồn và phối hợp làm việc nhóm bằng GitHub.

## 2. Mục tiêu hệ thống

Hệ thống cần đáp ứng các mục tiêu sau:

* Triển khai máy chủ trên Ubuntu Server.
* Thiết lập tên miền email nội bộ `vkuoffice.test`.
* Cấu hình Postfix để tiếp nhận và gửi email.
* Cấu hình Dovecot để xác thực người dùng và truy cập mailbox thông qua IMAP.
* Triển khai Roundcube làm giao diện webmail.
* Cho phép người dùng truy cập webmail từ các máy client trong mạng được cấu hình.
* Kiểm thử việc đăng nhập, gửi thư, nhận thư và đọc thư giữa các tài khoản nội bộ.
* Có tài liệu cài đặt, cấu hình, xử lý lỗi và hình ảnh minh chứng kết quả.

**Phạm vi:** Đồ án tập trung vào hệ thống email nội bộ phục vụ học tập và trình diễn. Không mặc định hệ thống có thể gửi email ra Internet hoặc đáp ứng đầy đủ yêu cầu của một mail server doanh nghiệp đang vận hành thực tế.

## 3. Mô hình hệ thống

### 3.1. Thông tin chung

| Thành phần              | Giá trị                           |
| ----------------------- | --------------------------------- |
| Doanh nghiệp mô phỏng   | VKU Office                        |
| Hệ điều hành máy chủ    | Ubuntu Server                     |
| Domain email nội bộ     | `vkuoffice.test`                  |
| Địa chỉ webmail dự kiến | `http://mail.vkuoffice.test`      |
| Dịch vụ SMTP            | Postfix                           |
| Dịch vụ IMAP            | Dovecot                           |
| Giao diện webmail       | Roundcube                         |
| Môi trường máy chủ      | Máy ảo VirtualBox                 |
| Máy client              | Các máy có thể kết nối đến server |

Tên miền `.test` dùng cho môi trường thử nghiệm nội bộ. Để truy cập bằng hostname, nhóm phải cấu hình DNS nội bộ hoặc ánh xạ tên miền trên các máy client.

### 3.2. Vai trò các dịch vụ

* **Ubuntu Server:** Môi trường chạy các dịch vụ và quản lý tài nguyên máy chủ.
* **Postfix:** Tiếp nhận và chuyển tiếp email qua SMTP theo cấu hình hệ thống.
* **Dovecot:** Cung cấp IMAP và xác thực người dùng theo phương án mailbox mà nhóm triển khai.
* **Roundcube:** Cung cấp giao diện web để đăng nhập, xem, soạn và gửi email.
* **DNS hoặc hosts:** Giúp máy client phân giải `mail.vkuoffice.test` đến địa chỉ IP máy chủ.
* **Firewall:** Cho phép các kết nối cần thiết và hạn chế những cổng không sử dụng.

### 3.3. Luồng hoạt động dự kiến

1. Người dùng mở trình duyệt và truy cập `http://mail.vkuoffice.test`.
2. Roundcube hiển thị giao diện đăng nhập.
3. Người dùng đăng nhập bằng tài khoản email nội bộ.
4. Roundcube kết nối đến Dovecot qua IMAP để đọc mailbox.
5. Khi gửi thư, Roundcube chuyển email đến Postfix qua SMTP.
6. Postfix xử lý và chuyển thư đến mailbox người nhận theo cấu hình.
7. Người nhận đăng nhập Roundcube để đọc thư thông qua Dovecot.

Luồng trên chỉ hoạt động khi các dịch vụ, tài khoản, quyền mailbox và cấu hình kết nối đã được thiết lập chính xác.

## 4. Tài khoản email demo

Nhóm dự kiến sử dụng các tài khoản sau:

| Email                     | Vai trò           |
| ------------------------- | ----------------- |
| `admin@vkuoffice.test`    | Quản trị hệ thống |
| `giamdoc@vkuoffice.test`  | Giám đốc          |
| `nhansu@vkuoffice.test`   | Phòng nhân sự     |
| `ketoan@vkuoffice.test`   | Phòng kế toán     |
| `nhanvien@vkuoffice.test` | Nhân viên         |

Đây là danh sách tài khoản mục tiêu, không có nghĩa các tài khoản đã được tạo sẵn. Nhóm phải tạo tài khoản, thiết lập xác thực và mailbox theo phương án triển khai thực tế.

**Quy tắc bảo mật:**

* Không lưu mật khẩu thật trong README hoặc mã nguồn.
* Không commit file chứa thông tin xác thực, khóa riêng hoặc dữ liệu nhạy cảm.
* Không sử dụng cùng một mật khẩu yếu cho toàn bộ tài khoản.
* Chỉ sử dụng tài khoản demo trong môi trường được phép kiểm thử.

## 5. Công nghệ và công cụ

* Ubuntu Server.
* VirtualBox.
* Postfix – SMTP.
* Dovecot – IMAP và xác thực.
* Roundcube Webmail.
* Web server tương thích với phiên bản Roundcube được cài đặt.
* PHP và cơ sở dữ liệu theo yêu cầu của phiên bản Roundcube.
* Git và GitHub để quản lý mã nguồn.
* Terminal Linux để cài đặt, cấu hình và kiểm tra dịch vụ.
* Trình duyệt web để kiểm thử webmail.

Nhóm cần ghi lại phiên bản hệ điều hành, package và cấu hình thực tế đã sử dụng trong quá trình triển khai.

## 6. Phân công nhiệm vụ

### TV1 – Ubuntu Server, Network và Firewall

**Nhánh Git:** `feature/server-setup`

**Mục tiêu:** Chuẩn bị môi trường Ubuntu Server để các dịch vụ mail có thể cài đặt và giao tiếp với máy client.

**Nhiệm vụ cụ thể:**

1. Cài đặt và kiểm tra Ubuntu Server trên VirtualBox.
2. Ghi lại hostname và địa chỉ IP của máy chủ.
3. Cấu hình mạng VirtualBox để máy client kết nối được đến server.
4. Thiết lập DNS nội bộ hoặc hướng dẫn ánh xạ `mail.vkuoffice.test`.
5. Chuẩn bị người dùng Linux, nhóm và quyền truy cập cần thiết.
6. Thiết lập UFW chỉ cho phép những cổng cần sử dụng.
7. Kiểm tra trạng thái mạng, dịch vụ và log hệ thống.
8. Viết tài liệu cài đặt môi trường và hướng dẫn khởi động hệ thống.
9. Phối hợp với các thành viên để tích hợp và xử lý lỗi kết nối.

**Thư mục phụ trách chính:** `scripts/`, `dns/`, `firewall/`, `docs/`.

**Sản phẩm bàn giao:**

* Tài liệu cấu hình Ubuntu Server.
* Thông tin hostname và IP dùng trong môi trường kiểm thử.
* Hướng dẫn mạng và phân giải tên miền.
* Cấu hình firewall có giải thích.
* Ảnh chụp hoặc kết quả kiểm tra kết nối.

### TV2 – Postfix và SMTP

**Nhánh Git:** `feature/postfix-smtp`

**Mục tiêu:** Triển khai thành phần xử lý email gửi qua SMTP.

**Nhiệm vụ cụ thể:**

1. Cài đặt Postfix trên Ubuntu Server.
2. Cấu hình hostname và domain email theo thống nhất của nhóm.
3. Cấu hình SMTP phục vụ gửi email nội bộ.
4. Phối hợp xác định phương thức chuyển thư và mailbox phù hợp với Dovecot.
5. Kiểm tra trạng thái dịch vụ và cấu hình Postfix.
6. Kiểm tra hàng đợi thư và log khi gửi email.
7. Thử gửi email đến tài khoản nội bộ khác.
8. Ghi lại lỗi gặp phải, nguyên nhân và cách xử lý.
9. Viết hướng dẫn cài đặt, cấu hình và kiểm thử.

**Thư mục phụ trách chính:** `postfix/`, `docs/`.

**Sản phẩm bàn giao:**

* File cấu hình mẫu có chú thích.
* Hướng dẫn cài đặt Postfix.
* Kết quả kiểm thử gửi thư.
* Ảnh chụp hoặc log chứng minh kết quả.

### TV3 – Dovecot, IMAP và Mailbox

**Nhánh Git:** `feature/dovecot-imap`

**Mục tiêu:** Triển khai dịch vụ cho phép người dùng xác thực và truy cập hộp thư.

**Nhiệm vụ cụ thể:**

1. Cài đặt Dovecot.
2. Cấu hình IMAP theo phương án triển khai của nhóm.
3. Thiết lập cơ chế xác thực người dùng.
4. Thống nhất định dạng tài khoản, vị trí lưu mailbox và quyền truy cập với thành viên 2.
5. Kiểm tra cấu hình và trạng thái Dovecot.
6. Kiểm tra đăng nhập và truy cập mailbox.
7. Phối hợp với thành viên 2 để kiểm thử gửi và nhận email.
8. Kiểm tra log khi xác thực thất bại hoặc không tìm thấy mailbox.
9. Viết tài liệu triển khai và kiểm thử.

**Thư mục phụ trách chính:** `dovecot/`, `docs/`.

**Sản phẩm bàn giao:**

* File cấu hình mẫu có chú thích.
* Hướng dẫn thiết lập IMAP và xác thực.
* Kết quả kiểm thử truy cập mailbox.
* Ảnh chụp hoặc log chứng minh kết quả.

### TV4 – Roundcube Webmail, kiểm thử và demo

**Nhánh Git:** `feature/roundcube-webmail`

**Người phụ trách:** Nhóm trưởng.

**Mục tiêu:** Cung cấp giao diện webmail và tích hợp các dịch vụ email của nhóm thành hệ thống có thể trình diễn.

**Nhiệm vụ cụ thể:**

1. Kiểm tra điều kiện mạng và các dịch vụ phụ thuộc trước khi cài đặt.
2. Cài đặt web server, PHP, các extension và cơ sở dữ liệu theo yêu cầu của phiên bản Roundcube.
3. Cài đặt Roundcube và thiết lập cấu hình phù hợp với môi trường Ubuntu.
4. Cấu hình kết nối IMAP đến Dovecot.
5. Cấu hình kết nối SMTP đến Postfix.
6. Thiết lập truy cập webmail bằng `mail.vkuoffice.test`.
7. Kiểm thử đăng nhập bằng tài khoản email nội bộ.
8. Kiểm thử đọc thư, soạn thư và gửi thư giữa hai tài khoản.
9. Kiểm tra log khi không đăng nhập được, không đọc được thư hoặc gửi thư thất bại.
10. Viết hướng dẫn cài đặt, sử dụng và xử lý lỗi cơ bản.
11. Tổng hợp ảnh chụp màn hình, kết quả kiểm thử và nội dung demo.
12. Phối hợp với các thành viên để tích hợp các phần vào hệ thống hoàn chỉnh.

**Thư mục phụ trách chính:** `roundcube/`, `docs/`.

**Sản phẩm bàn giao:**

* Hướng dẫn cài đặt và cấu hình Roundcube.
* File cấu hình mẫu không chứa bí mật.
* Hướng dẫn truy cập webmail.
* Bảng kiểm thử và ảnh chụp kết quả.
* Kịch bản demo toàn bộ hệ thống.

**Lưu ý:** TV4 không tự giả định Postfix và Dovecot đã hoạt động. Nếu các dịch vụ chưa sẵn sàng, cần ghi rõ phần phụ thuộc và phối hợp với TV2, TV3 để kiểm thử tích hợp.

## 7. Cấu trúc repository

```text
enterprise-mail-server/
├── README.md
├── .gitignore
├── scripts/
│   └── README.md
├── postfix/
│   ├── README.md
│   └── main.cf.example
├── dovecot/
│   ├── README.md
│   └── dovecot.conf.example
├── roundcube/
│   ├── README.md
│   └── config.inc.php.example
├── dns/
│   └── README.md
├── firewall/
│   └── README.md
└── docs/
    ├── SERVER_SETUP.md
    ├── DEPLOYMENT.md
    └── TESTING.md
```

Đây là cấu trúc đề xuất. Nếu repository hiện tại chưa có các file được liệt kê, thành viên phụ trách tạo chúng khi bắt đầu công việc; không tạo file trùng nếu đã có file tương đương.

### Quy tắc tổ chức file

* `scripts/`: script hỗ trợ cài đặt và kiểm tra hệ thống.
* `postfix/`: cấu hình mẫu và hướng dẫn Postfix.
* `dovecot/`: cấu hình mẫu và hướng dẫn Dovecot.
* `roundcube/`: cấu hình mẫu và hướng dẫn Roundcube.
* `dns/`: tài liệu phân giải tên miền nội bộ.
* `firewall/`: quy tắc firewall và hướng dẫn kiểm tra.
* `docs/`: tài liệu tổng thể, triển khai và kiểm thử.

Không tự ý sửa file cấu hình hệ thống đang chạy trên Ubuntu chỉ bằng cách thay đổi file mẫu trong repository. Phải kiểm tra nội dung, sao lưu cấu hình hiện tại và thử nghiệm trước khi áp dụng.

## 8. Quy tắc làm việc với GitHub

### 8.1. Quy ước nhánh

| Nhánh                       | Người phụ trách                                  |
| --------------------------- | ------------------------------------------------ |
| `main`                      | Nhánh chính chứa phiên bản đã được nhóm kiểm tra |
| `feature/server-setup`      | TV1                                              |
| `feature/postfix-smtp`      | TV2                                              |
| `feature/dovecot-imap`      | TV3                                              |
| `feature/roundcube-webmail` | TV4                                              |

Mỗi thành viên chỉ làm việc trên nhánh được phân công. Không commit trực tiếp lên `main`.

### 8.2. Clone repository

Mỗi thành viên thực hiện một lần trên máy của mình:

```bash
git clone https://github.com/qthang200606/enterprise-mail-server.git
cd enterprise-mail-server
```

### 8.3. Tạo nhánh cá nhân

Ví dụ TV4 tạo nhánh lần đầu:

```bash
git switch main
git pull origin main
git switch -c feature/roundcube-webmail
git push -u origin feature/roundcube-webmail
```

Nếu nhánh đã tồn tại trên GitHub, dùng:

```bash
git fetch origin
git switch --track origin/feature/roundcube-webmail
```

Thay tên nhánh tương ứng với nhiệm vụ của từng thành viên.

### 8.4. Commit và push

Trước khi commit, kiểm tra thay đổi:

```bash
git status
git diff
```

Chỉ thêm những file cần thiết. Ví dụ TV4:

```bash
git add roundcube/ docs/
git commit -m "Document Roundcube webmail setup"
git push
```

Các thành viên khác thay đường dẫn và nội dung commit theo công việc thực tế.

Không dùng `git add .` một cách máy móc khi chưa kiểm tra file mới hoặc file nhạy cảm.

### 8.5. Tạo Pull Request

Sau khi push:

1. Mở repository trên GitHub.
2. Chọn **Pull requests** → **New pull request**.
3. Chọn `main` làm nhánh đích và nhánh cá nhân làm nhánh nguồn.
4. Mô tả những gì đã thay đổi và cách kiểm thử.
5. Nhóm trưởng kiểm tra code, cấu hình và tài liệu.
6. Chỉ merge sau khi thay đổi được chấp nhận.

### 8.6. Cập nhật nhánh sau khi main thay đổi

Trước khi bắt đầu phần việc tiếp theo, thành viên nên cập nhật `main` và tích hợp thay đổi vào nhánh cá nhân theo quy trình nhóm thống nhất.

Không force-push hoặc ghi đè lịch sử nhánh của thành viên khác nếu chưa trao đổi với nhóm.

### 8.7. Bảo mật repository

* Không commit mật khẩu, token, private key hoặc thông tin xác thực.
* Không commit dữ liệu email riêng tư hoặc mailbox thật.
* File cấu hình mẫu chỉ chứa giá trị minh họa và chú thích.
* Kiểm tra `.gitignore` trước khi push.
* Nếu bí mật đã bị commit, cần thu hồi hoặc thay đổi bí mật đó; xóa file khỏi commit mới không nhất thiết loại bỏ nó khỏi lịch sử Git.

## 9. Kế hoạch tích hợp hệ thống

Nhóm thực hiện theo trình tự sau:

### Giai đoạn 1 – Chuẩn bị môi trường

TV1 thiết lập Ubuntu Server, mạng, hostname và firewall. Cả nhóm thống nhất IP server, domain, phương án xác thực và phương án lưu mailbox.

**Điều kiện chuyển bước:** Máy client kết nối được đến server và phân giải được hostname theo phương án đã chọn.

### Giai đoạn 2 – Triển khai Postfix và Dovecot

TV2 cấu hình Postfix; TV3 cấu hình Dovecot. Hai thành viên cần thống nhất domain, định dạng tài khoản, xác thực và nơi lưu mailbox.

**Điều kiện chuyển bước:** Dịch vụ hoạt động, tài khoản có thể xác thực theo cấu hình và nhóm có kết quả kiểm thử gửi/nhận thư phù hợp với phương án đã triển khai.

### Giai đoạn 3 – Triển khai Roundcube

TV4 cài đặt Roundcube, cấu hình kết nối IMAP/SMTP và thiết lập truy cập từ máy client.

**Điều kiện chuyển bước:** Người dùng có thể đăng nhập, đọc thư và gửi thư qua giao diện webmail.

### Giai đoạn 4 – Kiểm thử toàn hệ thống

Cả nhóm kiểm thử tích hợp, ghi nhận lỗi và cập nhật tài liệu. TV4 tổng hợp kết quả để chuẩn bị demo; các thành viên chịu trách nhiệm giải thích phần kỹ thuật của mình.

## 10. Tiêu chí kiểm thử và nghiệm thu

| Mã   | Nội dung kiểm thử                   | Kết quả mong đợi                                         |
| ---- | ----------------------------------- | -------------------------------------------------------- |
| TC01 | Kiểm tra hostname và IP server      | Thông tin đúng với cấu hình nhóm                         |
| TC02 | Truy cập hostname webmail từ client | Trình duyệt kết nối được đến Roundcube                   |
| TC03 | Kiểm tra trạng thái Postfix         | Dịch vụ hoạt động và không có lỗi cấu hình nghiêm trọng  |
| TC04 | Kiểm tra trạng thái Dovecot         | Dịch vụ hoạt động và có thể xử lý xác thực theo cấu hình |
| TC05 | Đăng nhập Roundcube                 | Tài khoản hợp lệ đăng nhập được                          |
| TC06 | Đăng nhập bằng thông tin sai        | Hệ thống từ chối truy cập                                |
| TC07 | Gửi email giữa hai tài khoản nội bộ | Email được chuyển đến người nhận                         |
| TC08 | Đọc email trong mailbox             | Người nhận xem được nội dung thư                         |
| TC09 | Kiểm tra log khi xảy ra lỗi         | Xác định được dịch vụ và thông báo lỗi liên quan         |
| TC10 | Khởi động lại máy chủ               | Các dịch vụ cần thiết khởi động lại theo cấu hình        |

Mỗi trường hợp kiểm thử cần ghi lại ngày thực hiện, môi trường, thao tác, kết quả thực tế và ảnh chụp hoặc log minh chứng.

Không đánh dấu một trường hợp là thành công nếu nhóm chưa thực sự chạy thử.

## 11. Tài liệu và minh chứng cần bàn giao

Mỗi thành viên phải bàn giao:

* Hướng dẫn cài đặt và cấu hình phần mình phụ trách.
* Các file cấu hình mẫu đã được chú thích.
* Những lệnh dùng để kiểm tra dịch vụ.
* Các lỗi đã gặp và cách xử lý.
* Kết quả kiểm thử thực tế.
* Ảnh chụp màn hình hoặc log phù hợp để đưa vào báo cáo.

Nhóm trưởng tổng hợp các tài liệu vào `docs/`, kiểm tra tính nhất quán và chuẩn bị kịch bản demo.

## 12. Nguyên tắc triển khai an toàn

* Kiểm tra phiên bản Ubuntu và package trước khi áp dụng hướng dẫn.
* Sao lưu file cấu hình trước khi chỉnh sửa.
* Chỉ mở các cổng mạng cần thiết cho hệ thống.
* Không cho phép truy cập trái phép từ mạng ngoài.
* Không tắt các cơ chế bảo mật chỉ để làm cho demo chạy được.
* Kiểm tra quyền đọc/ghi đối với mailbox và file cấu hình.
* Chỉ dùng dữ liệu và tài khoản thử nghiệm.
* Ghi lại thay đổi cấu hình để có thể khôi phục khi xảy ra lỗi.

## 13. Trạng thái thực hiện

Các dịch vụ, tài khoản và chức năng trong README là mục tiêu triển khai của đồ án, không phải xác nhận rằng hệ thống đã hoàn thành.

Nhóm chỉ cập nhật trạng thái hoàn thành sau khi đã cấu hình và kiểm thử thành công trên môi trường thực tế.

**Repository:** https://github.com/qthang200606/enterprise-mail-server
