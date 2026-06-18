#!/bin/sh
# bastion 에서 in-cluster prometheus-server 를 호스트 9090 으로 포트포워드.
# grafana/k6 컨테이너는 host.docker.internal:9090 으로 이 리스너에 접근(compose extra_hosts).
#
# 사용: ./prometheus_portforward.sh            # 포그라운드
#       nohup ./prometheus_portforward.sh >/tmp/pf.log 2>&1 &   # 백그라운드 상주
#
# --address 0.0.0.0 : 컨테이너(docker bridge)에서도 닿도록 모든 인터페이스에 바인드
set -eu

NS="${NS:-monitoring}"
SVC="${SVC:-svc/cc-dev-prometheus-server}"   # helm release "cc-dev-prometheus" → <release>-server
LOCAL_PORT="${LOCAL_PORT:-9090}"

echo "port-forward ${NS}/${SVC} → 0.0.0.0:${LOCAL_PORT} (Ctrl-C 종료)"
exec kubectl -n "$NS" port-forward --address 0.0.0.0 "$SVC" "${LOCAL_PORT}:80"
