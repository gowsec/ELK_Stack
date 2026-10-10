# Nginx và Filebeat trên VM Azure

---

## 1. Trạng thái hiện tại

| Mục | Giá trị | Tình trạng |
|---|---|---|
| Hệ điều hành | Ubuntu 24.04 LTS, 2 vCPU, ~3.8 GiB RAM, đĩa 30 GB | Đã xác nhận |
| Elasticsearch | 8.19.23, nghe `127.0.0.1:9200`, không xác thực | Đã xác nhận |
| Filebeat | 8.19.23 (cùng phiên bản Elasticsearch) | Đã xác nhận |
| Nginx | Cài từ kho Ubuntu 24.04 (xem `nginx -v`), cổng 80 | Đã xác nhận chạy, trả 404 đúng |
| Kho APT của Elastic | `https://artifacts.elastic.co/packages/8.x/apt` | Đã xác nhận |
| Index template | Đã nạp, `number_of_replicas: 0` | Đã xác nhận |
| Ingest Pipeline | `filebeat-8.19.23-nginx-access-pipeline` và `...-error-pipeline` | Đã xác nhận có trong Elasticsearch |
| Snapshot | `s1-es-ok` | Đã có |
| Snapshot | `s2-nginx-filebeat-ok` | Đã có |
| Endpoint `/error` | Trả về HTTP 500 | Đã xác nhận |
| IP giả (`X-Forwarded-For`) | Hiển thị đúng trong log sau khi sửa lỗi `::1` | Đã xác nhận |
| Trạng thái Elasticsearch | `active (running)` | Đã xác nhận |
| Trạng thái Filebeat | `active (running)` | Đã xác nhận |
| Trạng thái Nginx | `active (running)` | Đã xác nhận |
| Dữ liệu log | Đã vào Elasticsearch và được parse thành các field như `source.ip`, `http.response.status_code`, `url.path` | Đã xác nhận |

---

## 2. File cấu hình và vị trí trên VM

| File trong repo | Đặt trên VM tại | Vai trò |
|---|---|---|
| `default.txt` | `/etc/nginx/sites-available/default` | Site Nginx, có `location = /error { return 500; }` |
| `realip.conf` | `/etc/nginx/conf.d/realip.conf` | Ghi IP từ header `X-Forwarded-For` vào log |
| `filebeat.yml` | `/etc/filebeat/filebeat.yml` | Cấu hình chung, gửi thẳng vào Elasticsearch, `replicas: 0` |
| `nginx.yml` | `/etc/filebeat/modules.d/nginx.yml` | Bật module Nginx (access và error) |

---

## 3. Các bước đã cài và đã hoàn tất (không cần cài lại)

Chạy trên VM. Trước hết đưa 4 file cấu hình lên `~/cfg/` (bằng `scp` hoặc `git clone`), rồi xử lý ký tự xuống dòng kiểu Windows:

```bash
sed -i 's/\r$//' ~/cfg/*
```

### 3.1. Nginx

```bash
sudo apt-get update
sudo apt-get install -y nginx
nginx -v

sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
sudo cp ~/cfg/default.txt /etc/nginx/sites-available/default

sudo nginx -t                         # phải báo syntax is ok, test is successful
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```


### 3.2. Filebeat

Kho APT trên VM đã là `8.x` nên chỉ cần:

```bash
apt-cache policy filebeat | head -n 4     # Candidate phải là 8.19.23
sudo apt-get install -y filebeat
filebeat version                          # phải ra 8.19.23
sudo apt-mark hold elasticsearch filebeat # khóa phiên bản, tránh bị nâng lệch
```

**Filebeat phải cùng phiên bản với Elasticsearch.** (Filebeat mới hơn Elasticsearch là không được hỗ trợ)

Chép cấu hình và đặt quyền (Filebeat từ chối chạy nếu file không thuộc root hoặc người khác ghi được):

```bash
sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
sudo cp ~/cfg/filebeat.yml /etc/filebeat/filebeat.yml
sudo cp ~/cfg/nginx.yml /etc/filebeat/modules.d/nginx.yml
sudo chown root:root /etc/filebeat/filebeat.yml /etc/filebeat/modules.d/nginx.yml
sudo chmod 600 /etc/filebeat/filebeat.yml
sudo chmod 644 /etc/filebeat/modules.d/nginx.yml

sudo filebeat test config        # Config OK
sudo filebeat modules list       # nginx phải nằm trong mục Enabled
sudo filebeat test output        # talk to server... OK, version: 8.19.23
```

Dòng `TLS... WARN secure connection disabled` là cảnh báo bình thường, vì cấu hình dùng `http://` (đã tắt X-Pack Security theo đề bài).

### 3.3. Nạp template và pipeline TRƯỚC khi bật Filebeat

```bash
sudo filebeat setup --index-management
sudo filebeat setup --pipelines
```

Nếu dùng `setup --pipelines --modules nginx` mà báo `module nginx is configured but has no enabled filesets`, thì bỏ `--modules nginx` (như trên), hoặc bật tường minh:

```bash
sudo filebeat setup --pipelines --modules nginx -M "nginx.access.enabled=true" -M "nginx.error.enabled=true"
```

Kiểm tra pipeline đã có trong Elasticsearch:

```bash
curl -s "localhost:9200/_ingest/pipeline/filebeat-*nginx*?filter_path=*.description"
```

Phải thấy hai pipeline `...-nginx-access-pipeline` và `...-nginx-error-pipeline`.

### 3.4. Bật Filebeat

```bash
sudo systemctl enable --now filebeat
sudo systemctl status filebeat --no-pager
```

Nạp pipeline xong rồi mới bật Filebeat để dòng log đầu tiên đã được parse. Nếu lỡ bật trước, một số dòng đầu có thể vào index mà chưa được parse.

---

## 4. Nghiệm thu (chạy xong chụp snapshot `s2`)

```bash
# Ba dịch vụ
for s in elasticsearch filebeat nginx; do echo "$s: $(systemctl is-active $s)"; done

# Sinh traffic thử
for i in $(seq 1 10); do curl -s -o /dev/null http://localhost/; done
curl -s -o /dev/null -w "/error: %{http_code}\n" http://localhost/error
curl -s -o /dev/null -H "X-Forwarded-For: 203.0.113.50" http://localhost/admin
curl -s -o /dev/null -H "X-Forwarded-For: 198.51.100.7" http://localhost/.env
curl -s -o /dev/null -H "X-Forwarded-For: 192.0.2.99" http://localhost/wp-login.php
sudo tail -n 4 /var/log/nginx/access.log
sleep 30

# Dữ liệu trong Elasticsearch
curl -s "localhost:9200/_cluster/health?pretty" | grep status
curl -s "localhost:9200/filebeat-*/_count?q=event.dataset:nginx.access&pretty"
curl -s "localhost:9200/filebeat-*/_search?size=1&sort=@timestamp:desc&pretty&filter_path=hits.hits._source.source,hits.hits._source.http,hits.hits._source.url"
```

### Checklist đạt

- [x] `nginx`, `filebeat`, `elasticsearch` đều `active`
- [x] `/error` trả `500`
- [x] 3 dòng log cuối bắt đầu bằng `203.0.113.50`, `198.51.100.7`, `192.0.2.99` (không phải `::1`)
- [x] Cluster `green`
- [x] `_count` lớn hơn 0
- [x] Document có `source.ip`, `http.response.status_code`, `url.original`


---

## 5. Lỗi đã gặp và cách xử lý

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Log toàn `::1`, header `X-Forwarded-For` bị bỏ qua | `realip.conf` thiếu `set_real_ip_from ::1;` | Thêm dòng đó, `sudo nginx -t`, `sudo systemctl reload nginx` |
| `setup --pipelines --modules nginx` báo `has no enabled filesets` | Truyền `--modules` làm Filebeat bỏ qua phần bật trong `nginx.yml` | Chạy `setup --pipelines` không có `--modules`, hoặc thêm `-M "nginx.access.enabled=true"` |
| Cảnh báo `Overwriting lifecycle policy is disabled` | Chỉ là thông báo | Bỏ qua, nếu sau đó có dòng `Index setup finished.` |
| `TLS... WARN secure connection disabled` | Đã tắt X-Pack Security theo đề | Bỏ qua |
| `Could not get lock` khi `apt install` | Hệ thống đang tự cập nhật | Chờ vài phút rồi chạy lại |
| Script `.sh` báo `bad interpreter ^M` | File có xuống dòng kiểu Windows | `sed -i 's/\r$//' tên_file` |

---

## 6. Lời nhắn cho Lê Duy Tài (Kibana)

**Việc cần làm:** cài Kibana, kết nối với Elasticsearch, học cách tìm kiếm và lọc lỗi.
> Chỉ mang tích chất tham khảo

**Cài đặt, bốn điều quan trọng:**

1. **Cài đúng bản 8.19.23**, trùng Elasticsearch (Kibana khác phiên bản sẽ từ chối kết nối):
   ```bash
   apt-cache policy kibana | head -n 4
   sudo apt-get install -y kibana=8.19.23
   sudo apt-mark hold kibana
   ```
2. **Giới hạn bộ nhớ Kibana** để không ăn hết RAM của Elasticsearch. VM chỉ có ~3.8 GiB. Thêm vào `/etc/kibana/node.options`:
   ```
   --max-old-space-size=512
   ```
3. **Truy cập bằng SSH tunnel**, không mở cổng 5601 ra internet (Kibana không có mật khẩu). Chạy trên máy cá nhân, giữ cửa sổ mở, rồi vào Chrome `http://localhost:5601`:
   ```bash
   ssh -L 5601:127.0.0.1:5601 azureuser@<IP-VM>
   ```
4. Kibana mặc định nối `http://localhost:9200`, không cần sửa thêm. Nếu không lên, xem `sudo journalctl -u kibana -n 50 --no-pager`.

**Dùng Kibana:**

- Tạo **Data View** với pattern `filebeat-*`, time field `@timestamp`.
- Tên trường thật khác với tên trong đề bài:

  | Tên trong đề | Tên thật trong Elasticsearch | Ví dụ KQL |
  |---|---|---|
  | `client_ip` | `source.ip` | `source.ip : "203.0.113.50"` |
  | `status_code` | `http.response.status_code` | `http.response.status_code : 404` |
  | `request_url` | `url.original` | `url.original : "/admin"` |

**Về dữ liệu:**

- Index đang có dữ liệu thử (`/admin`, `/error`, `/khong-ton-tai`...), đủ để bạn tập KQL.
- Muốn thêm dữ liệu tập, tự sinh vài chục request với tiền tố riêng `/tap-*`:
  ```bash
  for i in $(seq 1 20); do curl -s -o /dev/null http://localhost/tap-$i; done
  ```
  **Chỉ vài chục request thôi**, đừng bắn nhiều vì VM còn ít RAM khi Kibana chạy.
- **Đừng tự xóa index.** Việc dọn dữ liệu cả nhóm sẽ thống nhất một lần trước khi chạy dữ liệu chính thức.
- Trong lúc chờ script của Quỳnh, bạn có thể phác bố cục dashboard, soạn sẵn các câu KQL cho Demo 3 (lọc 404, Top IP, Top URL) và dựng khung biểu đồ đường, biểu đồ tròn. Biểu đồ lưu trong Kibana nên không mất khi dữ liệu được dọn, miễn Data View vẫn là `filebeat-*`.

**Khi nộp PR:** kèm ảnh bằng chứng (Kibana kết nối được, Data View đã tạo), che IP VM và thông tin tài khoản. Nhớ **export dashboard ra file `.ndjson`** làm bản dự phòng.

---

## 7. Lời nhắn cho Đỗ Quỳnh (script traffic)

**Việc cần làm:** viết hai script, một giả khách bình thường, một giả hacker quét lỗ hổng.
> Chỉ mang tích chất tham khảo

**Những điều cần biết về Nginx trên VM:**

- `/` trả **200**, URL không tồn tại trả **404**, `/error` luôn trả **500**.
- Giả IP bằng header `X-Forwarded-For`, và chỉ có tác dụng khi chạy ngay trong VM (Nginx chỉ tin header từ `127.0.0.1` và `::1`). Gọi từ máy cá nhân vào VM thì header bị bỏ qua:
  ```bash
  curl -s -o /dev/null -H "X-Forwarded-For: 203.0.113.50" http://localhost/admin
  ```
- Request không có header sẽ hiện nguồn là `::1`. Đó là bình thường.
- Dùng các dải IP dành riêng cho tài liệu để IP giả không trùng IP thật: `203.0.113.x`, `198.51.100.x`, `192.0.2.x`.

**Để dữ liệu hữu ích cho Duy Tài (Demo 2 và 3):**

1. **Rải traffic theo thời gian**, đừng bắn hết trong vài giây. Chạy nhiều đợt, có `sleep`, nếu không biểu đồ theo thời gian chỉ có một cột nhọn.
2. **Cho vài IP quét lỗ hổng nổi bật hẳn:** ví dụ 1 đến 3 IP gây khoảng 25 đến 40 lỗi 404 mỗi IP, còn các IP khách thường chỉ vài request. Nếu mọi IP bằng nhau thì Demo 3 không có "IP đáng ngờ" nào nổi lên.
3. **Có đủ ba loại mã:** chủ yếu 200, một ít 404, vài chục 500 (gọi `/error`).
4. **Đặt tên theo quy ước** để dễ lọc:

   | Loại | Quy ước |
   |---|---|
   | Khách thường | URL `/demo2-*` |
   | Quét lỗ hổng | URL `/scan-*`, `User-Agent: scanner-sim` |
   | Demo 4 | URL `/outage-test-*` |

5. Cho script nhận **tham số số lượng** (ví dụ `./scanner_sim.sh 40`) để dễ điều chỉnh mà không phải sửa code.

**Khi nộp PR:**

- Kèm một mục "hợp đồng dữ liệu" trong `docs/conventions.md` để Duy Tài và người duyệt biết kết quả mong đợi:
  ```markdown
  ## Dữ liệu mẫu (do TV4 tạo)
  - Khách thường: IP 198.51.100.x, URL /demo2-*, chủ yếu 200
  - Kẻ quét: IP 203.0.113.50 (~40 lỗi 404), 203.0.113.77 (~25 lỗi 404)
  - URL bị quét: /admin, /.env, /wp-login.php, /phpmyadmin
  - Mã 500: ~10 request tới /error
  ```
- **Chỉ thử với số lượng nhỏ** (vài chục request). Đừng chạy bản chính thức lên VM khi chưa được báo, vì phải dọn dữ liệu thử trước và Duy Tài đang dựng biểu đồ trên đó.
- Kiểm tra file `.sh` không có ký tự xuống dòng kiểu Windows (`sed -i 's/\r$//' file.sh`) và không chứa mật khẩu hay key.
- Gửi ảnh bằng chứng (chạy script, log Nginx sau khi chạy), che IP VM.

---

## 8. Quy tắc chung

1. **Dữ liệu thử đang nằm trong index.** Việc dọn do cả nhóm thống nhất một lần, trước khi chạy dữ liệu chính thức. Không ai tự xóa index.
2. **Cấu hình trong repo là nguồn chính.** Nếu sửa trực tiếp trên VM cho nhanh, phải copy ngược về repo và nộp PR. Nếu không, lần triển khai sau sẽ ghi đè mất thay đổi.
3. **Snapshot do Leader chụp** (cần tài khoản Azure, SSH key không đủ). Cần mốc nào thì nhắn người đó. Tên theo mốc: `s1-es-ok`, `s2-nginx-filebeat-ok`, `s3-kibana-ok`, `s4-before-demo4`.
4. **Không đẩy lên Git:** file key `.pem`, mật khẩu, video, IP công cộng của VM.
5. **Nhắn cả nhóm trước khi restart hay dừng dịch vụ**, vì ảnh hưởng người khác đang dùng VM.
6. **Khôi phục từ snapshot sẽ mất mọi thứ làm sau lúc chụp.** Cấu hình trong repo không mất, nhưng dashboard Kibana chưa export thì mất.
