import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import 'login_screen.dart';

/// 비밀번호 찾기 (청온 FindPasswordActivity). 메일 발송 서버가 없어서 아직 안내만 합니다. 담당: 개발자1
class FindPasswordScreen extends StatefulWidget {
  const FindPasswordScreen({super.key});

  @override
  State<FindPasswordScreen> createState() => _FindPasswordScreenState();
}

class _FindPasswordScreenState extends State<FindPasswordScreen> {
  final _id = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  void _submit() {
    if (_id.text.trim().isEmpty) {
      setState(() => _error = '아이디를 입력해 주세요.');
      return;
    }
    setState(() => _error = null);
    showMessage(context, '비밀번호 찾기 기능은 준비 중이에요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuHeader(title: '비밀번호 찾기', subtitle: nt('Quên mật khẩu')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const Text(
                    '가입한 아이디를 입력해 주세요.',
                    style: TextStyle(fontSize: 15, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 20),
                  SectionLabel('아이디', sub: nt('Tên đăng nhập')),
                  const SizedBox(height: 8),
                  IjuTextField(
                    controller: _id,
                    errorText: _error,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: IjuButton(label: '비밀번호 찾기', onPressed: _submit),
            ),
          ],
        ),
      ),
    );
  }
}
