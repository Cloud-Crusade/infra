# aws_lb_controller

EKS에 AWS Load Balancer Controller를 설치한다(IRSA + Helm). terraform 소유 NLB/ALB 타겟그룹에
파드 IP를 등록하는 `TargetGroupBinding` 등 CRD를 제공하며, NLB↔EKS 와이어링(#133)의 전제다.

## 버전 핀 (함께 움직여야 함)

| 항목 | 값 | 출처 |
|---|---|---|
| Helm 차트 (`chart_version`) | `1.11.0` | aws/eks-charts |
| 앱(컨트롤러) | `v2.11.0` | kubernetes-sigs/aws-load-balancer-controller |
| `iam_policy.json` | `v2.11.0` | 위 레포 `docs/install/iam_policy.json` |

`chart_version`을 올리면 **`iam_policy.json`과 CRD도 같은 버전으로 함께 갱신**해야 한다. 셋 중
하나라도 어긋나면 권한 부족(AccessDenied) 또는 CRD 스키마 불일치로 프로비저닝이 실패한다.

## 업그레이드 절차

Helm은 차트의 CRD를 **최초 설치 때만** 적용하고 `upgrade` 때는 갱신하지 않는다. 따라서 버전을
올릴 때는 아래 순서를 지킨다(`<VER>` = 예: `v2.12.0`).

```sh
# 1) 새 버전 CRD 수동 선적용 (Helm 이 안 올려줌)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/<VER>/helm/aws-load-balancer-controller/crds/crds.yaml

# 2) IAM 정책 동기화 (같은 버전 태그로 교체)
curl -o modules/aws_lb_controller/iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/<VER>/docs/install/iam_policy.json

# 3) chart_version 갱신 후 apply (chart 1.x.y == app v2.x.y)
#    variables.tf 기본값 변경 또는 -var 'chart_version=1.x.y'
terraform apply
```
