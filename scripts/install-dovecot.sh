#!/bin/bash
# TODO: TV3 bổ sung script cài đặt và cấu hình Dovecot.
set -e
sudo apt update
sudo apt install -y dovecot-imapd dovecot-pop3d
