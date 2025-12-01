import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'edit_profile_screen.dart';
import '../utils/date_formatter.dart';
import 'user_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<dynamic> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // プロフィールと投稿を取得
  Future<void> _fetchProfile() async {
    // リフレッシュ時は画面全体をローディングにしない（リストだけ更新したい場合もあるため）
    // ここではシンプルに毎回ローディングを出します
    final data = await _apiService.getUserProfile(widget.username);

    if (mounted) {
      setState(() {
        if (data != null) {
          _userData = data['user'];
          _userPosts = data['posts'];
        }
        _isLoading = false;
      });
    }
  }

  // 💡 追加: 投稿削除メソッド
  Future<void> _deletePost(String postId) async {
    // 確認ダイアログ
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('削除の確認'),
          content: const Text('本当にこの投稿を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      // API呼び出し
      final success = await _apiService.deletePost(postId);
      if (success) {
        // 成功したらリストから削除して再描画（再度APIを呼ばなくても消せる）
        setState(() {
          _userPosts.removeWhere((post) => post['id'] == postId);
          // 投稿数も減らす
          if (_userData != null) {
            _userData!['postCount'] = (_userData!['postCount'] ?? 1) - 1;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
        }
      }
    }
  }

  // 💡 追加: 画像表示用ヘルパー (HomeScreenと同じ)
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

  // 💡 追加: いいね切り替えメソッド (HomeScreenと同じロジック)
  Future<void> _toggleLike(String postId, bool isCurrentlyLiked) async {
    bool success;
    if (isCurrentlyLiked) {
      success = await _apiService.unlikePost(postId);
    } else {
      success = await _apiService.likePost(postId);
    }

    if (success) {
      setState(() {
        final index = _userPosts.indexWhere((p) => p['id'] == postId);
        if (index != -1) {
          final post = _userPosts[index];
          post['isLikedByMe'] = !isCurrentlyLiked;
          post['likeCount'] =
              (post['likeCount'] ?? 0) + (isCurrentlyLiked ? -1 : 1);
        }
      });
    }
  }

  // 💡 追加: フォロー/アンフォローメソッド
  Future<void> _toggleFollow() async {
    if (_userData == null) return;

    final targetUserId = _userData!['id'];
    final isFollowing = _userData!['isFollowing'] ?? false;

    bool success;
    if (isFollowing) {
      success = await _apiService.unfollowUser(targetUserId);
    } else {
      success = await _apiService.followUser(targetUserId);
    }

    if (success) {
      setState(() {
        // フォロー状態を反転
        _userData!['isFollowing'] = !isFollowing;
        // フォロワー数を増減
        int currentFollowers = _userData!['followerCount'] ?? 0;
        _userData!['followerCount'] = currentFollowers + (isFollowing ? -1 : 1);
      });
    }
  }

  Widget _buildCountColumn(String label, int count, {VoidCallback? onTap}) {
    return InkWell(
      // 💡 タップ可能にする
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // 確認ダイアログを出すと親切です
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text('ログアウトしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ログアウト', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _apiService.logout();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userData == null) {
      return const Scaffold(body: Center(child: Text('ユーザーが見つかりませんでした')));
    }

    final isMe = _userData!['isMe'] ?? false;
    final isFollowing = _userData!['isFollowing'] ?? false;
    final followerCount = _userData!['followerCount'] ?? 0;
    final followingCount = _userData!['followingCount'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_userData!['displayName'] ?? 'プロフィール'),
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      currentDisplayName: _userData!['displayName'],
                      currentImageUrl: _userData!['profileImageUrl'],
                      currentStoreCode: _userData!['storeCode'] ?? 'A101',
                    ),
                  ),
                );
                if (result == true) {
                  _fetchProfile();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. ユーザー情報ヘッダー (変更なし) ---
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _getImageProvider(
                      _userData!['profileImageUrl'],
                    ),
                    child: _userData!['profileImageUrl'] == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userData!['displayName'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@${_userData!['username']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Chip(label: Text('店舗: ${_userData!['storeCode']}')),
                  const SizedBox(height: 10),
                  Text(
                    '投稿数: ${_userData!['postCount']}件',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // 💡 フォロー・フォロワー数の表示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCountColumn(
                        "フォロー中",
                        followingCount,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserListScreen(
                                username: _userData!['username'],
                                title: 'フォロー中',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      _buildCountColumn("フォロワー", followerCount),
                      const SizedBox(width: 20),
                      _buildCountColumn("投稿", _userData!['postCount']),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // 💡 自分以外なら「フォローボタン」を表示
                  if (!isMe)
                    ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? Colors.grey
                            : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isFollowing ? 'フォロー解除' : 'フォローする'),
                    ),
                ],
              ),
            ),
            const Divider(),
            // --- 2. ユーザーの投稿一覧 (デザイン修正と削除ボタン追加) ---
            _userPosts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('投稿はまだありません'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userPosts.length,
                    itemBuilder: (context, index) {
                      final post = _userPosts[index];
                      // 💡 バックエンド user.controller.ts が isMine を返している前提
                      final isMine = post['isMine'] ?? false;

                      // 💡 各種データを取得
                      final likeCount = post['likeCount'] ?? 0;
                      final commentCount = post['commentCount'] ?? 0;
                      final isLikedByMe = post['isLikedByMe'] ?? false;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ヘッダー行 (日付と削除ボタン)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormatter.timeAgo(post['createdAt']),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isMine)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _deletePost(post['id']),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // 本文
                              Text(
                                post['content'],
                                style: const TextStyle(fontSize: 16),
                              ),

                              // 💡 画像があれば表示
                              if (post['imageUrl'] != null) ...[
                                const SizedBox(height: 8),
                                Image(
                                  image: _getImageProvider(post['imageUrl'])!,
                                  fit: BoxFit.cover,
                                  height: 150,
                                  width: double.infinity,
                                ),
                              ],

                              const SizedBox(height: 10),

                              // 💡 アクションエリア (詳細リンク、コメント数、いいね数)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 詳細へ飛ぶ
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).pushNamed(
                                        '/post_detail',
                                        arguments: post,
                                      );
                                    },
                                    child: const Text(
                                      '詳細',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // コメントアイコンと数
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$commentCount'),

                                  const SizedBox(width: 16),

                                  // いいねボタンと数
                                  IconButton(
                                    icon: Icon(
                                      isLikedByMe
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isLikedByMe
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                    onPressed: () =>
                                        _toggleLike(post['id'], isLikedByMe),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$likeCount'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
