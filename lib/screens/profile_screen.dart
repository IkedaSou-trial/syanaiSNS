import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import '../utils/date_formatter.dart';
import 'user_list_screen.dart';
import '../widgets/post_image.dart';
import 'edit_post_screen.dart';
import 'copied_posts_screen.dart'; // 👈 追加

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

  Future<void> _fetchProfile() async {
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

  Future<void> _deletePost(String postId) async {
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
      final success = await _apiService.deletePost(postId);
      if (success) {
        setState(() {
          _userPosts.removeWhere((post) => post['id'] == postId);
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

  Future<void> _toggleReaction(String postId, String type) async {
    final index = _userPosts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    final post = _userPosts[index];
    final bool isLiked = post['isLikedByMe'] ?? false;
    final bool isCopied = post['isCopiedByMe'] ?? false;

    setState(() {
      if (type == 'LIKE') {
        post['isLikedByMe'] = !isLiked;
        post['likeCount'] = (post['likeCount'] ?? 0) + (!isLiked ? 1 : -1);
      } else if (type == 'COPY') {
        post['isCopiedByMe'] = !isCopied;
        post['copyCount'] = (post['copyCount'] ?? 0) + (!isCopied ? 1 : -1);
      }
    });

    final success = await _apiService.toggleReaction(postId, type);
    if (!success && mounted) {
      setState(() {
        if (type == 'LIKE') {
          post['isLikedByMe'] = isLiked;
          post['likeCount'] = (post['likeCount'] ?? 0) + (isLiked ? 1 : -1);
        } else if (type == 'COPY') {
          post['isCopiedByMe'] = isCopied;
          post['copyCount'] = (post['copyCount'] ?? 0) + (isCopied ? 1 : -1);
        }
      });
    }
  }

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
        _userData!['isFollowing'] = !isFollowing;
        int currentFollowers = _userData!['followerCount'] ?? 0;
        _userData!['followerCount'] = currentFollowers + (isFollowing ? -1 : 1);
      });
    }
  }

  Future<void> _handleLogout() async {
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

  Widget _buildCountColumn(String label, int count, {VoidCallback? onTap}) {
    return InkWell(
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
        title: Text(
          isMe ? 'マイページ' : (_userData!['displayName'] ?? 'プロフィール'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfileScreen(currentUser: _userData!),
                  ),
                );
                if (result == true) _fetchProfile();
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // --- ユーザー情報 ---
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipOval(
                        child: _userData!['profileImageUrl'] != null
                            ? PostImage(
                                imageUrl: _userData!['profileImageUrl'],
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
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

                    // ▼▼▼ 追加: 自分の場合だけ「真似したいリスト」ボタンを表示 ▼▼▼
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CopiedPostsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.lightbulb,
                            color: Colors.orange,
                          ),
                          label: const Text('真似したいリストを見る'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ),

                    // ▲▲▲▲▲▲
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

              // --- 投稿一覧 ---
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
                        final isMine = post['isMine'] ?? false;
                        final isLikedByMe = post['isLikedByMe'] ?? false;
                        final int likeCount = post['likeCount'] ?? 0;
                        final bool isCopiedByMe = post['isCopiedByMe'] ?? false;
                        final int copyCount = post['copyCount'] ?? 0;

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
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          color: Colors.grey,
                                        ),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            final result =
                                                await Navigator.of(
                                                  context,
                                                ).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditPostScreen(
                                                          post: post,
                                                        ),
                                                  ),
                                                );
                                            if (result == true) _fetchProfile();
                                          } else if (value == 'delete') {
                                            _deletePost(post['id']);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 8),
                                                Text('編集する'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text('削除する'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  post['content'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (post['imageUrl'] != null) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: PostImage(
                                      imageUrl: post['imageUrl'],
                                      fit: BoxFit.cover,
                                      height: 150,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          Navigator.of(context).pushNamed(
                                            '/post_detail',
                                            arguments: post,
                                          ),
                                      child: const Text(
                                        '詳細',
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: Icon(
                                        isCopiedByMe
                                            ? Icons.lightbulb
                                            : Icons.lightbulb_outline,
                                        color: isCopiedByMe
                                            ? Colors.orange
                                            : Colors.grey,
                                      ),
                                      onPressed: () =>
                                          _toggleReaction(post['id'], 'COPY'),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('$copyCount'),
                                    const SizedBox(width: 16),
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
                                          _toggleReaction(post['id'], 'LIKE'),
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
      ),
    );
  }
}
