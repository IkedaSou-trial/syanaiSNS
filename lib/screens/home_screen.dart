import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';
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

  // バッジフラグ (初期値は false に変更)
  bool _hasNewFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      // 「フォロー中」タブ（インデックス1）が選ばれたら
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        setState(() {
          _hasNewFollowing = false; // バッジを消す
        });
        // 💡 修正: 見た時間を保存する
        _apiService.saveLastReadTime('following');
      }
    });

    _refreshPosts();
  }

  // 💡 追加: 未読チェックロジック
  Future<void> _checkUnreadStatus(List<dynamic> posts) async {
    if (posts.isEmpty) return;

    // 最新の投稿の日時を取得
    final latestPostTimeStr = posts.first['createdAt']; // リストは降順なので先頭が最新
    if (latestPostTimeStr == null) return;

    final latestPostTime = DateTime.tryParse(latestPostTimeStr);
    if (latestPostTime == null) return;

    // 保存されている「最後に見た時間」を取得
    final lastReadTime = await _apiService.getLastReadTime('following');

    // 「最後に見た時間がない（初回）」または「最新投稿の方が新しい」場合にバッジをつける
    if (lastReadTime == null || latestPostTime.isAfter(lastReadTime)) {
      if (mounted) {
        setState(() {
          _hasNewFollowing = true;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    // ローディング中もバッジの状態は維持したいので、ここではフラグをリセットしない

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

      // 💡 修正: データの取得が終わったら、未読チェックを行う
      // もし現在「フォロー中タブ」を開いているなら、チェックせずに既読にする
      if (_tabController.index == 1) {
        _apiService.saveLastReadTime('following');
      } else {
        _checkUnreadStatus(_followingPosts);
      }
    }
  }

  // 投稿削除処理
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                              Icons.more_horiz,
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
                            height: 250,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // アクションボタンエリア
                    Row(
                      children: [
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
                          onTap: (bool isLiked) async {
                            bool success;
                            if (isLiked) {
                              success = await _apiService.unlikePost(
                                post['id'],
                              );
                            } else {
                              success = await _apiService.likePost(post['id']);
                            }
                            return success ? !isLiked : isLiked;
                          },
                        ),

                        const SizedBox(width: 24),

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'タイムライン',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[800],
          tabs: [
            const Tab(text: 'おすすめ'),
            // 💡 修正3: 変数を使ってバッジの表示/非表示を切り替える
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('フォロー中'),
                  if (_hasNewFollowing) ...[
                    // 変数がtrueの時だけ表示
                    const SizedBox(width: 8),
                    const Badge(smallSize: 8, backgroundColor: Colors.red),
                  ],
                ],
              ),
            ),
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
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}
