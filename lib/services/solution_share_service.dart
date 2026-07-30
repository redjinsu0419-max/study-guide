import 'package:share_plus/share_plus.dart';

import '../models/solution_result.dart';

class SolutionShareService {
  SolutionShareService._();

  static Future<void> shareOriginalProblem(SolutionResult result) async {
    await SharePlus.instance.share(
      ShareParams(
        title: '공부 가이드 문제',
        subject: '다시 풀어볼 문제',
        text: originalProblemText(result),
      ),
    );
  }

  static Future<void> shareOriginalAnswer(SolutionResult result) async {
    await SharePlus.instance.share(
      ShareParams(
        title: '공부 가이드 정답과 풀이',
        subject: '정답과 풀이',
        text: originalAnswerText(result),
      ),
    );
  }

  static Future<void> sharePracticeQuestion({
    required QuestionItem item,
    required String label,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        title: '공부 가이드 $label',
        subject: '$label 문제',
        text: practiceQuestionText(item: item, label: label),
      ),
    );
  }

  static Future<void> sharePracticeAnswer({
    required QuestionItem item,
    required String label,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        title: '공부 가이드 $label 정답',
        subject: '$label 정답과 풀이',
        text: practiceAnswerText(item: item, label: label),
      ),
    );
  }

  static String originalProblemText(SolutionResult result) {
    return '''
[공부 가이드]
${result.schoolLevel} ${result.grade}학년 · ${result.subject}

[문제]
${result.problemText}

정답은 나중에 따로 보내드릴게요. 먼저 풀어보세요.
'''.trim();
  }

  static String originalAnswerText(SolutionResult result) {
    final steps = result.steps.indexed
        .map((entry) => '${entry.$1 + 1}. ${entry.$2}')
        .join('\n');
    final concepts = result.keyConcepts.join(', ');
    return '''
[공부 가이드]
${result.schoolLevel} ${result.grade}학년 · ${result.subject}

[정답]
${result.finalAnswer}

[핵심 설명]
${result.summary}

[풀이 과정]
$steps
${concepts.isEmpty ? '' : '\n[핵심 개념]\n$concepts'}
'''.trim();
  }

  static String practiceQuestionText({
    required QuestionItem item,
    required String label,
  }) {
    return '''
[공부 가이드 · $label]

[문제]
${item.question}

정답은 나중에 따로 보내드릴게요. 먼저 풀어보세요.
'''.trim();
  }

  static String practiceAnswerText({
    required QuestionItem item,
    required String label,
  }) {
    return '''
[공부 가이드 · $label]

[정답]
${item.answer}
${item.explanation.isEmpty ? '' : '\n[풀이]\n${item.explanation}'}
'''.trim();
  }
}
