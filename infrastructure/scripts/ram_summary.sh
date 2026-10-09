#!/bin/bash
# Tóm tắt số liệu RAM từ file CSV. Dùng: ./ram_summary.sh [results/ram_log.csv]
F=${1:-results/ram_log.csv}
awk -F, '
NR==1 {for(i=1;i<=NF;i++) c[$i]=i; next}
{ n++; total=$c["total_mb"]; u=$c["used_mb"]; a=$c["available_mb"]
  su+=u; if(u>umax)umax=u; if(amin==""||a<amin)amin=a
  if($c["swap_used_mb"]>sw)sw=$c["swap_used_mb"]
  if($c["es_rss_mb"]>es)es=$c["es_rss_mb"]
  if($c["kibana_rss_mb"]>kb)kb=$c["kibana_rss_mb"]
  if($c["filebeat_rss_mb"]>fb)fb=$c["filebeat_rss_mb"]
  if($c["nginx_rss_mb"]>ng)ng=$c["nginx_rss_mb"]
  if($c["es_heap_used_mb"]>hp)hp=$c["es_heap_used_mb"] }
END { if(n==0){print "Chưa có dữ liệu"; exit}
  printf "Số mẫu: %d\nTổng RAM VM: %d MB\nUsed trung bình: %.0f MB | cao nhất: %d MB\nAvailable thấp nhất: %d MB\nSwap used cao nhất: %d MB\n", n,total,su/n,umax,amin,sw
  printf "RSS cao nhất: ES %d | Kibana %d | Filebeat %d | Nginx %d (MB)\nES heap used cao nhất: %d MB\n", es,kb,fb,ng,hp }' "$F"
