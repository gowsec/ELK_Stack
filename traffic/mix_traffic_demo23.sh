#!/bin/bash
# ==============================================================================
# Script Name: mix_traffic_demo23.sh
# Author     : Đỗ Quỳnh
# Description: Kịch bản giả lập "Giờ cao điểm" (Spike Traffic) cho Demo 2 & 3.
#              Chạy ngầm song song cả Normal và Hacker script để tạo ra 
#              hàng trăm IP và trộn lẫn đủ mã 200, 404, 500.
# Usage      : ./mix_traffic_demo23.sh
# ==============================================================================

echo "Đang chạy script trộn lẫn traffic cho Demo 2 & 3..."

# Cấp quyền chạy cho các script con
chmod +x normal_traffic.sh hacker_attack.sh

# Gọi script Normal (sinh ra ~150 IP khác nhau, chủ yếu mã 200) - Chạy nền (&)
./normal_traffic.sh 150 &

# Gọi script Hacker (sinh ra lỗi 404 từ 2 Top Attacker và mã 500) - Chạy nền (&)
./hacker_attack.sh 80 50 30 &

# Lệnh wait giúp terminal chờ cả 2 tiến trình ngầm chạy xong mới kết thúc
wait

echo "Đã trộn xong khối lượng dữ liệu. Có thể refresh Kibana."