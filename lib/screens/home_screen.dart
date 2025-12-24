import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/post_item.dart'; // 👈 作成したファイルをインポート

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<dynamic> _rawAllPosts = [];
  List<dynamic> _rawStorePosts = [];
  List<dynamic> _posts = [];
  List<dynamic> _storePosts = [];
  List<dynamic> _followingPosts = [];

  bool _isLoading = true;
  late TabController _tabController;
  bool _hasNewFollowing = false;
  Map<String, dynamic>? _currentUser;
  bool _isInit = true;
  bool _showMyPosts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 2) {
        setState(() => _hasNewFollowing = false);
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
        _apiService.getPosts(),
        _apiService.getPosts(filterType: 'store'),
        _apiService.getPosts(onlyFollowing: true),
      ]);

      if (mounted) {
        setState(() {
          _rawAllPosts = results[0];
          _rawStorePosts = results[1];
          _followingPosts = results[2];
          _isLoading = false;
        });

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

        if (isMine) return _showMyPosts;
        if (myCategories.contains(postCategory)) return true;
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
          // ▼▼▼ ここが変更点：分離したPostItemを使う ▼▼▼
          return PostItem(
            post: post,
            onPostUpdated: _fetchPosts, // 何かあったらリストを再取得
          );
          // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
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
          _buildPostList(_posts),
          _buildPostList(_storePosts),
          _buildPostList(_followingPosts),
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
