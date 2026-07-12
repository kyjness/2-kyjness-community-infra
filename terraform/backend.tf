# Terraform 원격 상태(remote state).
# 멀티 인스턴스·무중단·팀 협업을 전제한다면 로컬 tfstate는 성립하지 않는다:
#   - S3 = 상태 저장(버저닝으로 이력·복구)
#   - DynamoDB = 상태 잠금(LockID) → 동시 apply 충돌 방지
# (Terraform 1.10+는 S3 네이티브 lockfile(use_lockfile)로 DynamoDB를 대체 가능하나,
#  required_version 하한 호환을 위해 DynamoDB 잠금을 표준으로 둔다.)
#
# partial configuration: 버킷·테이블 등 환경별 값은 커밋하지 않고
#   `terraform init -backend-config=backend.hcl` 로 주입한다(환경·계정 분리).
# 이 레포는 apply하지 않는 '설계 아티팩트'이므로 검증은 `terraform init -backend=false`로 수행.
#
# 상태 백엔드 부트스트랩(선행): state 버킷은 자기 자신을 상태로 담을 수 없으므로,
#   버저닝+SSE+퍼블릭 차단된 S3 버킷과 LockID 해시키를 가진 DynamoDB 테이블을
#   별도 부트스트랩 단계에서 먼저 생성한다.
terraform {
  backend "s3" {
    # 값은 -backend-config로 주입 (backend.hcl.example 참고)
    #   bucket         = "puppytalk-tfstate"
    #   key            = "terraform/aws/terraform.tfstate"
    #   region         = "ap-northeast-2"
    #   dynamodb_table = "puppytalk-tfstate-lock"
    #   encrypt        = true
  }
}
