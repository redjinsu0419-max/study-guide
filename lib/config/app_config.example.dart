/// 이 파일을 app_config.dart로 복사한 뒤 Worker 주소를 입력하세요.
///
/// Gemini/Pinecone 키는 앱 파일이 아니라 Cloudflare Worker의
/// Secret으로 저장합니다.
class AppConfig {
  AppConfig._();

  static const String backendBaseUrl =
      'https://PASTE_WORKER_NAME.PASTE_SUBDOMAIN.workers.dev';

  /// Firestore 보안 규칙의 관리자 이메일과 반드시 똑같이 입력하세요.
  static const List<String> adminEmails = <String>[
    'redjinsu0419@gmail.com',
  ];

  static const int maxApprovedUsers = 10;

  static bool get hasBackendUrl =>
      backendBaseUrl.trim().startsWith('https://') &&
      !backendBaseUrl.contains('PASTE_');

  static bool isAdminEmail(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    return adminEmails.any(
      (admin) => admin.trim().toLowerCase() == normalized,
    );
  }
}
