## Dữ liệu mẫu 
- **Khách thường:** IP dải `198.51.100.x`, URL theo format `/demo2-*`, mã trạng thái chủ yếu `200`.
- **Hacker quét lỗi (User-Agent: scanner-sim):**
  - Kẻ tấn công 1: IP `203.0.113.50` (Tạo ~40 lỗi `404`).
  - Kẻ tấn công 2: IP `203.0.113.77` (Tạo ~25 lỗi `404`).
  - URL bị quét mục tiêu: `/admin`, `/.env`, `/wp-login.php`, `/phpmyadmin`, `/scan-*`.
- **Lỗi hệ thống:** Sinh ra ~10 request tới `/error` (mã `500`), sử dụng dải IP `192.0.2.x`.