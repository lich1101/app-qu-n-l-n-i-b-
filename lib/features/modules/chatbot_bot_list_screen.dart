import 'package:flutter/material.dart';

import '../../config/app_env.dart';
import '../../core/messaging/app_tag_message.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import 'chatbot_assistant_screen.dart';

class ChatbotBotListScreen extends StatefulWidget {
  const ChatbotBotListScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<ChatbotBotListScreen> createState() => _ChatbotBotListScreenState();
}

class _ChatbotBotListScreenState extends State<ChatbotBotListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bots = <Map<String, dynamic>>[];

  String _normalizeBotIcon(dynamic value) {
    final String icon = (value ?? '').toString().trim();
    if (icon.isEmpty) return '🤖';
    return icon;
  }

  Widget _buildBotAvatar({
    required String avatarUrl,
    required String fallbackIcon,
    double radius = 20,
  }) {
    final String resolvedAvatarUrl = AppEnv.resolveMediaUrl(avatarUrl);
    final String safeIcon = _normalizeBotIcon(fallbackIcon);
    if (resolvedAvatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: StitchTheme.primary.withValues(alpha: 0.14),
        child: Text(safeIcon, style: const TextStyle(fontSize: 18)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: StitchTheme.primary.withValues(alpha: 0.14),
      child: ClipOval(
        child: Image.network(
          resolvedAvatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  Center(
                    child: Text(safeIcon, style: const TextStyle(fontSize: 18)),
                  ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBots();
  }

  Future<void> _loadBots() async {
    setState(() => _loading = true);
    final Map<String, dynamic> data = await widget.apiService.getChatbotBots(
      widget.token,
    );
    if (!mounted) return;

    if (data['error'] == true) {
      setState(() {
        _loading = false;
        _bots = <Map<String, dynamic>>[];
      });
      _showSnack('Không tải được danh sách chatbot.');
      return;
    }

    setState(() {
      _loading = false;
      _bots =
          ((data['bots'] ?? <dynamic>[]) as List<dynamic>)
              .map((dynamic item) => Map<String, dynamic>.from(item as Map))
              .toList();
    });
  }

  Future<void> _openBot(Map<String, dynamic> bot) async {
    final dynamic idRaw = bot['id'];
    final int? botId = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
    if (botId == null || botId <= 0) {
      _showSnack('Bot không hợp lệ.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ChatbotAssistantScreen(
              token: widget.token,
              apiService: widget.apiService,
              botId: botId,
              botName: (bot['name'] ?? 'Trợ lý AI').toString(),
            ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppTagMessage.show(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách chatbot')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBots,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: StitchTheme.border),
                ),
                child: const Text(
                  'Chọn chatbot để bắt đầu hội thoại. Mỗi chatbot giữ ngữ cảnh riêng theo từng tài khoản.',
                  style: TextStyle(color: StitchTheme.textMuted, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _bots.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: const Text(
                    'Chưa có chatbot nào đang bật. Administrator cần vào Cài đặt hệ thống để tạo bot.',
                    style: TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
              ..._bots.map((Map<String, dynamic> bot) {
                final bool configured = (bot['configured'] ?? false) == true;
                final bool isDefault = (bot['is_default'] ?? false) == true;
                final String name = (bot['name'] ?? 'Trợ lý AI').toString();
                final String description =
                    (bot['description'] ?? '').toString().trim();
                final String icon = _normalizeBotIcon(bot['icon']);
                final String avatarUrl =
                    (bot['avatar_url'] ?? bot['avatar'] ?? '')
                        .toString()
                        .trim();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: ListTile(
                    onTap: () => _openBot(bot),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _buildBotAvatar(
                      avatarUrl: avatarUrl,
                      fallbackIcon: icon,
                    ),
                    title: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Mặc định',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            description.isEmpty
                                ? 'Trợ lý AI cho hội thoại nội bộ.'
                                : description,
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      configured
                                          ? const Color(0xFFDBEAFE)
                                          : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  configured ? 'Đã cấu hình' : 'Thiếu cấu hình',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        configured
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: StitchTheme.textSubtle,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
