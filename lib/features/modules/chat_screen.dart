import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_env.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/services/app_firebase.dart';
import '../../core/utils/vietnam_time.dart';
import '../../data/services/mobile_api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.currentUserId,
  });

  final String token;
  final MobileApiService apiService;
  final int? currentUserId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

class _MentionRange {
  const _MentionRange(this.start, this.end);

  final int start;
  final int end;
}

class _ChatScreenState extends State<ChatScreen> {
  bool loading = false;
  String search = '';
  List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> data = await widget.apiService.getTasks(
      widget.token,
      perPage: 40,
      chatScope: true,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      tasks = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filtered =
        tasks.where((task) {
          if (search.isEmpty) return true;
          final String title = (task['title'] ?? '').toString().toLowerCase();
          final String project =
              ((task['project'] as Map<String, dynamic>?)?['name'] ?? '')
                  .toString()
                  .toLowerCase();
          return title.contains(search.toLowerCase()) ||
              project.contains(search.toLowerCase());
        }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Chat nội bộ')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            const Text(
              'Đoạn chat',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Trao đổi theo công việc giống hộp thư Messenger.',
              style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Tìm theo công việc hoặc dự án',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onChanged: (String value) {
                setState(() => search = value.trim());
              },
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!loading && filtered.isEmpty)
              const Text(
                'Chưa có hội thoại phù hợp.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
            ...filtered.map((Map<String, dynamic> task) {
              final int comments =
                  (task['comments_count'] ?? 0) is int
                      ? task['comments_count'] as int
                      : int.tryParse('${task['comments_count'] ?? 0}') ?? 0;
              final String title = (task['title'] ?? 'Công việc').toString();
              final Map<String, dynamic>? projectMap = _asMap(task['project']);
              final String project =
                  (projectMap?['name'] ?? 'Dự án').toString();
              final String initial =
                  title.trim().isEmpty ? 'C' : title.trim()[0];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<Widget>(
                      builder:
                          (_) => ChatDetailScreen(
                            token: widget.token,
                            apiService: widget.apiService,
                            task: task,
                            currentUserId: widget.currentUserId,
                          ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE0E7FF),
                        child: Text(
                          initial.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4338CA),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              project,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (comments > 0)
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: StitchTheme.danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            comments > 99 ? '99+' : '$comments',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: StitchTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.task,
    this.currentUserId,
  });

  final String token;
  final MobileApiService apiService;
  final Map<String, dynamic> task;
  final int? currentUserId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController messageCtrl = TextEditingController();
  final TextEditingController attachmentCtrl = TextEditingController();
  bool loading = false;
  bool loadingMore = false;
  bool sending = false;
  String message = '';
  List<Map<String, dynamic>> comments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> participants = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> taggedUsers = <Map<String, dynamic>>[];
  bool showOptions = false;
  bool mentionOpen = false;
  String mentionQuery = '';
  int mentionAnchor = -1;
  int? editingId;
  String? editingAttachmentPath;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _messageKeys = <String>{};
  StreamSubscription<DatabaseEvent>? _chatAddSub;
  StreamSubscription<DatabaseEvent>? _chatChangeSub;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;
  bool _realtimeEnabled = false;

  bool get _isTaskClosed => (widget.task['status'] ?? '').toString() == 'done';

  bool get _isChatLocked {
    final Map<String, dynamic>? project = _asMap(widget.task['project']);
    return (project?['handover_status'] ?? '').toString() == 'approved';
  }

  String get _chatDisabledReason =>
      'Dự án đã bàn giao xong, chat công việc đã bị khóa.';

  static const Map<String, String> _diacriticMap = <String, String>{
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };

  String _normalizeToken(String value) {
    final String lower = value.toLowerCase();
    final StringBuffer buffer = StringBuffer();
    for (final int codeUnit in lower.codeUnits) {
      final String ch = String.fromCharCode(codeUnit);
      buffer.write(_diacriticMap[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), '');
  }

  String _normalizeMentionPhrase(String value) {
    final String lower = value.toLowerCase();
    final StringBuffer buffer = StringBuffer();
    for (final int codeUnit in lower.codeUnits) {
      final String ch = String.fromCharCode(codeUnit);
      buffer.write(_diacriticMap[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _mentionIdentity(Map<String, dynamic> user) {
    final int id = _asInt(user['id']);
    if (id > 0) {
      return 'id:$id';
    }
    final String email = (user['email'] ?? '').toString().trim().toLowerCase();
    if (email.isNotEmpty) {
      return 'email:$email';
    }
    final String name = _normalizeMentionPhrase(
      (user['name'] ?? '').toString(),
    );
    return name.isEmpty ? '' : 'name:$name';
  }

  List<Map<String, dynamic>> _mentionCandidates() {
    final Map<String, Map<String, dynamic>> unique =
        <String, Map<String, dynamic>>{};

    void addUsers(List<Map<String, dynamic>> users) {
      for (final Map<String, dynamic> user in users) {
        final String key = _mentionIdentity(user);
        if (key.isEmpty || unique.containsKey(key)) {
          continue;
        }
        unique[key] = <String, dynamic>{
          'id': user['id'],
          'name': (user['name'] ?? '').toString(),
          'email': (user['email'] ?? '').toString(),
          'avatar_url': user['avatar_url'],
          'role': user['role'],
        };
      }
    }

    addUsers(taggedUsers);
    addUsers(participants);
    return unique.values.toList();
  }

  void _registerTaggedUser(Map<String, dynamic> user) {
    final String key = _mentionIdentity(user);
    if (key.isEmpty) {
      return;
    }
    if (taggedUsers.any(
      (Map<String, dynamic> item) => _mentionIdentity(item) == key,
    )) {
      return;
    }
    taggedUsers.add(<String, dynamic>{
      'id': user['id'],
      'name': (user['name'] ?? 'Người dùng').toString(),
      'email': (user['email'] ?? '').toString(),
      'avatar_url': user['avatar_url'],
      'role': user['role'],
    });
  }

  List<String> _extractMentions(String text) {
    final Set<String> tokens = <String>{};
    final RegExp reg = RegExp(r'@([^\s@]+)');
    for (final RegExpMatch match in reg.allMatches(text)) {
      final String? token = match.group(1);
      if (token != null && token.trim().isNotEmpty) {
        tokens.add(token);
      }
    }
    return tokens.toList();
  }

  Map<String, dynamic>? _matchMentionToken(String key) {
    for (final Map<String, dynamic> u in _mentionCandidates()) {
      final String nameKey = _normalizeToken((u['name'] ?? '').toString());
      final String emailKey = _normalizeToken((u['email'] ?? '').toString());
      if (nameKey == key || emailKey == key || emailKey.contains(key)) {
        return u;
      }
    }
    return null;
  }

  bool _startsWithMentionBoundary(String phrase, String candidate) {
    if (phrase == candidate) {
      return true;
    }
    if (!phrase.startsWith(candidate) || phrase.length <= candidate.length) {
      return false;
    }
    final String next = phrase.substring(
      candidate.length,
      candidate.length + 1,
    );
    return RegExp(r'[\s\.,!?:;\)\]\}]').hasMatch(next);
  }

  Map<String, dynamic>? _matchCompletedMention(String value) {
    final String phrase = _normalizeMentionPhrase(value);
    if (phrase.isEmpty) {
      return null;
    }

    Map<String, dynamic>? bestMatch;
    int bestLength = -1;

    for (final Map<String, dynamic> user in _mentionCandidates()) {
      final List<String> candidates =
          <String>[
            _normalizeMentionPhrase((user['name'] ?? '').toString()),
            _normalizeMentionPhrase((user['email'] ?? '').toString()),
          ].where((String item) => item.isNotEmpty).toList();

      for (final String candidate in candidates) {
        if (_startsWithMentionBoundary(phrase, candidate) &&
            candidate.length > bestLength) {
          bestMatch = user;
          bestLength = candidate.length;
        }
      }
    }

    return bestMatch;
  }

  bool _containsExactMention(String normalizedText, String candidate) {
    if (candidate.isEmpty) {
      return false;
    }
    final String needle = '@$candidate';
    int start = 0;
    while (true) {
      final int index = normalizedText.indexOf(needle, start);
      if (index < 0) {
        return false;
      }
      final int end = index + needle.length;
      if (end >= normalizedText.length) {
        return true;
      }
      final String next = normalizedText.substring(end, end + 1);
      if (RegExp(r'[\s\.,!?:;\)\]\}]').hasMatch(next)) {
        return true;
      }
      start = index + 1;
    }
  }

  List<Map<String, dynamic>> _extractExactMentionMatches(String text) {
    final String normalizedText = _normalizeMentionPhrase(text);
    if (normalizedText.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final Map<String, Map<String, dynamic>> matches =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> user in _mentionCandidates()) {
      final String identity = _mentionIdentity(user);
      if (identity.isEmpty) {
        continue;
      }

      final List<String> candidates =
          <String>[
            _normalizeMentionPhrase((user['name'] ?? '').toString()),
            _normalizeMentionPhrase((user['email'] ?? '').toString()),
          ].where((String item) => item.isNotEmpty).toList();

      for (final String candidate in candidates) {
        if (_containsExactMention(normalizedText, candidate)) {
          matches[identity] = user;
          break;
        }
      }
    }

    return matches.values.toList();
  }

  Map<String, dynamic> _collectMentionTargets(String text) {
    final List<String> tokens = _extractMentions(text);
    final Map<String, Map<String, dynamic>> resolvedByIdentity =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> user in _extractExactMentionMatches(text)) {
      final String identity = _mentionIdentity(user);
      if (identity.isNotEmpty) {
        resolvedByIdentity[identity] = user;
      }
    }

    if (tokens.isEmpty) {
      return <String, dynamic>{
        'tokens': <String>[],
        'resolved': resolvedByIdentity.values.toList(),
        'unresolved': <String>[],
      };
    }
    final List<String> unresolved = <String>[];
    for (final String token in tokens) {
      final String key = _normalizeToken(token);
      if (key.isEmpty) continue;
      final Map<String, dynamic>? match = _matchMentionToken(key);
      if (match != null) {
        final String identity = _mentionIdentity(match);
        if (identity.isNotEmpty) {
          resolvedByIdentity[identity] = <String, dynamic>{
            'id': match['id'],
            'name': match['name'],
            'email': match['email'],
          };
        }
      } else {
        final bool coveredByExactMatch = resolvedByIdentity.values.any((
          Map<String, dynamic> user,
        ) {
          final String nameKey = _normalizeToken(
            (user['name'] ?? '').toString(),
          );
          final String emailKey = _normalizeToken(
            (user['email'] ?? '').toString(),
          );
          return (nameKey.isNotEmpty && nameKey.startsWith(key)) ||
              (emailKey.isNotEmpty && emailKey.startsWith(key));
        });
        if (!coveredByExactMatch) {
          unresolved.add(token);
        }
      }
    }
    return <String, dynamic>{
      'tokens': tokens,
      'resolved': resolvedByIdentity.values.toList(),
      'unresolved': unresolved,
    };
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    attachmentCtrl.dispose();
    _chatAddSub?.cancel();
    _chatChangeSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _fetchParticipants();
    await _fetchPage(reset: true);
    if (AppFirebase.isConfigured) {
      await AppFirebase.ensureInitialized();
      _listenRealtime();
    }
  }

  Future<void> _pickAttachment() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles();
    final String? path = result?.files.single.path;
    if (!mounted) return;
    if (path != null) {
      setState(() => attachmentCtrl.text = path);
    }
  }

  Future<void> _fetchPage({required bool reset}) async {
    final int taskId = _asInt(widget.task['id']);
    if (taskId <= 0) return;
    if (reset) {
      _page = 1;
      setState(() => loading = true);
    } else {
      if (loadingMore || !_hasMore) return;
      setState(() => loadingMore = true);
    }
    final PaginatedResult<Map<String, dynamic>> result = await widget.apiService
        .getTaskCommentsPage(
          widget.token,
          taskId,
          page: _page,
          perPage: _pageSize,
        );
    if (!mounted) return;
    final List<Map<String, dynamic>> rows = result.data;
    final List<Map<String, dynamic>> ordered = rows.reversed.toList();
    if (reset) {
      _messageKeys
        ..clear()
        ..addAll(
          ordered
              .map((Map<String, dynamic> c) => c['id']?.toString() ?? '')
              .where((String id) => id.isNotEmpty),
        );
      setState(() {
        loading = false;
        comments = ordered;
        _hasMore = result.hasMore;
        _page = result.currentPage;
      });
      _scrollToBottom();
    } else {
      final double beforeMax =
          _scrollController.hasClients
              ? _scrollController.position.maxScrollExtent
              : 0;
      final double beforeOffset =
          _scrollController.hasClients ? _scrollController.position.pixels : 0;
      final List<Map<String, dynamic>> older =
          ordered.where((Map<String, dynamic> c) {
            final String id = c['id']?.toString() ?? '';
            return id.isEmpty || !_messageKeys.contains(id);
          }).toList();
      for (final Map<String, dynamic> c in older) {
        final String id = c['id']?.toString() ?? '';
        if (id.isNotEmpty) _messageKeys.add(id);
      }
      setState(() {
        loadingMore = false;
        comments = <Map<String, dynamic>>[...older, ...comments];
        _hasMore = result.hasMore;
        _page = result.currentPage;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final double afterMax = _scrollController.position.maxScrollExtent;
        final double delta = afterMax - beforeMax;
        _scrollController.jumpTo(beforeOffset + delta);
      });
    }
  }

  Future<void> _fetchParticipants() async {
    final int taskId = _asInt(widget.task['id']);
    if (taskId <= 0) return;
    final List<Map<String, dynamic>> data = await widget.apiService
        .getChatParticipants(widget.token, taskId);
    if (!mounted) return;
    setState(() {
      participants = data;
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final double max = _scrollController.position.maxScrollExtent;
    final double current = _scrollController.position.pixels;
    return (max - current) < 120;
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final double max = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  Map<String, dynamic>? _normalizeRealtimeMessage(dynamic value, String? key) {
    if (value is! Map) return null;
    final Map<String, dynamic> data = Map<String, dynamic>.from(value);
    if (key != null && key.isNotEmpty && data['id'] == null) {
      data['id'] = int.tryParse(key) ?? key;
    }
    return data;
  }

  void _appendMessage(Map<String, dynamic> messageData) {
    final String id = messageData['id']?.toString() ?? '';
    if (id.isNotEmpty && _messageKeys.contains(id)) return;
    if (id.isNotEmpty) _messageKeys.add(id);
    setState(() {
      comments = <Map<String, dynamic>>[...comments, messageData];
    });
    final bool isMine =
        widget.currentUserId != null &&
        _asInt(messageData['user_id']) == widget.currentUserId;
    if (_isNearBottom() || isMine) {
      _scrollToBottom();
    }
  }

  void _updateMessage(Map<String, dynamic> messageData) {
    final String id = messageData['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      comments =
          comments
              .map(
                (Map<String, dynamic> c) =>
                    c['id']?.toString() == id ? {...c, ...messageData} : c,
              )
              .toList();
    });
  }

  void _listenRealtime() {
    final int taskId = _asInt(widget.task['id']);
    if (taskId <= 0 || _isChatLocked) return;
    final Query? query = AppFirebase.taskChatQuery(taskId, limit: _pageSize);
    if (query == null) {
      return;
    }
    _realtimeEnabled = true;
    _chatAddSub?.cancel();
    _chatChangeSub?.cancel();
    _chatAddSub = query.onChildAdded.listen((DatabaseEvent event) {
      final Map<String, dynamic>? data = _normalizeRealtimeMessage(
        event.snapshot.value,
        event.snapshot.key,
      );
      if (data == null) return;
      _appendMessage(data);
    });
    _chatChangeSub = query.onChildChanged.listen((DatabaseEvent event) {
      final Map<String, dynamic>? data = _normalizeRealtimeMessage(
        event.snapshot.value,
        event.snapshot.key,
      );
      if (data == null) return;
      _updateMessage(data);
    });
  }

  void _onMessageChanged(String value) {
    final int anchor = value.lastIndexOf('@');
    if (anchor >= 0) {
      final String query = value.substring(anchor + 1);
      final Map<String, dynamic>? completedUser = _matchCompletedMention(query);
      setState(() {
        if (completedUser != null) {
          _registerTaggedUser(completedUser);
          mentionOpen = false;
          mentionQuery = '';
          mentionAnchor = -1;
          return;
        }
        mentionQuery = query;
        mentionOpen = true;
        mentionAnchor = anchor;
      });
    } else if (mentionOpen) {
      setState(() {
        mentionOpen = false;
        mentionQuery = '';
        mentionAnchor = -1;
      });
    }
  }

  void _pickMention(Map<String, dynamic> user) {
    if (mentionAnchor < 0) return;
    final String name = (user['name'] ?? 'Người dùng').toString();
    final String text = messageCtrl.text;
    final String before = text.substring(0, mentionAnchor);
    final String after = text.substring(mentionAnchor);
    final String replaced = after.replaceFirst(
      RegExp(r'^@([^\n@]*)'),
      '@$name ',
    );
    final String next = '$before$replaced';
    messageCtrl.text = next;
    messageCtrl.selection = TextSelection.collapsed(offset: next.length);
    setState(() {
      mentionOpen = false;
      mentionQuery = '';
      mentionAnchor = -1;
      _registerTaggedUser(user);
    });
  }

  bool _showMentionWarning() {
    final String content = messageCtrl.text.trim();
    if (content.isEmpty) return false;
    final Map<String, dynamic> meta = _collectMentionTargets(content);
    final List<String> tokens = (meta['tokens'] as List<String>);
    final List<String> unresolved = (meta['unresolved'] as List<String>);
    if (tokens.isEmpty) return false;
    return unresolved.isNotEmpty;
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final DateTime? date = VietnamTime.parse(raw);
    if (date == null) return raw;
    return '${VietnamTime.formatTime(date)} ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  String _resolveAvatarUrl(dynamic value) {
    return AppEnv.resolveMediaUrl(value?.toString());
  }

  String _resolveExternalUrl(String value) {
    return AppEnv.resolveMediaUrl(value);
  }

  String _attachmentLabel(String rawValue, {String? fallback}) {
    final String preferred = (fallback ?? '').trim();
    if (preferred.isNotEmpty) {
      return preferred;
    }

    final String resolved = _resolveExternalUrl(rawValue);
    final Uri? uri = Uri.tryParse(resolved);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final String name = uri.pathSegments.last;
      if (name.isNotEmpty) {
        return Uri.decodeComponent(name);
      }
    }

    return rawValue;
  }

  Future<void> _openExternal(String rawValue) async {
    final String resolved = _resolveExternalUrl(rawValue);
    final Uri? uri = Uri.tryParse(resolved);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Liên kết không hợp lệ.')));
      return;
    }

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được liên kết hoặc tệp đính kèm.'),
        ),
      );
    }
  }

  List<InlineSpan> _buildLinkifiedSpans(String text, {TextStyle? style}) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp linkReg = RegExp(r'https?:\/\/[^\s]+', caseSensitive: false);
    int currentIndex = 0;

    for (final RegExpMatch match in linkReg.allMatches(text)) {
      final int start = match.start;
      final int end = match.end;
      if (start > currentIndex) {
        spans.add(
          TextSpan(text: text.substring(currentIndex, start), style: style),
        );
      }
      final String rawUrl = text.substring(start, end);
      spans.add(
        TextSpan(
          text: rawUrl,
          style: (style ?? const TextStyle()).copyWith(
            color: StitchTheme.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer:
              TapGestureRecognizer()..onTap = () => _openExternal(rawUrl),
        ),
      );
      currentIndex = end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: style));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: style));
    }

    return spans;
  }

  Widget _buildAvatar(
    Map<String, dynamic>? user,
    String fallbackName, {
    double radius = 18,
  }) {
    final String avatarUrl = _resolveAvatarUrl(user?['avatar_url']);
    return CircleAvatar(
      radius: radius,
      backgroundColor: StitchTheme.primary,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child:
          avatarUrl.isEmpty
              ? Text(
                _initials(fallbackName),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.66,
                ),
              )
              : null,
    );
  }

  List<InlineSpan> _buildMentionSpans(
    String text,
    List<Map<String, dynamic>> taggedUsers,
  ) {
    final List<String> mentionPatterns =
        taggedUsers
            .expand(
              (Map<String, dynamic> user) => <String>[
                if ((user['name'] ?? '').toString().trim().isNotEmpty)
                  '@${(user['name'] ?? '').toString().trim()}',
                if ((user['email'] ?? '').toString().trim().isNotEmpty)
                  '@${(user['email'] ?? '').toString().trim()}',
              ],
            )
            .toSet()
            .toList()
          ..sort((String a, String b) => b.length.compareTo(a.length));

    if (mentionPatterns.isEmpty) {
      return _buildLinkifiedSpans(text);
    }

    final List<_MentionRange> ranges = <_MentionRange>[];
    int cursor = 0;
    while (cursor < text.length) {
      String? matchedPattern;
      for (final String pattern in mentionPatterns) {
        final int end = cursor + pattern.length;
        if (end > text.length) {
          continue;
        }
        final String slice = text.substring(cursor, end);
        if (slice.toLowerCase() != pattern.toLowerCase()) {
          continue;
        }
        final String next =
            end < text.length ? text.substring(end, end + 1) : '';
        if (next.isEmpty || RegExp(r'[\s\.,!?:;\)\]\}]').hasMatch(next)) {
          matchedPattern = pattern;
          break;
        }
      }

      if (matchedPattern != null) {
        ranges.add(_MentionRange(cursor, cursor + matchedPattern.length));
        cursor += matchedPattern.length;
      } else {
        cursor += 1;
      }
    }

    if (ranges.isEmpty) {
      return _buildLinkifiedSpans(text);
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    int currentIndex = 0;
    for (final _MentionRange range in ranges) {
      if (range.start > currentIndex) {
        spans.addAll(
          _buildLinkifiedSpans(text.substring(currentIndex, range.start)),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(
            color: StitchTheme.successStrong,
            fontWeight: FontWeight.w700,
            backgroundColor: StitchTheme.successSoft,
          ),
        ),
      );
      currentIndex = range.end;
    }
    if (currentIndex < text.length) {
      spans.addAll(_buildLinkifiedSpans(text.substring(currentIndex)));
    }
    return spans;
  }

  Widget _buildBubble(BuildContext context, Map<String, dynamic> c) {
    final Map<String, dynamic>? user = _asMap(c['user']);
    final String name =
        (user?['name'] ?? c['user_name'] ?? user?['email'] ?? 'Ẩn danh')
            .toString();
    final int userId = _asInt(c['user_id'] ?? user?['id']);
    final bool isMine =
        widget.currentUserId != null && userId == widget.currentUserId;
    final bool isRecalled = c['is_recalled'] == true;
    final String content =
        isRecalled
            ? 'Tin nhắn đã bị thu hồi.'
            : (c['content'] ?? '').toString();
    final String attachment = (c['attachment_path'] ?? '').toString();
    final String attachmentName = _attachmentLabel(
      attachment,
      fallback: (c['attachment_name'] ?? '').toString(),
    );
    final dynamic tagUsers = c['tagged_users'];
    final dynamic rawTags = c['tagged_user_ids'];
    final List<Map<String, dynamic>> taggedUserList =
        tagUsers is List
            ? tagUsers
                .whereType<Map>()
                .map((Map item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
    String tagLabel = '';
    if (tagUsers is List) {
      tagLabel = tagUsers
          .map((dynamic u) => (u is Map ? u['name'] : u).toString())
          .where((String name) => name.isNotEmpty)
          .join(', ');
    } else if (rawTags is List) {
      tagLabel = rawTags.join(', ');
    } else if (rawTags != null && rawTags.toString().isNotEmpty) {
      tagLabel = rawTags.toString();
    }

    final Color bubbleColor =
        isMine
            ? StitchTheme.primarySoft
            : (isRecalled ? StitchTheme.surfaceAlt : Colors.white);
    final Color borderColor =
        isMine
            ? StitchTheme.primary.withValues(alpha: 0.25)
            : StitchTheme.border;
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 16),
    );

    final Widget bubble = GestureDetector(
      onLongPress: () => _showMessageActions(c),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            isRecalled
                ? const Text(
                  'Tin nhắn đã bị thu hồi.',
                  style: TextStyle(
                    color: StitchTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
                : RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: StitchTheme.textMain,
                      height: 1.4,
                    ),
                    children: _buildMentionSpans(content, taggedUserList),
                  ),
                  softWrap: true,
                ),
            if (!isRecalled && attachment.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _openExternal(attachment),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.attach_file,
                        size: 16,
                        color: StitchTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          attachmentName,
                          style: TextStyle(
                            fontSize: 11,
                            color: StitchTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!isRecalled && tagLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Tag: $tagLabel',
                style: TextStyle(
                  fontSize: 11,
                  color: StitchTheme.successStrong,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final Widget contentBody = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: bubble,
      builder: (BuildContext _, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
    );

    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: contentBody);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _buildAvatar(user, name),
          const SizedBox(width: 8),
          Flexible(child: contentBody),
        ],
      ),
    );
  }

  void _startEdit(Map<String, dynamic> c) {
    final bool isRecalled = c['is_recalled'] == true;
    if (_isTaskClosed || _isChatLocked || isRecalled) {
      setState(() {
        message =
            _isChatLocked
                ? _chatDisabledReason
                : _isTaskClosed
                ? 'Công việc đã hoàn thành, không thể chỉnh sửa.'
                : 'Tin nhắn đã bị thu hồi, không thể chỉnh sửa.';
      });
      return;
    }
    final int id = _asInt(c['id']);
    if (id <= 0) return;
    final String content = (c['content'] ?? '').toString();
    final String attachment = (c['attachment_path'] ?? '').toString();
    final List<Map<String, dynamic>> nextTags = <Map<String, dynamic>>[];
    if (c['tagged_users'] is List) {
      for (final dynamic u in c['tagged_users'] as List) {
        if (u is Map) {
          nextTags.add({
            'id': u['id'],
            'name': u['name'] ?? 'Người dùng',
            'email': u['email'] ?? '',
            'avatar_url': u['avatar_url'],
          });
        }
      }
    }
    setState(() {
      editingId = id;
      messageCtrl.text = content;
      messageCtrl.selection = TextSelection.collapsed(offset: content.length);
      taggedUsers = nextTags;
      mentionOpen = false;
      mentionQuery = '';
      mentionAnchor = -1;
      editingAttachmentPath = attachment.isEmpty ? null : attachment;
      attachmentCtrl.text = attachment;
      showOptions = attachment.isNotEmpty;
    });
  }

  void _cancelEdit() {
    setState(() {
      editingId = null;
      editingAttachmentPath = null;
      messageCtrl.clear();
      taggedUsers = <Map<String, dynamic>>[];
      mentionOpen = false;
      mentionQuery = '';
      mentionAnchor = -1;
      attachmentCtrl.clear();
      showOptions = false;
    });
  }

  Future<void> _recallMessage(Map<String, dynamic> c) async {
    final int taskId = _asInt(widget.task['id']);
    if (taskId <= 0) return;
    if (_isChatLocked) {
      setState(() {
        message = _chatDisabledReason;
      });
      return;
    }
    final int id = _asInt(c['id']);
    if (id <= 0) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Thu hồi tin nhắn'),
              content: const Text('Bạn muốn thu hồi tin nhắn này?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Thu hồi'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;
    final bool ok = await widget.apiService.deleteTaskComment(
      widget.token,
      taskId,
      id,
    );
    if (!mounted) return;
    setState(() {
      message = ok ? 'Đã thu hồi tin nhắn.' : 'Thu hồi tin nhắn thất bại.';
    });
    if (!_realtimeEnabled) {
      await _fetchPage(reset: true);
    }
  }

  void _showMessageActions(Map<String, dynamic> c) {
    final int userId = _asInt(c['user_id'] ?? _asMap(c['user'])?['id']);
    final bool isMine =
        widget.currentUserId != null && userId == widget.currentUserId;
    final bool isRecalled = c['is_recalled'] == true;
    final bool isTaskClosed =
        (widget.task['status'] ?? '').toString() == 'done';
    final String time = _formatTime((c['created_at'] ?? '').toString());

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Thông tin tin nhắn',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: StitchTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time.isEmpty ? 'Không xác định' : time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                ],
              ),
              if (isMine && !isRecalled && !isTaskClosed) ...<Widget>[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit, color: StitchTheme.primary),
                  title: const Text('Chỉnh sửa'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _startEdit(c);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.undo, color: StitchTheme.danger),
                  title: const Text('Thu hồi'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _recallMessage(c);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    final int taskId = _asInt(widget.task['id']);
    if (taskId <= 0) return;
    if (_isTaskClosed || _isChatLocked) {
      setState(() {
        message =
            _isChatLocked
                ? _chatDisabledReason
                : 'Công việc đã hoàn thành, không thể nhắn thêm.';
      });
      return;
    }
    final String content = messageCtrl.text.trim();
    if (content.isEmpty) return;
    final Map<String, dynamic> mentionMeta = _collectMentionTargets(content);
    final List<String> mentionTokens = (mentionMeta['tokens'] as List<String>);
    final List<Map<String, dynamic>> resolved =
        (mentionMeta['resolved'] as List<Map<String, dynamic>>);
    final List<String> unresolved = (mentionMeta['unresolved'] as List<String>);
    if (mentionTokens.isNotEmpty && unresolved.isNotEmpty) {
      setState(() {
        message = 'Vui lòng chọn người cần tag từ danh sách gợi ý.';
      });
      return;
    }
    if (sending) return;
    setState(() => sending = true);
    final Set<int> tagIds = <int>{};
    final Set<String> tagEmails = <String>{};
    for (final Map<String, dynamic> u in resolved) {
      final int id = _asInt(u['id']);
      if (id > 0) tagIds.add(id);
      final String email = (u['email'] ?? '').toString();
      if (email.isNotEmpty) tagEmails.add(email);
    }
    final String attachment = attachmentCtrl.text.trim();
    final bool ok =
        editingId == null
            ? await widget.apiService.createTaskComment(
              widget.token,
              taskId,
              content: content,
              taggedUserIds: tagIds.isEmpty ? null : tagIds.toList(),
              taggedUserEmails: tagEmails.isEmpty ? null : tagEmails.toList(),
              attachmentPath: attachment.isEmpty ? null : attachment,
            )
            : await widget.apiService.updateTaskComment(
              widget.token,
              taskId,
              editingId!,
              content: content,
              taggedUserIds: tagIds.isEmpty ? null : tagIds.toList(),
              taggedUserEmails: tagEmails.isEmpty ? null : tagEmails.toList(),
              attachmentPath: attachment.isEmpty ? null : attachment,
            );
    if (!mounted) return;
    setState(() {
      message =
          ok
              ? (editingId == null
                  ? 'Đã gửi tin nhắn.'
                  : 'Đã cập nhật tin nhắn.')
              : (editingId == null
                  ? 'Gửi tin nhắn thất bại.'
                  : 'Cập nhật tin nhắn thất bại.');
      sending = false;
    });
    if (ok) {
      messageCtrl.clear();
      setState(() {
        taggedUsers = <Map<String, dynamic>>[];
        mentionOpen = false;
        mentionQuery = '';
        mentionAnchor = -1;
        editingId = null;
        editingAttachmentPath = null;
      });
      attachmentCtrl.clear();
      if (!_realtimeEnabled) {
        await _fetchPage(reset: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = (widget.task['title'] ?? 'Công việc').toString();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification n) {
                if (n.metrics.pixels <= 24 &&
                    _hasMore &&
                    !loadingMore &&
                    !loading) {
                  _page += 1;
                  _fetchPage(reset: false);
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () => _fetchPage(reset: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount:
                      comments.length +
                      (loadingMore ? 1 : 0) +
                      ((loading && comments.isEmpty) ||
                              (!loading && comments.isEmpty)
                          ? 1
                          : 0),
                  itemBuilder: (BuildContext context, int index) {
                    int offset = index;
                    if (loadingMore) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      offset -= 1;
                    }

                    if ((loading && comments.isEmpty) ||
                        (!loading && comments.isEmpty)) {
                      if (offset == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child:
                                loading
                                    ? const CircularProgressIndicator()
                                    : const Text(
                                      'Chưa có trao đổi nào.',
                                      style: TextStyle(
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                          ),
                        );
                      }
                      offset -= 1;
                    }

                    final Map<String, dynamic> c = comments[offset];
                    return _buildBubble(context, c);
                  },
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: StitchTheme.border)),
            ),
            child: Column(
              children: <Widget>[
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      message,
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                  ),
                if (_isTaskClosed)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Công việc đã hoàn thành, không thể gửi tin nhắn.',
                      style: TextStyle(color: StitchTheme.textMuted),
                    ),
                  ),
                if (_isChatLocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _chatDisabledReason,
                      style: TextStyle(
                        color: StitchTheme.warningStrong,
                      ),
                    ),
                  ),
                if (participants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Phạm vi chat: Admin, phụ trách dự án, phụ trách công việc và toàn bộ phụ trách đầu việc.',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              participants.map((Map<String, dynamic> u) {
                                final String name =
                                    (u['name'] ?? 'Người dùng').toString();
                                return Chip(
                                  label: Text(
                                    name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: StitchTheme.border,
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (editingId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.edit,
                          size: 16,
                          color: StitchTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Đang chỉnh sửa tin nhắn',
                            style: TextStyle(color: StitchTheme.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: _cancelEdit,
                          child: const Text('Hủy sửa'),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed:
                          _isTaskClosed || _isChatLocked
                              ? null
                              : () =>
                                  setState(() => showOptions = !showOptions),
                      icon: Icon(
                        showOptions ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: const Text('Tùy chọn'),
                    ),
                    const Spacer(),
                    if (showOptions)
                      const Text(
                        'Tệp đính kèm',
                        style: TextStyle(
                          fontSize: 11,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                  ],
                ),
                if (showOptions) ...<Widget>[
                  if (taggedUsers.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children:
                          taggedUsers.map((Map<String, dynamic> u) {
                            final String name =
                                (u['name'] ?? 'User').toString();
                            return Chip(
                              backgroundColor: StitchTheme.successSoft,
                              labelStyle: TextStyle(
                                color: StitchTheme.successStrong,
                                fontWeight: FontWeight.w600,
                              ),
                              label: Text('@$name'),
                              onDeleted: () {
                                setState(() {
                                  taggedUsers.removeWhere(
                                    (Map<String, dynamic> x) =>
                                        x['id'] == u['id'],
                                  );
                                });
                              },
                            );
                          }).toList(),
                    ),
                  if (taggedUsers.isNotEmpty) const SizedBox(height: 8),
                  TextField(
                    controller: attachmentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Đường dẫn tệp hoặc liên kết',
                    ),
                    enabled: !_isTaskClosed && !_isChatLocked,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _isTaskClosed || _isChatLocked ? null : _pickAttachment,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Chọn file'),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: messageCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Nhập nội dung trao đổi',
                        ),
                        minLines: 1,
                        maxLines: 3,
                        onChanged: _onMessageChanged,
                        enabled: !_isTaskClosed && !_isChatLocked,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          _isTaskClosed || _isChatLocked || sending
                              ? null
                              : _send,
                      icon: Icon(Icons.send, color: StitchTheme.primary),
                    ),
                  ],
                ),
                if (_showMentionWarning())
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Bạn đang gõ @ nhưng chưa chọn người từ danh sách gợi ý.',
                      style: TextStyle(
                        fontSize: 12,
                        color: StitchTheme.warningStrong,
                      ),
                    ),
                  ),
                if (mentionOpen && !_isTaskClosed && !_isChatLocked)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          participants
                              .where((Map<String, dynamic> u) {
                                final String q = _normalizeToken(mentionQuery);
                                if (q.isEmpty) return true;
                                final String name = _normalizeToken(
                                  (u['name'] ?? '').toString(),
                                );
                                final String email = _normalizeToken(
                                  (u['email'] ?? '').toString(),
                                );
                                return name.contains(q) || email.contains(q);
                              })
                              .take(8)
                              .map((Map<String, dynamic> u) {
                                final String name =
                                    (u['name'] ?? 'Người dùng').toString();
                                final String email =
                                    (u['email'] ?? '').toString();
                                final String role =
                                    (u['role'] ?? '').toString();
                                return ListTile(
                                  dense: true,
                                  leading: _buildAvatar(u, name, radius: 16),
                                  title: Text('@$name'),
                                  subtitle:
                                      role.isEmpty
                                          ? (email.isEmpty
                                              ? null
                                              : Text(
                                                email,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ))
                                          : Text(
                                            email.isEmpty
                                                ? role
                                                : '$role • $email',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                  onTap: () => _pickMention(u),
                                );
                              })
                              .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
