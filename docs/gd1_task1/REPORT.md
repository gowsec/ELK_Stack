# Báo cáo Giai đoạn 1, Task 1: Hạ tầng & Elasticsearch

- Người thực hiện: Tuấn Khanh
- Ngày hoàn thành: 01/10/2026
- Deadline: 01/10/2026

## 1. Mục tiêu
Dựng hạ tầng cho hệ thống quản lý log tập trung ELK: 1 máy ảo giới hạn 3GB RAM, cài Elasticsearch (heap 1GB, tắt X-Pack Security), có cơ chế snapshot phòng hỏng máy và số liệu RAM chứng minh hệ thống ổn định.

## 2. Cấu hình thực tế

| Hạng mục | Giá trị |
|---|---|
| Phần mềm ảo hóa | Oracle VirtualBox |
| OS / phiên bản | Ubuntu Server 22.04.5 LTS (amd64) |
| RAM / CPU / Disk | 3072 MB (2968 MB nhận diện trong OS) / 2 vCPU / 20 GB |
| Swap | Tắt (0 MB) |
| Phiên bản Elasticsearch | 8.19.22 |
| Heap JVM | `-Xms1g -Xmx1g` (1024 MB) |
| Chế độ | single-node, `xpack.security.enabled: false` |
| Địa chỉ nghe | 127.0.0.1:9200 |

## 3. Các bước đã thực hiện
1. Tạo VM, tắt swap, đặt `vm.max_map_count=262144`. (ảnh `01-vm-ram.png`)
2. Cài Elasticsearch từ repo Elastic 8.x, áp dụng `elasticsearch.yml` và `heap.options`. (ảnh `02-es-running.png`, `03-es-heap.png`)
3. Chạy `verify_phase1.sh` để nghiệm thu.
4. Chụp snapshot theo từng mốc. (ảnh `04-snapshots.png`)
5. Chạy `monitor_ram.sh` kèm `load_test.sh` để đo RAM. (ảnh `05-ram-summary.png`)

## 4. Kết quả nghiệm thu

| Tiêu chí | Kết quả | Đạt |
|---|---|---|
| RAM VM ≤ 3072 MB | 2968 MB | ☑ |
| Swap tắt | 0 MB (đã tắt) | ☑ |
| Heap ES ≈ 1GB | 1024 MB (1073741824 bytes) | ☑ |
| ES truy cập không cần xác thực | HTTP 200 OK | ☑ |
| Cluster health | green | ☑ |

## 5. Danh sách snapshot

| Tên | Thời điểm | Nội dung |
|---|---|---|
| s1-es-ok | 01/10/2026 18:40 | OS + sysctl + Elasticsearch cài đặt hoàn tất và chạy ổn định |
| s2-gd1-task1-done | 01/10/2026 19:05 | Hoàn tất Task 1 Giai đoạn 1 (verify, test tải, số liệu RAM đầy đủ) |
| File sao lưu `.ova` | 01/10/2026 | Vị trí lưu: Google Drive (`ELK-VM.ova`) |

## 6. Số liệu RAM

Điều kiện đo: ES idle 30s → index 2000 document → idle 30s; chu kỳ ghi 5s.

| Chỉ số | Giá trị |
|---|---|
| Số mẫu | 19 |
| Used trung bình / cao nhất | 1658 / 1668 MB |
| Available thấp nhất | 1116 MB |
| RSS cao nhất: ES / Kibana / Filebeat / Nginx | 1502 / 0 / 0 / 0 MB |
| ES heap used cao nhất | 594 MB |
| Swap used cao nhất | 0 MB |

Biểu đồ: `results/ram_chart.png`

**Nhận xét:**
- **Mức RAM sử dụng an toàn:** RAM used cao nhất đạt **1668 MB** (trung bình **1658 MB**), chiếm ~56.2% tổng bộ nhớ khả dụng của VM (2968 MB), hoàn toàn không vượt quá giới hạn 3072 MB và vẫn còn cách trần hơn 1.4 GB.
- **Swap tắt hoàn toàn:** Swap used duy trì liên tục ở mức **0 MB**, loại bỏ triệt để hiện tượng disk thrashing giúp Elasticsearch phản hồi nhanh và trung thực với số liệu RAM vật lý.
- **Hiệu quả quản lý Heap:** Heap tối đa cấp phát là 1024 MB. Trong suốt quá trình test tải index 2000 document liên tục, heap used cao nhất chỉ đạt **594 MB** (tăng từ 138 MB khi idle). Sau khi tải hoàn tất, heap ổn định, không có hiện tượng rò rỉ bộ nhớ (leak).
- **Dư địa dồi dào cho các giai đoạn tiếp theo:** Lượng RAM Available thấp nhất vẫn còn **1116 MB** (~1.1 GB). Khoảng trống này hoàn toàn đủ để triển khai các dịch vụ còn lại trong các task tiếp theo:
  - **Kibana**: dự kiến cấp `--max-old-space-size=512` (~500 - 700 MB RAM thực tế).
  - **Filebeat**: agent thu thập log tiêu thụ rất ít tài nguyên (~50 - 100 MB).
  - **Nginx**: web server reverse proxy/load balancer (~20 - 50 MB).

## 7. Khó khăn & cách xử lý
- **Kiểm soát Heap trên Elasticsearch 8.x:** Elasticsearch mặc định tự động cấp phát heap dựa trên tài nguyên hệ thống, dễ dẫn đến thiếu RAM cho các dịch vụ khác. Đã xử lý bằng cách cấu hình tường minh file `/etc/elasticsearch/jvm.options.d/heap.options` với `-Xms1g -Xmx1g`.
- **Yêu cầu tham số hạt nhân `vm.max_map_count`:** Elasticsearch yêu cầu số lượng bản đồ bộ nhớ tối thiểu 262144. Đã cấu hình cố định trong `/etc/sysctl.d/99-elasticsearch.conf` và nạp vào kernel qua `sysctl --system`.
- **Tắt X-Pack Security cho môi trường phát triển nội bộ:** ES 8.x mặc định bật HTTPS và bảo mật nghiêm ngặt. Cấu hình đã tắt xpack security để đơn giản hóa giao tiếp nội bộ trong VM và thiết lập `network.host: 127.0.0.1` nhằm cô lập an toàn trên cổng nội bộ.

## 8. Bàn giao cho các Tasks tiếp theo
Xem [HANDOFF.md](HANDOFF.md).
