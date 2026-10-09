# Kiến trúc hệ thống

```text
Clients
   |
   | HTTP/HTTPS
   v
Roundcube
   |
   +---- IMAP ----> Dovecot ----> Mailbox
   |
   +---- SMTP ----> Postfix ----> Mail delivery
                         |
                         v
                    vkuoffice.test
```

Ubuntu Server là máy chủ trung tâm. Các máy trong cùng mạng truy cập webmail thông qua `mail.vkuoffice.test`.
