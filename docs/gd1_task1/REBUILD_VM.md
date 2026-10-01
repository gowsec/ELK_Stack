# Hướng dẫn dựng lại VM từ đầu (nếu không có file .ova)

Tài liệu hướng dẫn từng bước tạo mới máy ảo, cài đặt hệ điều hành Ubuntu Server và cấu hình Elasticsearch từ đầu dành cho trường hợp không thể sử dụng file máy ảo đóng gói sẵn (`.ova`).

Thời gian thực hiện dự kiến: **1.5 – 2 giờ**.

---

## 1. Tải công cụ & ISO
1. Cài đặt **VirtualBox** (tải từ [virtualbox.org](https://www.virtualbox.org/)).
2. Tải **Ubuntu Server 22.04 LTS** (tải file ISO amd64 từ [ubuntu.com/download/server](https://ubuntu.com/download/server), dung lượng khoảng 2GB).

## 2. Tạo máy ảo (VM)
1. Trong VirtualBox → chọn **New**:
   - **Name**: `ELK-VM`
   - **ISO Image**: Chọn file ISO Ubuntu vừa tải
   - Tích chọn **Skip Unattended Installation**
   - **Type**: Linux, **Version**: Ubuntu (64-bit)
2. Cấu hình phần cứng:
   - **Base Memory**: `3072 MB`
   - **Processors**: `2 vCPU`
   - **Hard Disk**: `20 GB`
3. Cấu hình mạng: Vào **Settings → Network → Advanced → Port Forwarding**, thêm 3 quy tắc NAT (TCP, để trống Host IP và Guest IP):

| Name | Host Port | Guest Port | Mục đích |
|---|---|---|---|
| ssh | 2222 | 22 | SSH truy cập terminal |
| http | 8080 | 80 | Web server Nginx |
| kibana | 5601 | 5601 | Dashboard Kibana |

## 3. Cài đặt Ubuntu Server
1. Bấm **Start** VM. Trong trình cài đặt, chọn các tùy chọn mặc định (nhấn Enter), lưu ý các mục sau:
   - **Hostname**: `elk-node`
   - **Username**: `elk` (tự đặt mật khẩu và ghi nhớ)
   - **Install OpenSSH server**: Nhấn phím Space để tích chọn cài đặt OpenSSH.
   - **Featured snaps**: Bỏ qua, không chọn bất kỳ package nào.
2. Hoàn tất cài đặt → Chọn **Reboot now** (nhấn Enter khi được nhắc tháo ổ đĩa ảo).
3. Đăng nhập kiểm tra qua SSH từ máy thật:
   ```bash
   ssh -p 2222 elk@127.0.0.1
   ```

## 4. Chuẩn bị hệ thống & Tắt Swap
Chạy các lệnh sau trong terminal VM:
```bash
sudo apt update && sudo apt -y upgrade
sudo apt install -y curl gnupg git unzip

# Tắt swap hoàn toàn
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Cấu hình kernel parameter cho Elasticsearch
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf
sudo sysctl --system

# Kiểm tra lại RAM và Swap
free -m
```
*Ghi chú: Lệnh `free -m` cần hiển thị Mem total ~2900–3000 MB và Swap = 0 MB.*
Sau bước này, nên tắt VM (`sudo poweroff`) và chụp snapshot đặt tên `S1-os-ready`.

## 5. Cài đặt & Cấu hình Elasticsearch
Thêm repository chính thức của Elastic và cài đặt Elasticsearch:
```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update && sudo apt install -y elasticsearch
```
*(Nếu terminal hiển thị mật khẩu mặc định của user elastic, có thể bỏ qua vì chúng ta sẽ tắt security nội bộ).*

Cấu hình `elasticsearch.yml`:
```bash
sudo cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak

sudo tee /etc/elasticsearch/elasticsearch.yml > /dev/null <<'EOF'
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
EOF
```

Giới hạn JVM Heap 1GB trong `heap.options`:
```bash
sudo tee /etc/elasticsearch/jvm.options.d/heap.options > /dev/null <<'EOF'
-Xms1g
-Xmx1g
EOF
sudo chown root:elasticsearch /etc/elasticsearch/jvm.options.d/heap.options

# Khởi động dịch vụ
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch
```

Đợi khoảng 60 giây để Elasticsearch khởi động xong, sau đó kiểm tra:
```bash
curl localhost:9200
curl 'localhost:9200/_cluster/health?pretty'
curl 'localhost:9200/_nodes/jvm?filter_path=**.heap_max_in_bytes&pretty'
```
Kết quả mong muốn: Phản hồi JSON chứa thông tin version, `status: green` và `heap_max_in_bytes: 1073741824`.
Sau bước này, chụp snapshot đặt tên `s1-es-ok`.

## 6. Copy mã nguồn dự án vào VM và nghiệm thu
Trên máy thật (PowerShell tại thư mục gốc dự án):
```bash
scp -P 2222 -r * elk@127.0.0.1:~/elk-project/
```

Trong VM:
```bash
cd ~/elk-project
chmod +x scripts/*.sh
./scripts/verify_phase1.sh        # Tất cả các mục phải hiển thị [PASS]
```

Chạy kiểm thử tải và giám sát RAM:
```bash
./scripts/monitor_ram.sh 5 results/ram_log.csv &
sleep 30
./scripts/load_test.sh 2000
sleep 30
kill %1
./scripts/ram_summary.sh results/ram_log.csv
```
*Yêu cầu nghiệm thu: RAM used không vượt quá 3072 MB, Swap used = 0 MB.*

## 7. Đóng gói & Bàn giao
1. Chụp snapshot bản hoàn chỉnh đặt tên `s2-gd1-task1-done`.
2. Tắt máy ảo an toàn: `sudo poweroff`.
3. Xuất file máy ảo trong VirtualBox: Vào menu **File → Export Appliance...** → chọn máy ảo `ELK-VM` và lưu thành file `ELK-VM.ova`.
4. Tải file `.ova` lên Google Drive để chia sẻ cho các thành viên trong nhóm.
