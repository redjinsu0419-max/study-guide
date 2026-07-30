import 'package:flutter_test/flutter_test.dart';
import 'package:study_guide/models/solution_result.dart';

void main() {
  test('Gemini 구조화 응답을 풀이 모델로 바꾼다', () {
    final result = SolutionResult.fromGemini(
      <String, dynamic>{
        'problemText': '1+1은?',
        'finalAnswer': '2',
        'summary': '두 수를 더한다.',
        'steps': <String>['1과 1을 더한다.', '2를 얻는다.'],
        'keyConcepts': <String>['덧셈'],
        'searchQuery': '초등 수학 한 자리 수 덧셈',
        'similarFallback': <Map<String, String>>[
          <String, String>{
            'question': '2+1은?',
            'answer': '3',
            'explanation': '덧셈',
          },
        ],
        'expectedFallback': <Map<String, String>>[
          <String, String>{
            'question': '3+1은?',
            'answer': '4',
            'explanation': '덧셈',
          },
        ],
      },
      schoolLevel: '초등학생',
      grade: 1,
      subject: '수학',
    );

    expect(result.finalAnswer, '2');
    expect(result.steps, hasLength(2));
    expect(result.similarQuestions.first.source, 'Gemini 대체 생성');
  });
}

