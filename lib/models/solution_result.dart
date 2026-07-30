import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionItem {
  const QuestionItem({
    required this.question,
    required this.answer,
    required this.explanation,
    required this.source,
  });

  final String question;
  final String answer;
  final String explanation;
  final String source;

  factory QuestionItem.fromMap(
    Map<String, dynamic> map, {
    String defaultSource = 'AI 생성',
  }) {
    return QuestionItem(
      question: _stringValue(
        map,
        const <String>['question', 'problem', 'chunk_text', 'text', 'content'],
      ),
      answer: _stringValue(
        map,
        const <String>['answer', 'finalAnswer', 'correct_answer'],
      ),
      explanation: _stringValue(
        map,
        const <String>['explanation', 'solution', 'rationale'],
      ),
      source: _stringValue(
        map,
        const <String>['source', 'origin'],
        fallback: defaultSource,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'question': question,
      'answer': answer,
      'explanation': explanation,
      'source': source,
    };
  }

  QuestionItem copyWith({String? source}) {
    return QuestionItem(
      question: question,
      answer: answer,
      explanation: explanation,
      source: source ?? this.source,
    );
  }

  static String _stringValue(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }
}

class SolutionResult {
  const SolutionResult({
    required this.schoolLevel,
    required this.grade,
    required this.subject,
    required this.problemText,
    required this.finalAnswer,
    required this.summary,
    required this.steps,
    required this.keyConcepts,
    required this.searchQuery,
    required this.similarQuestions,
    required this.expectedQuestions,
    required this.retrievalMessage,
    this.createdAt,
    this.isWrong = false,
  });

  final String schoolLevel;
  final int grade;
  final String subject;
  final String problemText;
  final String finalAnswer;
  final String summary;
  final List<String> steps;
  final List<String> keyConcepts;
  final String searchQuery;
  final List<QuestionItem> similarQuestions;
  final List<QuestionItem> expectedQuestions;
  final String retrievalMessage;
  final DateTime? createdAt;
  final bool isWrong;

  factory SolutionResult.fromGemini(
    Map<String, dynamic> map, {
    required String schoolLevel,
    required int grade,
    required String subject,
  }) {
    return SolutionResult(
      schoolLevel: schoolLevel,
      grade: grade,
      subject: subject,
      problemText: _text(map['problemText']),
      finalAnswer: _text(map['finalAnswer']),
      summary: _text(map['summary']),
      steps: _stringList(map['steps']),
      keyConcepts: _stringList(map['keyConcepts']),
      searchQuery: _text(map['searchQuery']),
      similarQuestions: _questionList(
        map['similarFallback'],
        defaultSource: 'Gemini 대체 생성',
      ),
      expectedQuestions: _questionList(
        map['expectedFallback'],
        defaultSource: 'Gemini 대체 생성',
      ),
      retrievalMessage: 'Pinecone 검색 전',
    );
  }

  factory SolutionResult.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'];
    return SolutionResult(
      schoolLevel: _text(map['schoolLevel']),
      grade: (map['grade'] as num?)?.toInt() ?? 1,
      subject: _text(map['subject']),
      problemText: _text(map['problemText']),
      finalAnswer: _text(map['finalAnswer']),
      summary: _text(map['summary']),
      steps: _stringList(map['steps']),
      keyConcepts: _stringList(map['keyConcepts']),
      searchQuery: _text(map['searchQuery']),
      similarQuestions: _questionList(map['similarQuestions']),
      expectedQuestions: _questionList(map['expectedQuestions']),
      retrievalMessage: _text(map['retrievalMessage']),
      createdAt: created is Timestamp ? created.toDate() : null,
      isWrong: map['isWrong'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap({Object? createdAtValue}) {
    final result = <String, dynamic>{
      'schoolLevel': schoolLevel,
      'grade': grade,
      'subject': subject,
      'problemText': problemText,
      'finalAnswer': finalAnswer,
      'summary': summary,
      'steps': steps,
      'keyConcepts': keyConcepts,
      'searchQuery': searchQuery,
      'similarQuestions':
          similarQuestions.map((item) => item.toMap()).toList(),
      'expectedQuestions':
          expectedQuestions.map((item) => item.toMap()).toList(),
      'retrievalMessage': retrievalMessage,
      'isWrong': isWrong,
    };
    if (createdAtValue != null) {
      result['createdAt'] = createdAtValue;
    }
    return result;
  }

  SolutionResult copyWith({
    List<QuestionItem>? similarQuestions,
    List<QuestionItem>? expectedQuestions,
    String? retrievalMessage,
    bool? isWrong,
    DateTime? createdAt,
  }) {
    return SolutionResult(
      schoolLevel: schoolLevel,
      grade: grade,
      subject: subject,
      problemText: problemText,
      finalAnswer: finalAnswer,
      summary: summary,
      steps: steps,
      keyConcepts: keyConcepts,
      searchQuery: searchQuery,
      similarQuestions: similarQuestions ?? this.similarQuestions,
      expectedQuestions: expectedQuestions ?? this.expectedQuestions,
      retrievalMessage: retrievalMessage ?? this.retrievalMessage,
      isWrong: isWrong ?? this.isWrong,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<QuestionItem> _questionList(
    dynamic value, {
    String defaultSource = 'AI 생성',
  }) {
    if (value is! List) return const <QuestionItem>[];
    return value
        .whereType<Map>()
        .map(
          (item) => QuestionItem.fromMap(
            Map<String, dynamic>.from(item),
            defaultSource: defaultSource,
          ),
        )
        .where((item) => item.question.isNotEmpty)
        .toList(growable: false);
  }
}
