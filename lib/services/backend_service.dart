import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/school_selection.dart';
import '../models/solution_result.dart';
import 'app_exception.dart';

class BackendService {
  BackendService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<SolutionResult> solveProblem({
    required Uint8List imageBytes,
    required String mimeType,
    required SchoolLevel schoolLevel,
    required int grade,
    required String subject,
  }) async {
    if (!AppConfig.hasBackendUrl) {
      throw const AppException(
        'Cloudflare Worker 주소가 아직 설정되지 않았습니다.',
      );
    }
    // Gemini의 인라인 요청 전체 제한은 20MB이며 Base64 변환 시
    // 사진 용량이 약 4/3배가 되므로 원본은 12MB 이하로 제한합니다.
    if (imageBytes.lengthInBytes > 12 * 1024 * 1024) {
      throw const AppException('사진 용량이 너무 큽니다. 다시 촬영해 주세요.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException('로그인이 만료되었습니다. 다시 로그인해 주세요.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AppException('로그인 확인 토큰을 만들지 못했습니다.');
    }

    final baseUrl = AppConfig.backendBaseUrl.replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final response = await _client
        .post(
          Uri.parse('$baseUrl/solve'),
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(
            <String, dynamic>{
              'imageBase64': base64Encode(imageBytes),
              'mimeType': mimeType,
              'schoolLevel': schoolLevel.storeValue,
              'schoolLevelLabel': schoolLevel.label,
              'grade': grade,
              'subject': subject,
            },
          ),
        )
        .timeout(const Duration(seconds: 120));

    final decoded = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString().trim();
      throw AppException(
        message == null || message.isEmpty
            ? '공부 가이드 서버 연결에 실패했습니다. (${response.statusCode})'
            : message,
      );
    }
    final resultValue = decoded['result'];
    if (resultValue is! Map) {
      throw const AppException('서버의 풀이 결과 형식을 읽지 못했습니다.');
    }
    final result = SolutionResult.fromMap(
      Map<String, dynamic>.from(resultValue),
    );
    if (result.problemText.isEmpty || result.finalAnswer.isEmpty) {
      throw const AppException('문제를 인식하지 못했습니다. 선명하게 다시 찍어 주세요.');
    }
    return result;
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {
      // 아래의 일반 오류 문구를 사용합니다.
    }
    return <String, dynamic>{};
  }
}
