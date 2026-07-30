import 'dart:typed_data';

import '../models/school_selection.dart';
import '../models/solution_result.dart';
import 'backend_service.dart';

typedef ProgressCallback = void Function(String message);

class ProblemSolverService {
  ProblemSolverService({BackendService? backendService})
      : _backendService = backendService ?? BackendService();

  final BackendService _backendService;

  Future<SolutionResult> solve({
    required Uint8List imageBytes,
    required String mimeType,
    required SchoolLevel schoolLevel,
    required int grade,
    required String subject,
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call('로그인 정보를 확인하고 문제를 풀이하고 있어요…');
    return _backendService.solveProblem(
      imageBytes: imageBytes,
      mimeType: mimeType,
      schoolLevel: schoolLevel,
      grade: grade,
      subject: subject,
    );
  }
}
