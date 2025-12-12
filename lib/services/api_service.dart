import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  String get _baseUrl {
    // 👇 RenderのURL
    const String productionUrl =
        "https://unferreted-campbell-hypermetaphorical.ngrok-free.dev";
    return productionUrl;
  }

  String get baseUrl => _baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders({bool needsAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (needsAuth) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // --- 🆕 バーコードログイン ---
  Future<Map<String, dynamic>?> loginWithBarcode(String barcode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login/barcode'),
        headers: await _getHeaders(),
        body: jsonEncode({'barcode': barcode}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['status'] == 'success') {
          await _storage.write(key: 'jwt_token', value: data['token']);
          // ▼▼▼ 追加: ユーザー名を保存 ▼▼▼
          if (data['user'] != null && data['user']['username'] != null) {
            await _storage.write(
              key: 'current_username',
              value: data['user']['username'],
            );
          }
          return {'status': 'success', 'user': data['user']};
        } else if (data['status'] == 'unregistered') {
          return {'status': 'unregistered', 'userData': data['userData']};
        }
      }
      return {'status': 'error', 'message': data['error'] ?? 'エラーが発生しました'};
    } catch (e) {
      return {'status': 'error', 'message': '通信エラー: $e'};
    }
  }

  // --- 🆕 手動ログイン ---
  Future<Map<String, dynamic>?> loginManual(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        // ▼▼▼ 追加: ユーザー名を保存 ▼▼▼
        if (data['user'] != null && data['user']['username'] != null) {
          await _storage.write(
            key: 'current_username',
            value: data['user']['username'],
          );
        }
        return data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- ▼▼▼ 新規追加: 保存されたユーザー名からプロフィールを取得する ▼▼▼ ---
  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      // 保存しておいたユーザー名を読み込む
      final username = await _storage.read(key: 'current_username');
      if (username == null) return null;

      // プロフィール取得APIを呼ぶ
      return await getUserProfile(username);
    } catch (e) {
      print('Fetch current user error: $e');
      return null;
    }
  }

  // --- 🆕 新規登録 ---
  Future<Map<String, dynamic>?> signup(
    String username,
    String password,
    String displayName,
    String storeCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup'),
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
        await _storage.write(key: 'jwt_token', value: data['token']);
        return data['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- 3. 投稿作成 API (画像付き対応版) ---
  Future<bool> createPostWithFile(
    String content, {
    String? title,
    File? imageFile,
    String category = 'その他',
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/posts'));
      final headers = await _getHeaders(needsAuth: true);
      request.headers.addAll(headers);

      request.fields['content'] = content;
      if (title != null) request.fields['title'] = title;
      request.fields['category'] = category;

      if (imageFile != null) {
        var stream = http.ByteStream(imageFile.openRead());
        var length = await imageFile.length();
        var multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: imageFile.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      var response = await request.send();
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- 1. 投稿一覧の取得 API ---
  Future<List<dynamic>> getPosts({
    String? displayName,
    String? storeCode,
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    bool onlyFollowing = false,
    String? category,
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

      final uri = Uri.parse(
        '$_baseUrl/posts',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await _getHeaders(needsAuth: true),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // --- 4. コメント一覧の取得 API ---
  Future<List<dynamic>> getComments(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/posts/$postId/comments'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // --- 5. コメントの作成 API ---
  Future<bool> createComment(String postId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/posts/$postId/comments'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode({'content': content}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- コメント削除 ---
  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/posts/$postId/comments/$commentId'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- ログアウト ---
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'current_user_name');
  }

  // --- いいね関連 ---
  Future<bool> likePost(String postId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/posts/$postId/like'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unlikePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/posts/$postId/like'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/posts/$postId'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- プロフィール関連 ---
  Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$username'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return null;
      }
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
        Uri.parse('$_baseUrl/users/me'),
        headers: await _getHeaders(needsAuth: true),
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- フォロー関連 ---
  Future<bool> followUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$userId/follow'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unfollowUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/$userId/follow'),
        headers: await _getHeaders(needsAuth: true),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getFollowingUsers(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$username/following'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // --- ランキング取得 API ---
  Future<List<dynamic>> getRanking(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/posts/ranking?type=$type'),
        headers: await _getHeaders(needsAuth: true),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // --- 未読管理用のメソッド ---
  Future<void> saveLastReadTime(String key) async {
    final now = DateTime.now().toIso8601String();
    await _storage.write(key: 'last_read_$key', value: now);
  }

  Future<DateTime?> getLastReadTime(String key) async {
    final timeStr = await _storage.read(key: 'last_read_$key');
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }

  // --- カテゴリー更新 ---
  Future<bool> updateCategories(String userId, List<String> categories) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'categories': categories}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Category update failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Category update error: $e');
      return false;
    }
  }
}
