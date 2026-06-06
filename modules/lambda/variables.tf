variable "lambda_role_arn" {
  type        = string
  description = "Lambda 함수 실행에 필요한 IAM Role ARN. 모든 Lambda에서 공통으로 사용되는 필수 값입니다."
}

variable "lambdas" {
  description = "Lambda 설정 맵. 각 Lambda별 소스, 핸들러, 타임아웃, 레이어, 환경변수를 정의합니다. 시크릿 값은 포함하지 않습니다."

  type = map(object({
    source_dir    = string
    function_name = string
    handler       = string
    timeout       = number
    lambda_layers = list(string)
    lambda_env    = map(string)
  }))
}