# 공부 가이드 Cloudflare Worker

이 Worker는 승인된 Firebase 사용자만 Gemini/Pinecone 문제 풀이 API를
사용하도록 중계합니다. 앱에는 API 키가 들어가지 않습니다.

## Cloudflare Secret

다음 값은 Worker의 `Settings > Variables and Secrets`에서 **Secret**으로
등록합니다.

- `GEMINI_API_KEY`: Gemini API 키
- `PINECONE_API_KEY`: Pinecone API 키
- `PINECONE_INDEX_HOST`: 선택 사항. 비우면 첫 번째 준비된 인덱스를 사용

일반 변수는 `wrangler.jsonc`에 있습니다.
기본 인덱스 이름은 `study-guide-questions`이며, 다른 이름을 사용하려면
`PINECONE_INDEX_NAME`을 함께 바꾸세요.

## 승인 검사

1. Firebase ID 토큰의 Google 공개키 서명을 검증합니다.
2. 관리자는 `ADMIN_EMAIL`과 일치하면 통과합니다.
3. 학생은 Firestore의 `users/{uid}.approved == true`여야 통과합니다.
4. 승인되지 않은 사용자는 Worker가 HTTP 403으로 차단합니다.

## 경로

- `GET /health`: 서버 상태 확인
- `POST /solve`: 승인된 사용자만 문제 풀이
