import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/post_image.dart';
import 'edit_post_screen.dart'; // 👈 追加: 編集画面のインポート

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  // 生データ（フィルター前）
  List<dynamic> _rawAllPosts = [];
  List<dynamic> _rawStorePosts = [];

  // 表示用データ（フィルター後）
  List<dynamic> _posts = [];
  List<dynamic> _storePosts = [];
  List<dynamic> _followingPosts = [];

  bool _isLoading = true;

  late TabController _tabController;
  bool _hasNewFollowing = false;

  Map<String, dynamic>? _currentUser;
  bool _isInit = true;

  // 自分の投稿を表示するかどうかのフラグ
  bool _showMyPosts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 2) {
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
      }
      _fetchPosts();
      _isInit = false;
    }
  }

  Future<void> _fetchPosts() async {
    if (_currentUser == null) {
      final fullProfileData = await _apiService.fetchCurrentUser();
      if (fullProfileData != null && fullProfileData['user'] != null) {
        _currentUser = fullProfileData['user'];
      }
    }

    try {
      final results = await Future.wait([
        _apiService.getPosts(), // 0: おすすめ
        _apiService.getPosts(filterType: 'store'), // 1: 店舗のみ
        _apiService.getPosts(onlyFollowing: true), // 2: フォロー中
      ]);

      if (mounted) {
        setState(() {
          _rawAllPosts = results[0];
          _rawStorePosts = results[1];
          _followingPosts = results[2];
          _isLoading = false;
        });

        // データを取得したらフィルター適用
        _applyFilter();

        if (_tabController.index == 2) {
          _apiService.saveLastReadTime('following');
        } else {
          _checkUnreadStatus(_followingPosts);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // フィルターロジック
  void _applyFilter() {
    List<dynamic> filterList(List<dynamic> sourceList) {
      if (_currentUser == null) return sourceList;

      final rawCategories = _currentUser!['interestedCategories'];
      final List<String> myCategories = (rawCategories is List)
          ? rawCategories.map((e) => e.toString()).toList()
          : [];

      return sourceList.where((post) {
        final String postCategory = post['category'] ?? 'その他';
        final bool isMine = post['isMine'] ?? false;

        // 1. 自分の投稿の場合
        if (isMine) {
          return _showMyPosts;
        }

        // 2. 他人の投稿の場合
        if (myCategories.contains(postCategory)) {
          return true;
        }

        return false;
      }).toList();
    }

    setState(() {
      _posts = filterList(_rawAllPosts);
      _storePosts = filterList(_rawStorePosts);
    });
  }

  Future<void> _checkUnreadStatus(List<dynamic> posts) async {
    if (posts.isEmpty) return;
    final latestPostTimeStr = posts.first['createdAt'];
    if (latestPostTimeStr == null) return;
    final latestPostTime = DateTime.tryParse(latestPostTimeStr);
    if (latestPostTime == null) return;

    final lastReadTime = await _apiService.getLastReadTime('following');

    if (lastReadTime == null || latestPostTime.isAfter(lastReadTime)) {
      if (mounted) setState(() => _hasNewFollowing = true);
    }
  }

  // リアクション切り替え処理
  Future<void> _toggleReaction(String postId, String type) async {
    void updateList(List<dynamic> list) {
      final index = list.indexWhere((p) => p['id'] == postId);
      if (index != -1) {
        final post = list[index];
        final bool isLiked = post['isLikedByMe'] ?? false;
        final bool isCopied = post['isCopiedByMe'] ?? false;

        if (type == 'LIKE') {
          post['isLikedByMe'] = !isLiked;
          post['likeCount'] = (post['likeCount'] ?? 0) + (!isLiked ? 1 : -1);
        } else if (type == 'COPY') {
          post['isCopiedByMe'] = !isCopied;
          post['copyCount'] = (post['copyCount'] ?? 0) + (!isCopied ? 1 : -1);
        }
      }
    }

    setState(() {
      updateList(_rawAllPosts);
      updateList(_rawStorePosts);
      updateList(_followingPosts);
      _applyFilter();
    });

    final success = await _apiService.toggleReaction(postId, type);

    if (!success && mounted) {
      _fetchPosts();
    }
  }

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
        _fetchPosts();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
        }
      }
    }
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
      onRefresh: _fetchPosts,
      child: ListView.builder(
        itemCount: targetPosts.length,
        itemBuilder: (context, index) {
          final post = targetPosts[index];
          return _buildPostItem(post);
        },
      ),
    );
  }

  // 個別の投稿カード
  Widget _buildPostItem(Map<String, dynamic> post) {
    final author = post['author'];
    final bool isMine = post['isMine'] ?? false;
    final String category = post['category'] ?? 'その他';

    // リアクション情報
    final bool isLiked = post['isLikedByMe'] ?? false;
    final int likeCount = post['likeCount'] ?? 0;
    final bool isCopied = post['isCopiedByMe'] ?? false;
    final int copyCount = post['copyCount'] ?? 0;

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed('/post_detail', arguments: post);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ヘッダー ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      final username = author?['username'];
                      if (username != null) {
                        Navigator.of(
                          context,
                        ).pushNamed('/profile', arguments: username);
                      }
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: ClipOval(
                            child: author?['profileImageUrl'] != null
                                ? PostImage(
                                    imageUrl: author!['profileImageUrl'],
                                    height: 40,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.person,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author?['displayName'] ?? '不明なユーザー',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      // ▼▼▼ 修正: 自分の投稿なら編集/削除メニューを表示 ▼▼▼
                      if (isMine)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.grey,
                          ),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              // 編集画面へ遷移
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditPostScreen(post: post),
                                ),
                              );
                              // 編集から戻ってきたらリストを更新
                              if (result == true) {
                                _fetchPosts();
                              }
                            } else if (value == 'delete') {
                              // 削除処理
                              _deletePostProcess(post['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('編集する'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('削除する'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      // ▲▲▲ 修正ここまで ▲▲▲
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // --- 本文 ---
              HashtagText(
                text: post['content'] ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.black,
                ),
                onTagTap: (tag) {
                  Navigator.of(
                    context,
                  ).pushNamed('/search', arguments: {'tag': tag});
                },
              ),

              // --- 画像 ---
              if (post['imageUrl'] != null) ...[
                const SizedBox(height: 12),
                Hero(
                  tag: post['id'],
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PostImage(imageUrl: post['imageUrl'], height: 250),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // --- リアクションボタンエリア ---
              Row(
                children: [
                  // 1. いいねボタン
                  _ReactionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    count: likeCount,
                    label: 'いいね',
                    onTap: () => _toggleReaction(post['id'], 'LIKE'),
                  ),

                  const SizedBox(width: 24),
                  // 2. 真似したいボタン
                  _ReactionButton(
                    icon: isCopied ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: isCopied ? Colors.orange : Colors.grey,
                    count: copyCount,
                    label: '真似したい',
                    onTap: () => _toggleReaction(post['id'], 'COPY'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () async {
              final args = Map<String, dynamic>.from(_currentUser!);
              args['isEditing'] = true;
              final updatedUser = await Navigator.of(
                context,
              ).pushNamed('/category_selection', arguments: args);

              if (updatedUser != null && updatedUser is Map<String, dynamic>) {
                setState(() => _currentUser = updatedUser);
                _applyFilter();
              }
            },
          ),
          Row(
            children: [
              const Text(
                '自分の投稿',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _showMyPosts,
                  activeColor: Colors.blue[800],
                  onChanged: (value) {
                    setState(() {
                      _showMyPosts = value;
                      _applyFilter();
                    });
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
            const Tab(text: '店舗'),
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
        children: [
          _buildPostList(_posts), // 0: おすすめ
          _buildPostList(_storePosts), // 1: 店舗
          _buildPostList(_followingPosts), // 2: フォロー中
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[800],
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/create_post');
          if (result == true) _fetchPosts();
        },
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

// リアクションボタン
class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
