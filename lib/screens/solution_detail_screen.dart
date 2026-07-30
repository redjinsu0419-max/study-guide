import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/solution_result.dart';
import '../services/firestore_service.dart';
import '../services/solution_share_service.dart';
import '../widgets/section_card.dart';

class SolutionDetailScreen extends StatefulWidget {
  const SolutionDetailScreen({
    super.key,
    required this.result,
    required this.historyId,
  });

  final SolutionResult result;
  final String historyId;

  @override
  State<SolutionDetailScreen> createState() => _SolutionDetailScreenState();
}

class _SolutionDetailScreenState extends State<SolutionDetailScreen> {
  late bool _isWrong;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isWrong = widget.result.isWrong;
  }

  Future<void> _toggleWrong() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirestoreService().setWrongNote(
        uid: user.uid,
        historyId: widget.historyId,
        result: widget.result,
        value: !_isWrong,
      );
      if (mounted) {
        setState(() => _isWrong = !_isWrong);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isWrong ? '오답 노트에 저장했습니다.' : '오답 노트에서 삭제했습니다.',
            ),
          ),
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

  Future<void> _shareProblemToKakaoTalk() {
    return SolutionShareService.shareOriginalProblem(widget.result);
  }

  Future<void> _shareAnswerToKakaoTalk() {
    return SolutionShareService.shareOriginalAnswer(widget.result);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('풀이 결과'),
        actions: <Widget>[
          IconButton(
            tooltip: '문제만 카카오톡으로 보내기',
            onPressed: _shareProblemToKakaoTalk,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: _isWrong ? '오답 노트에서 삭제' : '오답 노트에 저장',
            onPressed: _saving ? null : _toggleWrong,
            icon: Icon(
              _isWrong
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text(result.schoolLevel)),
                Chip(label: Text('${result.grade}학년')),
                Chip(label: Text(result.subject)),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '인식한 문제',
              icon: Icons.document_scanner_outlined,
              child: SelectableText(result.problemText),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '정답',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      result.finalAnswer,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '핵심 설명',
              icon: Icons.lightbulb_outline_rounded,
              child: SelectableText(result.summary),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '풀이 과정',
              icon: Icons.format_list_numbered_rounded,
              child: Column(
                children: result.steps.indexed
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 14,
                              child: Text('${entry.$1 + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(entry.$2),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (result.keyConcepts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SectionCard(
                title: '핵심 개념',
                icon: Icons.key_rounded,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.keyConcepts
                      .map((concept) => Chip(label: Text(concept)))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _QuestionSection(
              title: '유사 기출 2문제',
              icon: Icons.find_in_page_outlined,
              questions: result.similarQuestions,
            ),
            const SizedBox(height: 12),
            _QuestionSection(
              title: '예상 문제 2문제',
              icon: Icons.psychology_alt_outlined,
              questions: result.expectedQuestions,
            ),
            const SizedBox(height: 10),
            Text(
              result.retrievalMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _shareProblemToKakaoTalk,
              icon: const Icon(Icons.send_rounded),
              label: const Text('문제만 카카오톡으로 보내기'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _shareAnswerToKakaoTalk,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('정답·풀이 카카오톡으로 보내기'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _toggleWrong,
              icon: Icon(
                _isWrong
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
              ),
              label: Text(_isWrong ? '오답 노트에서 삭제' : '오답 노트에 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  const _QuestionSection({
    required this.title,
    required this.icon,
    required this.questions,
  });

  final String title;
  final IconData icon;
  final List<QuestionItem> questions;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: icon,
      child: questions.isEmpty
          ? const Text('표시할 문제가 없습니다.')
          : Column(
              children: questions.indexed
                  .map(
                    (entry) => _QuestionTile(
                      number: entry.$1 + 1,
                      item: entry.$2,
                      sectionTitle: title,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _QuestionTile extends StatefulWidget {
  const _QuestionTile({
    required this.number,
    required this.item,
    required this.sectionTitle,
  });

  final int number;
  final QuestionItem item;
  final String sectionTitle;

  @override
  State<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<_QuestionTile> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '문제 ${widget.number}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    widget.item.source,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(widget.item.question),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () =>
                        SolutionShareService.sharePracticeQuestion(
                      item: widget.item,
                      label: '${widget.sectionTitle} ${widget.number}번',
                    ),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('문제 보내기'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        SolutionShareService.sharePracticeAnswer(
                      item: widget.item,
                      label: '${widget.sectionTitle} ${widget.number}번',
                    ),
                    icon: const Icon(Icons.task_alt_outlined, size: 18),
                    label: const Text('정답·풀이 보내기'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAnswer = !_showAnswer),
                  child: Text(_showAnswer ? '정답 숨기기' : '정답 보기'),
                ),
              ),
              if (_showAnswer) ...<Widget>[
                const Divider(),
                Text('정답: ${widget.item.answer}'),
                if (widget.item.explanation.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(widget.item.explanation),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
