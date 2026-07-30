import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/school_selection.dart';
import '../services/firestore_service.dart';
import '../services/problem_solver_service.dart';
import 'solution_detail_screen.dart';

class SolveProblemScreen extends StatefulWidget {
  const SolveProblemScreen({
    super.key,
    required this.imageBytes,
    required this.mimeType,
    required this.schoolLevel,
    required this.grade,
    required this.subject,
  });

  final Uint8List imageBytes;
  final String mimeType;
  final SchoolLevel schoolLevel;
  final int grade;
  final String subject;

  @override
  State<SolveProblemScreen> createState() => _SolveProblemScreenState();
}

class _SolveProblemScreenState extends State<SolveProblemScreen> {
  bool _solving = false;
  String _progress = '사진을 확인한 뒤 풀이를 시작하세요.';
  String? _error;

  Future<void> _solve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = '로그인이 필요합니다.');
      return;
    }
    setState(() {
      _solving = true;
      _error = null;
    });
    try {
      final result = await ProblemSolverService().solve(
        imageBytes: widget.imageBytes,
        mimeType: widget.mimeType,
        schoolLevel: widget.schoolLevel,
        grade: widget.grade,
        subject: widget.subject,
        onProgress: (message) {
          if (mounted) setState(() => _progress = message);
        },
      );
      if (!mounted) return;
      setState(() => _progress = '풀이 기록을 저장하고 있어요…');
      final historyId = await FirestoreService().saveSolution(
        uid: user.uid,
        result: result,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SolutionDetailScreen(
            result: result,
            historyId: historyId,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _solving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문제 확인')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(maxHeight: 430),
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(
                  '${widget.schoolLevel.label} ${widget.grade}학년 · ${widget.subject}',
                ),
                subtitle: const Text('선택한 수준에 맞춰 설명합니다.'),
              ),
            ),
            if (_solving) ...<Widget>[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 14),
              Text(_progress, textAlign: TextAlign.center),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _solving ? null : _solve,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text('풀이 시작'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _solving ? null : () => Navigator.of(context).pop(),
              child: const Text('다시 촬영'),
            ),
          ],
        ),
      ),
    );
  }
}

