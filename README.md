# PuppyTalk Infra

**PuppyTalk** 커뮤니티용 **Docker Compose·Nginx** 설정 레포입니다.  
**일상적인 로컬 개발**은 저장소 **루트**의 `docker-compose.local.yml`만 사용합니다.  
`ec2/`, `lambda/`, `ecs/` 아래 파일은 **배포·아키텍처 참고용(기록)** 으로 두었으며, 이 레포에서 그 경로로 `compose up` 할 필요는 없다고 가정합니다.

- **백엔드**: [2-kyjness-community-be](https://github.com/kyjness/2-kyjness-community-be)
- **프론트엔드**: [2-kyjness-community-fe](https://github.com/kyjness/2-kyjness-community-fe)

---

## 디렉터리 구조 (요약)

| 경로 | 역할 |
|------|------|
| 루트 (`docker-compose.local.yml`, `nginx/default.local.conf`, `.env.local`) | **로컬 전체 스택** 실행용 |
| `ec2/` | EC2 시절 Compose·Nginx·배포 워크플로 참고 (`docker-compose.yml`, `default.conf`, `deploy.yml`) |
| `lambda/` | Lambda 관련 Dockerfile·compose·배포 YAML 참고 |
| `ecs/` | ECS 태스크 정의 등 JSON 참고 |

---

## 파일 역할 (로컬 실행에 쓰는 것)

| 파일 | 용도 |
|------|------|
| `docker-compose.local.yml` | **로컬**: Nginx + 백엔드 + 프론트 + PostgreSQL + Redis + MinIO |
| `nginx/default.local.conf` | 로컬 전용: `:80`만, `/v1`→백엔드, `/`→프론트, `/minio/`→MinIO 프록시 |

### 환경 파일 ↔ Compose (로컬)

| Compose 파일 | 사용하는 env 파일 | `env_file`이 붙는 서비스 |
|--------------|-------------------|---------------------------|
| `docker-compose.local.yml` | **`.env.local`** (저장소 루트에 필수) | `db`, `minio`, `backend` |

Compose 파일 안에 `${...}` 보간은 쓰지 않습니다. DB·MinIO 자격 증명은 각 컨테이너가 위 env 파일에서 직접 읽습니다. (`.env.local`은 `.gitignore`로 커밋하지 않습니다.)

### 참고용: `ec2/` (프로덕션 스택 스냅샷)

| 파일 | 용도 (참고) |
|------|-------------|
| `ec2/docker-compose.yml` | Nginx(80·443) + 백엔드 + DB + Redis. MinIO·프론트 컨테이너 없음 (S3·CloudFront 등 별도 배포 전제) |
| `ec2/default.conf` | 프로덕션 도메인·Let’s Encrypt·API 프록시 등 |
| `ec2/deploy.yml` | GitHub Actions 등 배포 파이프라인 참고 |

프로덕션 Compose는 호스트의 `/etc/letsencrypt`를 Nginx에 **읽기 전용**으로 마운트하는 전제입니다. 실제 서버에서 쓸 때는 `ec2/`를 작업 디렉터리로 두고 `ec2/.env`를 맞추면 됩니다.

---

## 로컬 실행 (Docker)

### 1. 레포 배치

백엔드·프론트·인프라 세 레포가 **같은 상위 폴더**에 있어야 빌드 컨텍스트가 맞습니다.

```
상위폴더/
├── 2-kyjness-community-be/
├── 2-kyjness-community-fe/
└── 2-kyjness-community-infra/   ← 여기서 명령 실행
```

### 2. 환경 변수

```bash
cd 2-kyjness-community-infra
cp .env.example .env.local
```

로컬 스택은 **`docker-compose.local.yml`만** 쓰고, **`db` / `minio` / `backend`는 모두 `.env.local`을 읽습니다.**  
반드시 맞출 항목(자세한 키는 `.env.example` 참고):

- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`(또는 예시와 동일한 DB 관련 키)
- `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`(MinIO 컨테이너용; 예시 기본값 사용 가능)
- `DB_PASSWORD` 등 백엔드·DB 연결 문자열과 일치하는 값
- `JWT_SECRET_KEY`: 32자 이상 랜덤 문자열
- MinIO/S3: `STORAGE_BACKEND`, `S3_*`, `S3_PUBLIC_BASE_URL`(예: `http://localhost/minio/puppytalk`) 등

### 3. 스택 기동 (로컬)

```bash
docker compose -f docker-compose.local.yml up --build -d
```

- 첫 실행은 `--build` 권장.
- 재기동만: `docker compose -f docker-compose.local.yml up -d`

백엔드 컨테이너 기동 시 `alembic upgrade head`가 실행되어 마이그레이션이 적용됩니다.

### 4. 로컬 포트

| 용도 | 호스트 포트 | 비고 |
|------|-------------|------|
| 웹 전체 (Nginx) | 80 | 프론트 `/`, API `/v1/` |
| PostgreSQL | 5432 | DB 클라이언트용 |
| Redis | 6379 | |
| MinIO API | 9000 | S3 호환 |
| MinIO 콘솔 | 9001 | 웹 UI |

백엔드·프론트는 호스트 포트를 열지 않고 Nginx(80) 경유입니다.

### 5. 동작 확인

- 프론트: http://localhost  
- API: http://localhost/v1/  
- Swagger: http://localhost/v1/docs  
- 헬스: http://localhost/v1/health  

마이그레이션만 수동:

```bash
docker compose -f docker-compose.local.yml exec backend alembic upgrade head
```

### 6. MinIO 버킷 공개 (이미지 Access Denied 방지)

스택 기동 후(버킷 이름은 `.env.local`의 `S3_BUCKET_NAME`에 맞게 조정):

```bash
docker exec minio mc alias set myminio http://localhost:9000 minioadmin minioadmin
docker exec minio mc anonymous set download myminio/puppytalk
```

콘솔(http://localhost:9001)에서 Access Rules로 동일 설정 가능.

### 7. 종료·볼륨 삭제

```bash
docker compose -f docker-compose.local.yml down
docker compose -f docker-compose.local.yml down -v   # DB·Redis·MinIO 데이터까지 초기화
```

### 기타 (로컬)

- 재빌드: `docker compose -f docker-compose.local.yml up --build -d`
- 백엔드만 재시작: `docker compose -f docker-compose.local.yml restart backend`
- db 업데이트: `docker compose -f docker-compose.local.yml exec backend alembic upgrade head`
- 로그: `docker compose -f docker-compose.local.yml logs -f [nginx|backend|frontend]`

---

## 프로덕션·레거시 참고 (`ec2/` 등)

- **이 레포의 일상 워크플로는 로컬 compose만** 쓰는 것을 전제로 합니다.
- EC2·Lambda·ECS 설정은 **`ec2/`, `lambda/`, `ecs/`** 에 두었고, 과거 배포 방식·태스크 정의를 **파일로 보존**하는 용도입니다.
- 다시 EC2에서 돌릴 경우: `ec2/`에서 `docker compose` 실행, **`ec2/.env`**, Let’s Encrypt, 보안 그룹·DB 포트 노출 여부 등은 운영 환경에 맞게 별도 점검합니다.
- Nginx는 **80 → 443 리다이렉트**, API는 `/v1/`, `/api/v1/` 프록시. 프론트는 **별도 CDN/호스팅** 전제입니다(`ec2/default.conf` 안내와 동일).

---

## 로컬 vs `ec2/` 참고 Compose 비교

| 항목 | `docker-compose.local.yml` (루트) | `ec2/docker-compose.yml` (참고) |
|------|-----------------------------------|----------------------------------|
| 프론트 컨테이너 | 있음 | 없음 |
| MinIO | 있음 | 없음 |
| Nginx TLS(443) | 없음 | 있음 (Let’s Encrypt 마운트) |
| Nginx 설정 파일 | `nginx/default.local.conf` | `ec2/default.conf` |
| 환경 파일 | `.env.local` (루트) | `ec2/.env` |
