enum SchoolLevel {
  elementary,
  middle,
  high,
}

extension SchoolLevelDetails on SchoolLevel {
  String get label {
    switch (this) {
      case SchoolLevel.elementary:
        return '초등학생';
      case SchoolLevel.middle:
        return '중학생';
      case SchoolLevel.high:
        return '고등학생';
    }
  }

  String get storeValue {
    switch (this) {
      case SchoolLevel.elementary:
        return 'elementary';
      case SchoolLevel.middle:
        return 'middle';
      case SchoolLevel.high:
        return 'high';
    }
  }

  int get maxGrade => this == SchoolLevel.elementary ? 6 : 3;

  List<int> get grades =>
      List<int>.generate(maxGrade, (index) => index + 1);

  List<String> get subjects {
    switch (this) {
      case SchoolLevel.elementary:
        return const <String>[
          '국어',
          '수학',
          '사회',
          '과학',
          '영어',
          '도덕',
        ];
      case SchoolLevel.middle:
        return const <String>[
          '국어',
          '수학',
          '영어',
          '사회',
          '역사',
          '과학',
          '도덕',
          '기술·가정',
          '정보',
        ];
      case SchoolLevel.high:
        return const <String>[
          '국어',
          '수학',
          '영어',
          '한국사',
          '통합사회',
          '통합과학',
          '물리학',
          '화학',
          '생명과학',
          '지구과학',
          '사회탐구',
          '정보',
        ];
    }
  }

}

SchoolLevel schoolLevelFromStore(String? value) {
  return SchoolLevel.values.firstWhere(
    (level) => level.storeValue == value,
    orElse: () => SchoolLevel.elementary,
  );
}
