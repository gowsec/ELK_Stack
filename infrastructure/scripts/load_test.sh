#!/bin/bash
# Tạo tải nhẹ lên Elasticsearch để có số liệu RAM có ý nghĩa. Dùng: ./load_test.sh [số_doc=2000]
N=${1:-2000}
for i in $(seq 1 "$N"); do
  curl -s -o /dev/null -XPOST localhost:9200/test-load/_doc -H 'Content-Type: application/json' \
    -d "{\"n\":$i,\"msg\":\"hello elk\",\"ts\":\"$(date -Is)\"}"
done
curl -s -XPOST localhost:9200/test-load/_refresh >/dev/null
echo "Đã index: $(curl -s localhost:9200/test-load/_count)"
curl -s -o /dev/null -XDELETE localhost:9200/test-load
