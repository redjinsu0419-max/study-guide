import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/school_selection.dart';
import '../services/firestore_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return StreamBuilder<List<AppUser>>(
      stream: service.watchApprovalRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('가입 요청을 불러오지 못했습니다.\n${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!
            .where((user) => !AppConfig.isAdminEmail(user.email))
            .toList();
        final approvedCount = users.where((user) => user.approved).length;
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.group_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '승인 사용자 $approvedCount / ${AppConfig.maxApprovedUsers}명',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: users.isEmpty
                  ? const Center(child: Text('가입 요청이 없습니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _ApprovalCard(
                          user: users[index],
                          service: service,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  const _ApprovalCard({required this.user, required this.service});

  final AppUser user;
  final FirestoreService service;

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _saving = false;

  Future<void> _approve() async {
    var guardianConfirmed = widget.user.guardianConsentConfirmed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('가입 승인'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${widget.user.displayName} 학생을 승인할까요?'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: guardianConfirmed,
                  onChanged: (value) => setDialogState(
                    () => guardianConfirmed = value ?? false,
                  ),
                  title: const Text('보호자 동의를 확인했습니다'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: guardianConfirmed
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('승인'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    await _run(
      () => widget.service.setApproval(
        user: widget.user,
        approved: true,
        guardianConsentConfirmed: guardianConfirmed,
      ),
      '승인했습니다.',
    );
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final status = user.approved
        ? '승인됨'
        : user.rejected
            ? '거절됨'
            : '승인 대기';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  child: Text(
                    user.displayName.isEmpty ? '?' : user.displayName[0],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(user.email),
                    ],
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${user.schoolLevel.label} ${user.grade}학년 · '
              '보호자 동의 요청 ${user.guardianConsentRequested ? '확인' : '미확인'}',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (!user.rejected)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _run(
                              () => widget.service.reject(user),
                              '가입을 거절했습니다.',
                            ),
                    child: const Text('거절'),
                  ),
                if (!user.approved) ...<Widget>[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _approve,
                    child: Text(_saving ? '처리 중…' : '승인'),
                  ),
                ],
                if (user.approved)
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => _run(
                              () => widget.service.setApproval(
                                user: user,
                                approved: false,
                                guardianConsentConfirmed:
                                    user.guardianConsentConfirmed,
                              ),
                              '승인을 해제했습니다.',
                            ),
                    child: const Text('승인 해제'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
