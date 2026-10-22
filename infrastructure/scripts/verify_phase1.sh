#!/bin/bash
# Kiểm tra nghiệm thu Giai đoạn 1. Chạy trong VM: ./verify_phase1.sh
FAIL=0
ok(){ echo "[PASS] $1"; }
bad(){ echo "[FAIL] $1"; FAIL=1; }

total=$(free -m | awk '/^Mem:/ {print $2}')
[ "$total" -le 3072 ] && ok "RAM VM = ${total} MB (<= 3072)" || bad "RAM VM = ${total} MB"

swap=$(free -m | awk '/^Swap:/ {print $2}')
[ "$swap" -eq 0 ] && ok "Swap đã tắt" || bad "Swap đang bật (${swap} MB)"

systemctl is-active --quiet elasticsearch && ok "Elasticsearch đang chạy" || bad "Elasticsearch không chạy"

code=$(curl -s -o /dev/null -w '%{http_code}' localhost:9200)
[ "$code" = "200" ] && ok "GET :9200 không cần xác thực (X-Pack Security tắt)" || bad "GET :9200 trả về $code"

heap=$(curl -s 'localhost:9200/_nodes/jvm?filter_path=nodes.*.jvm.mem.heap_max_in_bytes' | grep -o '[0-9]\{6,\}' | head -1)
if [ -n "$heap" ] && [ "$heap" -ge 1000000000 ] && [ "$heap" -le 1100000000 ]; then
  ok "Heap max = $((heap/1048576)) MB (~1GB)"
else
  bad "Heap max = ${heap:-N/A}"
fi

sysctl -n vm.max_map_count | awk '{exit !($1>=262144)}' && ok "vm.max_map_count >= 262144" || bad "vm.max_map_count quá thấp"

echo "[INFO] Phiên bản ES: $(curl -s localhost:9200 | grep '"number"' | tr -d ' ,')"
echo "[INFO] Cluster: $(curl -s localhost:9200/_cluster/health | grep -o '"status":"[a-z]*"')"
echo "[INFO] free -m:"; free -m
exit $FAIL
