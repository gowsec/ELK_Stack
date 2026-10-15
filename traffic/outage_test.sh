#!/bin/bash
# ==============================================================================
# Script Name: outage_test.sh
# Author     : Đỗ Quỳnh 
# Description: Script bơm traffic chuyên dụng phục vụ quay video Demo 4.
#              URL có tiền tố /outage-test-* để dễ dàng query trên Kibana.
# Usage      : ./outage_test.sh [số_lượng_request] (Mặc định: 50)
# ==============================================================================

COUNT=${1:-50}
echo "Bắt đầu bơm $COUNT request kiểm thử chịu lỗi cho Demo 4..."

for i in $(seq 1 $COUNT); do
    # Random chuỗi 5 ký tự để mỗi URL là duy nhất
    UNIQUE_ID=$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
    URL="http://localhost/outage-test-$i-$UNIQUE_ID"
    
    # Dùng IP nội bộ giả lập cho Demo 4
    IP="10.0.0.$((RANDOM % 254 + 1))"
    
    curl -s -o /dev/null -w "[Demo 4] Bắn log: /outage-test-$i-* | Status: %{http_code}\n" -H "X-Forwarded-For: $IP" "$URL"
    
    # Tốc độ bắn vừa phải (0.2s) để TV1 dễ quan sát RAM máy ảo
    sleep 0.2
done

echo "Hoàn tất bơm $COUNT request cho Demo 4!"