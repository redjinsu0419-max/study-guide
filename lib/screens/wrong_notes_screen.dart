import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/solution_list.dart';

class WrongNotesScreen extends StatelessWidget {
  const WrongNotesScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return SolutionList(
      stream: FirestoreService().watchWrongNotes(uid),
      emptyIcon: Icons.bookmark_outline_rounded,
      emptyTitle: '오답 노트가 비어 있습니다.',
    );
  }
}

