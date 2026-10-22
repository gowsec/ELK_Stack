#!/bin/bash
# ==============================================================================
# Script Name: mix_traffic_demo23.sh
# Author     : Đỗ Quỳnh (Đã cập nhật theo feedback)
# Description: Kịch bản giả lập "Giờ cao điểm" (Spike Traffic) cho Demo 2 & 3.
#              Chia thành nhiều đợt để tạo biểu đồ rải rác trên Kibana.
# Usage      : ./mix_traffic_demo23.sh [số_đợt] [giây_nghỉ_giữa_các_đợt]
# Ví dụ      : ./mix_traffic_demo23.sh 5 60
# ==============================================================================

# 1. Chuyển thư mục làm việc về nơi chứa script để tránh lỗi đường dẫn tương đối
cd "$(dirname "$0")" || exit 1

# 2. Nhận tham số hoặc dùng giá trị mặc định (5 đợt, nghỉ 60s)
ROUNDS=${1:-5}   
PAUSE=${2:-60}   

# 3. Kiểm tra biến đầu vào có phải là số không (Validate)
if ! [[ "$ROUNDS" =~ ^[0-9]+$ ]] || ! [[ "$PAUSE" =~ ^[0-9]+$ ]]; then
    echo "Lỗi: Tham số [số_đợt] và [giây_nghỉ] truyền vào phải là số nguyên."
    exit 1
fi

echo "Đang chạy script trộn lẫn traffic cho Demo 2 & 3..."
echo "Cấu hình: $ROUNDS đợt, nghỉ $PAUSE giây giữa mỗi đợt."

# Cấp quyền chạy cho các script con
chmod +x normal_traffic.sh hacker_attack.sh

# 4. Vòng lặp chia nhỏ traffic thành nhiều đợt
for r in $(seq 1 "$ROUNDS"); do
    echo "--- Đang chạy đợt $r / $ROUNDS ---"
    
    # Tính toán số request mỗi đợt sao cho tổng cộng vẫn bằng mức ban đầu (310)
    # Tổng ban đầu: Normal=150, H1=80, H2=50, Err=30
    NORM_COUNT=$((150 / ROUNDS))
    H1_COUNT=$((80 / ROUNDS))
    H2_COUNT=$((50 / ROUNDS))
    ERR_COUNT=$((30 / ROUNDS))

    # Gọi script Normal và Hacker chạy ngầm song song (&)
    ./normal_traffic.sh "$NORM_COUNT" &
    ./hacker_attack.sh "$H1_COUNT" "$H2_COUNT" "$ERR_COUNT" &
    
    # Lệnh wait giúp terminal chờ cả 2 tiến trình ngầm của đợt này chạy xong
    wait
    
    # Nếu chưa phải đợt cuối thì tạm nghỉ để Kibana tách cột thời gian
    if [ "$r" -lt "$ROUNDS" ]; then
        echo "Đã xong đợt $r. Tạm nghỉ $PAUSE giây..."
        sleep "$PAUSE"
    fi
done

echo "Đã hoàn tất rải dữ liệu. Có thể refresh Kibana để xem biểu đồ!"