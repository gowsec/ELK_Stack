# Dữ liệu mẫu Giai đoạn 2

## 1. Cách chạy chung
- **Môi trường:** Chạy trực tiếp trên máy ảo (VM), ngay trong thư mục chứa các script.
- **Lệnh chạy:** Dùng `bash <tên_script>` hoặc `./<tên_script>` (Tuyệt đối không dùng `sh`).
- **Yêu cầu kỹ thuật:** Các script sử dụng header `X-Forwarded-For` để giả lập IP, do đó thao tác này chỉ có tác dụng khi chạy trực tiếp trong nội bộ VM.
- **Thứ tự thực hiện:** Chạy Demo 2 & 3 trước. Sau khi chụp ảnh/quay phim xong dashboard mới chuyển sang chạy Demo 4.

---

## 2. Phục vụ Demo 2 & 3 (Biểu đồ Kibana)
> Các con số cụ thể để đối chiếu kết quả truy vấn

- **Script sử dụng:** `mix_traffic_demo23.sh`
- **Hiệu ứng tạo ra:** Sinh ra đồng thời **310 request** (Spike traffic), trộn lẫn các request hợp lệ, request quét lỗi và request gây sập hệ thống.

**Chi tiết thông số dữ liệu được rải:**

| Thông tin cần có | Giá trị cụ thể |
|---|---|
| **Tổng số request** | 310 request |
| **IP khách thường** | `198.51.100.1` đến `198.51.100.254`, chọn ngẫu nhiên cho mỗi request; tổng 150 request |
| **Attacker 1 (Top 1)** | IP giả lập `203.0.113.50`; 80 request; quét cường độ cao; nghỉ 0,2 giây giữa các request |
| **Attacker 2 (Top 2)** | IP giả lập `203.0.113.77`; 50 request; quét cường độ thấp; nghỉ 0,3 giây giữa các request |
| **Danh sách URL bị quét** | `/admin`, `/.env`, `/wp-login.php`, `/phpmyadmin`, `/config.php`, `/backup.zip`, `/api/users`, `/scan-<random>` |
| **Mã 500** | 30 request tới `/error`; IP ngẫu nhiên thuộc `192.0.2.1` đến `192.0.2.254`; nghỉ 0,5 giây giữa các request |
| **Tỉ lệ 200 / 404 / 500** | Khoảng 33.55% (Mã 200) / 56.77% (Mã 404) / 9.68% (Mã 500) |
| **Thời gian rải dữ liệu** | Chạy ngầm và hoàn thành trong thời gian ngắn (7 phút) |

---

## 3. Phục vụ Demo 4 (Kiểm tra chịu lỗi và đếm Log)
- **Script sử dụng:** `outage_test.sh <số request> <giây nghỉ>`
- **Định dạng URL:** `/outage-test-<RUN_ID>-<stt>` (Chuỗi URL duy nhất giúp kiểm tra chính xác từng request có đến được Elasticsearch không và phát hiện các dòng bị gửi trùng).
- **Dải IP sử dụng:** `10.0.0.x` (Giả lập IP nội bộ).

**Cách thức phối hợp và thực hiện quay video Demo 4:**
1. **Thời điểm chạy:** Demo 4 phải chạy **SAU** khi đã tắt dịch vụ Elasticsearch.
2. **Kịch bản lệnh:** TV4 sẽ chạy lệnh `./outage_test.sh 50 3.6` (Bơm 50 request với độ trễ 3.6 giây, kéo dài tổng cộng khoảng 3 phút).
3. **Quy tắc phối hợp:** Trong lúc quay Demo 4, **tuyệt đối không thành viên nào khác gửi request tới VM** để tránh làm nhiễu dữ liệu kiểm tra.
4. **Cách đếm log:** TV1 không được dùng lệnh `wc -l` để đếm tổng số dòng trong log (vì bất kỳ `curl` nào từ ngoài vào cũng sẽ làm lệch). Thay vào đó, phải dùng lệnh đếm theo tiền tố `/outage-test-`.

---

## 4. Lưu ý về Data Stream (Cực kỳ quan trọng)
- Toàn bộ dữ liệu từ Demo 2, 3 và 4 đều đổ vào cùng một data stream (ví dụ: `filebeat-8.19.23`). 
- **Vì sao phải tuân thủ thứ tự?** Dữ liệu của Demo 4 chứa các IP `10.0.0.x` và URL `/outage-test-...`. Nếu chạy chung, chúng sẽ làm lẫn lộn và sai lệch bảng xếp hạng "Top IP" cũng như "Top URL" của Demo 2 & 3. 
- Mỗi lần chạy lại script sẽ **cộng thêm (append)** dữ liệu mới, không ghi đè dữ liệu cũ.