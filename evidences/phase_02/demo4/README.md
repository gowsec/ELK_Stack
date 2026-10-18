# Demo 4 — Minh chứng Kiểm thử Khả năng Chịu lỗi (Fault Tolerance)

> **Kịch bản:** Dừng Elasticsearch trong khi Web Server Nginx vẫn nhận traffic; khởi động lại Elasticsearch và chứng minh cơ chế Registry / Retry của Filebeat giúp thu thập bù dữ liệu đầy đủ 100%, không bị mất bất kỳ bản ghi log nào.

---

## 📑 Bảng mô tả chi tiết ảnh minh chứng (Dùng cho Báo cáo & Slide)

| STT | Tên File | Câu lệnh thực thi | Ý nghĩa & Mô tả đưa vào báo cáo |
|:---:|---|---|---|
| 0 | [`00_ram_usage.png`](./00_ram_usage.png) | `free -h`<br>`cat heap.options` | **Ràng buộc tài nguyên ($\le$ 3GB):** RAM sử dụng thực tế của cả hệ thống là `2.6 GiB` ($\le$ 3GB theo yêu cầu). Giới hạn Java Heap của Elasticsearch ở mức `1GB` (`-Xms1g -Xmx1g`). |
| 1 | [`01_services_active.png`](./01_services_active.png) | `systemctl is-active elasticsearch nginx filebeat kibana` | **Khởi tạo hệ thống:** Cả 4 dịch vụ cốt lõi đều đang ở trạng thái hoạt động bình thường (`active`). |
| 2 | [`02_baseline_nginx_count.png`](./02_baseline_nginx_count.png) | `sudo wc -l /var/log/nginx/access.log` | **Mốc log Nginx ban đầu:** File access log sạch trước khi bắt đầu thử nghiệm sự cố (`0` dòng). |
| 3 | [`03_baseline_es_count.png`](./03_baseline_es_count.png) | `curl -s "localhost:9200/filebeat-*/_count?pretty"` | **Mốc Elasticsearch ban đầu:** Số lượng document hiện có sẵn trong Elasticsearch trước khi thử nghiệm (`527` docs). |
| 4 | [`04_es_inactive.png`](./04_es_inactive.png) | `sudo systemctl stop elasticsearch`<br>`systemctl is-active elasticsearch` | **Giả lập sự cố:** Tắt dịch vụ Elasticsearch, hệ thống xác nhận trạng thái chuyển sang `inactive`. |
| 5 | [`05_filebeat_retry_error.png`](./05_filebeat_retry_error.png) | `sudo journalctl -u filebeat -f` | **Cơ chế chịu lỗi (Fault Tolerance):** Filebeat phát hiện mất kết nối (`connection refused`), không drop log mà giữ lại trong hàng đợi và kích hoạt cơ chế `Exponential Backoff Retry`. |
| 6 | [`06_nginx_logging_during_outage.png`](./06_nginx_logging_during_outage.png) | `sudo tail -n 15 /var/log/nginx/access.log \| grep "/outage-test-"` | **Tính độc lập của Web Server:** Trong khi ES sập, Nginx vẫn tiếp nhận và ghi nhận trọn vẹn 50 request kiểm thử (`/outage-test-...`) vào file log. |
| 7 | [`07_es_recovered_active.png`](./07_es_recovered_active.png) | `sudo systemctl start elasticsearch`<br>`curl -s "localhost:9200/_cluster/health"` | **Khôi phục dịch vụ:** Bật lại Elasticsearch, cluster health đạt trạng thái `green` (khỏe mạnh). |
| 8 | [`08_reconciliation_50_equals_50.png`](./08_reconciliation_50_equals_50.png) | `grep wc -l` & `curl _count` | **Đối chiếu toàn vẹn dữ liệu (Trọng tâm Demo 4):** Số log tại Nginx = **50**, số document tại Elasticsearch = **50** ($50 = 50$). Không thất thoát bất kỳ dòng log nào (At-least-once Delivery). |
| 9 | [`09_kibana_discover_outage_logs.png`](./09_kibana_discover_outage_logs.png) | Kibana Discover UI (`url.original : *outage-test*`) | **Trực quan hóa trên Kibana:** Tìm kiếm thấy đúng `Documents (50)`, các trường thông tin (IP, status code 404, URL) được parse hoàn chỉnh. |

---

## 🎬 Video minh chứng

- File: [`demo4_fault_tolerance.mp4`](./demo4_fault_tolerance.mp4)
- Nội dung: Quay trực tiếp tiến trình chạy script bơm 50 request kiểm thử chịu lỗi (`outage_test.sh`) trong khi Elasticsearch đang tắt. Toàn bộ các mốc kiểm tra và đối chiếu số liệu trước, trong và sau sự cố được lưu trữ chi tiết qua các ảnh chụp màn hình (từ `00` đến `09`) ở bảng trên.