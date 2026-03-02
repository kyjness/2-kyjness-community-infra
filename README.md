# PuppyTalk Infra

**PuppyTalk** 커뮤니티 서비스의 인프라·배포 설정 레포입니다.  
Docker Compose(로컬/EC2 동일), 이후 Kubernetes 등 배포 정의를 이 레포에서 관리합니다.

- **백엔드**: [2-kyjness-community-be](https://github.com/kyjness/2-kyjness-community-be)
- **프론트엔드**: [2-kyjness-community-fe](https://github.com/kyjness/2-kyjness-community-fe)

---

## 디렉터리 구조

```
2-kyjness-community-infra/
├── docker-compose.yml    # 통합 (nginx + MySQL + 백엔드 + 프론트엔드)
├── nginx/
│   └── default.conf     # nginx 리버스 프록시 (/ → 프론트, /v1 → 백엔드)
├── docs/
│   └── docker.md        # Docker 이미지 단독 빌드·실행 등
├── .env.example         # 환경 변수 예시 (복사 후 .env 사용)
└── README.md
```

---

## 사전 준비

Compose 경로(`../2-kyjness-community-be` 등)가 맞으려면 **백엔드·프론트엔드·infra 레포가 같은 상위 폴더 아래 나란히** 있어야 합니다. (실행은 **infra 레포 안**에서 합니다.)

```
상위폴더/
├── 2-kyjness-community-be/
├── 2-kyjness-community-fe/
└── 2-kyjness-community-infra/   ← 여기서 docker compose 실행
```

1. 상위 폴더에서 세 레포를 clone 한 뒤, **infra 폴더로 이동**합니다.
2. 백엔드 레포에 `.env.production`을 준비합니다. (백엔드 README 참고)
3. (선택) infra에서 `.env.example`을 복사해 `.env`로 저장하고, DB 비밀번호·CORS·BE_API_URL 등 필요 시 수정합니다.

---

## 실행 방법

**모든 명령은 `2-kyjness-community-infra` 레포 안에서 실행합니다.**

### 전체 스택 기동

```bash
cd 2-kyjness-community-infra
docker compose up -d
```

- **접속**: http://localhost (로컬) 또는 http://서버IP (EC2)
- **API**: http://localhost/v1 (또는 서버IP/v1)
- **API 문서**: http://localhost/v1/docs

nginx가 80 포트로 받아서 `/`는 프론트엔드, `/v1`은 백엔드로 전달합니다.

**직접 포트 접속** (디버깅·개발 시):
- nginx: 80
- 프론트엔드: http://localhost:8080
- 백엔드 API·문서: http://localhost:8000, http://localhost:8000/docs
- MySQL: 3306

### 부분 기동

- **MySQL + 백엔드만**: `docker compose up -d mysql backend`
- **중지**: `docker compose down`
- **볼륨까지 삭제**: `docker compose down -v` (주의: DB·업로드 데이터 삭제)
- **재빌드 후 기동**: `docker compose up --build -d`

---

## Volume

- **mysql_data**: MySQL 데이터 유지
- **backend_upload**: 백엔드 업로드 파일 유지

`docker compose down -v` 시 볼륨까지 삭제되므로, 데이터를 보존하려면 `-v`를 붙이지 않습니다.

---

- **Docker 이미지 단독 빌드·실행** 등 상세: [docs/docker.md](docs/docker.md)

---

## 확장 (예정)

- Kubernetes 매니페스트·Helm 차트
- CI/CD 파이프라인 정의
