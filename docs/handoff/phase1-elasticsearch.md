# Hạ tầng và Elasticsearch

Tài liệu này chỉ ghi những gì đã cài và cấu hình trên VM Azure `elk-server`.

---

## 1. Máy ảo (VM)

| Mục | Giá trị | Tình trạng |
|---|---|---|
| Nền tảng | Microsoft Azure (gói sinh viên) | Đã xác nhận |
| Resource group | `ELK-PROJECT` | Đã xác nhận |
| Vùng (region) | `japaneast` | Đã xác nhận |
| Tên VM / hostname | `elk-server` | Đã xác nhận |
| User đăng nhập | `azureuser` (SSH, cổng 22) | Đã xác nhận |
| Hệ điều hành | Ubuntu 24.04.4 LTS (Noble Numbat) | Đã xác nhận |
| Kernel | `6.17.0-1022-azure`, x86_64 | Đã xác nhận |
| CPU | 2 vCPU, AMD EPYC 7763 | Đã xác nhận |
| RAM | 3862 MiB (~3.8 GiB), lúc chưa cài gì đã dùng ~503 MiB | Đã xác nhận |
| Swap | 0 (không có) | Đã xác nhận |
| Ổ đĩa | Ổ gốc `/` 30 GB, còn trống ~29 GB lúc chưa cài gì | Đã xác nhận |
| IP nội bộ | `172.16.0.4/24` (interface `eth0`) | Đã xác nhận |
| IP công cộng | Không ghi vào repo. Lấy từ Azure Portal; có thể đổi sau khi tắt/bật VM | Chưa ghi nhận |
| Kết nối internet | Ping `8.8.8.8` mất 0% gói, ~1.4 ms | Đã xác nhận |

**Về yêu cầu "3GB RAM" của đề:** Azure không có size đúng 3GB nên dùng VM 3.8 GiB (size gần nhất). Phần tài nguyên dành cho Elasticsearch được giới hạn bằng Java Heap 1GB (mục 3).

---

## 2. Elasticsearch

| Mục | Giá trị | Tình trạng |
|---|---|---|
| Phiên bản | **8.19.23** | Đã xác nhận |
| Cách cài | Gói `.deb` từ kho APT của Elastic (mục 2.1) | Đã xác nhận |
| Java | JDK đi kèm trong gói cài, không cần cài riêng | Đã xác nhận |
| Dịch vụ | `elasticsearch` (systemd), bật tự chạy khi khởi động VM | Đã xác nhận |
| Chế độ cluster | `single-node` (1 node) | Đã xác nhận |
| Tên cluster / node | `elk-demo` / `node-1` | Đã xác nhận |
| Địa chỉ nghe | `127.0.0.1:9200` (HTTP). Không truy cập được từ ngoài VM | Đã xác nhận |
| Bảo mật X-Pack | **Tắt**: truy cập bằng HTTP, không mật khẩu, không TLS | Đã xác nhận |
| Java Heap | 1 GB (`-Xms1g -Xmx1g`). Giá trị kỳ vọng `heap_max_in_bytes: 1073741824` | Đã xác nhận |
| Số bản sao (replica) | 0, do Filebeat đặt trong index template | Đã xác nhận |

Bằng chứng cho dòng "bảo mật tắt": `curl localhost:9200` trả về JSON mà không cần thông tin đăng nhập, và `filebeat test output` kết nối được qua `http://` với cảnh báo `TLS... WARN secure connection disabled`.

### 2.1. Kho APT

File `/etc/apt/sources.list.d/elastic-*.list`:

```
deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main
```

Các thành phần khác của ELK cài từ cùng kho này và phải **cùng phiên bản 8.19.23**.

---

## 3. Cấu hình đã thống nhất

### `/etc/elasticsearch/elasticsearch.yml`

```yaml
cluster.name: elk-demo
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
```

| Dòng | Ý nghĩa |
|---|---|
| `network.host: 127.0.0.1` | Chỉ nhận kết nối từ chính VM (Filebeat và Kibana chạy cùng VM) |
| `discovery.type: single-node` | Chạy 1 node, tự làm master, không chờ node khác |
| `xpack.security.enabled: false` | Tắt xác thực và phân quyền (yêu cầu của đề) |
| `xpack.security.enrollment.enabled: false` | Tắt cơ chế enrollment tự sinh từ bản 8.x |
| `xpack.security.http.ssl.enabled: false` | Dùng HTTP thường cho cổng 9200 |
| `xpack.security.transport.ssl.enabled: false` | Tắt TLS cho kênh giữa các node |

Khi cài bằng `apt`, Elasticsearch 8.x tự sinh thêm cấu hình bảo mật và dòng `cluster.initial_master_nodes` vào file mặc định. Dòng `cluster.initial_master_nodes` **xung đột** với `discovery.type: single-node` nên không được có trong file cuối cùng.

### `/etc/elasticsearch/jvm.options.d/heap.options`

```
-Xms1g
-Xmx1g
```

File thuộc `root:elasticsearch`. Sau khi sửa cấu hình cần `sudo systemctl daemon-reload` (nếu đổi file service) và `sudo systemctl restart elasticsearch`.

---

## 4. Vị trí file và thư mục

| Đường dẫn | Nội dung |
|---|---|
| `/etc/elasticsearch/elasticsearch.yml` | Cấu hình chính |
| `/etc/elasticsearch/jvm.options.d/heap.options` | Giới hạn Java Heap |
| `/var/lib/elasticsearch/` | Dữ liệu thật (index, document) |
| `/var/log/elasticsearch/elk-demo.log` | Log của Elasticsearch (tên file theo `cluster.name`) |
| `/etc/apt/sources.list.d/elastic-*.list` | Kho APT của Elastic |

---

## 5. Thành phần đã được nạp vào Elasticsearch

Do lệnh `filebeat setup` (thuộc Task 2) thực hiện:

| Thành phần | Trạng thái | Tình trạng |
|---|---|---|
| Index template của Filebeat (có `number_of_replicas: 0`) | Đã nạp (`Index setup finished.`) | Đã xác nhận |
| Ingest Pipeline `filebeat-8.19.23-nginx-access-pipeline` | Có | Đã xác nhận |
| Ingest Pipeline `filebeat-8.19.23-nginx-error-pipeline` | Có | Đã xác nhận |
| Data stream `filebeat-8.19.23` | Được tạo khi có dữ liệu đầu tiên | Đã xác nhận khi có dữ liệu |

---

## 6. Snapshot Azure

| Tên | Loại | Vùng | Dung lượng đĩa | Thời điểm tạo | Trạng thái lúc chụp |
|---|---|---|---|---|---|
| `s1-es-ok` | Incremental | `japaneast` | 32 GB | 2026-10-09 11:35 UTC | Elasticsearch đã cài và chạy. Chưa có Nginx, Filebeat |

Quy ước tên theo mốc: `s1-es-ok`, `s2-nginx-filebeat-ok`, `s3-kibana-ok`, `s4-before-demo4`.

Snapshot được tạo bằng tài khoản Azure của người giữ VM (SSH key không đủ quyền). Snapshot phải cùng vùng `japaneast` với đĩa gốc, vì gói sinh viên chặn các vùng khác (`RequestDisallowedByAzure`).

Liệt kê snapshot hiện có (Azure Cloud Shell, Bash):

```bash
az snapshot list -o table --query "[].{Name:name, Region:location, SizeGB:diskSizeGb, State:provisioningState, Created:timeCreated}"
```

---

## 7. Lệnh kiểm tra nhanh

Chạy trên VM.

```bash
# Dịch vụ
systemctl is-active elasticsearch
systemctl is-enabled elasticsearch

# Phiên bản và tên cluster
curl -s localhost:9200

# Sức khỏe cluster
curl -s "localhost:9200/_cluster/health?pretty"

# Java Heap thực tế (kỳ vọng ~1073741824)
curl -s "localhost:9200/_nodes/jvm?filter_path=**.heap_max_in_bytes&pretty"

# Heap và RAM theo node
curl -s "localhost:9200/_cat/nodes?v&h=name,heap.percent,heap.max,ram.percent,ram.max"

# Danh sách index và data stream
curl -s "localhost:9200/_cat/indices?v"
curl -s "localhost:9200/_data_stream?pretty&filter_path=data_streams.name"

# Cổng đang nghe (9200 chỉ nên nghe ở 127.0.0.1)
sudo ss -tulpn | grep -E "9200|9300"

# Nội dung cấu hình đang áp dụng
sudo cat /etc/elasticsearch/elasticsearch.yml
sudo cat /etc/elasticsearch/jvm.options.d/heap.options

# Tài nguyên VM
free -h
df -h /
nproc
```

Đối chiếu kết quả với các dòng đánh dấu ⚠️ ở mục 2, 3 và 5, rồi cập nhật thành ✅.

---

## 8. Ràng buộc của môi trường

- **X-Pack Security tắt** theo yêu cầu của đề: không xác thực, không mã hóa. Chỉ phù hợp môi trường demo.
- **1 node duy nhất**, không có bản sao dữ liệu. Index phải đặt `number_of_replicas: 0` để cluster ở trạng thái `green`.
- **Không có swap.** Bộ nhớ dành cho Elasticsearch giới hạn bằng Java Heap 1GB.
- **Elasticsearch chỉ nghe `127.0.0.1`.** Kibana, Filebeat chạy cùng VM nên kết nối được. Truy cập Kibana từ trình duyệt đi qua SSH tunnel.
- **Toàn bộ ELK dùng phiên bản 8.19.23.** Kibana khác phiên bản với Elasticsearch sẽ từ chối kết nối.
