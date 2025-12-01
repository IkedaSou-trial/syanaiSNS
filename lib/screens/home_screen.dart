import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../utils/date_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<dynamic> _posts = [];
  List<dynamic> _followingPosts = []; // フォロー中用リスト
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshPosts();
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait([
      _apiService.getPosts(), // すべて
      _apiService.getPosts(onlyFollowing: true), // フォロー中のみ
    ]);

    if (mounted) {
      setState(() {
        _posts = results[0];
        _followingPosts = results[1];
        _isLoading = false;
      });
    }
  }

  // 「いいね」ボタンを押したときの処理
  Future<void> _toggleLike(String postId, bool isCurrentlyLiked) async {
    bool success;
    if (isCurrentlyLiked) {
      success = await _apiService.unlikePost(postId);
    } else {
      success = await _apiService.likePost(postId);
    }

    if (success && mounted) {
      setState(() {
        // 💡 修正: 両方のリストから該当の投稿を探して更新する (同期させるため)
        void updateList(List<dynamic> list) {
          final index = list.indexWhere((p) => p['id'] == postId);
          if (index != -1) {
            final post = list[index];
            post['isLikedByMe'] = !isCurrentlyLiked;
            post['likeCount'] =
                (post['likeCount'] ?? 0) + (isCurrentlyLiked ? -1 : 1);
          }
        }

        updateList(_posts);
        updateList(_followingPosts);
      });
    }
  }

  // 投稿削除処理
  Future<void> _deletePostProcess(String postId) async {
    // 確認ダイアログを表示
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
        _refreshPosts(); // 一覧を更新
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
        }
      }
    }
  }

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

  // 💡 共通のリスト表示ウィジェット (ここが重要)
  Widget _buildPostList(List<dynamic> targetPosts) {
    if (targetPosts.isEmpty) {
      return const Center(child: Text('投稿はありません'));
    }

    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: ListView.builder(
        itemCount: targetPosts.length,
        itemBuilder: (context, index) {
          final post = targetPosts[index];
          final author = post['author'];

          final likeCount = post['likeCount'] ?? 0;
          final isLikedByMe = post['isLikedByMe'] ?? false;
          final commentCount = post['commentCount'] ?? 0;
          final isMine = post['isMine'] ?? false;

          return InkWell(
            onTap: () {
              Navigator.of(context).pushNamed('/post_detail', arguments: post);
            },
            child: Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー (アイコン・名前・日付・削除)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: _getImageProvider(
                                author?['profileImageUrl'],
                              ),
                              child: author?['profileImageUrl'] == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final username = author?['username'];
                                    if (username != null) {
                                      Navigator.of(context).pushNamed(
                                        '/profile',
                                        arguments: username,
                                      );
                                    }
                                  },
                                  child: Text(
                                    author?['displayName'] ?? '不明なユーザー',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormatter.timeAgo(post['createdAt']),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isMine)
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => _deletePostProcess(post['id']),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 本文
                    Text(post['content'] ?? ''),

                    // 画像
                    if (post['imageUrl'] != null) ...[
                      const SizedBox(height: 8),
                      Image(
                        image: _getImageProvider(post['imageUrl'])!,
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                      ),
                    ],
                    const SizedBox(height: 8),

                    // アクションボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text('$commentCount'),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLikedByMe ? Colors.red : Colors.grey,
                          ),
                          onPressed: () => _toggleLike(post['id'], isLikedByMe),
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'すべての投稿'),
            Tab(text: 'フォロー中'),
          ],
        ),
      ),
      // 💡 TabBarView を使って2つのリストを切り替える
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(_posts), // 1ページ目
                _buildPostList(_followingPosts), // 2ページ目
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/create_post');
          if (result == true) _refreshPosts();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
