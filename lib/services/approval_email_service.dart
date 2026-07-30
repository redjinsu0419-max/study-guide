import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/school_selection.dart';
import 'app_exception.dart';

class ApprovalEmailService {
  static Future<void> openApprovalRequest(AppUser user) async {
    final adminEmail = AppConfig.adminEmails.first;
    final subject = Uri.encodeComponent('[공부 가이드] 가입 승인 요청');
    final body = Uri.encodeComponent(
      '''
공부 가이드 가입 승인을 요청합니다.

이름: ${user.displayName}
가입 이메일: ${user.email}
학교급/학년: ${user.schoolLevel.label} ${user.grade}학년
사용자 UID: ${user.uid}

관리자 계정($adminEmail)으로 공부 가이드 앱에 로그인한 뒤
[승인 관리] 메뉴에서 보호자 동의 여부를 확인하고 승인해 주세요.
''',
    );
    final uri = Uri.parse(
      'mailto:$adminEmail?subject=$subject&body=$body',
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const AppException(
        '메일 앱을 열 수 없습니다. 관리자에게 직접 승인 요청을 보내 주세요.',
      );
    }
  }
}
