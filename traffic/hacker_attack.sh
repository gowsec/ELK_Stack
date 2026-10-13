#!/bin/bash
# ==============================================================================
# Script Name: hacker_attack.sh
# Author     : Đỗ Quỳnh
# Description: Kịch bản giả lập hacker quét lỗ hổng và tấn công server.
# Usage      : ./hacker_attack.sh [Số_lượng_Hacker1] [Số_lượng_Hacker2] [Số_Error500]
# Ví dụ      : ./hacker_attack.sh 40 25 10
# ==============================================================================

# Khởi tạo tham số để không phải sửa code trong vòng lặp (đúng yêu cầu của Lead)
H1_COUNT=${1:-40}
H2_COUNT=${2:-25}
ERR_COUNT=${3:-10}

echo "Bắt đầu giả lập Hacker tấn công..."

# ---------------------------------------------------------
# Hành vi 1: Kẻ tấn công số 1 quét cường độ cao
# ---------------------------------------------------------
echo "--- Kẻ tấn công 1: 203.0.113.50 đang quét ($H1_COUNT requests) ---"
for i in $(seq 1 $H1_COUNT); do
    PATHS=("/admin" "/.env" "/wp-login.php" "/phpmyadmin" "/scan-$RANDOM")
    REQ_PATH=${PATHS[$RANDOM % ${#PATHS[@]}]}
    
    curl -s -o /dev/null -w "[Hacker 1] URL: $REQ_PATH | Status: %{http_code}\n" -H "X-Forwarded-For: 203.0.113.50" -H "User-Agent: scanner-sim" "http://localhost$REQ_PATH"
    sleep 0.2
done

# ---------------------------------------------------------
# Hành vi 2: Kẻ tấn công số 2 quét cường độ thấp
# ---------------------------------------------------------
echo "--- Kẻ tấn công 2: 203.0.113.77 đang quét ($H2_COUNT requests) ---"
for i in $(seq 1 $H2_COUNT); do
    PATHS=("/config.php" "/backup.zip" "/api/users" "/scan-$RANDOM")
    REQ_PATH=${PATHS[$RANDOM % ${#PATHS[@]}]}
    
    curl -s -o /dev/null -w "[Hacker 2] URL: $REQ_PATH | Status: %{http_code}\n" -H "X-Forwarded-For: 203.0.113.77" -H "User-Agent: scanner-sim" "http://localhost$REQ_PATH"
    sleep 0.3
done

# ---------------------------------------------------------
# Hành vi 3: Tấn công gây ngập lụt hệ thống (Lỗi 500)
# ---------------------------------------------------------
echo "--- Tấn công gây lỗi Server 500 ($ERR_COUNT requests) ---"
for i in $(seq 1 $ERR_COUNT); do
    IP="192.0.2.$((RANDOM % 254 + 1))"
    curl -s -o /dev/null -w "[Error 500] IP: $IP | URL: /error | Status: %{http_code}\n" -H "X-Forwarded-For: $IP" "http://localhost/error"
    sleep 0.5
done

echo "Hoàn tất kịch bản hacker!"