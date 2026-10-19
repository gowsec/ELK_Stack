# Demo 4 — Minh chứng Kiểm thử Khả năng Chịu lỗi (Fault Tolerance)

> **Kịch bản:** Dừng Elasticsearch trong khi Web Server Nginx vẫn nhận traffic; khởi động lại Elasticsearch và chứng minh cơ chế Registry / Retry của Filebeat giúp thu thập bù dữ liệu đầy đủ 100%, không bị mất bất kỳ bản ghi log nào.

---

## 0. Kiểm tra Ràng buộc Tài nguyên Hệ thống ($\le$ 3GB RAM)

* **Thao tác:** Kiểm tra mức RAM đang sử dụng (`free -h`) và file cấu hình Java Heap của Elasticsearch.
* **Mô tả:** Hệ thống tiêu thụ `2.6 GiB` ($\le$ 3GB theo yêu cầu). Giới hạn Heap của Elasticsearch ở mức `1GB` (`-Xms1g -Xmx1g`).

![00_ram_usage](./00_ram_usage.png)

---

## Bước 1. Khởi tạo & Lấy mốc ban đầu (Baseline)

* **Thao tác:** Kiểm tra 4 dịch vụ (`active`), đếm số dòng log Nginx và số document Elasticsearch trước khi thử nghiệm.

![01_services_active](./01_services_active.png)

* File log Nginx ban đầu sạch (`0` dòng):

![02_baseline_nginx_count](./02_baseline_nginx_count.png)

* Elasticsearch hiện có sẵn `527` documents (tích lũy từ các phase trước):

![03_baseline_es_count](./03_baseline_es_count.png)

---

## Bước 2. Giả lập sự cố Elasticsearch (Outage)

* **Thao tác:** Tắt dịch vụ Elasticsearch (`systemctl stop elasticsearch`). Hệ thống xác nhận trạng thái `inactive`.

![04_es_inactive](./04_es_inactive.png)

---

## Bước 3. Bơm Traffic kiểm thử & Quan sát chịu lỗi

* **Thao tác:** Chạy `outage_test.sh` bơm 50 request kiểm thử (`/outage-test-*`) trong khi Elasticsearch đang tắt.
* **Video quá trình chạy script:** [`demo4_fault_tolerance.mp4`](./demo4_fault_tolerance.mp4)

* Filebeat phát hiện mất kết nối (`connection refused`), lưu log vào hàng đợi và kích hoạt cơ chế `Exponential Backoff Retry`:

![05_filebeat_retry_error](./05_filebeat_retry_error.png)

* Web Server Nginx vẫn hoạt động độc lập và ghi nhận đủ 50 log `/outage-test-...` (mã 404):

![06_nginx_logging_during_outage](./06_nginx_logging_during_outage.png)

---

## Bước 4. Khôi phục dịch vụ Elasticsearch (Recovery)

* **Thao tác:** Bật lại Elasticsearch (`systemctl start elasticsearch`). Cụm phục hồi `active` và cluster health đạt `green`. Filebeat tự động đọc theo Registry offset và đẩy bù toàn bộ log tồn đọng.

![07_es_recovered_active](./07_es_recovered_active.png)

---

## Bước 5. Đối chiếu Toàn vẹn Dữ liệu & Trực quan hóa (Reconciliation)

* **Thao tác:** So sánh số log tại Nginx và số document tại Elasticsearch, sau đó kiểm tra trên Kibana Discover.

* **Đối chiếu số lượng:** Số log Nginx = **50**, số doc Elasticsearch = **50** ($50 = 50$). Đạt tỷ lệ 50/50 (**Zero Data Loss** — At-least-once Delivery thành công 100%):

![08_reconciliation_50_equals_50](./08_reconciliation_50_equals_50.png)

* **Giao diện Kibana Discover:** Tìm kiếm `url.original : *outage-test*` hiển thị chính xác `Documents (50)`, các trường (IP, status 404, URL) được parse đầy đủ:

![09_kibana_discover_outage_logs](./09_kibana_discover_outage_logs.png)