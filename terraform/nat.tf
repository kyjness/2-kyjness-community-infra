# -----------------------------------------------------------------------------
# NAT + 프라이빗 라우팅.
# app tier: AZ별 NAT GW로 egress (한 AZ의 NAT 장애가 다른 AZ 태스크에 영향 없도록 HA).
#   → 비용 절감이 우선이면 단일 NAT + 단일 app 라우트 테이블로 축소 가능(운영 전제상 HA 채택).
# data tier: 인터넷 경로 없음(격리) — 라우트 테이블에 로컬 경로만.
# -----------------------------------------------------------------------------

resource "aws_eip" "nat_1" {
  domain     = "vpc"
  tags       = { Name = "${var.project_name}-nat-eip-1" }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_2" {
  domain     = "vpc"
  tags       = { Name = "${var.project_name}-nat-eip-2" }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "az_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id # NAT는 퍼블릭 서브넷에 위치
  tags          = { Name = "${var.project_name}-nat-1" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "az_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id
  tags          = { Name = "${var.project_name}-nat-2" }
  depends_on    = [aws_internet_gateway.igw]
}

# App tier 라우트 테이블 — AZ별 NAT로 0.0.0.0/0
resource "aws_route_table" "private_app_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.az_1.id
  }

  tags = { Name = "${var.project_name}-private-app-rt-1" }
}

resource "aws_route_table" "private_app_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.az_2.id
  }

  tags = { Name = "${var.project_name}-private-app-rt-2" }
}

resource "aws_route_table_association" "private_app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private_app_1.id
}

resource "aws_route_table_association" "private_app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private_app_2.id
}

# Data tier 라우트 테이블 — 로컬 경로만(인터넷 격리). 두 data 서브넷 공유.
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-private-data-rt" }
}

resource "aws_route_table_association" "private_data_1" {
  subnet_id      = aws_subnet.private_data_1.id
  route_table_id = aws_route_table.private_data.id
}

resource "aws_route_table_association" "private_data_2" {
  subnet_id      = aws_subnet.private_data_2.id
  route_table_id = aws_route_table.private_data.id
}
