# Báo cáo Giai đoạn 1, Task 2: Luồng dữ liệu (Nginx + Filebeat)

- Người thực hiện: Hoàng Diễm Phương
- Ngày hoàn thành: 06/10/2026
- Deadline: 06/10/2026

## 1. Mục tiêu
Cài Nginx làm web server có tính năng giả lập lỗi (trang `/error` trả 500) và nhận diện IP giả, cài Filebeat đọc log Nginx, parse thành các field có cấu trúc và đẩy thẳng vào Elasticsearch của Task 1.

## 2. Cấu hình thực tế

| Hạng mục | Giá trị |
|---|---|
| OS | Ubuntu Server 22.04.5 LTS (amd64) |
| Nginx | 1.18.0 (Ubuntu), cổng 80 |
| Filebeat | 8.19.22 (cùng phiên bản với Elasticsearch 8.19.22) |
| Module | `nginx` (access, error); `ingress_controller` tắt |
| Output | `http://localhost:9200`, không xác thực |
| Index | data stream `filebeat-8.19.22`, 1 shard, `number_of_replicas: 0` |
| Nhận diện IP giả | module `realip`, `real_ip_header X-Forwarded-For`, tin cậy `127.0.0.1` và `10.0.2.0/24` |

## 3. Các bước đã thực hiện
1. Nhập `.ova` của Task 1, kiểm tra Elasticsearch chạy (`curl localhost:9200`: cluster `elk-demo`, v8.19.22).
2. Cài Nginx, kiểm tra trang mặc định qua `http://localhost:8080`. (ảnh `01-nginx-running.png`)
3. Thêm `location = /error { return 500; }` và `realip.conf`, kiểm tra `nginx -t`. Test: `/error` trả 500, URL lạ trả 404, IP giả hiện đúng ở đầu dòng `access.log`. (ảnh `02-error-500-and-fake-ip.png`)
4. Cài Filebeat 8.19.22 từ repo Elastic 8.x, bật module `nginx`, trỏ output vào Elasticsearch, nạp Ingest Pipeline và index template.
5. Kiểm tra log vào Elasticsearch và đã được parse thành field riêng. (ảnh `03-filebeat-parsed-fields.png`)

## 4. Kết quả nghiệm thu

| Tiêu chí | Kết quả | Đạt |
|---|---|---|
| Nginx chạy, trả 200 ở `/` | HTTP 200 OK | ☑ |
| `/error` trả 500, URL lạ trả 404 | 500 / 404 | ☑ |
| Nhận diện IP giả | `203.0.113.50`, `198.51.100.7` hiện ở đầu dòng log | ☑ |
| Filebeat cùng phiên bản Elasticsearch | 8.19.22 | ☑ |
| Log được parse thành field | `source.ip`, `url.original`, `http.response.status_code` | ☑ |
| Index health | green | ☑ |

### Ánh xạ tên field (đề → thực tế)

Filebeat nginx module dùng chuẩn ECS nên tên field khác với tên trong đề:

| Tên trong đề | Tên thực tế |
|---|---|
| `client_ip` | `source.ip` |
| `status_code` | `http.response.status_code` |
| `request_url` | `url.original` |

### Mẫu một document đã parse

```json
{
  "source": { "address": "198.51.100.7", "ip": "198.51.100.7" },
  "url": { "path": "/wp-login.php", "extension": "php", "original": "/wp-login.php" },
  "http": {
    "request": { "method": "GET" },
    "response": { "status_code": 404, "body": { "bytes": 162 } },
    "version": "1.1"
  }
}
```

## 5. Số liệu RAM sau khi thêm Nginx và Filebeat

Đo lúc hệ thống rảnh bằng `free -m` và `ps -eo rss,comm --sort=-rss`.

| Chỉ số | Giá trị |
|---|---|
| RAM nhận diện | 2968 MB |
| Used / Available | 1669 / 1121 MB |
| Swap (tổng / đang dùng) | 1753 / 4 MB |
| RSS: Elasticsearch | ≈ 1424 MB |
| RSS: Filebeat | ≈ 122 MB |
| RSS: Nginx | TODO: đo bằng `ps -C nginx -o rss= \| awk '{s+=$1} END {printf "%.1f MB\n", s/1024}'` |

**Nhận xét:**
- Cột `free` chỉ còn khoảng 87 MB vì Linux dùng RAM rảnh làm cache (`buff/cache` 1211 MB), phần này được trả lại khi cần. Chỉ số đáng xem là `available` = **1121 MB**.
- Filebeat tốn khoảng 122 MB, cao hơn mức 50 đến 100 MB ước tính ban đầu. Phần RAM còn lại (1121 MB) vẫn đủ cho Kibana (dự kiến 500 đến 700 MB) nhưng không dư nhiều, cần lưu ý khi cài Kibana.
- Swap đang dùng chỉ 4 MB, không có dấu hiệu thiếu RAM.

## 6. Khó khăn & cách xử lý
- **`apt` bị giữ khóa khi cài Filebeat:** `unattended-upgrades` tự chạy ngay sau khi VM boot và giữ `/var/lib/dpkg/lock-frontend`. Đã chờ tiến trình kết thúc thay vì xóa file khóa, để tránh hỏng cơ sở dữ liệu gói.
- **`filebeat setup --modules nginx` báo "no enabled filesets":** cờ `--modules` bỏ qua `modules.d/nginx.yml`. Đã bổ sung `-M "nginx.access.enabled=true" -M "nginx.error.enabled=true"`.
- **Index có nguy cơ ở trạng thái yellow:** cluster chỉ có 1 node nên replica không có chỗ đặt. Đã đặt `index.number_of_replicas: 0` trong `filebeat.yml`.
- **Tên field khác đề:** đã lập bảng ánh xạ ở mục 4 để các thành viên khác và phần trình bày dùng đúng tên.

## 7. Bàn giao cho các Tasks tiếp theo
Xem [HANDOFF.md](HANDOFF.md).