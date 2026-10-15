#!/bin/bash
# ==============================================================================
# Script Name: outage_test.sh
# Author     : Đỗ Quỳnh (Đã cập nhật theo feedback)
# Description: Script bơm traffic chuyên dụng phục vụ quay video Demo 4.
#              URL có tiền tố /outage-test-* để chứng minh cơ chế at-least-once.
# Usage      : bash outage_test.sh [số_lượng_request] [giây_nghỉ]
# Ví dụ      : bash outage_test.sh 50 3.6 (Kéo dài khoảng 3 phút)
# Lưu ý      : Phải chạy bằng `bash` hoặc `./`, không dùng `sh` trên Ubuntu (dash) 
#              để tránh lỗi biến $RANDOM.
# ==============================================================================

# 1. Chuyển thư mục làm việc về nơi chứa script để tránh lỗi đường dẫn tương đối
cd "$(dirname "$0")" || exit 1

COUNT=${1:-50}
DELAY=${2:-0.2}

# 2. Kiểm tra biến đầu vào có phải là số không (Validate số nguyên cho COUNT và số thực cho DELAY)
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || ! [[ "$DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Lỗi: Tham số [số_lượng_request] và [giây_nghỉ] phải là định dạng số."
    exit 1
fi

echo "Bắt đầu bơm $COUNT request kiểm thử chịu lỗi cho Demo 4..."
echo "Độ trễ giữa mỗi request: $DELAY giây."

# 3. Tạo mã của lần chạy ở NGOÀI vòng lặp để gom chung thành 1 danh sách nhất quán
RUN_ID=$(date +%H%M%S)
LOG_FILE="outage_sent_$RUN_ID.txt"

echo "Danh sách URL đã gửi sẽ được lưu vào: $LOG_FILE"

for i in $(seq 1 "$COUNT"); do
    URL="http://localhost/outage-test-$RUN_ID-$i"
    
    # Ghi URL vào danh sách đã gửi (Ghi thêm vào cùng 1 file log của đợt chạy)
    echo "/outage-test-$RUN_ID-$i" >> "$LOG_FILE"
    
    # Dùng IP nội bộ giả lập cho Demo 4
    IP="10.0.0.$((RANDOM % 254 + 1))"
    
    curl -s -o /dev/null -w "[Demo 4] Bắn log: /outage-test-$RUN_ID-$i | Status: %{http_code}\n" -H "X-Forwarded-For: $IP" "$URL"
    
    sleep "$DELAY"
done

echo "Hoàn tất bơm $COUNT request cho Demo 4!"