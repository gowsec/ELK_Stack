# Hướng dẫn Teammate kết nối vào Azure VM
> Tài liệu chỉ mang tính chất tham khảo, các bạn có thể sử dụng AI hoặc nguồn tài liệu khác để tối ưu lệnh cho nhiệm vụ.

## 1. Mô hình kết nối

VM được tạo trên Azure và chạy Ubuntu Server.

Mỗi thành viên trong team sẽ có một SSH key riêng.

```sh
Teammate A
    │
    ├── Private Key
    │      (chỉ A giữ)
    │
    └── Public Key
           │
           │ gửi cho Leader
           ↓
      Azure VM
           │
           └── ~/.ssh/authorized_keys
```

## 2. Nguyên tắc bảo mật
**Mỗi thành viên phải có SSH key riêng.**

```sh 
Leader
├── elk-server-key.pem       ← PRIVATE KEY của Leader
└── public key                ← được lưu trên VM

Teammate A
├── id_ed25519                ← PRIVATE KEY của A
└── id_ed25519.pub            ← PUBLIC KEY của A

Teammate B
├── id_ed25519                ← PRIVATE KEY của B
└── id_ed25519.pub            ← PUBLIC KEY của B
```

**Tuyệt đối KHÔNG:**

- Gửi private key cho Leader hoặc teammate khác.
- Upload private key lên GitHub.
- Commit private key vào repository.
- Dùng chung file .pem của Leader.
- Gửi file id_ed25519 cho người khác.
- Chỉ được gửi **public key** (`.pub`).

## 3. Teammate tạo SSH key
Teammate thực hiện trên chính máy của mình.
* **macOS / Linux**
```sh
ssh-keygen -t ed25519 -C "(your_name)"
```
Sau khi tạo xong, cặp SSH key thường được lưu tại:
```sh
~/.ssh/
├── id_ed25519
└── id_ed25519.pub
```

* **Windows**

Mở sh hoặc Command Prompt và chạy:
 
```sh
ssh-keygen -t ed25519 -C "(your_name)"
```
Sau khi tạo xong, cặp SSH key thường được lưu tại:
```sh
C:\Users\<username>\.ssh\

├── id_ed25519
└── id_ed25519.pub
```

Trong đó:
- `id_ed25519` = Private key
- `id_ed25519`.pub = Public key

## 4. Lấy Public Key
* **macOS / Linux**
Chạy:
```sh
cat ~/.ssh/id_ed25519.pub
```

* **Windows**
```sh
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

- Copy toàn bộ -> Gửi dòng public key cho Leader.
- Không gửi: `id_ed25519`.

## 5. Chờ leader xử lí
- Thêm Public Key của Teammate vào VM.
- Tạo Linux user cho Teammate.
- Tạo thư mục SSH cho Teammate.
- Thêm Public Key của Teammate.
- Thiết lập quyền cho SSH.
- Leader sẽ báo lại cho teammate. 

## 6. Teammate kết nối vào VM
- Teammate sử dụng private key của chính mình.
* **macOS / Linux**
Ví dụ:
```sh
ssh -i ~/.ssh/id_ed25519 teammateA@PUBLIC_IP
```

* **Windows**
Ví dụ:
```sh
ssh -i $env:USERPROFILE\.ssh\id_ed25519 teammateA@PUBLIC_IP
```
- Nếu thành công, sẽ thấy:
```sh
teammateA@elk-server:~$
```

- Sau khi kết nối xong, teammate có thể bắt đầu làm nhiệm vụ của mình. 

**Lưu ý:** PUBLIC_IP sẽ được Leader gửi vào group chat mỗi khi bật VM

## 7. Cách thoát VM
- Teammate exit ssh trên terminal đang chạy.
- Báo leader để stop VM (tránh tốn thêm credit).

