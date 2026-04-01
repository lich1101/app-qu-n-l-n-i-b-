import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/app_env.dart';
import '../../core/utils/vietnam_time.dart';

class MobileApiService {
  Map<String, String> _jsonHeaders([String? token]) {
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _authHeaders([String? token]) {
    return <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  bool _fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getMeta() async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/meta'),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/settings'),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(
    String token, {
    String? brandName,
    String? primaryColor,
    String? logoUrl,
    File? logoFile,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/settings');
    if (logoFile != null) {
      final http.MultipartRequest request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_authHeaders(token));
      if (brandName != null) request.fields['brand_name'] = brandName;
      if (primaryColor != null) request.fields['primary_color'] = primaryColor;
      if (logoUrl != null) request.fields['logo_url'] = logoUrl;
      request.files.add(
        await http.MultipartFile.fromPath('logo', logoFile.path),
      );
      final http.StreamedResponse res = await request.send();
      if (res.statusCode != 200) return <String, dynamic>{'error': true};
      final String body = await res.stream.bytesToString();
      return jsonDecode(body) as Map<String, dynamic>;
    }
    final http.Response res = await http.post(
      uri,
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (brandName != null) 'brand_name': brandName,
        if (primaryColor != null) 'primary_color': primaryColor,
        if (logoUrl != null) 'logo_url': logoUrl,
      }),
    );
    if (res.statusCode != 200) return <String, dynamic>{'error': true};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPublicSummary([String? token]) async {
    final Map<String, String> headers =
        token != null && token.isNotEmpty
            ? _authHeaders(token)
            : <String, String>{};
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/public/summary'),
      headers: headers,
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPublicAccountsSummary([String? token]) async {
    final Map<String, String> headers =
        token != null && token.isNotEmpty
            ? _authHeaders(token)
            : <String, String>{};
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/public/accounts-summary'),
      headers: headers,
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String deviceName = 'flutter-mobile-app',
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/login'),
      headers: _jsonHeaders(),
      body: jsonEncode(<String, dynamic>{
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );
    return <String, dynamic>{
      'statusCode': res.statusCode,
      'body': jsonDecode(res.body) as Map<String, dynamic>,
    };
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/forgot-password'),
      headers: _jsonHeaders(),
      body: jsonEncode(<String, dynamic>{'email': email}),
    );

    Map<String, dynamic> body = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = <String, dynamic>{'message': res.body};
      }
    }

    return <String, dynamic>{'statusCode': res.statusCode, 'body': body};
  }

  Future<Map<String, dynamic>> me(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/me'),
      headers: _jsonHeaders(token),
    );
    return <String, dynamic>{
      'statusCode': res.statusCode,
      'body':
          res.statusCode == 200
              ? jsonDecode(res.body) as Map<String, dynamic>
              : <String, dynamic>{},
    };
  }

  Future<void> logout(String token) async {
    await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/logout'),
      headers: _jsonHeaders(token),
    );
  }

  Future<String?> getFirebaseToken(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/firebase/token'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return null;
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final String? firebaseToken = body['token']?.toString();
    return firebaseToken?.isNotEmpty == true ? firebaseToken : null;
  }

  Future<Map<String, dynamic>> testPush(String token) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/push/test'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'status': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChatbotMessages(
    String token, {
    int limit = 220,
    int? botId,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/chatbot/messages').replace(
      queryParameters: <String, String>{
        'limit': '$limit',
        if (botId != null && botId > 0) 'bot_id': '$botId',
      },
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'statusCode': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChatbotBots(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/chatbot/bots'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'statusCode': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendChatbotMessage(
    String token, {
    required String content,
    File? attachment,
    int? botId,
  }) async {
    final String trimmed = content.trim();
    if (attachment != null && _fileExists(attachment.path)) {
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppEnv.apiBaseUrl}/chatbot/messages'),
      );
      request.headers.addAll(_authHeaders(token));
      if (trimmed.isNotEmpty) {
        request.fields['content'] = trimmed;
      }
      if (botId != null && botId > 0) {
        request.fields['bot_id'] = '$botId';
      }
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
      final http.StreamedResponse streamed = await request.send();
      final String body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        return <String, dynamic>{
          'error': true,
          'statusCode': streamed.statusCode,
        };
      }
      return jsonDecode(body) as Map<String, dynamic>;
    }

    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/chatbot/messages'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'content': trimmed,
        if (botId != null && botId > 0) 'bot_id': botId,
      }),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'statusCode': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stopChatbot(String token, {int? botId}) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/chatbot/stop'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (botId != null && botId > 0) 'bot_id': botId,
      }),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'statusCode': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateQueuedChatbotMessage(
    String token,
    int messageId, {
    required String content,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/chatbot/messages/$messageId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'content': content}),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'statusCode': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteQueuedChatbotMessage(
    String token,
    int messageId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/chatbot/messages/$messageId'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'statusCode': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getProjects(
    String token, {
    int perPage = 50,
    String? status,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/projects').replace(
      queryParameters: <String, String>{
        'per_page': perPage.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> payload =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows =
        (payload['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createProject(
    String token, {
    required String name,
    required String serviceType,
    String? serviceTypeOther,
    String status = 'moi_tao',
    int? contractId,
    int? ownerId,
    String? startDate,
    String? deadline,
    String? customerRequirement,
    String? repoUrl,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/projects'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'service_type': serviceType,
        if (serviceTypeOther != null) 'service_type_other': serviceTypeOther,
        'status': status,
        if (contractId != null) 'contract_id': contractId,
        if (ownerId != null) 'owner_id': ownerId,
        if (startDate != null) 'start_date': startDate,
        if (deadline != null) 'deadline': deadline,
        if (customerRequirement != null)
          'customer_requirement': customerRequirement,
        if (repoUrl != null) 'repo_url': repoUrl,
      }),
    );
    return res.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getContracts(
    String token, {
    int perPage = 50,
    String search = '',
    String status = '',
    int? clientId,
    String approvalStatus = '',
    bool withItems = false,
    bool availableOnly = false,
    int? projectId,
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (withItems) {
      params['with_items'] = '1';
    }
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (clientId != null) {
      params['client_id'] = clientId.toString();
    }
    if (approvalStatus.trim().isNotEmpty) {
      params['approval_status'] = approvalStatus.trim();
    }
    if (availableOnly) {
      params['available_only'] = '1';
      if (projectId != null) {
        params['project_id'] = projectId.toString();
      }
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/contracts',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> getContractDetail(String token, int id) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$id'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getUsersLookup(
    String token, {
    String search = '',
    String role = '',
    String purpose = '',
  }) async {
    final Map<String, String> params = <String, String>{};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (role.trim().isNotEmpty) {
      params['role'] = role.trim();
    }
    if (purpose.trim().isNotEmpty) {
      params['purpose'] = purpose.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/users/lookup',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createContract(
    String token, {
    required String title,
    required int clientId,
    int? projectId,
    int? collectorUserId,
    List<int>? careStaffIds,
    double? value,
    int? paymentTimes,
    String status = 'draft',
    bool createAndApprove = false,
    String? signedAt,
    String? startDate,
    String? endDate,
    String? notes,
    List<Map<String, dynamic>> items = const <Map<String, dynamic>>[],
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'title': title,
      'client_id': clientId,
      'status': status,
      'create_and_approve': createAndApprove,
      if (projectId != null) 'project_id': projectId,
      if (collectorUserId != null) 'collector_user_id': collectorUserId,
      if (careStaffIds != null) 'care_staff_ids': careStaffIds,
      if (value != null) 'value': value,
      if (paymentTimes != null) 'payment_times': paymentTimes,
      if (signedAt != null) 'signed_at': signedAt,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (notes != null) 'notes': notes,
      if (items.isNotEmpty) 'items': items,
    };
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts'),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateContract(
    String token,
    int id, {
    required String title,
    required int clientId,
    int? projectId,
    int? collectorUserId,
    List<int>? careStaffIds,
    double? value,
    int? paymentTimes,
    String status = 'draft',
    String? signedAt,
    String? startDate,
    String? endDate,
    String? notes,
    List<Map<String, dynamic>> items = const <Map<String, dynamic>>[],
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'title': title,
      'client_id': clientId,
      'status': status,
      if (projectId != null) 'project_id': projectId,
      if (collectorUserId != null) 'collector_user_id': collectorUserId,
      if (careStaffIds != null) 'care_staff_ids': careStaffIds,
      if (value != null) 'value': value,
      if (paymentTimes != null) 'payment_times': paymentTimes,
      if (signedAt != null) 'signed_at': signedAt,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (notes != null) 'notes': notes,
      if (items.isNotEmpty) 'items': items,
    };
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteContract(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<bool> approveContract(String token, int id, {String? note}) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$id/approve'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (note != null) 'approval_note': note,
      }),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> createContractCareNote(
    String token,
    int contractId, {
    required String title,
    required String detail,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/care-notes'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'title': title, 'detail': detail}),
    );
    if (res.statusCode != 201) return null;
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final dynamic note = body['note'];
    return note is Map<String, dynamic> ? note : null;
  }

  Future<List<Map<String, dynamic>>> getContractPayments(
    String token,
    int contractId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/payments'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createContractPayment(
    String token,
    int contractId, {
    required double amount,
    String? paidAt,
    String? method,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/payments'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'amount': amount,
        if (paidAt != null) 'paid_at': paidAt,
        if (method != null) 'method': method,
        if (note != null) 'note': note,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateContractPayment(
    String token,
    int contractId,
    int paymentId, {
    required double amount,
    String? paidAt,
    String? method,
    String? note,
  }) async {
    final http.Response res = await http.put(
      Uri.parse(
        '${AppEnv.apiBaseUrl}/contracts/$contractId/payments/$paymentId',
      ),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'amount': amount,
        if (paidAt != null) 'paid_at': paidAt,
        if (method != null) 'method': method,
        if (note != null) 'note': note,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteContractPayment(
    String token,
    int contractId,
    int paymentId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse(
        '${AppEnv.apiBaseUrl}/contracts/$contractId/payments/$paymentId',
      ),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getContractCosts(
    String token,
    int contractId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/costs'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createContractCost(
    String token,
    int contractId, {
    required double amount,
    String? costDate,
    String? costType,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/costs'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'amount': amount,
        if (costDate != null) 'cost_date': costDate,
        if (costType != null) 'cost_type': costType,
        if (note != null) 'note': note,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateContractCost(
    String token,
    int contractId,
    int costId, {
    required double amount,
    String? costDate,
    String? costType,
    String? note,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/costs/$costId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'amount': amount,
        if (costDate != null) 'cost_date': costDate,
        if (costType != null) 'cost_type': costType,
        if (note != null) 'note': note,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteContractCost(
    String token,
    int contractId,
    int costId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/costs/$costId'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> importClients(String token, File file) async {
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppEnv.apiBaseUrl}/imports/clients'),
    );
    request.headers.addAll(_authHeaders(token));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final http.StreamedResponse streamed = await request.send();
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      return <String, dynamic>{'error': body};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importContracts(String token, File file) async {
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppEnv.apiBaseUrl}/imports/contracts'),
    );
    request.headers.addAll(_authHeaders(token));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final http.StreamedResponse streamed = await request.send();
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      return <String, dynamic>{'error': body};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importTasks(String token, File file) async {
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppEnv.apiBaseUrl}/imports/tasks'),
    );
    request.headers.addAll(_authHeaders(token));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final http.StreamedResponse streamed = await request.send();
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      return <String, dynamic>{'error': body};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLeadTypes(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-types'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createLeadType(
    String token, {
    required String name,
    String? colorHex,
    int? sortOrder,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-types'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (colorHex != null) 'color_hex': colorHex,
        if (sortOrder != null) 'sort_order': sortOrder,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateLeadType(
    String token,
    int id, {
    required String name,
    String? colorHex,
    int? sortOrder,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-types/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (colorHex != null) 'color_hex': colorHex,
        if (sortOrder != null) 'sort_order': sortOrder,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteLeadType(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-types/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getOpportunityStatuses(
    String token,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunity-statuses'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createOpportunityStatus(
    String token, {
    required String name,
    String? colorHex,
    int? sortOrder,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunity-statuses'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (colorHex != null) 'color_hex': colorHex,
        if (sortOrder != null) 'sort_order': sortOrder,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateOpportunityStatus(
    String token,
    int id, {
    required String name,
    String? colorHex,
    int? sortOrder,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunity-statuses/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (colorHex != null) 'color_hex': colorHex,
        if (sortOrder != null) 'sort_order': sortOrder,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteOpportunityStatus(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunity-statuses/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getRevenueTiers(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/revenue-tiers'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createRevenueTier(
    String token, {
    required String name,
    required String label,
    String? colorHex,
    double? minAmount,
    int? sortOrder,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/revenue-tiers'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'label': label,
        if (colorHex != null) 'color_hex': colorHex,
        if (minAmount != null) 'min_amount': minAmount,
        if (sortOrder != null) 'sort_order': sortOrder,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateRevenueTier(
    String token,
    int id, {
    required String name,
    required String label,
    String? colorHex,
    double? minAmount,
    int? sortOrder,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/revenue-tiers/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'label': label,
        if (colorHex != null) 'color_hex': colorHex,
        if (minAmount != null) 'min_amount': minAmount,
        if (sortOrder != null) 'sort_order': sortOrder,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteRevenueTier(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/revenue-tiers/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getProducts(
    String token, {
    int perPage = 100,
    String search = '',
    String isActive = '',
    int? categoryId,
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (isActive.trim().isNotEmpty) {
      params['is_active'] = isActive.trim();
    }
    if (categoryId != null) {
      params['category_id'] = '$categoryId';
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/products',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createProduct(
    String token, {
    required String name,
    int? categoryId,
    String? unit,
    double? unitPrice,
    String? description,
    bool isActive = true,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/products'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (categoryId != null) 'category_id': categoryId,
        if (unit != null) 'unit': unit,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (description != null) 'description': description,
        'is_active': isActive,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateProduct(
    String token,
    int id, {
    required String name,
    int? categoryId,
    String? unit,
    double? unitPrice,
    String? description,
    bool isActive = true,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/products/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (categoryId != null) 'category_id': categoryId,
        if (unit != null) 'unit': unit,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (description != null) 'description': description,
        'is_active': isActive,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteProduct(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/products/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getProductCategories(
    String token, {
    int perPage = 100,
    String search = '',
    String isActive = '',
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (isActive.trim().isNotEmpty) {
      params['is_active'] = isActive.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/product-categories',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createProductCategory(
    String token, {
    String? code,
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/product-categories'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (code != null) 'code': code,
        'name': name,
        if (description != null) 'description': description,
        'is_active': isActive,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateProductCategory(
    String token,
    int id, {
    String? code,
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/product-categories/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (code != null) 'code': code,
        'name': name,
        if (description != null) 'description': description,
        'is_active': isActive,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteProductCategory(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/product-categories/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getDepartments(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/departments'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getUsersAccounts(
    String token, {
    int perPage = 200,
    String search = '',
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/users/accounts',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows =
        ((body['users'] ?? <String, dynamic>{})['data'] ?? <dynamic>[])
            as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createDepartment(
    String token, {
    required String name,
    int? managerId,
    List<int> staffIds = const <int>[],
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/departments'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (managerId != null) 'manager_id': managerId,
        if (staffIds.isNotEmpty) 'staff_ids': staffIds,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateDepartment(
    String token,
    int id, {
    String? name,
    int? managerId,
    List<int> staffIds = const <int>[],
    List<int> removeStaffIds = const <int>[],
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/departments/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (name != null) 'name': name,
        if (managerId != null) 'manager_id': managerId,
        if (staffIds.isNotEmpty) 'staff_ids': staffIds,
        if (removeStaffIds.isNotEmpty) 'remove_staff_ids': removeStaffIds,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteDepartment(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/departments/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getDepartmentAssignments(
    String token, {
    int perPage = 50,
    int? departmentId,
    String status = '',
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (departmentId != null) {
      params['department_id'] = departmentId.toString();
    }
    if (status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/department-assignments',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createDepartmentAssignment(
    String token, {
    required int clientId,
    int? contractId,
    required int departmentId,
    String? requirements,
    String? deadline,
    double? allocatedValue,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/department-assignments'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'client_id': clientId,
        if (contractId != null) 'contract_id': contractId,
        'department_id': departmentId,
        if (requirements != null) 'requirements': requirements,
        if (deadline != null) 'deadline': deadline,
        if (allocatedValue != null) 'allocated_value': allocatedValue,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateDepartmentAssignment(
    String token,
    int id, {
    String? status,
    int? progressPercent,
    String? progressNote,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/department-assignments/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (status != null) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (progressNote != null) 'progress_note': progressNote,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteDepartmentAssignment(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/department-assignments/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getRevenueReport(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/reports/revenue'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCompanyRevenueReport(
    String token, {
    String? from,
    String? to,
    String? targetRevenue,
  }) async {
    final Map<String, String> params = <String, String>{};
    if (from != null && from.trim().isNotEmpty) {
      params['from'] = from.trim();
    }
    if (to != null && to.trim().isNotEmpty) {
      params['to'] = to.trim();
    }
    if (targetRevenue != null && targetRevenue.trim().isNotEmpty) {
      params['target_revenue'] = targetRevenue.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/reports/company',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLeadForms(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-forms?per_page=200'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createLeadForm(
    String token, {
    required String name,
    String? slug,
    int? leadTypeId,
    int? departmentId,
    bool isActive = true,
    String? redirectUrl,
    String? description,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-forms'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (slug != null) 'slug': slug,
        if (leadTypeId != null) 'lead_type_id': leadTypeId,
        if (departmentId != null) 'department_id': departmentId,
        'is_active': isActive,
        if (redirectUrl != null) 'redirect_url': redirectUrl,
        if (description != null) 'description': description,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateLeadForm(
    String token,
    int id, {
    required String name,
    int? leadTypeId,
    int? departmentId,
    bool isActive = true,
    String? redirectUrl,
    String? description,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-forms/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        if (leadTypeId != null) 'lead_type_id': leadTypeId,
        if (departmentId != null) 'department_id': departmentId,
        'is_active': isActive,
        if (redirectUrl != null) 'redirect_url': redirectUrl,
        if (description != null) 'description': description,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteLeadForm(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-forms/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTasks(
    String token, {
    String status = '',
    int? projectId,
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/tasks').replace(
      queryParameters: <String, String>{
        'per_page': '$perPage',
        if (status.isNotEmpty) 'status': status,
        if (projectId != null) 'project_id': projectId.toString(),
      },
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getProject(String token, int projectId) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$projectId'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProjectSearchConsole(
    String token,
    int projectId, {
    bool refresh = true,
    bool force = false,
    int days = 21,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/projects/$projectId/search-console',
    ).replace(
      queryParameters: <String, String>{
        'refresh': refresh ? '1' : '0',
        'force': force ? '1' : '0',
        'days': '$days',
      },
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));

    Map<String, dynamic> body = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = <String, dynamic>{};
      }
    }

    if (res.statusCode != 200) {
      final String message =
          (body['message'] ?? 'Không tải được dữ liệu Google Search Console.')
              .toString();
      return <String, dynamic>{
        'error': true,
        'statusCode': res.statusCode,
        'message': message,
        'body': body,
      };
    }

    return <String, dynamic>{
      'error': false,
      'statusCode': res.statusCode,
      'body': body,
    };
  }

  Future<Map<String, dynamic>> syncProjectSearchConsole(
    String token,
    int projectId,
  ) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$projectId/search-console/sync'),
      headers: _jsonHeaders(token),
    );

    Map<String, dynamic> body = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = <String, dynamic>{};
      }
    }

    if (res.statusCode != 200) {
      final String message =
          (body['message'] ??
                  'Không đồng bộ được dữ liệu Google Search Console.')
              .toString();
      return <String, dynamic>{
        'error': true,
        'statusCode': res.statusCode,
        'message': message,
        'body': body,
      };
    }

    return <String, dynamic>{
      'error': false,
      'statusCode': res.statusCode,
      'body': body,
    };
  }

  Future<List<Map<String, dynamic>>> getProjectHandovers(
    String token, {
    int perPage = 50,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/project-handovers',
    ).replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> submitProjectHandover(String token, int projectId) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$projectId/handover-submit'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<bool> reviewProjectHandover(
    String token,
    int projectId, {
    required String decision,
    String? reason,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$projectId/handover-review'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'decision': decision,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> getTaskDetail(String token, int taskId) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> createTask(
    String token, {
    required int projectId,
    int? departmentId,
    int? assigneeId,
    required String title,
    String? description,
    String priority = 'medium',
    String status = 'todo',
    String? deadline,
    int? weightPercent,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'project_id': projectId,
        if (departmentId != null) 'department_id': departmentId,
        if (assigneeId != null) 'assignee_id': assigneeId,
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'priority': priority,
        'status': status,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
        if (weightPercent != null) 'weight_percent': weightPercent,
      }),
    );
    return res.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getTaskItems(
    String token,
    int taskId, {
    int perPage = 50,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/tasks/$taskId/items',
    ).replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createTaskItem(
    String token,
    int taskId, {
    required String title,
    String? description,
    String priority = 'medium',
    String status = 'todo',
    int? progressPercent,
    int? weightPercent,
    String? deadline,
    int? assigneeId,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/items'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'priority': priority,
        'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (weightPercent != null) 'weight_percent': weightPercent,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
        if (assigneeId != null) 'assignee_id': assigneeId,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateTaskItem(
    String token,
    int taskId,
    int itemId, {
    String? title,
    String? description,
    String? priority,
    String? status,
    int? progressPercent,
    int? weightPercent,
    String? deadline,
    int? assigneeId,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (weightPercent != null) 'weight_percent': weightPercent,
        if (deadline != null) 'deadline': deadline,
        if (assigneeId != null) 'assignee_id': assigneeId,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteTaskItem(String token, int taskId, int itemId) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTaskItemUpdates(
    String token,
    int taskId,
    int itemId, {
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates',
    ).replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getTaskItemProgressInsight(
    String token,
    int taskId,
    int itemId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse(
        '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/progress-insight',
      ),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> createTaskItemUpdate(
    String token,
    int taskId,
    int itemId, {
    String? status,
    int? progressPercent,
    String? note,
    File? attachment,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates',
    );
    if (attachment != null) {
      final http.MultipartRequest request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_jsonHeaders(token));
      if (status != null && status.isNotEmpty) {
        request.fields['status'] = status;
      }
      if (progressPercent != null) {
        request.fields['progress_percent'] = '$progressPercent';
      }
      if (note != null && note.trim().isNotEmpty) {
        request.fields['note'] = note.trim();
      }
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
      final http.StreamedResponse res = await request.send();
      return res.statusCode == 201;
    }
    final http.Response res = await http.post(
      uri,
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> approveTaskItemUpdate(
    String token,
    int taskId,
    int itemId,
    int updateId, {
    String? status,
    int? progressPercent,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse(
        '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates/$updateId/approve',
      ),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> updateTaskItemUpdate(
    String token,
    int taskId,
    int itemId,
    int updateId, {
    String? status,
    int? progressPercent,
    String? note,
    File? attachment,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates/$updateId',
    );
    final http.MultipartRequest request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders(token));
    request.fields['_method'] = 'PUT';
    if (status != null && status.isNotEmpty) {
      request.fields['status'] = status;
    }
    if (progressPercent != null) {
      request.fields['progress_percent'] = '$progressPercent';
    }
    if (note != null) {
      request.fields['note'] = note.trim();
    }
    if (attachment != null && _fileExists(attachment.path)) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
    }
    final http.StreamedResponse res = await request.send();
    return res.statusCode == 200;
  }

  Future<bool> rejectTaskItemUpdate(
    String token,
    int taskId,
    int itemId,
    int updateId, {
    required String reviewNote,
  }) async {
    final http.Response res = await http.post(
      Uri.parse(
        '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates/$updateId/reject',
      ),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'review_note': reviewNote}),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteTaskItemUpdate(
    String token,
    int taskId,
    int itemId,
    int updateId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse(
        '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates/$updateId',
      ),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<bool> updateTaskStatus(
    String token,
    Map<String, dynamic> task,
    String newStatus,
  ) async {
    final int taskId = (task['id'] ?? 0) as int;
    final Map<String, dynamic> payload = <String, dynamic>{
      'project_id': task['project_id'],
      'title': task['title'],
      'description': task['description'],
      'priority': task['priority'] ?? 'medium',
      'status': newStatus,
      'start_at': task['start_at'],
      'deadline': task['deadline'],
      'completed_at': task['completed_at'],
      'progress_percent': task['progress_percent'],
      'weight_percent': task['weight_percent'],
      'assigned_by': task['assigned_by'],
      'assignee_id': task['assignee_id'],
      'reviewer_id': task['reviewer_id'],
      'require_acknowledgement': task['require_acknowledgement'] ?? false,
      'acknowledged_at': task['acknowledged_at'],
    };
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    return res.statusCode == 200;
  }

  Future<bool> acknowledgeTask(String token, Map<String, dynamic> task) async {
    final int taskId = (task['id'] ?? 0) as int;
    if (taskId <= 0) return false;
    final DateTime now = VietnamTime.now();
    final String stamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:00';
    final Map<String, dynamic> payload = <String, dynamic>{
      'project_id': task['project_id'],
      'title': task['title'],
      'description': task['description'],
      'priority': task['priority'] ?? 'medium',
      'status': task['status'],
      'start_at': task['start_at'],
      'deadline': task['deadline'],
      'completed_at': task['completed_at'],
      'progress_percent': task['progress_percent'],
      'weight_percent': task['weight_percent'],
      'assigned_by': task['assigned_by'],
      'assignee_id': task['assignee_id'],
      'reviewer_id': task['reviewer_id'],
      'require_acknowledgement': task['require_acknowledgement'] ?? true,
      'acknowledged_at': stamp,
    };
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTaskUpdates(
    String token,
    int taskId, {
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/tasks/$taskId/updates',
    ).replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createTaskUpdate(
    String token,
    int taskId, {
    String? status,
    int? progressPercent,
    String? note,
    File? attachment,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/updates');
    if (attachment != null) {
      final http.MultipartRequest request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_jsonHeaders(token));
      if (status != null && status.isNotEmpty) {
        request.fields['status'] = status;
      }
      if (progressPercent != null) {
        request.fields['progress_percent'] = '$progressPercent';
      }
      if (note != null && note.trim().isNotEmpty) {
        request.fields['note'] = note.trim();
      }
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachment.path),
      );
      final http.StreamedResponse res = await request.send();
      return res.statusCode == 201;
    }
    final http.Response res = await http.post(
      uri,
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> approveTaskUpdate(
    String token,
    int taskId,
    int updateId, {
    String? status,
    int? progressPercent,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/updates/$updateId/approve'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> rejectTaskUpdate(
    String token,
    int taskId,
    int updateId, {
    required String reviewNote,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/updates/$updateId/reject'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'review_note': reviewNote}),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getNotifications(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/notifications/in-app'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> markNotificationRead(
    String token, {
    required String sourceType,
    required int sourceId,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/notifications/in-app/read'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'source_type': sourceType,
        'source_id': sourceId,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> markAllNotificationsRead(
    String token, {
    String? sourceType,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/notifications/in-app/read-all'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (sourceType != null && sourceType.isNotEmpty)
          'source_type': sourceType,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> clearReadNotifications(
    String token, {
    String? sourceType,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/notifications/in-app/clear-read'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (sourceType != null && sourceType.isNotEmpty)
          'source_type': sourceType,
      }),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getNotificationPreferences(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/notification-preferences'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{
        'notifications_enabled': true,
        'category_system_enabled': true,
        'category_crm_realtime_enabled': true,
      };
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(
    String token, {
    bool? notificationsEnabled,
    bool? categorySystemEnabled,
    bool? categoryCrmRealtimeEnabled,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/notification-preferences'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (notificationsEnabled != null)
          'notifications_enabled': notificationsEnabled,
        if (categorySystemEnabled != null)
          'category_system_enabled': categorySystemEnabled,
        if (categoryCrmRealtimeEnabled != null)
          'category_crm_realtime_enabled': categoryCrmRealtimeEnabled,
      }),
    );
    if (res.statusCode != 200) {
      return <String, dynamic>{'error': true, 'status': res.statusCode};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getActivityLogs(
    String token, {
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/activity-logs',
    ).replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) {
      return <String, dynamic>{
        'statusCode': res.statusCode,
        'data': <dynamic>[],
      };
    }
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return <String, dynamic>{'statusCode': res.statusCode, 'data': rows};
  }

  Future<Map<String, dynamic>> getMeetings(
    String token, {
    int perPage = 20,
    String search = '',
    String dateFrom = '',
    String dateTo = '',
    int? attendeeId,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/meetings').replace(
      queryParameters: <String, String>{
        'per_page': '$perPage',
        if (search.isNotEmpty) 'search': search,
        if (dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo.isNotEmpty) 'date_to': dateTo,
        if (attendeeId != null) 'attendee_id': '$attendeeId',
      },
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> createMeeting(
    String token, {
    required String title,
    required String scheduledAt,
    String? meetingLink,
    String? description,
    String? minutes,
    List<int> attendeeIds = const <int>[],
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/meetings'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'scheduled_at': scheduledAt,
        'meeting_link': meetingLink,
        'description': description,
        'minutes': minutes,
        if (attendeeIds.isNotEmpty) 'attendee_ids': attendeeIds,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateMeeting(
    String token,
    int id, {
    required String title,
    required String scheduledAt,
    String? meetingLink,
    String? description,
    String? minutes,
    List<int> attendeeIds = const <int>[],
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/meetings/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'scheduled_at': scheduledAt,
        'meeting_link': meetingLink,
        'description': description,
        'minutes': minutes,
        'attendee_ids': attendeeIds,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteMeeting(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/meetings/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getClients(
    String token, {
    int perPage = 50,
    String search = '',
    int? leadTypeId,
    bool leadOnly = false,
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (leadTypeId != null) {
      params['lead_type_id'] = leadTypeId.toString();
    }
    if (leadOnly) {
      params['lead_only'] = '1';
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/crm/clients',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createClient(
    String token, {
    required String name,
    String? company,
    String? email,
    String? phone,
    String? notes,
    int? salesOwnerId,
    int? assignedDepartmentId,
    int? assignedStaffId,
    List<int>? careStaffIds,
    int? leadTypeId,
    String? leadSource,
    String? leadChannel,
    String? leadMessage,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/clients'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'notes': notes,
        if (salesOwnerId != null) 'sales_owner_id': salesOwnerId,
        if (assignedDepartmentId != null)
          'assigned_department_id': assignedDepartmentId,
        if (assignedStaffId != null) 'assigned_staff_id': assignedStaffId,
        if (careStaffIds != null) 'care_staff_ids': careStaffIds,
        if (leadTypeId != null) 'lead_type_id': leadTypeId,
        if (leadSource != null) 'lead_source': leadSource,
        if (leadChannel != null) 'lead_channel': leadChannel,
        if (leadMessage != null) 'lead_message': leadMessage,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateClient(
    String token,
    int id, {
    required String name,
    String? company,
    String? email,
    String? phone,
    String? notes,
    int? salesOwnerId,
    int? assignedDepartmentId,
    int? assignedStaffId,
    List<int>? careStaffIds,
    int? leadTypeId,
    String? leadSource,
    String? leadChannel,
    String? leadMessage,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/clients/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'notes': notes,
        if (salesOwnerId != null) 'sales_owner_id': salesOwnerId,
        if (assignedDepartmentId != null)
          'assigned_department_id': assignedDepartmentId,
        if (assignedStaffId != null) 'assigned_staff_id': assignedStaffId,
        if (careStaffIds != null) 'care_staff_ids': careStaffIds,
        if (leadTypeId != null) 'lead_type_id': leadTypeId,
        if (leadSource != null) 'lead_source': leadSource,
        if (leadChannel != null) 'lead_channel': leadChannel,
        if (leadMessage != null) 'lead_message': leadMessage,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteClient(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/clients/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getPayments(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/payments?per_page=10'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createPayment(
    String token, {
    required int clientId,
    required double amount,
    required String status,
    String? dueDate,
    String? paidAt,
    String? invoiceNo,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/payments'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'client_id': clientId,
        'amount': amount,
        'status': status,
        'due_date': dueDate,
        'paid_at': paidAt,
        'invoice_no': invoiceNo,
        'note': note,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updatePayment(
    String token,
    int id, {
    required int clientId,
    required double amount,
    required String status,
    String? dueDate,
    String? paidAt,
    String? invoiceNo,
    String? note,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/payments/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'client_id': clientId,
        'amount': amount,
        'status': status,
        'due_date': dueDate,
        'paid_at': paidAt,
        'invoice_no': invoiceNo,
        'note': note,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deletePayment(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/payments/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getReportSummary(
    String token, {
    String? from,
    String? to,
  }) async {
    final Map<String, String> params = <String, String>{};
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/reports/dashboard-summary',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final http.Response res = await http.get(
      uri,
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getServiceItems(
    String token,
    String type,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/services/$type/items?per_page=10'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createServiceItem(
    String token,
    String type,
    Map<String, dynamic> payload,
  ) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/services/$type/items'),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateServiceItem(
    String token,
    String type,
    int id,
    Map<String, dynamic> payload,
  ) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/services/$type/items/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(payload),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteServiceItem(String token, String type, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/services/$type/items/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTaskComments(
    String token,
    int taskId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments?per_page=20'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<PaginatedResult<Map<String, dynamic>>> getTaskCommentsPage(
    String token,
    int taskId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/tasks/$taskId/comments',
    ).replace(
      queryParameters: <String, String>{
        'per_page': '$perPage',
        'page': '$page',
      },
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) {
      return PaginatedResult<Map<String, dynamic>>.empty();
    }
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return PaginatedResult<Map<String, dynamic>>(
      data: rows.map((dynamic e) => e as Map<String, dynamic>).toList(),
      currentPage: (body['current_page'] ?? page) as int,
      lastPage: (body['last_page'] ?? page) as int,
    );
  }

  Future<List<Map<String, dynamic>>> getChatParticipants(
    String token,
    int taskId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/chat-participants'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createTaskComment(
    String token,
    int taskId, {
    required String content,
    List<int>? taggedUserIds,
    List<String>? taggedUserEmails,
    String? attachmentPath,
  }) async {
    if (_fileExists(attachmentPath)) {
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments'),
      );
      request.headers.addAll(_authHeaders(token));
      request.fields['content'] = content;
      if (taggedUserIds != null) {
        request.fields['tagged_user_ids'] = jsonEncode(taggedUserIds);
      }
      if (taggedUserEmails != null) {
        request.fields['tagged_user_emails'] = jsonEncode(taggedUserEmails);
      }
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachmentPath!),
      );
      final http.StreamedResponse streamed = await request.send();
      final http.Response res = await http.Response.fromStream(streamed);
      return res.statusCode == 201;
    }

    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'content': content,
        if (taggedUserIds != null) 'tagged_user_ids': taggedUserIds,
        if (taggedUserEmails != null) 'tagged_user_emails': taggedUserEmails,
        if (attachmentPath != null) 'attachment_path': attachmentPath,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateTaskComment(
    String token,
    int taskId,
    int commentId, {
    required String content,
    List<int>? taggedUserIds,
    List<String>? taggedUserEmails,
    String? attachmentPath,
  }) async {
    if (_fileExists(attachmentPath)) {
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments/$commentId'),
      );
      request.headers.addAll(_authHeaders(token));
      request.fields['_method'] = 'PUT';
      request.fields['content'] = content;
      if (taggedUserIds != null) {
        request.fields['tagged_user_ids'] = jsonEncode(taggedUserIds);
      }
      if (taggedUserEmails != null) {
        request.fields['tagged_user_emails'] = jsonEncode(taggedUserEmails);
      }
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachmentPath!),
      );
      final http.StreamedResponse streamed = await request.send();
      final http.Response res = await http.Response.fromStream(streamed);
      return res.statusCode == 200;
    }

    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments/$commentId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'content': content,
        if (taggedUserIds != null) 'tagged_user_ids': taggedUserIds,
        if (taggedUserEmails != null) 'tagged_user_emails': taggedUserEmails,
        if (attachmentPath != null) 'attachment_path': attachmentPath,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteTaskComment(
    String token,
    int taskId,
    int commentId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments/$commentId'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<bool> registerDeviceToken(
    String token, {
    required String deviceToken,
    String? platform,
    String? deviceName,
    bool? notificationsEnabled,
    String? apnsEnvironment,
  }) async {
    final Map<String, dynamic> result = await registerDeviceTokenWithResult(
      token,
      deviceToken: deviceToken,
      platform: platform,
      deviceName: deviceName,
      notificationsEnabled: notificationsEnabled,
      apnsEnvironment: apnsEnvironment,
    );
    return result['ok'] == true;
  }

  Future<Map<String, dynamic>> registerDeviceTokenWithResult(
    String token, {
    required String deviceToken,
    String? platform,
    String? deviceName,
    bool? notificationsEnabled,
    String? apnsEnvironment,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/device-tokens'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'token': deviceToken,
        if (platform != null) 'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
        if (notificationsEnabled != null)
          'notifications_enabled': notificationsEnabled,
        if (apnsEnvironment != null) 'apns_environment': apnsEnvironment,
      }),
    );
    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      body = <String, dynamic>{'raw': res.body};
    }

    return <String, dynamic>{
      'ok': res.statusCode == 200,
      'status': res.statusCode,
      'body': body,
      'message': body['message']?.toString() ?? '',
    };
  }

  Future<String?> updateProfileAvatar(
    String token, {
    required String filePath,
  }) async {
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppEnv.apiBaseUrl}/profile/avatar'),
    );
    request.headers.addAll(_authHeaders(token));
    request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
    final http.StreamedResponse streamed = await request.send();
    final http.Response res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) return null;
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    return (body['avatar_url'] ?? '').toString();
  }

  Future<List<Map<String, dynamic>>> getTaskAttachments(
    String token,
    int taskId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/attachments?per_page=20'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createTaskAttachment(
    String token,
    int taskId, {
    required String type,
    String? title,
    String? externalUrl,
    String? filePath,
    int? version,
    bool isHandover = false,
    String? note,
  }) async {
    if (_fileExists(filePath)) {
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/attachments'),
      );
      request.headers.addAll(_authHeaders(token));
      request.fields['type'] = type;
      if (title != null) request.fields['title'] = title;
      if (externalUrl != null) request.fields['external_url'] = externalUrl;
      if (version != null) request.fields['version'] = version.toString();
      request.fields['is_handover'] = isHandover ? '1' : '0';
      if (note != null) request.fields['note'] = note;
      request.files.add(await http.MultipartFile.fromPath('file', filePath!));
      final http.StreamedResponse streamed = await request.send();
      final http.Response res = await http.Response.fromStream(streamed);
      return res.statusCode == 201;
    }

    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/attachments'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'type': type,
        'title': title,
        'external_url': externalUrl,
        'file_path': filePath,
        'version': version,
        'is_handover': isHandover,
        'note': note,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> deleteTaskAttachment(
    String token,
    int taskId,
    int attachmentId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/attachments/$attachmentId'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getTaskReminders(
    String token,
    int taskId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/reminders?per_page=20'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createTaskReminder(
    String token,
    int taskId, {
    required String channel,
    required String triggerType,
    required String scheduledAt,
    String status = 'pending',
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/reminders'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'channel': channel,
        'trigger_type': triggerType,
        'scheduled_at': scheduledAt,
        'status': status,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateTaskReminder(
    String token,
    int taskId,
    int reminderId, {
    required String channel,
    required String triggerType,
    required String scheduledAt,
    String status = 'pending',
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/reminders/$reminderId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'channel': channel,
        'trigger_type': triggerType,
        'scheduled_at': scheduledAt,
        'status': status,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteTaskReminder(
    String token,
    int taskId,
    int reminderId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/reminders/$reminderId'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final dynamic decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Map<String, dynamic> _withMeta(http.Response res) {
    final Map<String, dynamic> body = _decodeResponseBody(res.body);
    return <String, dynamic>{
      ...body,
      'ok': res.statusCode >= 200 && res.statusCode < 300,
      'statusCode': res.statusCode,
      'message':
          (body['message'] ?? body['error'] ?? 'Co loi xay ra').toString(),
    };
  }

  Future<Map<String, dynamic>> getAttendanceDashboard(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/dashboard'),
      headers: _jsonHeaders(token),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceRecords(
    String token, {
    String? fromDate,
    String? toDate,
  }) async {
    final Map<String, String> params = <String, String>{};
    if (fromDate != null && fromDate.trim().isNotEmpty) {
      params['from_date'] = fromDate.trim();
    }
    if (toDate != null && toDate.trim().isNotEmpty) {
      params['to_date'] = toDate.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/attendance/records/my',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceRequests(
    String token, {
    int page = 1,
    int perPage = 50,
    String status = '',
    String requestType = '',
    String search = '',
  }) async {
    final Map<String, String> params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (requestType.trim().isNotEmpty) {
      params['request_type'] = requestType.trim();
    }
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/attendance/requests',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> submitAttendanceRequest(
    String token, {
    required String requestType,
    required String requestDate,
    required String title,
    String? expectedCheckInTime,
    String? content,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/requests'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'request_type': requestType,
        'request_date': requestDate,
        'title': title,
        if (expectedCheckInTime != null &&
            expectedCheckInTime.trim().isNotEmpty)
          'expected_check_in_time': expectedCheckInTime.trim(),
        if (content != null && content.trim().isNotEmpty)
          'content': content.trim(),
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> reviewAttendanceRequest(
    String token,
    int requestId, {
    required String status,
    String? approvalMode,
    double? approvedWorkUnits,
    String? decisionNote,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/requests/$requestId/review'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'status': status,
        if (approvalMode != null && approvalMode.trim().isNotEmpty)
          'approval_mode': approvalMode.trim(),
        if (approvedWorkUnits != null) 'approved_work_units': approvedWorkUnits,
        if (decisionNote != null && decisionNote.trim().isNotEmpty)
          'decision_note': decisionNote.trim(),
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> submitAttendanceDevice(
    String token, {
    required String deviceUuid,
    required String deviceName,
    required String devicePlatform,
    required String deviceModel,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/devices/request'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'device_uuid': deviceUuid,
        'device_name': deviceName,
        'device_platform': devicePlatform,
        'device_model': deviceModel,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> reviewAttendanceDevice(
    String token,
    int deviceId, {
    required String status,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/devices/$deviceId/review'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> checkInAttendance(
    String token, {
    required String deviceUuid,
    required String deviceName,
    required String devicePlatform,
    required String deviceModel,
    required String wifiSsid,
    String? wifiBssid,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/check-in'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'device_uuid': deviceUuid,
        'device_name': deviceName,
        'device_platform': devicePlatform,
        'device_model': deviceModel,
        'wifi_ssid': wifiSsid,
        if (wifiBssid != null && wifiBssid.trim().isNotEmpty)
          'wifi_bssid': wifiBssid.trim(),
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceSettings(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/settings'),
      headers: _jsonHeaders(token),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> updateAttendanceSettings(
    String token, {
    required bool attendanceEnabled,
    required String workStartTime,
    required String workEndTime,
    required String afternoonStartTime,
    required int lateGraceMinutes,
    required bool reminderEnabled,
    required int reminderMinutesBefore,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/settings'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'attendance_enabled': attendanceEnabled,
        'attendance_work_start_time': workStartTime,
        'attendance_work_end_time': workEndTime,
        'attendance_afternoon_start_time': afternoonStartTime,
        'attendance_late_grace_minutes': lateGraceMinutes,
        'attendance_reminder_enabled': reminderEnabled,
        'attendance_reminder_minutes_before': reminderMinutesBefore,
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceWifiNetworks(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/wifi'),
      headers: _jsonHeaders(token),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> createAttendanceWifiNetwork(
    String token, {
    required String ssid,
    String? bssid,
    String? note,
    bool isActive = true,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/wifi'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'ssid': ssid,
        if (bssid != null && bssid.trim().isNotEmpty) 'bssid': bssid.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'is_active': isActive,
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> updateAttendanceWifiNetwork(
    String token,
    int wifiId, {
    required String ssid,
    String? bssid,
    String? note,
    bool isActive = true,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/wifi/$wifiId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'ssid': ssid,
        if (bssid != null && bssid.trim().isNotEmpty) 'bssid': bssid.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'is_active': isActive,
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> deleteAttendanceWifiNetwork(
    String token,
    int wifiId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/wifi/$wifiId'),
      headers: _jsonHeaders(token),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceDevices(
    String token, {
    int page = 1,
    int perPage = 50,
    String status = '',
    String search = '',
  }) async {
    final Map<String, String> params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/attendance/devices',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceHolidays(
    String token, {
    String? fromDate,
    String? toDate,
  }) async {
    final Map<String, String> params = <String, String>{};
    if (fromDate != null && fromDate.trim().isNotEmpty) {
      params['from_date'] = fromDate.trim();
    }
    if (toDate != null && toDate.trim().isNotEmpty) {
      params['to_date'] = toDate.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/attendance/holidays',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> createAttendanceHoliday(
    String token, {
    required String startDate,
    required String endDate,
    required String title,
    String? note,
    bool isActive = true,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/holidays'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'start_date': startDate,
        'end_date': endDate,
        'title': title,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'is_active': isActive,
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> updateAttendanceHoliday(
    String token,
    int holidayId, {
    required String startDate,
    required String endDate,
    required String title,
    String? note,
    bool isActive = true,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/holidays/$holidayId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'start_date': startDate,
        'end_date': endDate,
        'title': title,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'is_active': isActive,
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> deleteAttendanceHoliday(
    String token,
    int holidayId,
  ) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/holidays/$holidayId'),
      headers: _jsonHeaders(token),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceStaff(
    String token, {
    int page = 1,
    int perPage = 100,
    String search = '',
    String role = '',
  }) async {
    final Map<String, String> params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (role.trim().isNotEmpty) {
      params['role'] = role.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/attendance/staff',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> updateAttendanceStaff(
    String token,
    int userId, {
    required String employmentType,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/staff/$userId'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'attendance_employment_type': employmentType,
      }),
    );
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> getAttendanceReport(
    String token, {
    required String startDate,
    required String endDate,
    String search = '',
    String userId = '',
  }) async {
    final Map<String, String> params = <String, String>{
      'start_date': startDate,
      'end_date': endDate,
    };
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (userId.trim().isNotEmpty) {
      params['user_id'] = userId.trim();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/attendance/report',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    return _withMeta(res);
  }

  Future<Map<String, dynamic>> manualUpdateAttendanceRecord(
    String token, {
    required int userId,
    required String workDate,
    required double workUnits,
    String? checkInTime,
    String? note,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/attendance/records/manual'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'user_id': userId,
        'work_date': workDate,
        'work_units': workUnits,
        if (checkInTime != null && checkInTime.trim().isNotEmpty)
          'check_in_time': checkInTime.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
    return _withMeta(res);
  }

  // ─── Project Update & Delete ───────────────────────────────────────────

  Future<bool> updateProject(
    String token,
    int id, {
    required String name,
    required String serviceType,
    String? serviceTypeOther,
    String? status,
    int? contractId,
    int? ownerId,
    String? startDate,
    String? deadline,
    String? customerRequirement,
    String? repoUrl,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'service_type': serviceType,
        if (serviceTypeOther != null) 'service_type_other': serviceTypeOther,
        if (status != null) 'status': status,
        if (contractId != null) 'contract_id': contractId,
        if (ownerId != null) 'owner_id': ownerId,
        if (startDate != null) 'start_date': startDate,
        if (deadline != null) 'deadline': deadline,
        if (customerRequirement != null)
          'customer_requirement': customerRequirement,
        if (repoUrl != null) 'repo_url': repoUrl,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteProject(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  // ─── Project Flow & Files ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getProjectFlow(String token, int projectId) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/projects/$projectId/flow'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getProjectFiles(
    String token,
    int projectId, {
    int? parentId,
  }) async {
    final Map<String, String> params = <String, String>{};
    if (parentId != null) {
      params['parent_id'] = parentId.toString();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/projects/$projectId/files',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  // ─── Task Full Update & Delete ────────────────────────────────────────

  Future<bool> updateTask(
    String token,
    int id, {
    required int projectId,
    int? departmentId,
    int? assigneeId,
    int? reviewerId,
    required String title,
    String? description,
    String priority = 'medium',
    String status = 'todo',
    String? startAt,
    String? deadline,
    String? completedAt,
    int? progressPercent,
    int? weightPercent,
    bool? requireAcknowledgement,
    String? acknowledgedAt,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'project_id': projectId,
        if (departmentId != null) 'department_id': departmentId,
        if (assigneeId != null) 'assignee_id': assigneeId,
        if (reviewerId != null) 'reviewer_id': reviewerId,
        'title': title,
        if (description != null) 'description': description,
        'priority': priority,
        'status': status,
        if (startAt != null) 'start_at': startAt,
        if (deadline != null) 'deadline': deadline,
        if (completedAt != null) 'completed_at': completedAt,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (weightPercent != null) 'weight_percent': weightPercent,
        if (requireAcknowledgement != null)
          'require_acknowledgement': requireAcknowledgement,
        if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteTask(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getTaskConversations(
    String token, {
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/task-conversations',
    ).replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> markTaskChatRead(
    String token, {
    required int taskId,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/notifications/in-app/read-task-chat'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'task_id': taskId}),
    );
    return res.statusCode == 200;
  }

  // ─── Opportunities CRUD ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOpportunities(
    String token, {
    int perPage = 50,
    String search = '',
    String? status,
    int? clientId,
  }) async {
    final Map<String, String> params = <String, String>{'per_page': '$perPage'};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (clientId != null) {
      params['client_id'] = clientId.toString();
    }
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/opportunities',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getOpportunityDetail(
    String token,
    int id,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunities/$id'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> createOpportunity(
    String token, {
    required String title,
    required int clientId,
    String? opportunityType,
    double? amount,
    String? status,
    String? source,
    int? successProbability,
    int? productId,
    int? assignedTo,
    List<int>? watcherIds,
    String? expectedCloseDate,
    String? notes,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunities'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'client_id': clientId,
        if (opportunityType != null) 'opportunity_type': opportunityType,
        if (amount != null) 'amount': amount,
        if (status != null) 'status': status,
        if (source != null) 'source': source,
        if (successProbability != null)
          'success_probability': successProbability,
        if (productId != null) 'product_id': productId,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (watcherIds != null) 'watcher_ids': watcherIds,
        if (expectedCloseDate != null) 'expected_close_date': expectedCloseDate,
        if (notes != null) 'notes': notes,
      }),
    );
    return res.statusCode == 201;
  }

  Future<bool> updateOpportunity(
    String token,
    int id, {
    required String title,
    required int clientId,
    String? opportunityType,
    double? amount,
    String? status,
    String? source,
    int? successProbability,
    int? productId,
    int? assignedTo,
    List<int>? watcherIds,
    String? expectedCloseDate,
    String? notes,
  }) async {
    final http.Response res = await http.put(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunities/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'client_id': clientId,
        if (opportunityType != null) 'opportunity_type': opportunityType,
        if (amount != null) 'amount': amount,
        if (status != null) 'status': status,
        if (source != null) 'source': source,
        if (successProbability != null)
          'success_probability': successProbability,
        if (productId != null) 'product_id': productId,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (watcherIds != null) 'watcher_ids': watcherIds,
        if (expectedCloseDate != null) 'expected_close_date': expectedCloseDate,
        if (notes != null) 'notes': notes,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteOpportunity(String token, int id) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/opportunities/$id'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
  }

  // ─── Client Flow & Care Notes ─────────────────────────────────────────

  Future<Map<String, dynamic>> getClientFlow(
    String token,
    int clientId,
  ) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/clients/$clientId/flow'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> storeClientCareNote(
    String token,
    int clientId, {
    required String title,
    required String detail,
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/crm/clients/$clientId/care-notes'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'title': title, 'detail': detail}),
    );
    return res.statusCode == 201;
  }

  // ─── Lead Form Duplicate ──────────────────────────────────────────────

  Future<bool> duplicateLeadForm(String token, int id) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-forms/$id/duplicate'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 201;
  }

  // ─── Chatbot History ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getChatbotHistory(
    String token, {
    int perPage = 20,
    int? botId,
  }) async {
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
      if (botId != null && botId > 0) 'bot_id': '$botId',
    };
    final Uri uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/chatbot/history',
    ).replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class PaginatedResult<T> {
  PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.lastPage,
  });

  factory PaginatedResult.empty() {
    return PaginatedResult<T>(data: <T>[], currentPage: 1, lastPage: 1);
  }

  final List<T> data;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}
