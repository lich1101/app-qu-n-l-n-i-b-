import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/stitch_theme.dart';

/// Màn hình đăng nhập full-screen: hiển thị khi chưa có token.
/// Sau khi đăng nhập thành công, [onLogin] callback cập nhật state ở shell
/// và chuyển sang dashboard có bottom navigation.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.authMessage,
    required this.isLoading,
    required this.onLogin,
    required this.onForgotPassword,
    required this.savedAccounts,
    required this.rememberMe,
    required this.onToggleRemember,
    required this.onSelectAccount,
    required this.onRemoveAccount,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String authMessage;
  final bool isLoading;
  final Future<void> Function({required String email, required String password})
  onLogin;
  final Future<String> Function({required String email}) onForgotPassword;
  final List<String> savedAccounts;
  final bool rememberMe;
  final ValueChanged<bool> onToggleRemember;
  final ValueChanged<String> onSelectAccount;
  final ValueChanged<String> onRemoveAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isSendingForgotPassword = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: <Widget>[
            const SizedBox(height: 8),
            Column(
              children: <Widget>[
                AnimatedBuilder(
                  animation: appSettingsStore,
                  builder: (BuildContext context, Widget? child) {
                    final String? logoUrl = appSettingsStore.settings.logoUrl;
                    if (logoUrl != null && logoUrl.isNotEmpty) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          logoUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Image.asset(
                                'icon.png',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'icon.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: appSettingsStore,
                  builder: (BuildContext context, Widget? child) {
                    return Text(
                      appSettingsStore.settings.brandName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.textMain,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hệ thống quản lý nội bộ Jobs ClickOn',
                  style: TextStyle(color: StitchTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 24,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.savedAccounts.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.account_box_outlined,
                          color: StitchTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tài khoản đã lưu (${widget.savedAccounts.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: StitchTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children:
                          widget.savedAccounts.map((String email) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: StitchTheme.border),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.person_outline,
                                    color: StitchTheme.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => widget.onSelectAccount(email),
                                      child: Text(
                                        email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: StitchTheme.textMain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        () => widget.onRemoveAccount(email),
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: StitchTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Tài khoản',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.emailController,
                    decoration: const InputDecoration(
                      hintText: 'Email đăng nhập',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(context),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: widget.rememberMe,
                        onChanged: (bool? value) {
                          if (value == null) return;
                          widget.onToggleRemember(value);
                        },
                      ),
                      const Text('Ghi nhớ'),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            _isSendingForgotPassword
                                ? null
                                : () => _showForgotPasswordDialog(context),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: widget.isLoading ? null : () => _submit(context),
                    child: Text(
                      widget.isLoading ? 'Đang đăng nhập...' : 'Đăng nhập',
                    ),
                  ),
                  if (widget.authMessage.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      widget.authMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            widget.authMessage.contains('thất bại') ||
                                    widget.authMessage.contains('lỗi')
                                ? StitchTheme.danger
                                : StitchTheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '© 2026 Clickon. Mọi quyền được bảo lưu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StitchTheme.textSubtle),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final String email = widget.emailController.text.trim();
    final String password = widget.passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      return;
    }
    widget.onLogin(email: email, password: password);
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final TextEditingController emailController = TextEditingController(
      text: widget.emailController.text.trim(),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> submitForgotPassword() async {
              final String email = emailController.text.trim();
              if (email.isEmpty || _isSendingForgotPassword) {
                return;
              }

              setDialogState(() => _isSendingForgotPassword = true);

              try {
                final String message = await widget.onForgotPassword(
                  email: email,
                );
                if (!mounted || !dialogContext.mounted) return;
                setState(() => _isSendingForgotPassword = false);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text(message)));
              } catch (_) {
                if (!mounted || !dialogContext.mounted) return;
                setDialogState(() => _isSendingForgotPassword = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Không thể gửi mật khẩu mới. Vui lòng thử lại.',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Quên mật khẩu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Nhập email đăng nhập. Hệ thống sẽ tạo mật khẩu mới và gửi về email đó.',
                    style: TextStyle(
                      fontSize: 13,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email đăng nhập',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    onSubmitted: (_) => submitForgotPassword(),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      _isSendingForgotPassword
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed:
                      _isSendingForgotPassword ? null : submitForgotPassword,
                  child: Text(
                    _isSendingForgotPassword
                        ? 'Đang gửi...'
                        : 'Gửi mật khẩu mới',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
