# 공부 가이드 Cloudflare Worker

이 Worker는 Firebase에 로그인한 사용자에게 Gemini/Pinecone 문제 풀이 API를
중계합니다. 앱에는 API 키가 들어가지 않습니다.

## Cloudflare Secret

다음 값은 Worker의 `Settings > Variables and Secrets`에서 **Secret**으로
등록합니다.

- `GEMINI_API_KEY`: Gemini API 키
- `PINECONE_API_KEY`: Pinecone API 키
- `PINECONE_INDEX_HOST`: 선택 사항. 비우면 첫 번째 준비된 인덱스를 사용

일반 변수는 `wrangler.jsonc`에 있습니다.
기본 인덱스 이름은 `study-guide-questions`이며, 다른 이름을 사용하려면
`PINECONE_INDEX_NAME`을 함께 바꾸세요.

## 로그인 검사

1. Firebase ID 토큰의 Google 공개키 서명을 검증합니다.
2. 토큰의 프로젝트, 발급 시각, 만료 시각을 확인합니다.
3. 유효한 Firebase 로그인 사용자라면 별도 관리자 승인 없이 통과합니다.

## 경로

- `GET /health`: 서버 상태 확인
- `POST /solve`: 로그인 사용자 문제 풀이
