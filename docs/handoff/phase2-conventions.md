## Dữ liệu mẫu Giai đoạn 2 

### 1. Phục vụ Demo 2 & 3 (Biểu đồ Kibana)
- **Script sử dụng:** `mix_traffic_demo23.sh`
- **Hiệu ứng tạo ra:** Sinh ra đồng thời ~310 request trong thời gian ngắn (Spike traffic).
- **Đa dạng IP:** Chứa hơn 100+ IP ngẫu nhiên từ dải `198.51.100.x` và `192.0.2.x`.
- **Phân bổ mã lỗi:** Kết hợp song song tỷ lệ mã 200 (Normal), 404 (Hacker quét), và 500 (Lỗi hệ thống).

### 2. Phục vụ Demo 4 (Kiểm tra chịu lỗi và đếm Log)
- **Script sử dụng:** `outage_test.sh`
- **Định dạng URL:** `/outage-test-[stt]-[random_id]` (Đảm bảo Kibana không gộp log trùng lặp).
- **Dải IP sử dụng:** `10.0.0.x`.
- **Cách thức phối hợp:** Khi quay video Demo 4, TV1 sẽ gõ lệnh đếm số dòng (`wc -l`). TV4 sẽ chạy `./outage_test.sh 50` để cộng thêm chính xác 50 dòng log vào hệ thống.