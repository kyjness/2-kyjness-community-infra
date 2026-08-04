# 백엔드 전부가 이 인스턴스 한 대에 있다 — Caddy(TLS 종단) · API · Celery 워커 ·
# PostgreSQL · Redis가 docker compose로 함께 뜬다(puppytalk-be/compose.prod.yml).
#
# EC2가 아니라 Lightsail인 이유: 고정 IP·디스크·전송이 요금에 포함돼 월 비용이 절반이고,
# 데모 등급에는 VPC·보안그룹·NAT를 직접 다룰 이유가 없다. 대가는 IAM 인스턴스 롤이 없어
# SSM 무키 배포를 못 쓰는 것(→ SSH 배포). 근거는 puppytalk-be ADR 0015.

resource "aws_lightsail_key_pair" "deploy" {
  name       = "${var.project_name}-deploy"
  public_key = var.ssh_public_key
}

resource "aws_lightsail_instance" "app" {
  name              = "${var.project_name}-app"
  availability_zone = var.lightsail_availability_zone
  blueprint_id      = var.lightsail_blueprint_id
  bundle_id         = var.lightsail_bundle_id
  key_pair_name     = aws_lightsail_key_pair.deploy.name

  # 여기서는 "컨테이너를 돌릴 수 있는 상태"까지만 만든다. compose 파일과 .env.prod(시크릿)는
  # 최초 1회 scp로 올린다 — user_data에 시크릿을 넣으면 인스턴스 메타데이터에 평문으로 남는다.
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user

    # compose는 플러그인으로 설치(버전 고정 — 부트스트랩이 매번 같은 결과를 내도록).
    mkdir -p /usr/libexec/docker/cli-plugins
    curl -sSL "https://github.com/docker/compose/releases/download/${var.docker_compose_version}/docker-compose-linux-x86_64" \
      -o /usr/libexec/docker/cli-plugins/docker-compose
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

    # 2GB 인스턴스에서 마이그레이션·시드가 순간적으로 메모리를 밀어올릴 때 OOM 킬러가
    # PostgreSQL을 먼저 죽이는 일을 막는 완충재.
    if [ ! -f /swapfile ]; then
      dd if=/dev/zero of=/swapfile bs=1M count=2048
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    mkdir -p /opt/puppytalk
    chown ec2-user:ec2-user /opt/puppytalk

    # DB 백업(매일 04:00 KST = 19:00 UTC). 스크립트는 배포 파일과 함께 올라온다.
    echo '0 19 * * * ec2-user cd /opt/puppytalk && ./backup_db.sh >> /var/log/puppytalk-backup.log 2>&1' \
      > /etc/cron.d/puppytalk-backup
  EOT
}

resource "aws_lightsail_static_ip" "app" {
  name = "${var.project_name}-ip"
}

resource "aws_lightsail_static_ip_attachment" "app" {
  static_ip_name = aws_lightsail_static_ip.app.name
  instance_name  = aws_lightsail_instance.app.name
}

# 이 블록이 인스턴스의 방화벽 규칙 **전체**를 대체한다(여기 없는 규칙은 닫힌다).
resource "aws_lightsail_instance_public_ports" "app" {
  instance_name = aws_lightsail_instance.app.name

  port_info {
    protocol  = "tcp"
    from_port = 80 # ACME HTTP-01 챌린지 + HTTPS 리다이렉트
    to_port   = 80
    cidrs     = ["0.0.0.0/0"]
  }

  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
    cidrs     = ["0.0.0.0/0"]
  }

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    # CD가 GitHub Actions 러너에서 SSH로 들어온다 — 러너 IP가 고정이 아니라 기본은 전체 공개다.
    # 인증은 키 전용(AL2023은 비밀번호 로그인 기본 비활성). 자세한 판단은 변수 설명 참조.
    cidrs = var.ssh_allowed_cidrs
  }
}
