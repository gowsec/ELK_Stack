# Hướng dẫn nền tảng

---

## 1. Thông tin kết nối

| Mục | Giá trị |
|---|---|
| Tên VM trong VirtualBox | `ELK-VM` |
| User / mật khẩu VM | `elk` / (cung cấp riêng nội bộ nhóm, không lưu trên GitHub) |
| OS | Ubuntu Server 22.04.5 LTS (amd64) |
| Phiên bản Elasticsearch | 8.19.22 |
| RAM available khi ES idle | ~1126 MB (khi ES chạy) / 2558 MB (khi mới bật OS) |
| File VM để nhập (`.ova`) | Link Drive: `https://drive.google.com/drive/folders/1SXzGOl89EHskBB9O6vqmoS53_ZJygnVx?usp=sharing` |
| Snapshot sạch để quay về | `s2-gd1-task1-done` |

Từ máy bạn, VM được truy cập qua các cổng đã cấu hình sẵn:

| Dịch vụ | Địa chỉ trên máy bạn |
|---|---|
| SSH | `127.0.0.1` cổng **2222** |
| Nginx | `http://127.0.0.1:8080` |
| Kibana | `http://127.0.0.1:5601` |
| Elasticsearch | chỉ dùng **bên trong VM**: `http://localhost:9200` |

## 2. Cách có VM

**Cách nhanh (khuyên dùng): nhập file `.ova`.** Mỗi người nhập một bản riêng trên máy mình. Máy cần ≥ 8GB RAM và ≥ 25GB ổ trống.

1. Cài VirtualBox (virtualbox.org).
2. Tải file `.ova` từ link ở mục 1.
3. VirtualBox → **File → Import Appliance** → chọn file → Next → **Import** (vài phút).
4. Chọn VM → **Settings**, kiểm tra:
   - System → Base Memory = **3072 MB**
   - Network → Advanced → Port Forwarding có 3 dòng: 2222→22, 8080→80, 5601→5601. Thiếu thì thêm lại (TCP, để trống Host IP và Guest IP).

Không có file `.ova`: xem hướng dẫn tại [REBUILD_VM.md](REBUILD_VM.md).

## 3. Bật VM và đăng nhập

1. Chọn VM → mũi tên cạnh **Start** → **Headless Start** (chạy nền, đỡ tốn RAM) hoặc Start thường. Đợi ~1 phút.
2. Mở **PowerShell** trên máy bạn:
   ```
   ssh -p 2222 elk@127.0.0.1
   ```
   Lần đầu gõ `yes`. Gõ mật khẩu (không hiện ký tự là bình thường). Thấy dấu nhắc `elk@elk-node:~$` là đã vào VM.
3. Tắt VM đúng cách (không bấm X cửa sổ): `sudo poweroff`

Elasticsearch **tự chạy** khi VM bật. Gõ `exit` để thoát SSH.

## 4. Kiểm tra nền tảng còn khỏe

Trong VM (đã SSH vào):
```bash
cd ~/elk-project
./scripts/verify_phase1.sh
```
Mọi dòng phải là `[PASS]`. Nếu `FAIL`, đọc dòng đó và kiểm tra trạng thái dịch vụ. Kiểm tra nhanh thủ công:
```bash
curl localhost:9200                       # thấy JSON có "tagline" là ES đang chạy
sudo systemctl status elasticsearch       # thấy "active (running)"; bấm q để thoát
free -m                                   # xem RAM
```
Nếu chạy script báo `Permission denied` thì gõ `chmod +x ~/elk-project/scripts/*.sh`.

## 5. Snapshot (điểm lưu)

**Luôn chụp snapshot trước khi cài hoặc sửa gì lớn.** Cách làm bằng giao diện:

- Chụp: chọn VM → tab **Snapshots** (trên cùng bên phải) → **Take** → đặt tên theo mẫu `S-<task>-<mô tả>`, ví dụ `S-nginx-truoc-khi-cai`.
- Quay về: **tắt VM** (`sudo poweroff`) → Snapshots → chuột phải snapshot → **Restore**. Mọi thay đổi sau điểm đó **mất hết**.
- Giữ tối đa ~5 snapshot (nhiều quá VM chậm); xóa cái cũ bằng chuột phải → Delete.

Snapshot sạch của nền tảng là `s2-gd1-task1-done`.

## 6. Dựng lại VM từ đầu (nếu không có file .ova)

Nếu không thể nhập file `.ova`, bạn có thể tự tạo và cấu hình lại máy ảo theo tài liệu hướng dẫn chi tiết tại:
[**Hướng dẫn dựng lại VM từ đầu (REBUILD_VM.md)**](REBUILD_VM.md)