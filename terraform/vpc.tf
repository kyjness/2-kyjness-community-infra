# 1. VPC 생성 (10.0.0.0/16 대역)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # EC2 도메인 접속을 위해 필수
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. 퍼블릭 서브넷 1 (가용영역 2a) - ALB 및 퍼블릭 서비스용
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true # 이 서브넷에 생성되는 리소스는 퍼블릭 IP를 가짐

  tags = {
    Name = "${var.project_name}-public-1"
  }
}

# 3. 퍼블릭 서브넷 2 (가용영역 2c) - 고가용성을 위한 보조 서브넷
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-2"
  }
}

# 4. 인터넷 게이트웨이 (VPC의 대문)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 5. 퍼블릭 라우팅 테이블 (인터넷으로 나가는 경로 설정)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # 모든 외부 트래픽은
    gateway_id = aws_internet_gateway.igw.id # 인터넷 게이트웨이로 보냄
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 6. 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}