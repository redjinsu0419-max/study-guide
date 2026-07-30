# 공부 가이드

초·중·고등학생이 문제를 촬영하면 학년과 과목에 맞춘 풀이를 받고,
유사 기출 2문제와 예상 문제 2문제로 복습하는 Android Flutter 앱입니다.

## 포함된 기능

- 초등학교 1~6학년, 중·고등학교 1~3학년 및 과목 선택
- 카메라 촬영 또는 갤러리 문제 불러오기
- Gemini 멀티모달 API를 통한 문제 인식, 정답, 단계별 풀이, 핵심 개념
- Pinecone 검색을 통한 유사 기출 2문제와 예상 문제 2문제
- Firebase 이메일/비밀번호 로그인
- 회원가입 직후 관리자 승인 없이 바로 사용
- 원문·유사·예상 문제를 문제와 정답·풀이로 나눠 카카오톡 전송
- UID별 풀이 기록과 오답 노트 분리 저장
- 문제 사진은 Firestore에 저장하지 않음

## 구조와 보안

Flutter 앱은 API 키를 직접 사용하지 않고 Cloudflare Worker의 `/solve`만
호출합니다. Worker는 요청마다 Firebase ID 토큰의 서명·프로젝트·만료 시간을
검증합니다. 유효한 로그인 사용자라면 별도 관리자 승인 없이 Gemini와
Pinecone을 호출할 수 있습니다.

Gemini·Pinecone 키는 Cloudflare의 암호화된 Secret에만 저장합니다.
Firebase는 Spark 요금제의 Authentication과 Firestore를 사용합니다.

## 1. 준비물

- 최신 안정 버전 Flutter와 Android Studio
- Dart 3.9 이상
- Firebase Spark 프로젝트
- Cloudflare Workers 계정
- Gemini API 키
- Pinecone API 키
- 이 프로젝트용 `google-services.json`

## 2. Cloudflare Worker 배포

Cloudflare 대시보드의 **Workers & Pages**에서 `study-guide-api` Worker를
만들고 `worker/src/index.js` 전체 내용을 편집기에 붙여 넣어 배포합니다.

Worker의 **Settings → Variables and Secrets**에서 다음 값을 등록합니다.

### 일반 변수

| 이름 | 값 |
|---|---|
| `FIREBASE_PROJECT_ID` | `stst-27641` |
| `GEMINI_MODEL` | `gemini-3.6-flash` |
| `PINECONE_INDEX_NAME` | `study-guide-questions` |
| `PINECONE_NAMESPACE` | `__default__` |
| `PINECONE_TEXT_FIELD` | `chunk_text` |

### Secret

| 이름 | 값 |
|---|---|
| `GEMINI_API_KEY` | Gemini API 키 |
| `PINECONE_API_KEY` | Pinecone API 키 |
| `PINECONE_INDEX_HOST` | 선택 사항. 비우면 첫 준비 완료 인덱스 자동 선택 |

배포 뒤 아래 주소에서 `{"ok":true,...}`가 보이는지 확인합니다.

```text
https://내-Worker-주소.workers.dev/health
```

> API 키를 채팅이나 GitHub에 다시 적지 마세요. 이전에 공개된 키는
> 오용 가능성이 있으므로 실제 운영 전 새 키로 교체하는 것이 안전합니다.

## 3. 앱에 Worker 주소 연결

다음 파일을 복사합니다.

```text
lib/config/app_config.example.dart
→ lib/config/app_config.dart
```

`app_config.dart`에서 Worker 주소만 바꿉니다.

```dart
static const String backendBaseUrl =
    'https://내-Worker-주소.workers.dev';
```

앱 파일에는 Gemini 또는 Pinecone 키를 넣지 않습니다.

## 4. Firebase 연결

1. Firebase Console의 Authentication에서 **이메일/비밀번호**를 활성화합니다.
2. Cloud Firestore 데이터베이스를 만듭니다.
3. `google-services.json`을 아래 위치에 복사합니다.

   ```text
   android/app/google-services.json
   ```

4. 이 프로젝트의 새 보안 규칙을 배포합니다.

   ```bash
   firebase login
   firebase use stst-27641
   firebase deploy --only firestore:rules
   ```

회원가입이 완료되면 바로 앱을 사용할 수 있습니다. 기존 계정의
`approved` 값이 `false`여도 새 앱과 새 Worker에서는 차단하지 않습니다.

## 5. Pinecone 준비

Pinecone 텍스트 검색에는 통합 임베딩 인덱스와 문제 데이터가 필요합니다.
Node.js 20 이상이 설치된 PC에서 PowerShell을 열고 실행합니다.

```powershell
$env:PINECONE_API_KEY="Pinecone 키"
node scripts/setup_pinecone.mjs
Remove-Item Env:PINECONE_API_KEY
```

스크립트는 Starter 요금제에서 사용할 수 있는 AWS `us-east-1`에
`study-guide-questions` 인덱스를 만들고 샘플 데이터를 넣습니다. 샘플은
연결 확인용으로 새로 작성된 문제이며 실제 기출문제가 아닙니다.
운영 전에는 이용 허락을 받은 자료로 교체하세요.

## 6. APK 만들기

### Windows

Flutter와 Android Studio가 설치된 컴퓨터에서 `APK_만들기.bat`를
두 번 클릭합니다. 필요한 설정 파일과 Worker 주소를 확인한 뒤
`공부_가이드.apk`를 만듭니다.

### 명령줄

```bash
flutter pub get
flutter test
flutter build apk --release
```

APK 생성 위치:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### GitHub Actions

저장소의 **Settings → Secrets and variables → Actions**에 다음 Secrets를
등록합니다.

- `BACKEND_BASE_URL`
- `GOOGLE_SERVICES_JSON_BASE64`
- `PINECONE_API_KEY` (Pinecone 자동 준비 작업용)

`GOOGLE_SERVICES_JSON_BASE64` 값은 PowerShell에서 다음 명령으로 만듭니다.

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("google-services.json")
)
```

**Actions → Build Android APK → Run workflow**를 누르면 빌드가 끝난 뒤
`study-guide-android` 항목에서 APK를 받을 수 있습니다.

Pinecone을 PC에 Node.js를 설치하지 않고 준비하려면
**Actions → Setup Pinecone → Run workflow**를 먼저 실행하세요.

현재 Android 릴리스 설정은 설치 시험을 위해 디버그 서명을 사용합니다.
Play Store 배포 전에는 본인의 릴리스 키로 교체하세요.

## 7. GitHub 업로드 전 확인

다음 파일은 공개 저장소에 포함하지 않습니다.

- `lib/config/app_config.dart`
- `android/app/google-services.json`
- `.env`, 서비스 계정 JSON, JKS·keystore 파일

이 ZIP에는 실제 API 키와 실제 `google-services.json`이 포함되지 않습니다.

## 운영 전 확인

[개인정보·아동 이용 점검표](docs/PRIVACY_CHECKLIST_KO.md)를 읽고 실제
서비스에 맞는 이용약관과 개인정보 처리방침을 준비하세요. 풀이 결과는 AI가
생성하므로 중요한 학습·평가에는 교사나 보호자가 다시 확인해야 합니다.
