import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../config/app_env.dart';
import '../../core/services/app_firebase.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import '../modules/notification_preferences_screen.dart';
import '../modules/system_settings_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.summary,
    required this.authUser,
    required this.onLogout,
    required this.token,
    required this.apiService,
    this.onSyncDeviceToken,
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic>? authUser;
  final Future<void> Function() onLogout;
  final String? token;
  final MobileApiService apiService;
  final Future<Map<String, dynamic>> Function()? onSyncDeviceToken;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  static final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  String? _avatarUrl;

  String _roleLabel(String value) {
    switch (value) {
      case 'admin':
        return 'Admin';
      case 'quan_ly':
        return 'Quản lý';
      case 'nhan_vien':
        return 'Nhân viên';
      case 'ke_toan':
        return 'Kế toán';
      default:
        return value;
    }
  }

  String _initials(String name) {
    final List<String> parts =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((String p) => p.isNotEmpty)
            .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _avatarUrl = AppEnv.resolveMediaUrl(
      (widget.authUser?['avatar_url'] ?? '').toString(),
    );
  }

  @override
  void didUpdateWidget(covariant AccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextUrl = AppEnv.resolveMediaUrl(
      (widget.authUser?['avatar_url'] ?? '').toString(),
    );
    if (nextUrl != _avatarUrl) {
      _avatarUrl = nextUrl;
    }
  }

  Future<void> _pickAvatar() async {
    if (widget.token == null || widget.token!.isEmpty) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Cần đăng nhập để cập nhật ảnh đại diện.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
        ),
      );
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    final String? path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    final String? url = await widget.apiService.updateProfileAvatar(
      widget.token!,
      filePath: path,
    );
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật ảnh đại diện.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
        ),
      );
      return;
    }
    setState(() => _avatarUrl = AppEnv.resolveMediaUrl(url));
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật ảnh đại diện.'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom + 80;
    final String displayName =
        (widget.authUser?['name'] ?? 'Nhân sự').toString();
    final String displayRole = _roleLabel(
      (widget.authUser?['role'] ?? '').toString(),
    );
    final String email = (widget.authUser?['email'] ?? '').toString();
    final List<dynamic> roles =
        (widget.summary['roles'] ?? <dynamic>[]) as List<dynamic>;
    final bool isAdmin = (widget.authUser?['role'] ?? '') == 'admin';

    Future<void> handleTestPush() async {
      if (widget.token == null || widget.token!.isEmpty) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Cần đăng nhập để test thông báo.'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
          ),
        );
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final Map<String, dynamic> result = await widget.apiService.testPush(
        widget.token!,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (result['error'] == true) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể gửi push. Kiểm tra quyền admin và cấu hình Firebase.',
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
          ),
        );
        return;
      }
      final int tokenCount = (result['token_count'] ?? 0) as int;
      final bool pushSent = result['push_sent'] == true;
      final bool emailSent = result['email_sent'] == true;
      final Map<String, dynamic> tokenByPlatform =
          result['token_by_platform'] is Map
              ? Map<String, dynamic>.from(result['token_by_platform'] as Map)
              : <String, dynamic>{};
      final int androidTokens =
          (tokenByPlatform['android'] as num?)?.toInt() ?? 0;
      final int iosTokens = (tokenByPlatform['ios'] as num?)?.toInt() ?? 0;
      final int webTokens = (tokenByPlatform['web'] as num?)?.toInt() ?? 0;
      final int tokenEnabled =
          (result['token_notifications_enabled'] as num?)?.toInt() ?? 0;
      final int tokenDisabled =
          (result['token_notifications_disabled'] as num?)?.toInt() ?? 0;
      final Map<String, dynamic> pushResult =
          result['push_result'] is Map
              ? Map<String, dynamic>.from(result['push_result'] as Map)
              : <String, dynamic>{};
      final String pushReason =
          (pushResult['error'] ?? result['error'] ?? '—').toString();
      final String? localToken = AppFirebase.lastPushToken;
      final String? localTokenAt =
          AppFirebase.lastPushTokenAt == null
              ? null
              : AppFirebase.lastPushTokenAt!.toLocal().toString();
      final StringBuffer buffer = StringBuffer();
      if (pushSent) {
        buffer.write('Đã gửi push thử nghiệm.');
      } else {
        buffer.write('Không gửi được push (token: $tokenCount).');
        if (tokenCount <= 0) {
          buffer.write(' Mở Cài đặt thông báo trên app để đồng bộ token.');
        }
      }
      if (emailSent) {
        buffer.write(' Đã gửi email dự phòng.');
      }
      buffer.write(' Token: $tokenCount.');
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(buffer.toString()),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        ),
      );

      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Chi tiết test thông báo'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _StatusRow(
                      label: 'Kết quả push',
                      value: pushSent ? 'Đã gửi' : 'Không gửi',
                      color: pushSent ? Colors.green : Colors.red,
                    ),
                    _StatusRow(
                      label: 'Email dự phòng',
                      value: emailSent ? 'Đã gửi' : 'Không gửi',
                      color: emailSent ? Colors.green : Colors.red,
                    ),
                    _StatusRow(
                      label: 'Token server',
                      value: tokenCount.toString(),
                      color: StitchTheme.textMain,
                    ),
                    _StatusRow(
                      label: 'Lý do',
                      value: pushReason,
                      color: StitchTheme.textMuted,
                    ),
                    _StatusRow(
                      label: 'Token Android / iOS / Web',
                      value: '$androidTokens / $iosTokens / $webTokens',
                      color: StitchTheme.textMain,
                    ),
                    _StatusRow(
                      label: 'Token quyền ON / OFF',
                      value: '$tokenEnabled / $tokenDisabled',
                      color: StitchTheme.textMain,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Token thiết bị (cục bộ)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      localToken?.isNotEmpty == true
                          ? localToken!
                          : 'Chưa có token',
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                    if (localTokenAt != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Cập nhật: $localTokenAt',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
      );
    }

    return SafeArea(
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
          children: <Widget>[
            const Text(
              'Tài khoản',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.authUser == null
                  ? 'Đăng nhập để truy cập đầy đủ phân hệ.'
                  : 'Xin chào, $displayName!',
              style: const TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                children: <Widget>[
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: StitchTheme.primary,
                        backgroundImage:
                            (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                ? NetworkImage(_avatarUrl!)
                                : null,
                        child:
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                                ? Text(
                                  _initials(displayName),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                )
                                : null,
                      ),
                      InkWell(
                        onTap: _pickAvatar,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: StitchTheme.primary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: StitchTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayRole.isEmpty ? '—' : displayRole,
                    style: TextStyle(
                      color: StitchTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (email.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'TÀI KHOẢN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: StitchTheme.textSubtle,
              ),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              children: <Widget>[
                _MenuItem(
                  icon: Icons.person_outline,
                  title: 'Thông tin cá nhân',
                ),
                _MenuDivider(),
                _MenuItem(icon: Icons.lock_outline, title: 'Đổi mật khẩu'),
                _MenuDivider(),
                _MenuItem(
                  icon: Icons.notifications_none,
                  title: 'Cài đặt thông báo',
                  onTap: () {
                    if (widget.token == null || widget.token!.isEmpty) {
                      _messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Cần đăng nhập để cấu hình thông báo.'),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<Widget>(
                        builder:
                            (_) => NotificationPreferencesScreen(
                              token: widget.token!,
                              apiService: widget.apiService,
                              onSyncDeviceToken: widget.onSyncDeviceToken,
                            ),
                      ),
                    );
                  },
                ),
                _MenuDivider(),
                _MenuItem(
                  icon: Icons.language,
                  title: 'Ngôn ngữ',
                  trailing: const Text(
                    'Tiếng Việt',
                    style: TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
                if (isAdmin) ...<Widget>[
                  _MenuDivider(),
                  _MenuItem(
                    icon: Icons.settings,
                    title: 'Cài đặt hệ thống',
                    onTap: () {
                      if (widget.token == null || widget.token!.isEmpty) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<Widget>(
                          builder:
                              (_) => SystemSettingsScreen(
                                token: widget.token!,
                                apiService: widget.apiService,
                              ),
                        ),
                      );
                    },
                  ),
                  _MenuDivider(),
                  _MenuItem(
                    icon: Icons.notifications_active,
                    title: 'Test gửi thông báo',
                    onTap: () {
                      handleTestPush();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'PHÂN BỔ VAI TRÒ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: StitchTheme.textSubtle,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Phân bổ vai trò',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (roles.isEmpty)
                    const Text(
                      'Chưa có dữ liệu vai trò.',
                      style: TextStyle(color: StitchTheme.textMuted),
                    )
                  else
                    ...roles.map((dynamic e) {
                      final Map<String, dynamic> m = e as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${m['label']}: ${m['value']}',
                          style: const TextStyle(color: StitchTheme.textMuted),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'HỖ TRỢ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: StitchTheme.textSubtle,
              ),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              children: const <Widget>[
                _MenuItem(icon: Icons.help_outline, title: 'Trợ giúp & Hỗ trợ'),
                _MenuDivider(),
                _MenuItem(icon: Icons.info_outline, title: 'Về hệ thống'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: StitchTheme.border);
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: StitchTheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(color: StitchTheme.textMuted)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
