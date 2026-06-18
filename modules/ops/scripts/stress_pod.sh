#!/bin/sh
# ticketing 파드에 stress-ng ephemeral container 를 붙여 CPU 부하를 건다.
# (bastion 에 stress 를 설치하지 않고, 대상 파드의 컨텍스트에서 직접 부하)
#
# 사용: ./stress_pod.sh <pod-name> [cpu=2] [duration=300s]
# 예:   ./stress_pod.sh ticketing-event-xxxx 2 300s
#
# 주의: ephemeral container 는 resource requests 가 없어 HPA(CPU%) 계산식에 직접 잡히지 않을 수 있다.
#       파드 cgroup·노드 부하는 발생하므로 노드 압박/관측엔 유효하나, HPA 스케일아웃 트리거가 목적이면
#       앱 컨테이너 자체 부하(또는 k6 HTTP 트래픽) 병행을 검토한다.
set -eu

NS="${NS:-ticketing}"
POD="${1:?usage: stress_pod.sh <pod-name> [cpu] [duration]}"
CPU="${2:-2}"
DUR="${3:-300s}"

kubectl debug -n "$NS" "pod/$POD" \
  --image=ghcr.io/colinianking/stress-ng:latest \
  --target=app -- \
  stress-ng --cpu "$CPU" --timeout "$DUR" --metrics-brief
