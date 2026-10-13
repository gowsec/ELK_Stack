#!/bin/bash
# ==============================================================================
# Script Name: normal_traffic.sh
# Author     : Đỗ Quỳnh
# Description: Kịch bản giả lập lượng khách truy cập bình thường vào hệ thống.
#              Sinh ra các HTTP log với mã trạng thái chủ yếu 200 OK.
#              Sử dụng dải IP tài liệu chuẩn: 198.51.100.x.
# Usage      : ./normal_traffic.sh [số_lượng_request] (Mặc định: 20)
# ==============================================================================

COUNT=${1:-20} 
echo "Bắt đầu giả lập $COUNT khách bình thường..."

for i in $(seq 1 $COUNT); do
    IP="198.51.100.$((RANDOM % 254 + 1))"
    
    # Trộn URL: Tỷ lệ lớn vào "/" để nhận HTTP 200, thỉnh thoảng sinh "/demo2-*"
    PATHS=("/")
    # Thêm 3 lần "/" và 1 lần "/demo2-" để tỷ lệ 200 chiếm 75%
    PATHS+=("/") 
    PATHS+=("/")
    PATHS+=("/demo2-$RANDOM")
    
    REQ_PATH=${PATHS[$RANDOM % ${#PATHS[@]}]}
    URL="http://localhost$REQ_PATH"
    
    curl -s -o /dev/null -w "[Normal] IP: $IP | URL: $REQ_PATH | Status: %{http_code}\n" -H "X-Forwarded-For: $IP" "$URL"
    
    sleep $(awk -v min=0.5 -v max=1.5 'BEGIN{srand(); print min+rand()*(max-min)}')
done

echo "Hoàn tất tạo traffic bình thường!"