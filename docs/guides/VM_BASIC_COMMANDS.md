# Lệnh kiểm tra cấu hình VM

> **Tài liệu chỉ mang tính chất tham khảo**

---

## 1. Hệ điều hành và tên máy

```bash
cat /etc/os-release      # Phiên bản Ubuntu
uname -a                 # Kernel và kiến trúc
hostname                 # Tên máy
whoami                   # User đang đăng nhập
uptime                   # Máy chạy được bao lâu, tải CPU
timedatectl              # Múi giờ và giờ hệ thống
```

## 2. CPU

```bash
nproc                    # Số vCPU
lscpu                    # Chi tiết CPU
lscpu | grep -E "Model name|^CPU\(s\)|Thread|Core"   # Bản rút gọn
```

## 3. RAM và swap

```bash
free -h                  # Nhìn cột "total" và "available"
free -m                  # Cùng nội dung, đơn vị MB
cat /proc/meminfo | head -n 5
swapon --show            # Có swap hay không (không in gì = chưa có swap)
```

## 4. Ổ đĩa

```bash
df -h                    # Dung lượng các phân vùng (nhìn dòng "/")
df -h /                  # Chỉ ổ gốc
lsblk                    # Cấu trúc ổ đĩa
du -sh /var/lib/elasticsearch 2>/dev/null   # Dung lượng dữ liệu Elasticsearch (sau khi cài)
```

## 5. Mạng

```bash
ip addr                  # IP nội bộ của VM (interface eth0)
ip route                 # Bảng định tuyến
curl -s ifconfig.me; echo                    # IP công cộng của VM
ping -c 4 8.8.8.8        # Kiểm tra ra internet
ping -c 4 artifacts.elastic.co               # Kiểm tra phân giải tên miền (cần để cài ELK)
sudo ss -tulpn           # Các cổng đang lắng nghe
```

## 6. Tài nguyên đang dùng

```bash
top                      # Tiến trình ăn tài nguyên (thoát: q)
ps aux --sort=-%mem | head -n 6    # 5 tiến trình ăn RAM nhiều nhất
ps aux --sort=-%cpu | head -n 6    # 5 tiến trình ăn CPU nhiều nhất
```

## 7. Thông tin riêng của Azure

```bash
# Tên size VM (ví dụ Standard_B2als_v2)
curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text"; echo

# Vùng (region) đặt VM
curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/location?api-version=2021-02-01&format=text"; echo
```

## 8. Thông số hệ thống Elasticsearch cần

```bash
sysctl vm.max_map_count          # Elasticsearch cần tối thiểu 262144
ulimit -n                        # Giới hạn file mở
java -version 2>&1 | head -n 1   # Elasticsearch đã đóng gói sẵn Java, lệnh này có thể báo chưa cài, bình thường
```

---

## Lệnh tổng hợp: chạy 1 lần có đủ thông tin để đưa vào báo cáo

```bash
echo "===== HỆ ĐIỀU HÀNH ====="
grep PRETTY_NAME /etc/os-release
uname -r
hostname
echo
echo
echo "===== RAM / SWAP ====="
free -h
echo
echo "===== Ổ ĐĨA ====="
df -h / | tail -n 1
echo
echo "===== MẠNG ====="
echo "IP nội bộ: $(hostname -I)"
echo "IP công cộng: $(curl -s ifconfig.me)"
echo
echo "===== CỔNG ĐANG MỞ ====="
sudo ss -tulpn | grep LISTEN
echo
echo "===== THỜI GIAN ====="
date
uptime
```

Chụp màn hình kết quả để dùng cho mục **3.1 Bảng tài nguyên hệ thống** trong báo cáo.

---

## Mốc đối chiếu cho đồ án

| Hạng mục | Cần có | VM hiện tại |
|---|---|---|
| RAM | 3GB | 3.8 GiB |
| vCPU | 2 | 2 |
| Ổ đĩa trống | Từ 10 GB | Khoảng 29 GB |
| Java Heap Elasticsearch | 1 GB (đặt sau khi cài) | Chưa cài |
| `vm.max_map_count` | Từ 262144 | Kiểm tra bằng lệnh mục 8 |
