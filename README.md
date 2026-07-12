# PuppyTalk Infra

반려견 커뮤니티 **PuppyTalk**의 인프라(IaC) 레포입니다. Terraform으로 AWS 운영 등급 토폴로지를
코드로 기술합니다 — **1차: ECS Fargate 스택**(`terraform/`)과 **대안: 쿠버네티스(EKS) 트랙**(`eks/`).
두 트랙은 **서로 독립된 root**이며, "왜 둘 다 두었나"는 아래 [ECS vs EKS 판단 근거](#5-ecs-vs-eks--왜-둘-다-두었나-판단-근거)에서 설명합니다.

- 백엔드: [PuppyTalk Backend](https://github.com/kyjness/2-kyjness-community-be)
- 프론트엔드: [PuppyTalk Frontend](https://github.com/kyjness/2-kyjness-community-fe)

---

## 1. 배포 모델 — 설계와 실행의 분리

| 트랙 | 정체 | 위치 | 상태 |
|------|------|------|------|
| **AWS 운영 설계** | 프라이빗 3-tier · ALB · ECS Fargate · RDS · ElastiCache · CloudFront 등 운영 등급 토폴로지 | 이 레포 `terraform/` · `eks/` | **설계 산출물** — 상시 과금(ALB·Fargate·RDS·NAT)을 피하려 **`apply` 하지 않음** |
| **라이브 데모** | 실제 공개 URL로 돌아가는 데모 | be/fe 레포 | 무료 티어(Vercel·Fly·Neon·Upstash·R2)로 별도 구동 *(구성 예정)* |

> Terraform 스택은 "이렇게 운영 등급으로 설계했다"를 코드로 증명하는 산출물이고(무료·미적용),
> 비용 0의 공개 데모는 무료 티어에서 별도로 돌립니다. **설계 깊이와 실제 과금은 별개 축**입니다.

---

## 2. 레포 구조

```text
2-kyjness-community-infra/
├── terraform/                    # 1차 스택: AWS ECS Fargate (단일 root)
│   ├── provider.tf backend.tf    #  프로바이더·default_tags · S3+DynamoDB 원격 상태
│   ├── variables.tf outputs.tf
│   ├── vpc.tf nat.tf             #  네트워크: 3-tier 서브넷 · AZ별 NAT
│   ├── vpc_endpoints.tf security_group.tf
│   ├── alb.tf ecs.tf             #  로드밸런서 · Fargate 서비스/태스크
│   ├── ecs_autoscaling.tf ecr.tf #  오토스케일 · 이미지 레지스트리(+lifecycle)
│   ├── rds.tf elasticache.tf     #  데이터 계층: PostgreSQL · Redis
│   ├── cloudfront.tf frontend.tf media.tf   #  CDN · 정적/미디어 S3
│   ├── dns.tf acm.tf             #  Route 53 · ACM(TLS)
│   ├── ssm.tf iam.tf iam_github_oidc.tf     #  시크릿 · 권한 · GitHub OIDC
│   ├── sns.tf cloudwatch.tf      #  알림 · 로그
│   └── *.example                 #  terraform.tfvars.example · backend.hcl.example
└── eks/                          # 대안 트랙: 쿠버네티스 (별도 root)
    ├── provider.tf variables.tf outputs.tf
    ├── vpc.tf eks.tf irsa.tf     #  VPC 모듈 · EKS 모듈 · Cluster Autoscaler IRSA
    └── k8s/
        ├── base/                 #  Deployment · Service · HPA · kustomization
        ├── overlays/prod-seoul/  #  환경 오버레이(ConfigMap · GHCR 이미지 치환)
        └── rollout-bluegreen/    #  Argo Rollouts 블루/그린(대안 배포 전략)
```

---

## 3. AWS 운영 스택 (`terraform/` — 1차 · ECS Fargate)

리전 `ap-northeast-2`(서울), CloudFront용 ACM만 `us-east-1`. VPC `10.0.0.0/16`,
**3-tier**: 퍼블릭(ALB·NAT) / 프라이빗 app(ECS) / 프라이빗 data(RDS·Redis, 인터넷 격리).

### 아키텍처 다이어그램

```mermaid
flowchart TB
    user([사용자])
    gha["GitHub Actions<br/>OIDC AssumeRole"]

    subgraph edge["엣지 · DNS · TLS"]
        r53["Route 53<br/>Hosted Zone"]
        acm["ACM<br/>us-east-1(CF) · ap-northeast-2(ALB)"]
        cf["CloudFront + OAC"]
    end

    subgraph vpc["VPC 10.0.0.0/16 · Multi-AZ(2a·2c)"]
        igw["Internet Gateway"]
        subgraph pub["퍼블릭 서브넷 10.0.1/2"]
            alb["ALB<br/>80 to 443 redirect · TLS 종단"]
            nat["NAT GW x2<br/>AZ별 HA"]
        end
        subgraph appt["프라이빗 app 서브넷 10.0.11/12"]
            ecs["ECS Fargate<br/>be 서비스 · Auto Scaling(CPU 70%)"]
            vpce["VPC 엔드포인트<br/>ECR·Logs·SSM(Interface) · S3(Gateway)"]
        end
        subgraph datat["프라이빗 data 서브넷 10.0.21/22 · 인터넷 격리"]
            rds[("RDS PostgreSQL<br/>Multi-AZ · gp3 암호화 · 자동 백업")]
            redis[("ElastiCache Redis<br/>primary+replica 자동 페일오버")]
        end
    end

    subgraph mng["관리형 · 스토리지"]
        s3fe[["S3<br/>프론트 정적"]]
        s3media[["S3<br/>미디어"]]
        ecr[["ECR<br/>be 이미지 (+lifecycle)"]]
        ssm[["SSM Parameter Store<br/>SecureString"]]
        sns[["SNS 알림"]]
        logs[["CloudWatch Logs"]]
    end

    user --> r53
    r53 -->|apex| cf
    r53 -->|api 서브도메인| alb
    cf -->|기본 경로| s3fe
    cf -->|미디어 경로| s3media
    acm -.인증서.-> cf
    acm -.인증서.-> alb
    alb -->|8000| ecs
    ecs -->|5432| rds
    ecs -->|6379| redis
    ecs -. egress .-> nat
    nat --> igw
    ecs -->|이미지·시크릿·로그| vpce
    vpce -.-> ecr
    vpce -.-> ssm
    vpce -.-> logs
    ecs -->|Task Role| sns
    ecs -->|Task Role| s3media

    gha -->|FE 롤: S3 sync + CF 무효화| s3fe
    gha -->|BE 롤: ECR push + ecs UpdateService| ecr
    gha -.배포.-> ecs
```

### 컴포넌트별 선택 근거

| 컴포넌트 | 리소스 | 왜 이렇게 |
|----------|--------|-----------|
| **네트워크** | 프라이빗 3-tier + NAT (`vpc.tf`·`nat.tf`) | app(ECS)·data(DB) 계층 분리. data 티어는 **인터넷 경로 없음**(격리), app egress는 **AZ별 NAT**(HA) |
| **컨테이너 실행** | ECS Fargate (`ecs.tf`) | 서버리스 컨테이너 — 노드 관리 없이 태스크만. **프라이빗 서브넷 배치**(퍼블릭 IP 없음), `ecs_autoscaling.tf`로 CPU 70% 타깃 추적 |
| **로드밸런서** | ALB (`alb.tf`) | `api.<domain>` 종단 TLS + 80→443 리다이렉트. ECS는 ALB SG에서만 8000 수신 |
| **정적 프론트 + CDN** | CloudFront + S3 (`cloudfront.tf`·`frontend.tf`) | 정적 SPA는 S3(OAC로 비공개) + CloudFront 캐시·TLS. 관리형 `CachingOptimized` 정책 + 압축 |
| **이미지 저장** | S3 media (`media.tf`) | 업로드 이미지, CloudFront 미디어 경로 서빙. 앱은 Task Role로 해당 버킷만 |
| **DB** | RDS PostgreSQL (`rds.tf`) | **Multi-AZ 자동 페일오버 · gp3 암호화 · 자동 백업**. data 티어, ECS SG에서만 5432 |
| **캐시·브로커** | ElastiCache Redis (`elasticache.tf`) | primary+replica **자동 페일오버 · Multi-AZ · at-rest 암호화**. data 티어, ECS SG에서만 6379 |
| **VPC 엔드포인트** | S3 gateway + ECR/Logs/SSM interface (`vpc_endpoints.tf`) | 프라이빗 ECS가 이미지 pull·시크릿·로그를 **NAT/인터넷 없이 AWS 백본**으로 → 비용·노출 감소 |
| **비동기 알림** | SNS (`sns.tf`) | 앱(boto3)이 **Task Role**로 발행 — AK/SK 불필요 |
| **로그** | CloudWatch Logs (`cloudwatch.tf`) | ECS awslogs 드라이버, 그룹은 Terraform이 사전 생성 |
| **이미지 레지스트리** | ECR (`ecr.tf`) | AWS-native, `scan_on_push` + **lifecycle 정책**(untagged·오래된 이미지 만료) |
| **시크릿** | SSM Parameter Store (`ssm.tf`) | `JWT_SECRET_KEY`·`DB_PASSWORD`를 SecureString으로 — 태스크 정의에 평문 미노출 |
| **DNS · TLS** | Route 53 · ACM (`dns.tf`·`acm.tf`) | 호스팅 영역 + apex/`api.` 레코드, ACM DNS 검증. CloudFront 인증서는 `us-east-1` |

### CI/CD — GitHub Actions + OIDC (정적 키 없음)

배포 자격은 장기 AK/SK 대신 **GitHub OIDC AssumeRole**로만 발급합니다 (`iam_github_oidc.tf`).

| 대상 | IAM Role | 권한 (최소) |
|------|----------|-------------|
| **FE** | `fe_github_actions` | S3 프론트 버킷 sync + CloudFront 무효화 |
| **BE** | `be_github_actions` | ECR push + `ecs:UpdateService`(지정 서비스 한정) |

> 이전에는 Jenkins EC2가 BE 배포를 담당했으나, 상시 과금·이중 CD 경로를 없애고 **GitHub OIDC
> 한 갈래로 일원화**했습니다. `be_github_actions`는 AWS 스택 `apply` 시 활성화되는 CD 경로 —
> 무료 라이브 데모 트랙은 BE 이미지를 GHCR→Fly로 배포하므로, 적용 전까지 이 롤은 휴면입니다.

**이미지 태그 전략(판단)**: 현재 BE 롤은 `ecs:UpdateService`만 가지며, `:latest` 가변 태그를
`--force-new-deployment`로 재배포하는 **단순 경로**입니다. 운영 정석은 **불변 SHA 태그 + 새 task
def 리비전 등록**(즉시 롤백·배포 추적성)이며, 이 경우 `ecs:RegisterTaskDefinition`·`iam:PassRole`이
추가로 필요합니다. 포트폴리오 범위에선 단순 경로를 유지하되, ECR 라이프사이클 정책(`ecr.tf`)으로
`:latest` 재푸시가 남기는 dangling 이미지를 정리해 가변 태그의 비용 부작용만 상쇄했습니다.

---

## 4. EKS 대안 트랙 (`eks/` — 별도 root)

"동일 앱을 쿠버네티스로 운영한다면"을 별도 root로 모델링합니다. 전용 VPC `10.1.0.0/16`(ECS 스택
`10.0.0.0/16`과 분리)에 **커뮤니티 모듈**로 클러스터를 세우고, 워크로드는 **Kustomize**로 렌더합니다.
데이터 계층(RDS·Redis)은 새로 만들지 않고 **`terraform/` 스택의 것을 공유**합니다.

### 아키텍처 다이어그램

```mermaid
flowchart TB
    user([사용자])
    ghcr[["GHCR<br/>ghcr.io/kyjness/puppytalk-be"]]

    subgraph vpc["EKS VPC 10.1.0.0/16 (terraform-aws-modules/vpc) · Multi-AZ"]
        subgraph pub["퍼블릭 서브넷 10.1.1/2 · role/elb"]
            alb["ALB<br/>(AWS Load Balancer Controller)"]
            nat["NAT GW (single)"]
        end
        subgraph priv["프라이빗 서브넷 10.1.11/12 · role/internal-elb"]
            subgraph eks["EKS 클러스터 v1.30 · 관리형 노드그룹 t3.medium(2~5)"]
                subgraph ns["namespace: puppytalk"]
                    deploy["Deployment puppytalk-api<br/>replicas 2 · /v1/health probe"]
                    svc["Service ClusterIP<br/>80 to 8000"]
                    hpa["HPA CPU 70%<br/>2~20"]
                    rollout["Argo Rollouts<br/>블루/그린(active·preview)<br/>대안 전략"]
                    cm["ConfigMap<br/>DB_HOST·REDIS_URL 등"]
                end
                subgraph ksys["namespace: kube-system"]
                    ca["Cluster Autoscaler"]
                end
            end
        end
    end

    irsa["IRSA IAM Role<br/>iam-role-for-service-accounts-eks"]
    rdsShared[("terraform/ RDS<br/>공유")]
    redisShared[("terraform/ ElastiCache<br/>공유")]

    user --> alb --> svc --> deploy
    hpa -.스케일.-> deploy
    rollout -. 대안 배포 .- deploy
    cm -.envFrom.-> deploy
    ghcr -->|이미지 pull| deploy
    deploy -->|5432| rdsShared
    deploy -->|6379| redisShared
    deploy -. egress .-> nat
    ca -->|노드 스케일| eks
    irsa -.assume SA.-> ca
```

### 구성

| 요소 | 리소스 | 설명 |
|------|--------|------|
| **네트워크** | `terraform-aws-modules/vpc` (`vpc.tf`) | 전용 VPC `10.1.0.0/16`, 퍼블릭/프라이빗 서브넷. `kubernetes.io/role/elb`·`internal-elb` 태그로 LB Controller가 서브넷 자동 발견. `single_nat_gateway`(비용 절감·설계용) |
| **클러스터** | `terraform-aws-modules/eks ~>20.31` (`eks.tf`) | EKS v1.30 + **관리형 노드그룹**(t3.medium, 2~5). 엔드포인트 public+private, `enable_irsa` |
| **파드 IAM** | Cluster Autoscaler IRSA (`irsa.tf`) | `iam-role-for-service-accounts-eks` 모듈 → `kube-system:cluster-autoscaler` SA에 역할 바인딩(파드 단위 최소 권한). 노드그룹 ASG엔 발견용 `k8s.io/cluster-autoscaler/*` 태그 |
| **워크로드(기본)** | `k8s/base` | Deployment(replicas 2, `/v1/health` readiness) · Service(ClusterIP 80→8000) · HPA(CPU 70%, 2~20) |
| **환경 오버레이** | `k8s/overlays/prod-seoul` | Kustomize `configMapGenerator`로 `DB_HOST`·`REDIS_URL` 등 주입, 이미지를 **GHCR**로 치환(`newName`/`newTag`) |
| **고급 배포(대안)** | `k8s/rollout-bluegreen` | **Argo Rollouts 블루/그린**(active/preview, 수동 승격). Rollouts Controller 설치 전제 |

**데이터 계층 공유 · 시크릿**: 오버레이 ConfigMap의 `DB_HOST`·`REDIS_URL`은
`terraform/`의 `terraform output -raw rds_address`·`redis_primary_endpoint` 값으로 채웁니다.
시크릿(`DB_PASSWORD`·`JWT_SECRET_KEY`)은 매니페스트에 넣지 않고 별도 Secret(예: External Secrets로
SSM 연동)을 전제합니다.

---

## 5. ECS vs EKS — 왜 둘 다 두었나 (판단 근거)

**ECS Fargate가 1차 아키텍처**, EKS(`eks/`)는 대안 설계입니다. 겉멋이 아니라 **선택지를 비교·판단할 수
있음을 보이려는** 것으로, 별도 root로 분리해 혼동을 막습니다.

| 관점 | ECS Fargate (1차) | EKS (`eks/`, 대안) |
|------|-------------------|--------------------|
| 운영 부담 | 낮음(서버리스, AWS 관리) | 높음(컨트롤플레인·애드온·업그레이드) |
| 생태계 | AWS 네이티브(ALB·IAM·CloudWatch 통합) | k8s 표준(Helm·Operator·Argo·metrics-server) |
| 이식성 | AWS 종속 | 멀티클라우드 이식 용이 |
| 배포 전략 | 롤링(+CodeDeploy 블루그린) | 롤링/HPA + **Argo Rollouts 블루그린** |
| 적합 규모 | 소~중규모, k8s 전문성 불필요 | k8s 표준·세밀 제어가 필요한 규모 |

**판단**: PuppyTalk 규모에는 ECS가 운영 부담·비용 대비 적정 → 1차로 채택. k8s 생태계가 필요해지는
시점을 대비해 EKS 경로를 **코드로 미리 설계**(`eks/`)해 두되 적용하지 않습니다. ("쓸 데·안 쓸 데 구분")

---

## 6. 운영 성숙도 · 의도적 비선택

- **원격 상태**: `backend.tf`에 **S3(버저닝·SSE) + DynamoDB 락** 백엔드를 partial-config로 정의.
  환경별 값은 `terraform init -backend-config=backend.hcl`로 주입(`backend.hcl.example` 참고),
  이 레포는 apply하지 않으므로 검증은 `terraform init -backend=false`로 수행.
- **공통 태그**: provider `default_tags`(`Project`·`Environment`·`ManagedBy`)로 전 리소스 태깅 → 비용 할당·거버넌스.
- **의도적 비선택**: 단일 환경 포트폴리오라 `modules/`·워크스페이스 분리는 **하지 않음**(과잉 복잡도 배제).
- **적용 시 전제(미구현·서술)**: Redis in-transit TLS(`transit_encryption_enabled=true` → `REDIS_URL`이
  `rediss://`+auth_token 전제, 앱 설정 연동 필요).

---

## 7. 로컬 실행

로컬 개발 스택은 **백엔드 레포**로 이관했습니다(설정이 사실상 백엔드 것이라 앱과 함께 둠).
`2-kyjness-community-be`에서 `docker compose up --build` → DB·Redis·MinIO와 함께 API가 `localhost:8000`.
프론트는 `2-kyjness-community-fe`에서 `npm run dev`(vite 프록시가 `:8000`으로 붙음).
자세한 절차는 각 레포 README를 참고하세요. 이 레포는 **AWS 운영 설계(IaC)** 에 집중합니다.

---

## 8. Terraform 사용 (참고)

> ⚠️ 이 스택을 `apply` 하면 ALB·Fargate·**RDS·ElastiCache·NAT** 등이 **상시 과금**됩니다.
> 설계 검토는 `validate`/`plan`까지만. 공개 라이브 데모는 무료 티어 트랙(be/fe 레포)을 씁니다.

**AWS Provider `>= 5.40, < 6.0`**, 상태 백엔드는 `backend.tf`에 **S3 + DynamoDB 락**으로 정의(partial-config).

> 🔐 `ssm.tf`·`rds.tf`가 시크릿(`jwt_secret_key`·`db_master_password`)을 관리하므로 그 값은
> **`tfstate`에 평문 저장**됩니다. 상태 파일을 절대 커밋하지 말고(현재 `.gitignore`), 원격 상태는
> **암호화 S3 백엔드(SSE) + DynamoDB 락 + 접근 제어**를 전제로 합니다(`backend.tf`).

### 사전 준비

1. Terraform CLI 설치.
2. AWS 자격 증명: 환경 변수 또는 `aws configure`. **`terraform.tfvars`에 AK/SK를 넣지 않습니다.**
3. 변수 파일: `terraform.tfvars.example` → `terraform.tfvars`(`.gitignore`) 복사 후 값 입력.

**반드시 채울 민감 값**(`variables.tf`):

| 변수 | 설명 |
|------|------|
| `db_master_password` | RDS 마스터 비밀번호 (SSM SecureString으로 ECS에도 주입) |
| `jwt_secret_key` | 백엔드 JWT 서명 키, 32자 이상 (SSM SecureString) |

`project_name`·`region`·`domain_name`·`github_*_oidc_subject`·`rds_*`·`elasticache_*`·오토스케일 값 등은 기본값이 있습니다.

### 명령

```bash
# 1차 스택 (ECS)
cd terraform
terraform init -backend=false && terraform validate    # 구성 검사 (백엔드 없이)
# 실제 운영: terraform init -backend-config=backend.hcl  # S3 원격 상태 연결
terraform plan                                         # 변경 계획 (실계정 자격 필요)
# terraform apply                                      # (과금 주의)

# EKS 대안 트랙
cd ../eks
terraform init -backend=false && terraform validate
kubectl kustomize k8s/overlays/prod-seoul              # 매니페스트 렌더 확인(클러스터 불필요)
```

- 적용 시 **Route 53** 호스팅 영역 NS를 도메인 등록업체에 위임해야 `api.<domain>`·apex·ACM 검증이 동작.
- 출력: `terraform output` (`ecr_be_repository_url`·`rds_address`·`redis_primary_endpoint`·FE/BE OIDC 롤 ARN 등).
