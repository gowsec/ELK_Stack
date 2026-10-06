# Cấu hình Task 2 (Nginx + Filebeat)

Mỗi file nằm trong thư mục của chương trình **đọc** nó. Muốn dựng lại, chép file về đúng đường dẫn trên VM:

| File trong repo | Đường dẫn trên VM |
|---|---|
| `config/nginx/default` | `/etc/nginx/sites-available/default` |
| `config/nginx/realip.conf` | `/etc/nginx/conf.d/realip.conf` |
| `config/filebeat/filebeat.yml` | `/etc/filebeat/filebeat.yml` |
| `config/filebeat/nginx.yml` | `/etc/filebeat/modules.d/nginx.yml` |

Sau khi chép:

```bash
sudo nginx -t && sudo systemctl reload nginx
sudo filebeat test config && sudo filebeat test output
sudo filebeat setup --pipelines --modules nginx -M "nginx.access.enabled=true" -M "nginx.error.enabled=true"
sudo filebeat setup --index-management
sudo systemctl enable --now filebeat
```

Lưu ý: `realip.conf` tin header `X-Forwarded-For` từ `127.0.0.1` và `10.0.2.0/24` để giả IP khi demo. Không dùng cấu hình này ngoài môi trường demo.