import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../utils/date_formatter.dart';
import '../widgets/post_skeleton.dart';

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
  bool _hasNewFollowing = false;

  Map<String, dynamic>? _currentUser;
  bool _isInit = true;

  // ▼▼▼ 追加: 自分の投稿を表示するかどうかのフラグ ▼▼▼
  bool _showMyPosts = false; // デフォルトはOFF（厳格なフィルター）

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        setState(() {
          _hasNewFollowing = false;
        });
        _apiService.saveLastReadTime('following');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        _currentUser = args;
        print("📲 引数からユーザー情報を取得しました");
      } else {
        print("⚠️ 引数がありません。APIからユーザー情報を取得します...");
      }
      _refreshPosts();
      _isInit = false;
    }
  }

  Future<void> _checkUnreadStatus(List<dynamic> posts) async {
    if (posts.isEmpty) return;
    final latestPostTimeStr = posts.first['createdAt'];
    if (latestPostTimeStr == null) return;

    final latestPostTime = DateTime.tryParse(latestPostTimeStr);
    if (latestPostTime == null) return;

    final lastReadTime = await _apiService.getLastReadTime('following');

    if (lastReadTime == null || latestPostTime.isAfter(lastReadTime)) {
      if (mounted) {
        setState(() {
          _hasNewFollowing = true;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    if (_currentUser == null) {
      final fullProfileData = await _apiService.fetchCurrentUser();
      if (fullProfileData != null && fullProfileData['user'] != null) {
        _currentUser = fullProfileData['user'];
        print("🔄 APIからユーザー情報を復元しました");
      }
    }

    final results = await Future.wait([
      _apiService.getPosts(),
      _apiService.getPosts(onlyFollowing: true),
    ]);

    List<dynamic> allPosts = results[0];

    // フィルター処理
    if (_currentUser != null) {
      final rawCategories = _currentUser!['interestedCategories'];

      if (rawCategories != null &&
          rawCategories is List &&
          rawCategories.isNotEmpty) {
        final List<String> myCategories = rawCategories
            .map((e) => e.toString())
            .toList();
        print("🔎 フィルター実行: $myCategories (自分の投稿を表示: $_showMyPosts)");

        allPosts = allPosts.where((post) {
          final String postCategory = post['category'] ?? 'その他';
          final bool isMine = post['isMine'] ?? false;

          // ▼▼▼ 修正: スイッチがONなら自分の投稿は無条件で表示 ▼▼▼
          if (_showMyPosts && isMine) return true;

          // それ以外はカテゴリーで判定
          return myCategories.contains(postCategory);
        }).toList();

        print("✅ フィルター完了: 残り${allPosts.length}件");
      }
    }

    if (mounted) {
      setState(() {
        _posts = allPosts;
        _followingPosts = results[1];
        _isLoading = false;
      });

      if (_tabController.index == 1) {
        _apiService.saveLastReadTime('following');
      } else {
        _checkUnreadStatus(_followingPosts);
      }
    }
  }

  // ... (省略: _deletePostProcess, _getImageProvider, _buildPostList は変更なし) ...
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
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => const PostSkeleton(),
      );
    }
    if (targetPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('表示する投稿がありません'),
            if (_currentUser != null &&
                (_currentUser!['interestedCategories'] as List? ?? [])
                    .isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '選択中のカテゴリー: ${_currentUser!['interestedCategories'].join(', ')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            if (!_showMyPosts)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  '(右上のスイッチで自分の投稿を表示できます)',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
          ],
        ),
      );
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
          final String category = post['category'] ?? 'その他';

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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post['content'] ?? '',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
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
        actions: [
          // ▼▼▼ 追加: カテゴリー変更ボタン ▼▼▼
          IconButton(
            icon: const Icon(Icons.tune), // 調節つまみアイコン
            tooltip: '表示カテゴリーを変更',
            onPressed: () async {
              // カテゴリー選択画面を開き、戻ってくるのを待つ
              final updatedUser = await Navigator.of(context).pushNamed(
                '/category_selection',
                arguments: _currentUser, // 今の設定を渡す
              );

              // もし更新されて帰ってきたら、画面を更新する
              if (updatedUser != null && updatedUser is Map<String, dynamic>) {
                setState(() {
                  _currentUser = updatedUser;
                });
                _refreshPosts(); // リストを再取得してフィルターし直す
              }
            },
          ),

          // ▼▼▼ 既存: 自分の投稿スイッチ ▼▼▼
          Row(
            children: [
              const Text(
                '自分の投稿',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Transform.scale(
                scale: 0.8, // スイッチを少し小さく
                child: Switch(
                  value: _showMyPosts,
                  activeColor: Colors.blue[800],
                  onChanged: (value) {
                    setState(() {
                      _showMyPosts = value;
                    });
                    _refreshPosts();
                  },
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[800],
          tabs: [
            const Tab(text: 'おすすめ'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('フォロー中'),
                  if (_hasNewFollowing) ...[
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
