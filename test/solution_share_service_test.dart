import 'package:flutter_test/flutter_test.dart';
import 'package:study_guide/models/solution_result.dart';
import 'package:study_guide/services/solution_share_service.dart';

void main() {
  const result = SolutionResult(
    schoolLevel: '중학교',
    grade: 2,
    subject: '수학',
    problemText: '2 + 2는?',
    finalAnswer: '4',
    summary: '두 수를 더합니다.',
    steps: <String>['2와 2를 더합니다.', '답은 4입니다.'],
    keyConcepts: <String>['덧셈'],
    searchQuery: '중학교 수학 덧셈',
    similarQuestions: <QuestionItem>[],
    expectedQuestions: <QuestionItem>[],
    retrievalMessage: '',
  );

  test('original problem and answer are separated', () {
    final problemText = SolutionShareService.originalProblemText(result);
    final answerText = SolutionShareService.originalAnswerText(result);
    expect(problemText, contains('2 + 2는?'));
    expect(problemText, isNot(contains('[정답]')));
    expect(answerText, isNot(contains('2 + 2는?')));
    expect(answerText, contains('[정답]\n4'));
    expect(answerText, contains('1. 2와 2를 더합니다.'));
  });

  test('practice question and answer are separated', () {
    const item = QuestionItem(
      question: '3 + 3은?',
      answer: '6',
      explanation: '3을 두 번 더합니다.',
      source: '예상 문제',
    );
    final problemText = SolutionShareService.practiceQuestionText(
      item: item,
      label: '예상 문제 1번',
    );
    final answerText = SolutionShareService.practiceAnswerText(
      item: item,
      label: '예상 문제 1번',
    );
    expect(problemText, contains('3 + 3은?'));
    expect(problemText, isNot(contains('[정답]')));
    expect(answerText, contains('[정답]\n6'));
    expect(answerText, isNot(contains('3 + 3은?')));
  });
}
