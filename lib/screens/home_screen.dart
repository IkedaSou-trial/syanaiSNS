import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart'; // 💡 追加
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
  List<dynamic> _followingPosts = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshPosts();
  }

  Future<void> _refreshPosts() async {
    // 引っ張って更新の時はローディングを出さない方が自然ですが、
    // 初回ロード時は出すように制御しても良いです。今回は簡易的にそのまま。
    final results = await Future.wait([
      _apiService.getPosts(),
      _apiService.getPosts(onlyFollowing: true),
    ]);

    if (mounted) {
      setState(() {
        _posts = results[0];
        _followingPosts = results[1];
        _isLoading = false;
      });
    }
  }

  // 💡 投稿削除処理
  Future<void> _deletePostProcess(String postId) async {
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
        _refreshPosts();
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

  Widget _buildPostList(List<dynamic> targetPosts) {
    if (_isLoading && targetPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
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

          final int likeCount = post['likeCount'] ?? 0;
          final bool isLikedByMe = post['isLikedByMe'] ?? false;
          final int commentCount = post['commentCount'] ?? 0;
          final bool isMine = post['isMine'] ?? false;

          return InkWell(
            onTap: () {
              Navigator.of(context).pushNamed('/post_detail', arguments: post);
            },
            child: Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              elevation: 2, // 💡 少し影をつけてリッチに
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // 💡 角丸を少し大きく
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: _getImageProvider(
                                author?['profileImageUrl'],
                              ),
                              backgroundColor: Colors.grey[200],
                              child: author?['profileImageUrl'] == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
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
                                      fontSize: 15,
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
                              Icons.more_horiz, // 💡 メニューっぽいアイコンに変更
                              color: Colors.grey,
                            ),
                            onPressed: () => _deletePostProcess(post['id']),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 本文
                    Text(
                      post['content'] ?? '',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),

                    // 画像
                    if (post['imageUrl'] != null) ...[
                      const SizedBox(height: 12),
                      Hero(
                        tag: post['id'],
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: _getImageProvider(post['imageUrl'])!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            // 高さを固定せず、アスペクト比で表示するとより現代的ですが、今回は固定で
                            height: 250,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // アクションボタンエリア
                    Row(
                      children: [
                        // 💡 いいねボタン (アニメーション付き)
                        LikeButton(
                          size: 24,
                          isLiked: isLikedByMe,
                          likeCount: likeCount,
                          countBuilder:
                              (int? count, bool isLiked, String text) {
                                return Text(
                                  text,
                                  style: TextStyle(
                                    color: isLiked ? Colors.red : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                          // サーバーへのリクエスト処理
                          onTap: (bool isLiked) async {
                            bool success;
                            if (isLiked) {
                              success = await _apiService.unlikePost(
                                post['id'],
                              );
                            } else {
                              success = await _apiService.likePost(post['id']);
                            }
                            // API通信が成功したら、新しい状態(!isLiked)を返す
                            return success ? !isLiked : isLiked;
                          },
                        ),

                        const SizedBox(width: 24),

                        // コメントアイコン
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 22,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$commentCount',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
      backgroundColor: Colors.grey[50], // 💡 背景を少しグレーにしてカードを目立たせる
      appBar: AppBar(
        title: const Text(
          'タイムライン',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false, // 左寄せでSNSっぽく
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[800],
          tabs: const [
            Tab(text: 'おすすめ'),
            Tab(text: 'フォロー中'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPostList(_posts), _buildPostList(_followingPosts)],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[800],
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/create_post');
          if (result == true) _refreshPosts();
        },
        child: const Icon(Icons.edit, color: Colors.white), // 💡 ペンアイコンに変更
      ),
    );
  }
}
