# Bàn giao Task 2: Luồng dữ liệu (Nginx + Filebeat)

Kết nối VM, SSH và quy tắc snapshot xem thêm [../gd1_task1/HANDOFF.md](../gd1_task1/HANDOFF.md).

## 1. Trạng thái hiện tại

| Mục | Giá trị |
|---|---|
| Nginx | 1.18.0 (Ubuntu), cổng 80, từ máy bạn: `http://127.0.0.1:8080` |
| Filebeat | 8.19.22 (bằng phiên bản Elasticsearch), tự chạy khi boot |
| Module Filebeat | `nginx` (access + error), đọc `/var/log/nginx/access.log*` và `error.log*` |
| Output Filebeat | `http://localhost:9200` (không xác thực), `number_of_replicas: 0` |
| Index | data stream `filebeat-8.19.22`, cluster `green` |
| Snapshot sạch | `TODO: tên snapshot, ví dụ s3-gd1-task2-done` |
| File VM để nhập (`.ova`) | `TODO: link Drive của bản mới` |

**Dùng file `.ova` mới này**, không dùng bản của Task 1, vì bản cũ chưa có Nginx và Filebeat. Sau khi nhập, kiểm tra Port Forwarding có đủ 3 dòng: 2222→22, 8080→80, 5601→5601 (thiếu thì thêm lại).

## 2. Dành cho TV3 (Kibana)

- Tạo Data View với pattern **`filebeat-*`**, time field `@timestamp`.
- Tên field là chuẩn ECS, không trùng tên trong đề:

| Tên trong đề | Tên thực tế trong index |
|---|---|
| `client_ip` | `source.ip` |
| `status_code` | `http.response.status_code` |
| `request_url` | `url.original` |

- Index đang có sẵn dữ liệu thử nghiệm (request tới `/admin`, `/wp-login.php`, `/error`, `/khong-ton-tai`, `/outage-N`). Cần lọc hoặc xóa trước khi quay demo thật nếu muốn biểu đồ sạch. Việc xóa do cả nhóm thống nhất vì Elasticsearch thuộc Task 1.
- RAM: available khoảng 1121 MB khi chưa có Kibana. Filebeat dùng khoảng 122 MB. Nên giới hạn heap Node của Kibana (ví dụ `--max-old-space-size=512`) để không tràn.

## 3. Dành cho TV4 (kiểm thử)

- `GET /error` luôn trả **500**. URL không tồn tại trả **404**.
- Giả IP client bằng header `X-Forwarded-For` (Nginx đã bật `realip` nên IP này hiện trong log và Kibana):
  ```bash
  curl -H "X-Forwarded-For: 203.0.113.50" http://localhost/admin
  ```
- Từ máy thật, gọi qua cổng đã chuyển tiếp: `http://127.0.0.1:8080/error`. Khi test từ máy thật thì IP client trong log là IP của NAT, muốn có IP khác nhau phải thêm header `X-Forwarded-For`.

## 4. Kiểm tra nhanh

```bash
sudo systemctl status nginx filebeat --no-pager
curl -s 'localhost:9200/_cat/indices?v'
sudo tail -n 5 /var/log/nginx/access.log
```
Cả hai dịch vụ phải `active (running)`, index `green`, và `access.log` có dòng mới sau mỗi `curl`.

## 5. Lưu ý

- Sau khi bật VM, `unattended-upgrades` có thể giữ khóa `apt` vài phút (báo `Could not get lock`). Cứ chờ, không xóa file khóa.
- File cấu hình Nginx và Filebeat nằm trong thư mục `config/`, kèm bảng đường dẫn trên VM ở [config/README.md](../../config/README.md). Dùng nó nếu phải dựng lại.
- `realip` trong cấu hình chỉ phục vụ demo (tin header `X-Forwarded-For` từ `127.0.0.1` và `10.0.2.0/24`). Không dùng nguyên cấu hình này ngoài môi trường thử nghiệm.