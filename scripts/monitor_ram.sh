#!/bin/bash
# Ghi log RAM định kỳ ra CSV. Dùng: ./monitor_ram.sh [giây=5] [file=results/ram_log.csv]
# Cột *_rss_mb = RAM thực của từng tiến trình (=0 nếu chưa cài hoặc đang dừng).
INTERVAL=${1:-5}
OUT=${2:-results/ram_log.csv}
mkdir -p "$(dirname "$OUT")"
[ -f "$OUT" ] || echo "time,total_mb,used_mb,available_mb,swap_used_mb,es_rss_mb,kibana_rss_mb,filebeat_rss_mb,nginx_rss_mb,es_heap_used_mb" > "$OUT"
trap 'echo "Đã dừng ghi log: $OUT"; exit 0' INT TERM

svc_rss() {   # Tổng RSS (MB) của MỌI tiến trình thuộc 1 service systemd (tính cả tiến trình con như JVM)
  local cg s=0 p kb
  cg=$(systemctl show -p ControlGroup --value "$1" 2>/dev/null)
  if [ -z "$cg" ] || [ ! -r "/sys/fs/cgroup$cg/cgroup.procs" ]; then echo 0; return; fi
  for p in $(cat "/sys/fs/cgroup$cg/cgroup.procs"); do
    kb=$(awk '/VmRSS/ {print $2}' /proc/$p/status 2>/dev/null)
    s=$((s + ${kb:-0}))
  done
  echo $((s / 1024))
}

echo "Đang ghi log mỗi ${INTERVAL}s vào $OUT (Ctrl+C để dừng)"
while true; do
  read -r total used avail < <(free -m | awk '/^Mem:/ {print $2, $3, $7}')
  swap=$(free -m | awk '/^Swap:/ {print $3}')
  es=$(svc_rss elasticsearch); kb=$(svc_rss kibana); fb=$(svc_rss filebeat)
  ng=$(ps -C nginx -o rss= 2>/dev/null | awk '{s+=$1} END {printf "%d", s/1024}')
  heap=$(curl -s --max-time 2 'localhost:9200/_nodes/stats/jvm?filter_path=nodes.*.jvm.mem.heap_used_in_bytes' \
        | grep -o '"heap_used_in_bytes":[0-9]*' | head -1 | cut -d: -f2)
  heap=$(( ${heap:-0} / 1048576 ))
  echo "$(date '+%F %T'),$total,$used,$avail,$swap,${es:-0},${kb:-0},${fb:-0},${ng:-0},$heap" >> "$OUT"
  sleep "$INTERVAL"
done
