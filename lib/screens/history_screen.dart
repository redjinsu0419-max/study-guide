import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/solution_list.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return SolutionList(
      stream: FirestoreService().watchHistory(uid),
      emptyIcon: Icons.history_rounded,
      emptyTitle: '아직 저장된 풀이가 없습니다.',
    );
  }
}

