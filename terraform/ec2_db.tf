locals {
  db_bootstrap_script = <<-SCRIPT
#!/bin/bash
# 로그 기록 설정
exec > >(tee /var/log/user-data-db.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== AL2023 DB Bootstrap Started ==="

# 1. 패키지 업데이트 및 설치
dnf update -y
dnf install -y postgresql15-server postgresql15 postgresql15-contrib redis6

# 2. Postgres 초기화
if [ ! -d /var/lib/pgsql/data/base ]; then
  /usr/bin/postgresql-setup --initdb
fi

# 3. 외부 접속 및 인증 방식 수정 (Ident -> md5)
# 모든 접속 주소를 허용하도록 설정
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# 💡 [핵심] 기존의 모든 ident 인증을 md5(비밀번호 방식)로 교체합니다.
sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

# 만약 0.0.0.0/0 규칙이 없다면 추가
if ! grep -q "0.0.0.0/0" /var/lib/pgsql/data/pg_hba.conf; then
  echo "host all all 0.0.0.0/0 md5" >> /var/lib/pgsql/data/pg_hba.conf
fi

# 4. Postgres 서비스 시작
systemctl enable --now postgresql

# 5. DB 사용자 비밀번호 설정 및 DB 생성
# 변수에서 가져온 비밀번호를 안전하게 주입
DBPASS="${var.db_master_password}"
ESC_PASS=$(echo "$DBPASS" | sed "s/'/''/g")
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ESC_PASS';"

# puppytalk DB 생성
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'puppytalk'" | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE puppytalk;" || true

# 6. Redis 설정 및 시작 (외부 접속 허용)
if [ -f /etc/redis6/redis6.conf ]; then
  sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis6/redis6.conf || true
  sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis6/redis6.conf || true
  systemctl enable --now redis6
fi

echo "=== AL2023 DB Bootstrap Completed Successfully ==="
SCRIPT
}

# 1. 최신 Amazon Linux 2023 AMI ID 찾기
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }
}

# 2. SSH 접속을 위한 키 페어
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/id_rsa.pub") 
}

# 3. 데이터베이스 전용 EC2 인스턴스
resource "aws_instance" "db_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro" 

  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.db_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true 

  user_data                   = local.db_bootstrap_script
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-db-server"
  }
}

# 4. 접속 주소 출력
output "db_server_public_ip" {
  value       = aws_instance.db_server.public_ip
}

output "db_server_private_ip" {
  value       = aws_instance.db_server.private_ip
}