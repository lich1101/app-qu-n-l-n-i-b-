import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/app_env.dart';

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
    final http.Response res =
        await http.get(Uri.parse('${AppEnv.apiBaseUrl}/meta'));
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final http.Response res =
        await http.get(Uri.parse('${AppEnv.apiBaseUrl}/settings'));
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
      request.files.add(await http.MultipartFile.fromPath('logo', logoFile.path));
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

  Future<Map<String, dynamic>> getPublicSummary() async {
    final http.Response res =
        await http.get(Uri.parse('${AppEnv.apiBaseUrl}/public/summary'));
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPublicAccountsSummary() async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/public/accounts-summary'),
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

  Future<Map<String, dynamic>> me(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/me'),
      headers: _jsonHeaders(token),
    );
    return <String, dynamic>{
      'statusCode': res.statusCode,
      'body': res.statusCode == 200
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final http.Response res = await http.get(
      uri,
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> payload =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (payload['data'] ?? <dynamic>[]) as List<dynamic>;
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
        if (customerRequirement != null) 'customer_requirement': customerRequirement,
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
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
    };
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
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/contracts').replace(
      queryParameters: params,
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getUsersLookup(
    String token, {
    String search = '',
    String role = '',
  }) async {
    final Map<String, String> params = <String, String>{};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (role.trim().isNotEmpty) {
      params['role'] = role.trim();
    }
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/users/lookup').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createContract(
    String token, {
    String? code,
    required String title,
    required int clientId,
    int? projectId,
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
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      if (projectId != null) 'project_id': projectId,
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
    String? code,
    required String title,
    required int clientId,
    int? projectId,
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
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      if (projectId != null) 'project_id': projectId,
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
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/payments/$paymentId'),
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

  Future<bool> deleteContractPayment(String token, int contractId, int paymentId) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/contracts/$contractId/payments/$paymentId'),
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

  Future<bool> deleteContractCost(String token, int contractId, int costId) async {
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
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
    };
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (isActive.trim().isNotEmpty) {
      params['is_active'] = isActive.trim();
    }
    if (categoryId != null) {
      params['category_id'] = '$categoryId';
    }
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/products')
        .replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<bool> createProduct(
    String token, {
    String? code,
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
        if (code != null) 'code': code,
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
    String? code,
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
        if (code != null) 'code': code,
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
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
    };
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (isActive.trim().isNotEmpty) {
      params['is_active'] = isActive.trim();
    }
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/product-categories')
        .replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
    };
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/users/accounts')
        .replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
    };
    if (departmentId != null) {
      params['department_id'] = departmentId.toString();
    }
    if (status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/department-assignments')
        .replace(queryParameters: params);
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/reports/company').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final http.Response res = await http.get(
      uri,
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLeadForms(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/lead-forms?per_page=200'),
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    int? progressPercent,
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
        if (progressPercent != null) 'progress_percent': progressPercent,
      }),
    );
    return res.statusCode == 201;
  }

  Future<List<Map<String, dynamic>>> getTaskItems(
    String token,
    int taskId, {
    int perPage = 50,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/items')
        .replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
        if (deadline != null) 'deadline': deadline,
        if (assigneeId != null) 'assignee_id': assigneeId,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteTaskItem(
    String token,
    int taskId,
    int itemId,
  ) async {
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
    final Uri uri =
        Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates')
            .replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
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
        '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates');
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
      request.files.add(await http.MultipartFile.fromPath(
          'attachment', attachment.path));
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
          '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates/$updateId/approve'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );
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
          '${AppEnv.apiBaseUrl}/tasks/$taskId/items/$itemId/updates/$updateId/reject'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{'review_note': reviewNote}),
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
    final DateTime now = DateTime.now();
    final String stamp = '${now.year.toString().padLeft(4, '0')}-'
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
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/updates')
        .replace(queryParameters: <String, String>{'per_page': '$perPage'});
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
      request.files.add(await http.MultipartFile.fromPath('attachment', attachment.path));
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

  Future<Map<String, dynamic>> getActivityLogs(
    String token, {
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/activity-logs').replace(
      queryParameters: <String, String>{'per_page': '$perPage'},
    );
    final http.Response res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) {
      return <String, dynamic>{'statusCode': res.statusCode, 'data': <dynamic>[]};
    }
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final http.Response res = await http.get(
      uri,
      headers: _jsonHeaders(token),
    );
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
    final Map<String, String> params = <String, String>{
      'per_page': '$perPage',
    };
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (leadTypeId != null) {
      params['lead_type_id'] = leadTypeId.toString();
    }
    if (leadOnly) {
      params['lead_only'] = '1';
    }
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/crm/clients')
        .replace(queryParameters: params);
    final http.Response res = await http.get(
      uri,
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) return <Map<String, dynamic>>[];
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> getReportSummary(String token) async {
    final http.Response res = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/reports/dashboard-summary'),
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> rows = (body['data'] ?? <dynamic>[]) as List<dynamic>;
    return rows.map((dynamic e) => e as Map<String, dynamic>).toList();
  }

  Future<PaginatedResult<Map<String, dynamic>>> getTaskCommentsPage(
    String token,
    int taskId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final Uri uri = Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/comments').replace(
      queryParameters: <String, String>{
        'per_page': '$perPage',
        'page': '$page',
      },
    );
    final http.Response res = await http.get(
      uri,
      headers: _jsonHeaders(token),
    );
    if (res.statusCode != 200) {
      return PaginatedResult<Map<String, dynamic>>.empty();
    }
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<bool> deleteTaskComment(String token, int taskId, int commentId) async {
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
  }) async {
    final http.Response res = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/device-tokens'),
      headers: _jsonHeaders(token),
      body: jsonEncode(<String, dynamic>{
        'token': deviceToken,
        if (platform != null) 'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
      }),
    );
    return res.statusCode == 200;
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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
      Uri.parse(
        '${AppEnv.apiBaseUrl}/tasks/$taskId/attachments/$attachmentId',
      ),
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
    final Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<bool> deleteTaskReminder(String token, int taskId, int reminderId) async {
    final http.Response res = await http.delete(
      Uri.parse('${AppEnv.apiBaseUrl}/tasks/$taskId/reminders/$reminderId'),
      headers: _jsonHeaders(token),
    );
    return res.statusCode == 200;
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
