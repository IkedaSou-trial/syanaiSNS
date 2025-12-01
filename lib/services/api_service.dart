import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // プラットフォーム（OS）に応じてベースURLを自動で切り替えます
  String get _baseUrl {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:3000"; // Androidエミュレータ
    } else if (Platform.isIOS) {
      return "http://localhost:3000"; // iOSシミュレータ
    } else {
      return "http://localhost:3000"; // Webやデスクトップなど
    }
  }

  final _storage = const FlutterSecureStorage();

  // ヘッダーを生成するヘルパー
  Future<Map<String, String>> _getHeaders({bool needsAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (needsAuth) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // --- 🆕 バーコードログイン API ---
  Future<bool> loginWithBarcode(String barcode) async {
    try {
      print('API呼び出し: バーコードログイン ($barcode)');
      await Future.delayed(const Duration(seconds: 1)); // 通信のフリ

      // 仮実装: ダミートークン保存
      const fakeToken = "dummy_jwt_token_for_development";
      await _storage.write(key: 'jwt_token', value: fakeToken);
      await _storage.write(key: 'current_user_name', value: "テスト店長");

      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // --- (旧) ID/PASSログイン API ---
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await _storage.write(key: 'jwt_token', value: token);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // --- 2. 投稿一覧の取得 API ---
  Future<List<dynamic>> getPosts({
    String? displayName,
    String? storeCode,
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    bool onlyFollowing = false,
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

  // --- 3. 投稿作成 API (旧シグネチャ互換用) ---
  // CreatePostScreenから呼ばれる可能性があるため残します
  Future<bool> createPost(
    String content, {
    String? title,
    String? base64Image,
  }) async {
    return false; // 使わない
  }

  // --- 3b. 投稿作成 API (画像ファイル送信対応) ---
  Future<bool> createPostWithFile(
    String content, {
    String? title,
    File? imageFile,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/posts'));
      final headers = await _getHeaders(needsAuth: true);
      request.headers.addAll(headers);

      request.fields['content'] = content;
      if (title != null) request.fields['title'] = title;

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

  // --- コメント削除 (PostDetailScreenで使用) ---
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

  // --- プロフィール関連 (ProfileScreenで使用) ---
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

  // --- プロフィール更新 (EditProfileScreenで使用) ---
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

  // --- アカウント作成 (SignUpScreenで使用) ---
  // ※店舗アカウント化に伴い不要ですが、エラー回避のために残します
  Future<bool> signup(
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
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- フォロー関連 (UserListScreen, ProfileScreenで使用) ---
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
}
