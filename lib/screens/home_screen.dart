import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/school_selection.dart';
import 'solve_problem_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.defaultUser});

  final AppUser? defaultUser;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SchoolLevel _schoolLevel;
  late int _grade;
  late String _subject;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _schoolLevel =
        widget.defaultUser?.schoolLevel ?? SchoolLevel.elementary;
    _grade = widget.defaultUser?.grade ?? 1;
    _subject = _schoolLevel.subjects.first;
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final mimeType = _mimeType(file, bytes);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SolveProblemScreen(
            imageBytes: bytes,
            mimeType: mimeType,
            schoolLevel: _schoolLevel,
            grade: _grade,
            subject: _subject,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진을 불러오지 못했습니다. $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  static String _mimeType(XFile file, Uint8List bytes) {
    final declared = file.mimeType;
    if (declared != null && declared.startsWith('image/')) return declared;
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF5357D9), Color(0xFF7B5FEA)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '모르는 문제,\n사진 한 장이면 돼요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '수준별 풀이와 복습 문제를 함께 받아보세요.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.document_scanner_rounded,
                size: 72,
                color: Colors.white70,
              ),
            ],
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
                  '학년과 과목 선택',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                      _subject = _schoolLevel.subjects.first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'grade-${_schoolLevel.storeValue}',
                        ),
                        initialValue: _grade,
                        decoration: const InputDecoration(labelText: '학년'),
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey<String>(
                          'subject-${_schoolLevel.storeValue}',
                        ),
                        initialValue: _subject,
                        decoration: const InputDecoration(labelText: '과목'),
                        items: _schoolLevel.subjects
                            .map(
                              (subject) => DropdownMenuItem<String>(
                                value: subject,
                                child: Text(
                                  subject,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _subject =
                              value ?? _schoolLevel.subjects.first,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _pickingImage ? null : () => _pick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_rounded),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_pickingImage ? '사진 준비 중…' : '문제 촬영하기'),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickingImage ? null : () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('갤러리에서 가져오기'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '문제 사진은 풀이를 위해 Gemini에 전송되지만 앱과 Firestore에는 저장하지 않습니다. 얼굴·이름·학교명은 촬영하지 마세요.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
