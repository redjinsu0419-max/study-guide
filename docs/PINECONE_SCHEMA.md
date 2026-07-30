# Pinecone 문제 데이터 형식

앱은 `chunk_text`가 임베딩 대상인 **통합 임베딩 인덱스**를 사용합니다.
한국어 검색을 위해 기본 설정 스크립트는 `multilingual-e5-large` 모델을 사용합니다.

필수·권장 필드는 다음과 같습니다.

| 필드 | 필수 | 예시 | 용도 |
| --- | --- | --- | --- |
| `_id` | 필수 | `math-m2-001` | 레코드 고유 ID |
| `chunk_text` | 필수 | `중2 수학 일차함수 기울기` | Pinecone 임베딩·검색 |
| `question` | 필수 | 문제 본문 | 앱에 표시 |
| `answer` | 권장 | 정답 | 정답 보기 |
| `explanation` | 권장 | 간단한 풀이 | 정답 설명 |
| `kind` | 권장 | `past` 또는 `predicted` | 유사 기출/예상 분류 |
| `source` | 권장 | 자료 출처 | 앱에 출처 표시 |
| `schoolLevel` | 권장 | `elementary`, `middle`, `high` | 학교급 우선순위 |
| `grade` | 권장 | `1` | 학년 우선순위 |
| `subject` | 권장 | `수학` | 과목 우선순위 |

`kind`가 `predicted`, `expected`, `forecast`, `예상` 중 하나를 포함하면
예상 문제로 분류합니다. 그 외 레코드는 유사 기출 후보로 분류합니다.

`data/questions.sample.json`은 연결 시험용으로 새로 작성된 샘플이며 실제
기출문제가 아닙니다. 서비스에 사용할 때는 이용 허락을 받은 자료로 교체하세요.

