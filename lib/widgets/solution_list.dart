import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/solution_result.dart';
import '../screens/solution_detail_screen.dart';

class SolutionList extends StatelessWidget {
  const SolutionList({
    super.key,
    required this.stream,
    required this.emptyIcon,
    required this.emptyTitle,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final IconData emptyIcon;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('목록을 불러오지 못했습니다.\n${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final documents = snapshot.data!.docs;
        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(emptyIcon, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(emptyTitle),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: documents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final document = documents[index];
            final result = SolutionResult.fromMap(document.data());
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    result.isWrong
                        ? Icons.bookmark_rounded
                        : Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  result.problemText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${result.schoolLevel} ${result.grade}학년 · ${result.subject}'
                    '${result.createdAt == null ? '' : ' · ${DateFormat('MM.dd HH:mm').format(result.createdAt!)}'}',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SolutionDetailScreen(
                        result: result,
                        historyId: document.data()['historyId']?.toString() ??
                            document.id,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
