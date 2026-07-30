import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../services/approval_email_service.dart';
import '../services/auth_service.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool _openingMail = false;

  Future<void> _openMail() async {
    setState(() => _openingMail = true);
    try {
      await ApprovalEmailService.openApprovalRequest(widget.user);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _openingMail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = widget.user.rejected;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        rejected
                            ? Icons.block_rounded
                            : Icons.mark_email_unread_outlined,
                        size: 62,
                        color: rejected
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        rejected ? '가입 승인이 거절되었습니다' : '관리자 승인 대기 중',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        rejected
                            ? '관리자에게 가입 정보를 확인해 달라고 문의해 주세요.'
                            : '${AppConfig.adminEmails.first}에서 승인한 뒤 앱을 사용할 수 있습니다.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!rejected)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _openingMail ? null : _openMail,
                            icon: const Icon(Icons.send_outlined),
                            label: Text(
                              _openingMail
                                  ? '메일 앱 여는 중…'
                                  : '승인 요청 이메일 보내기',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: AuthService().signOut,
                        child: const Text('다른 계정으로 로그인'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

