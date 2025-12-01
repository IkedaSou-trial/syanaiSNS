import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserListScreen extends StatefulWidget {
  final String username; // 誰の「フォロー中」を見るか
  final String title; // 画面タイトル (例: フォロー中)

  const UserListScreen({
    super.key,
    required this.username,
    required this.title,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    // 今回は「フォロー中」専用ですが、将来「フォロワー」も見たい場合はここで分岐可能です
    final users = await _apiService.getFollowingUsers(widget.username);

    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  // 画像ヘルパー (共通化推奨ですがここでも定義)
  ImageProvider? _getImageProvider(String? url) {
    if (url == null) return null;
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.split(',')[1];
        return MemoryImage(base64Decode(base64Str));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('ユーザーはいません'))
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: _getImageProvider(user['profileImageUrl']),
                    child: user['profileImageUrl'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user['displayName'] ?? 'No Name'),
                  subtitle: Text('@${user['username']}'),
                  onTap: () {
                    // プロフィールへ遷移
                    Navigator.of(
                      context,
                    ).pushNamed('/profile', arguments: user['username']);
                  },
                );
              },
            ),
    );
  }
}
