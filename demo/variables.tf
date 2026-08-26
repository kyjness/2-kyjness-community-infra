variable "project_name" {
  type        = string
  default     = "puppytalk-demo"
  description = "리소스 이름 접두·비용 할당 태그에 공통 사용"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_profile" {
  type        = string
  default     = "puppytalk"
  description = <<-EOT
    자격증명 프로필(~/.aws/credentials). 기본값을 두는 이유는 이 워크스테이션에 다른 계정
    프로필이 여럿 있고 그중 `default`가 **다른 조직의 SSO 계정**이기 때문이다 — 지정하지 않으면
    기본 자격증명 체인이 그쪽을 집어 데모가 엉뚱한 계정에 만들어진다.
    다른 머신에서 이름이 다르면 `-var aws_profile=...`로 덮는다.
  EOT
}

variable "domain_name" {
  type        = string
  default     = "puppytalk.shop"
  description = "apex는 프론트(CloudFront), api 서브도메인은 백엔드(Lightsail)로 붙는다"
}

# --- Lightsail (백엔드 한 대) ---
variable "lightsail_bundle_id" {
  type        = string
  default     = "small_3_0"
  description = <<-EOT
    인스턴스 플랜. small_3_0 = 2GB RAM · 2 vCPU · SSD 60GB · 전송 3TB.
    이 스택(Caddy·API·워커·PostgreSQL·Redis)의 상주 메모리가 약 1.1GB라 2GB + swap이면 충분하다.
    micro_3_0(1GB)은 마이그레이션·시드 중 OOM 위험이 있어 쓰지 않는다.
  EOT
}

variable "lightsail_blueprint_id" {
  type        = string
  default     = "amazon_linux_2023"
  description = "OS 이미지. 기본 로그인 사용자는 ec2-user"
}

variable "lightsail_availability_zone" {
  type    = string
  default = "ap-northeast-2a"
}

variable "ssh_public_key" {
  type        = string
  description = <<-EOT
    배포·운영용 SSH 공개키(ssh-ed25519 …). 대응하는 개인키는 GitHub Secrets(DEPLOY_SSH_KEY)에 둔다.
    공개키는 비밀이 아니므로 tfvars에 넣어도 무방하다.
  EOT
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = <<-EOT
    22번 포트를 열어줄 대역.

    기본이 전체 공개인 이유: 배포(CD)가 GitHub Actions 러너에서 SSH로 들어오는데 러너의
    공인 IP가 고정이 아니다. 대신 인증은 키 전용이다 — Amazon Linux 2023은 비밀번호
    로그인이 기본 비활성이고, 이 인스턴스에는 등록된 공개키(ssh_public_key)만 들어온다.

    배포를 손으로만 할 거라면 ["<내 IP>/32"] 로 좁히는 편이 낫다.
  EOT
}

variable "docker_compose_version" {
  type        = string
  default     = "v2.32.4"
  description = "user_data가 설치하는 compose 플러그인 버전(고정 = 재현 가능한 부트스트랩)"
}

# --- GitHub Actions OIDC (프론트 배포 전용) ---
variable "github_fe_oidc_subject" {
  type        = string
  default     = "repo:kyjness/puppytalk-fe:*"
  description = <<-EOT
    이 subject 패턴에 맞는 워크플로만 FE 배포 롤을 맡을 수 있다.

    `ref:refs/heads/main`으로 좁혔더니 **수동 실행(workflow_dispatch)이 막혔다.** GitHub이
    그때 발급하는 sub는 `ref:...` 형태가 아니라서다. 워크플로는 `workflow_dispatch`를 허용하는데
    IAM이 거부해 둘이 어긋나 있었고, 첫 배포에서 드러났다 —
    `Not authorized to perform sts:AssumeRoleWithWebIdentity`.

    최초 배포·긴급 재배포에는 수동 트리거가 필요하므로 저장소 단위(`:*`)로 넓힌다. 이 저장소는
    공개지만 **포크의 워크플로는 이 토큰을 못 받는다**(GitHub이 sub에 원본 저장소를 넣는다).
    남는 것은 "이 저장소의 어느 브랜치에서든 배포 롤을 맡을 수 있다"이고, 롤 권한 자체가
    프론트 버킷 쓰기 + CloudFront 무효화로 한정돼 있어 수용한다.

    백엔드 배포는 Lightsail에 IAM 롤을 붙일 수 없어 SSH로 하며, 그래서 BE용 OIDC 롤은 없다.
  EOT
}
