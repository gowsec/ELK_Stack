# Hướng dẫn thực hiện giai đoạn 1 - Lê Duy Tài
> Tài liệu tổng hợp các lệnh đã dùng trong quá trình thực hiện nhiệm vụ. IP của Azure VM có thể thay đổi; sử dụng IP hiện tại do Leader cung cấp.

## 1. Nhiệm vụ và mô hình kết nối

**Vai trò:** Kỹ sư Giao diện.

- Cài đặt Kibana và kết nối với Elasticsearch.
- Sử dụng công cụ tìm kiếm trên Kibana để lọc lỗi.

Hệ thống của nhóm chạy trên Azure VM. Mac dùng SSH để quản trị và SSH tunnel để mở Kibana.

```text
Mac của Lê Duy Tài
    │
    ├── SSH → Azure VM Ubuntu (elk-server)
    │              └── Nginx → Filebeat → Elasticsearch → Kibana
    │
    └── Trình duyệt: http://localhost:5601
                   └── SSH tunnel → 127.0.0.1:5601 trên VM
```

Thông tin ghi nhận trong buổi thực hiện:

| Hạng mục | Giá trị |
|---|---|
| User Linux | `duytai` |
| Public IP lúc kết nối | `20.89.151.46` |
| Tên VM trong Linux | `elk-server` |
| Elasticsearch / Filebeat | `8.19.23` |
| Kibana cài đặt | `8.19.23` |
| Data stream | `filebeat-8.19.23` |

## 2. Kiểm tra SSH key trên Mac

**Chạy trên Mac**, trước khi đăng nhập VM.

Tìm public key đã có:

```bash
find ~/.ssh -maxdepth 1 -type f -name '*.pub'
```

Xem public key để đối chiếu với key đã gửi Leader:

```bash
cat ~/.ssh/id_ed25519.pub
```

- `id_ed25519` = Private key.
- `id_ed25519.pub` = Public key, gửi cho Leader cấp quyền đăng nhập.
- Không tạo lại hoặc ghi đè key đang dùng.

Tìm lệnh SSH từng chạy khi cần:

```bash
history | grep 'ssh '
```

## 3. Kết nối vào Azure VM

**Chạy trên Mac:**

```bash
ssh -i ~/.ssh/id_ed25519 duytai@20.89.151.46
```

Lần đầu kết nối có thể xuất hiện câu hỏi xác nhận danh tính máy chủ. Đối chiếu IP và fingerprint với Leader trước khi nhập `yes`.

Nếu đăng nhập thành công, sẽ thấy:

```text
duytai@elk-server:~$
```

Khi kết nối bị chờ lâu, dùng lệnh chẩn đoán đã được hướng dẫn:

```bash
ssh -v -o ConnectTimeout=10 -i ~/.ssh/id_ed25519 duytai@20.89.151.46
```

**Lưu ý:** Các lệnh Linux ở những mục tiếp theo chạy trong phiên SSH trên VM.

## 4. Kiểm tra môi trường và dịch vụ

**Chạy trên VM:**

```bash
whoami
hostname
cat /etc/os-release
```

Kiểm tra trạng thái các dịch vụ theo đúng thứ tự trong lệnh:

```bash
systemctl is-active elasticsearch nginx filebeat kibana
```

Kết quả trước khi cài Kibana:

```text
active
active
active
inactive
```

Kiểm tra phiên bản phần mềm:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' elasticsearch kibana filebeat nginx
```

Kết quả ban đầu: Elasticsearch và Filebeat `8.19.23`; Nginx `1.24.0-2ubuntu7.18`; chưa có gói Kibana.

Kiểm tra RAM và swap:

```bash
free -h
```

Kết quả lúc kiểm tra: tổng RAM khoảng `3.8 GiB`, RAM khả dụng khoảng `1.9 GiB`, chưa có swap.

```bash
sudo ss -ltnp
```

## 5. Kiểm tra quyền sudo

SSH key dùng để đăng nhập. Quyền `sudo` dùng để cài gói, sửa cấu hình hệ thống và quản lý dịch vụ.

Lệnh kiểm tra quyền đã được hướng dẫn:

```bash
sudo -v
```

Nếu Leader cấu hình sudo không cần mật khẩu, có thể kiểm tra mà không mở lời nhắc mật khẩu:

```bash
sudo -n whoami
```

- Hiện `root`: lệnh kiểm tra này được phép chạy.
- Hiện `a password is required`: thao tác này chưa được phép chạy không cần mật khẩu, phải yêu cầu cấp quyền.

## 6. Kiểm tra Elasticsearch

**Chạy trên VM:**

```bash
curl --max-time 10 -i http://localhost:9200
```

Kết quả đã ghi nhận:

```text
HTTP/1.1 200 OK
X-elastic-product: Elasticsearch
```

Phần JSON trả về có `cluster_name: elk-demo` và phiên bản `8.19.23`. Truy vấn này không yêu cầu tài khoản trong môi trường đang dùng; điều đó chưa đủ để kết luận toàn bộ cấu hình bảo mật.

Lệnh đọc chọn lọc cấu hình kết nối đã được hướng dẫn:

```bash
sudo grep -nE '^[[:space:]]*(network\.host|http\.port|http\.host|xpack\.security\.enabled|xpack\.security\.http\.ssl\.enabled|enabled:)' /etc/elasticsearch/elasticsearch.yml
```


## 7. Cài Kibana đúng phiên bản

**Chạy trên VM.** Kho APT của Elastic đã được nhóm cấu hình sẵn.

Kiểm tra gói có trong kho:

```bash
apt-cache policy kibana
```

Rút gọn kết quả:

```bash
apt-cache policy kibana | head -n 20
```

Kết quả trước khi cài:

```text
Installed: (none)
Candidate: 8.19.23
```

Cập nhật danh sách gói:

```bash
sudo apt-get update
```

Nếu cập nhật thành công, cài phiên bản khớp Elasticsearch:

```bash
sudo apt-get install kibana=8.19.23
```

Khi được hỏi `Do you want to continue? [Y/n]`, nhập `Y` rồi Enter.

Kiểm tra phiên bản sau khi cài:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' kibana
```

## 8. Cấu hình Kibana

**Chạy trên VM:**

Sao lưu cấu hình trước khi sửa:

```bash
sudo cp -n /etc/kibana/kibana.yml /etc/kibana/kibana.yml.before-duytai
```

Lệnh đã hiện cảnh báo về tính tương thích của `cp -n`. Đây không phải lỗi; `-n` tránh ghi đè nếu bản sao lưu đã tồn tại.

Mở cấu hình:

```bash
sudo nano /etc/kibana/kibana.yml
```

Sửa hoặc bổ sung các mục dưới đây. Không để dấu `#` ở đầu và không khai báo trùng khóa:

```yaml
server.host: "127.0.0.1"
server.port: 5601
elasticsearch.hosts: ["http://localhost:9200"]
```

- `server.host`: Kibana chỉ lắng nghe trên loopback của VM; truy cập từ Mac qua SSH tunnel.
- `server.port`: Cổng HTTP của Kibana.
- `elasticsearch.hosts`: Elasticsearch trên cùng VM, đã kiểm tra phản hồi qua HTTP ở mục 6.
- Trong nano: `Ctrl + O` → `Enter` để lưu, `Ctrl + X` để thoát.

## 9. Khởi động và kiểm tra Kibana

**Chạy trên VM:**

```bash
sudo systemctl daemon-reload
```

```bash
sudo systemctl enable --now kibana
```

Lệnh trên bật Kibana ngay và thiết lập tự chạy khi VM khởi động.

Kiểm tra tiến trình:

```bash
systemctl is-active kibana
```

Kết quả đã ghi nhận: `active`.

Đợi Kibana khởi động rồi kiểm tra HTTP:

```bash
curl --max-time 15 -I http://127.0.0.1:5601
```

Trong lần thực hiện đầu, curl báo chưa kết nối được vì dịch vụ đang khởi động. `active` chưa bảo đảm giao diện đã sẵn sàng.

Đọc nhật ký khi cần:

```bash
sudo journalctl -u kibana -n 50 --no-pager
```

Hoặc xem 30 dòng gần nhất:

```bash
sudo journalctl -u kibana -n 30 --no-pager
```

Nhật ký đã ghi nhận HTTP server chạy tại `http://127.0.0.1:5601`; sau đó giao diện Kibana đã mở thành công trên Mac.

## 10. Mở Kibana từ Mac bằng SSH tunnel

Giữ phiên SSH quản trị ở tab hiện tại. Mở **tab Terminal mới trên Mac** bằng `Command + T`.

**Chạy trên Mac, không chạy trong phiên SSH:**

```bash
ssh -i ~/.ssh/id_ed25519 -N -L 5601:127.0.0.1:5601 -o ExitOnForwardFailure=yes duytai@20.89.151.46
```

- `-N`: Chỉ mở đường hầm, không mở shell từ xa.
- `-L`: Chuyển cổng 5601 trên Mac đến cổng 5601 trên loopback của VM.
- `ExitOnForwardFailure=yes`: Báo lỗi và thoát nếu không thiết lập được chuyển tiếp cổng.
- Lệnh đứng yên và không trả lại dòng nhắc là bình thường khi tunnel hoạt động. Giữ tab này mở.

Mở trình duyệt trên Mac:

```text
http://localhost:5601
```

Giao diện **Welcome to Elastic** đã hiển thị. Chọn **Explore on my own** để tiếp tục.

## 11. Kiểm tra dữ liệu Filebeat trong Elasticsearch

**Chạy trên VM:**

```bash
curl --max-time 15 -sS 'http://localhost:9200/_cat/indices?v'
```

```bash
curl --max-time 15 -sS 'http://localhost:9200/_data_stream?pretty'
```

Kết quả lúc kiểm tra:

- Data stream: `filebeat-8.19.23`.
- Trường thời gian: `@timestamp`.
- Backing index: `.ds-filebeat-8.19.23-2026.10.10-000001`.
- Có 23 document, trạng thái `green`.

Số lượng document có thể tăng khi Filebeat tiếp tục gửi log.

## 12. Tìm kiếm và lọc lỗi trên Kibana

Phần này thao tác trên trình duyệt.

Mở **Discover** và tạo Data View:

| Mục | Giá trị đã dùng |
|---|---|
| Name | `nginx logs` |
| Index pattern | `filebeat-*` |
| Timestamp field | `@timestamp` |

Chọn khoảng thời gian có chứa log, ví dụ **Last 7 days**. `Today` thay đổi khi qua ngày mới nên có thể không thấy dữ liệu ngày trước.

Lọc log truy cập Nginx:

```text
event.dataset: "nginx.access"
```

Lọc request trả về lỗi 404:

```text
event.dataset: "nginx.access" and http.response.status_code: 404
```

Lọc riêng IP trong dữ liệu demo:

```text
event.dataset: "nginx.access" and http.response.status_code: 404 and source.ip: "203.0.113.50"
```

Thêm các cột `@timestamp`, `source.ip`, `url.path`, `http.response.status_code` để đọc kết quả. Đã ghi nhận 7 request 404; IP `203.0.113.50` có 3 request đến `/admin`. Đây là kết quả trong dữ liệu và khoảng thời gian đã kiểm tra, không tự chứng minh có tấn công.

Mở chi tiết document để kiểm tra JSON. Bản ghi mẫu đã có các trường thời gian, IP, đường dẫn và mã HTTP được tách riêng.

## 13. Kết quả và cách kết thúc phiên làm việc

**Giai đoạn 1 đã thực hiện:**

- Cài Kibana `8.19.23` trên Azure VM.
- Kết nối Kibana với Elasticsearch và mở giao diện từ Mac.
- Tạo Data View để xem dữ liệu Filebeat.
- Tìm kiếm, lọc lỗi 404 và lọc theo IP trong Discover.

Các biểu đồ, dashboard

