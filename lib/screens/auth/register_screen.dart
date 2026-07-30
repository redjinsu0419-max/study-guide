import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/school_selection.dart';
import '../../services/approval_email_service.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  SchoolLevel _schoolLevel = SchoolLevel.elementary;
  int _grade = 1;
  bool _guardianConsent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_guardianConsent) {
      setState(() {
        _error = '만 14세 미만 학생은 보호자 동의를 확인해 주세요.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final firebaseUser = await AuthService().register(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        schoolLevel: _schoolLevel,
        grade: _grade,
      );
      final pendingUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? _emailController.text.trim(),
        displayName: _nameController.text.trim(),
        schoolLevel: _schoolLevel,
        grade: _grade,
        approved: false,
        rejected: false,
        guardianConsentRequested: true,
        guardianConsentConfirmed: false,
      );
      try {
        await ApprovalEmailService.openApprovalRequest(pendingUser);
      } catch (_) {
        // 메일 앱을 열지 못해도 가입은 유지하며 대기 화면에서 다시 요청할 수 있습니다.
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() => _error = AuthService.readableError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가입 승인 요청')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: <Widget>[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: '학생 이름',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  value != null && value.trim().length >= 2
                                      ? null
                                      : '이름을 2자 이상 입력해 주세요.',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: '이메일',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) =>
                                  value != null && value.contains('@')
                                      ? null
                                      : '올바른 이메일을 입력해 주세요.',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '비밀번호(6자 이상)',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) =>
                                  value != null && value.length >= 6
                                      ? null
                                      : '비밀번호를 6자 이상 입력해 주세요.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '학년 정보',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            SegmentedButton<SchoolLevel>(
                              segments: SchoolLevel.values
                                  .map(
                                    (level) => ButtonSegment<SchoolLevel>(
                                      value: level,
                                      label: Text(level.label.substring(0, 2)),
                                    ),
                                  )
                                  .toList(),
                              selected: <SchoolLevel>{_schoolLevel},
                              onSelectionChanged: (selection) {
                                setState(() {
                                  _schoolLevel = selection.first;
                                  _grade = 1;
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              key: ValueKey<String>(
                                'grade-${_schoolLevel.storeValue}',
                              ),
                              initialValue: _grade,
                              decoration:
                                  const InputDecoration(labelText: '학년'),
                              items: _schoolLevel.grades
                                  .map(
                                    (grade) => DropdownMenuItem<int>(
                                      value: grade,
                                      child: Text('$grade학년'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _grade = value ?? 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: CheckboxListTile(
                        value: _guardianConsent,
                        onChanged: (value) => setState(
                          () => _guardianConsent = value ?? false,
                        ),
                        title: const Text('보호자 동의를 받았습니다'),
                        subtitle: const Text(
                          '문제 사진은 AI 풀이를 위해 Google에 전송되며 저장하지 않습니다. 사진에 얼굴·이름 등 개인정보가 나오지 않게 촬영해 주세요.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _register,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('가입하고 승인 요청하기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
