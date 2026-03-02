# Docker

Docker Compose 실행 방법은 [README](../README.md)를 참고하고, 이 문서는 **백엔드 이미지 단독 빌드·실행** 방법만 정리합니다.

---

## 백엔드 이미지 단독 빌드·실행

Compose 없이 백엔드 컨테이너만 쓸 때 사용합니다. **백엔드 레포**에서 이미지를 빌드하고, 실행 시 환경 변수는 `-e` 또는 `--env-file`로 넘깁니다.

**빌드** (백엔드 폴더에서)

```bash
cd ../2-kyjness-community-be
docker build -t puppytalk-be .
```

**실행**

```bash
docker run -d -p 8000:8000 \
  -e ENV=production \
  -e DB_HOST=호스트 \
  -e DB_PORT=3306 \
  -e DB_USER=사용자 \
  -e DB_PASSWORD=비밀번호 \
  -e DB_NAME=puppytalk \
  --name puppytalk-be puppytalk-be
```

- 나머지 변수(CORS, S3, LOG_LEVEL 등)는 `-e` 또는 `--env-file ../2-kyjness-community-be/.env.production` 로 전달.
- 프로덕션: `ENV=production`, `COOKIE_SECURE=true`(HTTPS 사용 시), `CORS_ORIGINS`에 실제 프론트 도메인, DB·S3 시크릿은 환경으로만 주입.
