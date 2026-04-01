import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_env.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class ChatbotAssistantScreen extends StatefulWidget {
  const ChatbotAssistantScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.botId,
    this.botName,
  });

  final String token;
  final MobileApiService apiService;
  final int botId;
  final String? botName;

  @override
  State<ChatbotAssistantScreen> createState() => _ChatbotAssistantScreenState();
}

class _ChatbotAssistantScreenState extends State<ChatbotAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  Timer? _pollingTimer;
  bool _loading = false;
  bool _sending = false;
  bool _stopping = false;
  File? _pendingAttachment;
  Map<String, dynamic>? _sendingPreview;

  Map<String, dynamic> _chatbot = <String, dynamic>{};
  Map<String, dynamic> _bot = <String, dynamic>{};
  Map<String, dynamic> _state = <String, dynamic>{};
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  final Map<int, String> _queueDrafts = <int, String>{};
  bool _queueExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadConversation(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _inputController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom({double threshold = 72}) {
    if (!_messageScrollController.hasClients) return true;
    final ScrollPosition position = _messageScrollController.position;
    return (position.maxScrollExtent - position.pixels) <= threshold;
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_messageScrollController.hasClients) return;
    final double target = _messageScrollController.position.maxScrollExtent;
    if (animated) {
      _messageScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    _messageScrollController.jumpTo(target);
  }

  Future<void> _loadConversation({bool silent = false}) async {
    final bool shouldAutoScroll = _isNearBottom();
    if (!silent) {
      setState(() => _loading = true);
    }

    final Map<String, dynamic> data = await widget.apiService
        .getChatbotMessages(widget.token, limit: 220, botId: widget.botId);

    if (!mounted) return;
    if (data['error'] == true) {
      if (!silent) {
        setState(() => _loading = false);
      }
      _showSnack('Không tải được hội thoại chatbot.');
      return;
    }

    final List<Map<String, dynamic>> messages =
        ((data['messages'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final List<Map<String, dynamic>> queue =
        ((data['queue'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();

    setState(() {
      _loading = false;
      _chatbot = Map<String, dynamic>.from(
        (data['chatbot'] ?? <String, dynamic>{}) as Map,
      );
      _bot = Map<String, dynamic>.from(
        (data['bot'] ?? <String, dynamic>{}) as Map,
      );
      _state = Map<String, dynamic>.from(
        (data['state'] ?? <String, dynamic>{}) as Map,
      );
      _messages = messages;
      _queue = queue;

      for (final Map<String, dynamic> item in queue) {
        final int id = _toInt(item['id']);
        if (!_queueDrafts.containsKey(id)) {
          _queueDrafts[id] = (item['content'] ?? '').toString();
        }
      }
      final Set<int> validIds = queue.map((item) => _toInt(item['id'])).toSet();
      final List<int> staleIds =
          _queueDrafts.keys.where((int id) => !validIds.contains(id)).toList();
      for (final int id in staleIds) {
        _queueDrafts.remove(id);
      }
    });

    if (shouldAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: true);
      });
    }
  }

  Future<void> _send() async {
    final String content = _inputController.text.trim();
    if ((content.isEmpty && _pendingAttachment == null) || _sending) return;

    final File? attachment = _pendingAttachment;
    final String fileName = attachment?.path.split('/').last ?? '';
    final String fileSize =
        attachment == null ? '' : _formatBytes(attachment.lengthSync());
    final bool attachmentIsImage =
        attachment != null && _isImageFileName(fileName);

    setState(() {
      _sending = true;
      _sendingPreview = <String, dynamic>{
        'content': content,
        'attachment_name': fileName,
        'attachment_size': fileSize,
        'attachment_is_image': attachmentIsImage,
      };
      _inputController.clear();
      _pendingAttachment = null;
    });

    final Map<String, dynamic> data = await widget.apiService
        .sendChatbotMessage(
          widget.token,
          content: content,
          attachment: attachment,
          botId: widget.botId,
        );

    if (!mounted) return;
    setState(() => _sending = false);
    if (data['error'] == true) {
      setState(() {
        _sendingPreview = <String, dynamic>{
          ...?_sendingPreview,
          'failed': true,
        };
      });
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            if ((_sendingPreview?['failed'] ?? false) == true) {
              _sendingPreview = null;
            }
          });
        }),
      );
      _showSnack('Không gửi được câu hỏi.');
      return;
    }

    setState(() => _sendingPreview = null);
    _applyPayload(data, forceScroll: true);
  }

  Future<void> _stop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    final Map<String, dynamic> data = await widget.apiService.stopChatbot(
      widget.token,
      botId: widget.botId,
    );
    if (!mounted) return;
    setState(() => _stopping = false);
    if (data['error'] == true) {
      _showSnack('Không gửi được yêu cầu dừng.');
      return;
    }
    _applyPayload(data);
    _showSnack('Đã gửi yêu cầu dừng phản hồi hiện tại.');
  }

  Future<void> _updateQueue(int messageId) async {
    final String content = (_queueDrafts[messageId] ?? '').trim();
    if (content.isEmpty) {
      _showSnack('Nội dung hàng chờ không được để trống.');
      return;
    }

    final Map<String, dynamic> data = await widget.apiService
        .updateQueuedChatbotMessage(widget.token, messageId, content: content);
    if (!mounted) return;
    if (data['error'] == true) {
      _showSnack('Không cập nhật được hàng chờ.');
      return;
    }
    _applyPayload(data);
    _showSnack('Đã cập nhật hàng chờ.');
  }

  Future<void> _deleteQueue(int messageId) async {
    final Map<String, dynamic> data = await widget.apiService
        .deleteQueuedChatbotMessage(widget.token, messageId);
    if (!mounted) return;
    if (data['error'] == true) {
      _showSnack('Không xoá được tin nhắn hàng chờ.');
      return;
    }
    _applyPayload(data);
    _showSnack('Đã xoá khỏi hàng chờ.');
  }

  void _applyPayload(Map<String, dynamic> data, {bool forceScroll = false}) {
    final bool shouldAutoScroll = forceScroll || _isNearBottom();
    final List<Map<String, dynamic>> messages =
        ((data['messages'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final List<Map<String, dynamic>> queue =
        ((data['queue'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();

    setState(() {
      _chatbot = Map<String, dynamic>.from(
        (data['chatbot'] ?? <String, dynamic>{}) as Map,
      );
      _bot = Map<String, dynamic>.from(
        (data['bot'] ?? <String, dynamic>{}) as Map,
      );
      _state = Map<String, dynamic>.from(
        (data['state'] ?? <String, dynamic>{}) as Map,
      );
      _messages = messages;
      _queue = queue;
      for (final Map<String, dynamic> item in queue) {
        final int id = _toInt(item['id']);
        _queueDrafts.putIfAbsent(id, () => (item['content'] ?? '').toString());
      }
    });

    if (shouldAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: true);
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  bool get _isProcessing => (_state['is_processing'] ?? false) == true;
  bool get _chatbotEnabled => (_chatbot['enabled'] ?? false) == true;
  bool get _chatbotConfigured => (_chatbot['configured'] ?? false) == true;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAttachment() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final String? path = result.files.single.path;
    if (path == null || path.isEmpty) {
      _showSnack('Không đọc được file đã chọn.');
      return;
    }
    setState(() {
      _pendingAttachment = File(path);
    });
  }

  void _clearAttachment() {
    setState(() => _pendingAttachment = null);
  }

  bool _isImageFileName(String value) {
    final String lower = value.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  String _formatBytes(dynamic value) {
    final int size = _toInt(value);
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _resolveAttachmentUrl(String raw) {
    return AppEnv.resolveMediaUrl(raw);
  }

  String _normalizeBotIcon(dynamic value) {
    final String icon = (value ?? '').toString().trim();
    if (icon.isEmpty) return '🤖';
    return icon;
  }

  Widget _buildBotAvatar({
    required String avatarUrl,
    required String fallbackIcon,
    double radius = 15,
    double iconSize = 13,
  }) {
    final String resolvedAvatarUrl = _resolveAttachmentUrl(avatarUrl);
    final String safeIcon = _normalizeBotIcon(fallbackIcon);
    if (resolvedAvatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: StitchTheme.primary.withValues(alpha: 0.14),
        child: Text(safeIcon, style: TextStyle(fontSize: iconSize)),
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
                    child: Text(safeIcon, style: TextStyle(fontSize: iconSize)),
                  ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final String resolved = _resolveAttachmentUrl(url);
    if (resolved.isEmpty) {
      _showSnack('File đính kèm không hợp lệ.');
      return;
    }
    final Uri uri = Uri.parse(resolved);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showSnack('Không mở được file đính kèm.');
    }
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'queued':
        return 'Đang chờ';
      case 'processing':
        return 'Đang xử lý';
      case 'failed':
        return 'Lỗi';
      case 'cancelled':
        return 'Đã dừng';
      default:
        return 'Hoàn tất';
    }
  }

  Color _statusBg(String raw) {
    switch (raw) {
      case 'queued':
        return const Color(0xFFFEF3C7);
      case 'processing':
        return const Color(0xFFDBEAFE);
      case 'failed':
        return const Color(0xFFFEE2E2);
      case 'cancelled':
        return const Color(0xFFE2E8F0);
      default:
        return const Color(0xFFDCFCE7);
    }
  }

  Color _statusText(String raw) {
    switch (raw) {
      case 'queued':
        return const Color(0xFF92400E);
      case 'processing':
        return const Color(0xFF1D4ED8);
      case 'failed':
        return const Color(0xFFB91C1C);
      case 'cancelled':
        return const Color(0xFF334155);
      default:
        return const Color(0xFF166534);
    }
  }

  MarkdownStyleSheet _markdownStyle({required bool isUser}) {
    final Color textColor = isUser ? Colors.white : StitchTheme.textMain;
    final Color headingColor = isUser ? Colors.white : StitchTheme.textMain;
    return MarkdownStyleSheet(
      p: TextStyle(fontSize: 14, height: 1.5, color: textColor),
      h1: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h2: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h3: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      listBullet: TextStyle(fontSize: 14, height: 1.45, color: textColor),
      strong: TextStyle(fontWeight: FontWeight.w700, color: headingColor),
      a: TextStyle(
        color: isUser ? Colors.white : StitchTheme.primary,
        decoration: TextDecoration.underline,
      ),
      code: TextStyle(
        fontSize: 12.5,
        fontFamily: 'monospace',
        color: isUser ? Colors.white : const Color(0xFF1E293B),
        backgroundColor:
            isUser
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFE2E8F0),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color:
            isUser
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isUser
                  ? Colors.white.withValues(alpha: 0.25)
                  : StitchTheme.border,
        ),
      ),
      blockSpacing: 8,
      listIndent: 22,
    );
  }

  Future<void> _openMarkdownLink(String raw) async {
    final String value = raw.trim();
    if (value.isEmpty) return;
    final String href =
        value.startsWith('http://') || value.startsWith('https://')
            ? value
            : 'https://$value';
    final Uri? uri = Uri.tryParse(href);
    if (uri == null) {
      _showSnack('Liên kết không hợp lệ.');
      return;
    }
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showSnack('Không mở được liên kết.');
    }
  }

  Widget _buildMessageMarkdown({
    required String content,
    required bool isUser,
  }) {
    final String text = content.trim();
    if (text.isEmpty) {
      return Text(
        'Tin nhắn chỉ có tệp đính kèm.',
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color:
              isUser
                  ? Colors.white.withValues(alpha: 0.9)
                  : StitchTheme.textMuted,
        ),
      );
    }
    return MarkdownBody(
      data: text,
      selectable: false,
      softLineBreak: true,
      styleSheet: _markdownStyle(isUser: isUser),
      onTapLink: (String text, String? href, String title) {
        if (href == null || href.trim().isEmpty) return;
        unawaited(_openMarkdownLink(href));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String inputTrimmed = _inputController.text.trim();
    final bool hasPendingAttachment = _pendingAttachment != null;
    final bool showStop =
        _isProcessing && inputTrimmed.isEmpty && !hasPendingAttachment;
    final bool canSend =
        _chatbotEnabled &&
        _chatbotConfigured &&
        (inputTrimmed.isNotEmpty || hasPendingAttachment);
    final bool canStop = _chatbotEnabled && _chatbotConfigured && _isProcessing;
    final String assistantIcon = _normalizeBotIcon(_bot['icon']);
    final String assistantAvatarUrl =
        (_bot['avatar_url'] ?? _bot['avatar'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.botName?.trim().isNotEmpty == true
              ? widget.botName!
              : 'Trợ lý AI',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: StitchTheme.border),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child:
                      _loading
                          ? Container(
                            color: const Color(0xFFF8FAFC),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          )
                          : RefreshIndicator(
                            onRefresh: () => _loadConversation(silent: true),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    Color(0xFFF8FAFC),
                                    Color(0xFFFFFFFF),
                                    Color(0xFFF1F5F9),
                                  ],
                                ),
                              ),
                              child: ListView(
                                controller: _messageScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  12,
                                ),
                                children: <Widget>[
                                  if (!_chatbotConfigured || !_chatbotEnabled)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFCD34D),
                                        ),
                                      ),
                                      child: const Text(
                                        'Chatbot chưa sẵn sàng. Administrator cần hoàn tất cấu hình ở Cài đặt hệ thống.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  if (_messages.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: StitchTheme.border,
                                        ),
                                      ),
                                      child: const Text(
                                        'Chưa có hội thoại. Hãy gửi câu hỏi đầu tiên.',
                                        style: TextStyle(
                                          color: StitchTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ..._messages.map((Map<String, dynamic> row) {
                                    final bool isUser =
                                        (row['role'] ?? '') == 'user';
                                    final String status =
                                        (row['status'] ?? '').toString();
                                    final String content =
                                        (row['content'] ?? '').toString();
                                    final String error =
                                        (row['error_message'] ?? '').toString();
                                    final Map<String, dynamic>? attachment =
                                        row['attachment'] is Map
                                            ? Map<String, dynamic>.from(
                                              row['attachment'] as Map,
                                            )
                                            : null;
                                    final String attachmentUrl =
                                        _resolveAttachmentUrl(
                                          (attachment?['url'] ?? '').toString(),
                                        );
                                    final String attachmentName =
                                        (attachment?['name'] ?? 'Tệp đính kèm')
                                            .toString();
                                    final String attachmentSize = _formatBytes(
                                      attachment?['size'],
                                    );
                                    final bool attachmentIsImage =
                                        (attachment?['is_image'] == true) ||
                                        _isImageFileName(attachmentName) ||
                                        _isImageFileName(attachmentUrl);
                                    final DateTime? createdAt =
                                        DateTime.tryParse(
                                          (row['created_at'] ?? '').toString(),
                                        );
                                    final String timeLabel =
                                        createdAt == null
                                            ? ''
                                            : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            isUser
                                                ? MainAxisAlignment.end
                                                : MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          if (!isUser)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                                top: 2,
                                              ),
                                              child: _buildBotAvatar(
                                                avatarUrl: assistantAvatarUrl,
                                                fallbackIcon: assistantIcon,
                                                radius: 15,
                                                iconSize: 13,
                                              ),
                                            ),
                                          Flexible(
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width *
                                                    0.82,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isUser
                                                        ? StitchTheme.primary
                                                        : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                boxShadow: const <BoxShadow>[
                                                  BoxShadow(
                                                    color: Color(0x220F172A),
                                                    blurRadius: 14,
                                                    offset: Offset(0, 5),
                                                  ),
                                                ],
                                                border:
                                                    isUser
                                                        ? null
                                                        : Border.all(
                                                          color:
                                                              StitchTheme
                                                                  .border,
                                                        ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  _buildMessageMarkdown(
                                                    content: content,
                                                    isUser: isUser,
                                                  ),
                                                  if (attachment != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8,
                                                          ),
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        onTap:
                                                            attachmentUrl
                                                                    .isEmpty
                                                                ? null
                                                                : () => _openAttachment(
                                                                  attachmentUrl,
                                                                ),
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                isUser
                                                                    ? Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.14,
                                                                        )
                                                                    : const Color(
                                                                      0xFFF8FAFC,
                                                                    ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  isUser
                                                                      ? Colors
                                                                          .white
                                                                          .withValues(
                                                                            alpha:
                                                                                0.22,
                                                                          )
                                                                      : StitchTheme
                                                                          .border,
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: <Widget>[
                                                              if (attachmentIsImage &&
                                                                  attachmentUrl
                                                                      .isNotEmpty)
                                                                ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                  child: Image.network(
                                                                    attachmentUrl,
                                                                    height: 150,
                                                                    width:
                                                                        double
                                                                            .infinity,
                                                                    fit:
                                                                        BoxFit
                                                                            .cover,
                                                                    errorBuilder:
                                                                        (
                                                                          _,
                                                                          __,
                                                                          ___,
                                                                        ) => Container(
                                                                          height:
                                                                              78,
                                                                          alignment:
                                                                              Alignment.center,
                                                                          color:
                                                                              Colors.black26,
                                                                          child: Text(
                                                                            'Không xem trước được ảnh',
                                                                            style: TextStyle(
                                                                              color:
                                                                                  isUser
                                                                                      ? Colors.white
                                                                                      : StitchTheme.textMuted,
                                                                              fontSize:
                                                                                  12,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                  ),
                                                                )
                                                              else
                                                                Row(
                                                                  children: <
                                                                    Widget
                                                                  >[
                                                                    Container(
                                                                      width: 34,
                                                                      height:
                                                                          34,
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            isUser
                                                                                ? Colors.white.withValues(
                                                                                  alpha:
                                                                                      0.2,
                                                                                )
                                                                                : const Color(
                                                                                  0xFFE2E8F0,
                                                                                ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      child: Text(
                                                                        attachmentIsImage
                                                                            ? '🖼️'
                                                                            : '📎',
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: <
                                                                          Widget
                                                                        >[
                                                                          Text(
                                                                            attachmentName,
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                            style: TextStyle(
                                                                              fontWeight:
                                                                                  FontWeight.w600,
                                                                              color:
                                                                                  isUser
                                                                                      ? Colors.white
                                                                                      : StitchTheme.textMain,
                                                                            ),
                                                                          ),
                                                                          if (attachmentSize
                                                                              .isNotEmpty)
                                                                            Text(
                                                                              attachmentSize,
                                                                              style: TextStyle(
                                                                                fontSize:
                                                                                    11,
                                                                                color:
                                                                                    isUser
                                                                                        ? Colors.white.withValues(
                                                                                          alpha:
                                                                                              0.9,
                                                                                        )
                                                                                        : StitchTheme.textMuted,
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              if (attachmentIsImage &&
                                                                  attachmentUrl
                                                                      .isNotEmpty)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        top: 6,
                                                                      ),
                                                                  child: Text(
                                                                    '$attachmentName${attachmentSize.isNotEmpty ? ' • $attachmentSize' : ''}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color:
                                                                          isUser
                                                                              ? Colors.white.withValues(
                                                                                alpha:
                                                                                    0.9,
                                                                              )
                                                                              : StitchTheme.textMuted,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: <Widget>[
                                                      if (timeLabel.isNotEmpty)
                                                        Text(
                                                          timeLabel,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                isUser
                                                                    ? Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.88,
                                                                        )
                                                                    : StitchTheme
                                                                        .textMuted,
                                                          ),
                                                        ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isUser
                                                                  ? Colors.white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      )
                                                                  : _statusBg(
                                                                    status,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          _statusLabel(status),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                isUser
                                                                    ? Colors
                                                                        .white
                                                                    : _statusText(
                                                                      status,
                                                                    ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (error.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8,
                                                          ),
                                                      child: Text(
                                                        error,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              isUser
                                                                  ? Colors.white
                                                                  : const Color(
                                                                    0xFFB91C1C,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (_sendingPreview != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Flexible(
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width *
                                                    0.82,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: StitchTheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                boxShadow: const <BoxShadow>[
                                                  BoxShadow(
                                                    color: Color(0x330F172A),
                                                    blurRadius: 14,
                                                    offset: Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  _buildMessageMarkdown(
                                                    content:
                                                        (_sendingPreview?['content'] ??
                                                                '')
                                                            .toString(),
                                                    isUser: true,
                                                  ),
                                                  if ((_sendingPreview?['attachment_name'] ??
                                                          '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8,
                                                          ),
                                                      child: Container(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.14,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.22,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: <Widget>[
                                                            const Text(
                                                              '📎',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                (_sendingPreview?['attachment_name'] ??
                                                                        '')
                                                                    .toString(),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              (_sendingPreview?['attachment_size'] ??
                                                                      '')
                                                                  .toString(),
                                                              style: const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white70,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.22,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: <Widget>[
                                                        Container(
                                                          width: 7,
                                                          height: 7,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          ((_sendingPreview?['failed'] ??
                                                                      false) ==
                                                                  true)
                                                              ? 'Gửi thất bại'
                                                              : 'Đang gửi...',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                ),
              ),
            ),
            if (_queue.isNotEmpty)
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: _queueExpanded ? 250 : 88,
                ),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StitchTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'Hàng chờ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: StitchTheme.textMain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Text(
                            '${_queue.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: StitchTheme.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () {
                            setState(() => _queueExpanded = !_queueExpanded);
                          },
                          tooltip:
                              _queueExpanded
                                  ? 'Thu gọn hàng chờ'
                                  : 'Mở rộng hàng chờ',
                          icon: AnimatedRotation(
                            turns: _queueExpanded ? 0 : -0.25,
                            duration: const Duration(milliseconds: 160),
                            child: const Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                            ),
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(28, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bạn có thể sửa nội dung trước khi chatbot xử lý.',
                      style: TextStyle(
                        fontSize: 11,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_queueExpanded)
                      Expanded(
                        child: ListView.separated(
                          itemCount: _queue.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, int index) {
                            final Map<String, dynamic> item = _queue[index];
                            final int messageId = _toInt(item['id']);
                            final String status =
                                (item['status'] ?? '').toString();
                            final String current =
                                _queueDrafts[messageId] ??
                                (item['content'] ?? '').toString();
                            final Map<String, dynamic>? attachment =
                                item['attachment'] is Map
                                    ? Map<String, dynamic>.from(
                                      item['attachment'] as Map,
                                    )
                                    : null;
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: StitchTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        '#$messageId',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: StitchTheme.textMuted,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _statusText(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    key: ValueKey<String>(
                                      'queue-input-$messageId-$current',
                                    ),
                                    minLines: 2,
                                    maxLines: 4,
                                    initialValue: current,
                                    onChanged: (String value) {
                                      _queueDrafts[messageId] = value;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Nội dung hàng chờ',
                                    ),
                                  ),
                                  if (attachment != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: StitchTheme.border,
                                          ),
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            const Text('📎'),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                (attachment['name'] ??
                                                        'Tệp đính kèm')
                                                    .toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      IconButton(
                                        tooltip: 'Lưu hàng chờ',
                                        style: IconButton.styleFrom(
                                          backgroundColor: StitchTheme.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(36, 36),
                                        ),
                                        onPressed:
                                            () => _updateQueue(messageId),
                                        icon: const Icon(Icons.check_rounded),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Xóa khỏi hàng chờ',
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFEF2F2,
                                          ),
                                          foregroundColor: const Color(
                                            0xFFB91C1C,
                                          ),
                                          minimumSize: const Size(36, 36),
                                        ),
                                        onPressed:
                                            () => _deleteQueue(messageId),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: StitchTheme.border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  if (_pendingAttachment != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: Row(
                        children: <Widget>[
                          if (_isImageFileName(_pendingAttachment!.path))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _pendingAttachment!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '📎',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _pendingAttachment!.path.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: StitchTheme.textMain,
                                  ),
                                ),
                                Text(
                                  _formatBytes(
                                    _pendingAttachment!.lengthSync(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _clearAttachment,
                            icon: const Icon(Icons.close),
                            tooltip: 'Bỏ tệp đính kèm',
                          ),
                        ],
                      ),
                    ),
                  Focus(
                    onKeyEvent: (FocusNode node, KeyEvent event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey != LogicalKeyboardKey.enter &&
                          event.logicalKey != LogicalKeyboardKey.numpadEnter) {
                        return KeyEventResult.ignored;
                      }
                      if (HardwareKeyboard.instance.isShiftPressed) {
                        return KeyEventResult.ignored;
                      }
                      if (canSend && !_sending) {
                        unawaited(_send());
                      }
                      return KeyEventResult.handled;
                    },
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 6,
                      enabled: _chatbotEnabled && _chatbotConfigured,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'Nội dung câu hỏi',
                        hintText:
                            _isProcessing
                                ? 'Nhập để đưa vào hàng chờ'
                                : 'Nhập câu hỏi',
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: StitchTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: StitchTheme.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _isProcessing
                              ? ((inputTrimmed.isNotEmpty ||
                                      hasPendingAttachment)
                                  ? 'Đang phản hồi. Tin nhắn lúc này sẽ vào hàng chờ.'
                                  : 'Đang phản hồi. Bấm nút dừng để ngắt trả lời.')
                              : 'Sẵn sàng nhận câu hỏi mới.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed:
                            (_chatbotEnabled && _chatbotConfigured)
                                ? _pickAttachment
                                : null,
                        tooltip: 'Đính kèm file/ảnh',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(color: StitchTheme.border),
                          ),
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.attach_file_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor:
                              showStop
                                  ? const Color(0xFFEF4444)
                                  : StitchTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed:
                            showStop
                                ? (canStop && !_stopping ? _stop : null)
                                : (canSend && !_sending ? _send : null),
                        tooltip: showStop ? 'Dừng phản hồi' : 'Gửi tin nhắn',
                        icon: Icon(
                          showStop ? Icons.stop_rounded : Icons.send_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
