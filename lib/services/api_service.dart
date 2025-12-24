import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // ▼▼▼ 変更: static const にして、外部から ApiService.baseUrl で呼べるようにしました ▼▼▼
  // ※ ngrokを再起動した場合は、ここを新しいURLに書き換えてください
  static const String baseUrl = "https://toragram-api.onrender.com";

  final _storage = const FlutterSecureStorage();

  // ヘッダー取得
  Future<Map<String, String>> _getHeaders({bool needsAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true', // ngrok対策
    };

    if (needsAuth) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // --- 投稿作成 ---
  Future<bool> createPost(
    String content,
    String? imageBase64, {
    String? title,
    String category = 'その他',
    String postType = 'INDIVIDUAL',
  }) async {
    try {
      final body = {
        'content': content,
        'category': category,
        'postType': postType,
        if (title != null) 'title': title,
        if (imageBase64 != null) 'imageBase64': imageBase64,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/posts'), // $_baseUrl ではなく $baseUrl を使用
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode(body),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('投稿作成エラー: $e');
      return false;
    }
  }

  // --- ユーザー存在確認 ---
  Future<Map<String, dynamic>?> checkUserExists(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/check-user'),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- 新規登録 ---
  Future<Map<String, dynamic>?> signup(
    String username,
    String password,
    String displayName,
    String storeCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
          'storeCode': storeCode,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null)
          await _storage.write(key: 'jwt_token', value: data['token']);
        if (data['user']?['username'] != null)
          await _storage.write(
            key: 'current_username',
            value: data['user']['username'],
          );
        return data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- 手動ログイン ---
  Future<Map<String, dynamic>?> loginManual(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null)
          await _storage.write(key: 'jwt_token', value: data['token']);
        if (data['user']?['username'] != null)
          await _storage.write(
            key: 'current_username',
            value: data['user']['username'],
          );
        return data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- プロフィール取得 ---
  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      final username = await _storage.read(key: 'current_username');
      if (username == null) return null;
      return await getUserProfile(username);
    } catch (e) {
      return null;
    }
  }

  // --- 投稿一覧取得 ---
  Future<List<dynamic>> getPosts({
    String? displayName,
    String? storeCode,
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    bool onlyFollowing = false,
    String? category,
    String? filterType,
    String? tag,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (displayName != null) queryParams['displayName'] = displayName;
      if (storeCode != null) queryParams['storeCode'] = storeCode;
      if (keyword != null) queryParams['keyword'] = keyword;
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null)
        queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
      if (onlyFollowing) queryParams['onlyFollowing'] = 'true';
      if (category != null) queryParams['category'] = category;
      if (filterType != null) queryParams['filterType'] = filterType;
      if (tag != null) queryParams['tag'] = tag;

      final uri = Uri.parse(
        '$baseUrl/posts',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(needsAuth: true),
      );

      if (response.statusCode == 200)
        return jsonDecode(response.body) as List<dynamic>;
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- ログアウト ---
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'current_user_name');
  }

  // --- リアクション (いいね / 真似したい) ---
  // type: 'LIKE' または 'COPY'
  Future<bool> toggleReaction(String postId, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/reaction'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({'type': type}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- 投稿削除 ---
  Future<bool> deletePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- ユーザープロフィール取得 ---
  Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$username'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- プロフィール更新 ---
  Future<bool> updateProfile(
    String displayName,
    String? base64Image,
    String storeCode,
  ) async {
    try {
      final body = {
        'displayName': displayName,
        if (base64Image != null) 'profileImageBase64': base64Image,
        'storeCode': storeCode,
      };
      final response = await http.put(
        Uri.parse('$baseUrl/users/me'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- フォロー ---
  Future<bool> followUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- フォロー解除 ---
  Future<bool> unfollowUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- フォローリスト ---
  Future<List<dynamic>> getFollowingUsers(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$username/following'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body) as List<dynamic>;
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- ランキング ---
  Future<List<dynamic>> getRanking(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/ranking?type=$type'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body) as List<dynamic>;
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 未読管理 ---
  Future<void> saveLastReadTime(String key) async {
    await _storage.write(
      key: 'last_read_$key',
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastReadTime(String key) async {
    final timeStr = await _storage.read(key: 'last_read_$key');
    if (timeStr != null) return DateTime.tryParse(timeStr);
    return null;
  }

  // --- カテゴリー更新 ---
  Future<bool> updateCategories(String userId, List<String> categories) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/categories'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({'categories': categories}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- 店舗リスト取得 ---
  Future<List<dynamic>> getStores() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stores'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get stores error: $e');
      return [];
    }
  }

  // 店舗ランキング取得
  Future<List<dynamic>> getStoreRanking() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ranking/stores'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 店舗内ユーザーランキング取得
  Future<List<dynamic>> getStoreUserRanking(String storeCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ranking/stores/$storeCode/users'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- 投稿編集 ---
  Future<bool> updatePost(String postId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update post error: $e');
      return false;
    }
  }

  // --- 真似したいリスト取得 ---
  Future<List<dynamic>> getCopiedPosts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me/copied'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
