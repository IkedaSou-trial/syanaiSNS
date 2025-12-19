import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/post_image.dart';

// ---------------------------------------------------------
// 1. ランキング画面全体
// ---------------------------------------------------------
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ランキング',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF1A237E),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1A237E),
            tabs: [
              Tab(text: '店舗ランキング'),
              Tab(text: '人気投稿'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [StoreRankingView(), PostRankingView()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 2. 店舗ランキング表示
// ---------------------------------------------------------
class StoreRankingView extends StatefulWidget {
  const StoreRankingView({super.key});

  @override
  State<StoreRankingView> createState() => _StoreRankingViewState();
}

class _StoreRankingViewState extends State<StoreRankingView> {
  final ApiService _apiService = ApiService();
  List<dynamic> _storeRanking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    try {
      final data = await _apiService.getStoreRanking();
      if (mounted) {
        setState(() {
          _storeRanking = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StoreUserRankingModal(store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_storeRanking.isEmpty) {
      return const EmptyState(
        title: 'データがありません',
        message: '店舗データが見つかりませんでした',
        icon: Icons.store_mall_directory,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRanking,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _storeRanking.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final store = _storeRanking[index];
          final int rank = index + 1;
          final int followers = store['totalFollowers'] ?? 0;

          Widget rankIcon;
          if (rank == 1) {
            rankIcon = const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 32,
            );
          } else if (rank == 2) {
            rankIcon = const Icon(
              Icons.emoji_events,
              color: Colors.grey,
              size: 28,
            );
          } else if (rank == 3) {
            rankIcon = const Icon(
              Icons.emoji_events,
              color: Colors.brown,
              size: 28,
            );
          } else {
            rankIcon = Text(
              '$rank',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            );
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            leading: SizedBox(width: 40, child: Center(child: rankIcon)),
            title: Text(
              store['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '店舗コード: ${store['code']} / メンバー: ${store['memberCount']}人',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '総フォロワー',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  '$followers',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            onTap: () => _showStoreDetails(store),
          );
        },
      ),
    );
  }
}

class _StoreUserRankingModal extends StatefulWidget {
  final Map<String, dynamic> store;
  const _StoreUserRankingModal({required this.store});

  @override
  State<_StoreUserRankingModal> createState() => _StoreUserRankingModalState();
}

class _StoreUserRankingModalState extends State<_StoreUserRankingModal> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await _apiService.getStoreUserRanking(widget.store['code']);
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            '${widget.store['name']} のメンバー',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? const Center(child: Text('ユーザーがいません'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final rank = index + 1;

                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ClipOval(
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: user['profileImageUrl'] != null
                                    ? PostImage(
                                        imageUrl: user['profileImageUrl'],
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(user['displayName']),
                        trailing: Text(
                          '${user['followerCount']} フォロワー',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed('/profile', arguments: user['username']);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. 人気投稿ランキング (修正版: レイアウト崩れ防止)
// ---------------------------------------------------------
class PostRankingView extends StatefulWidget {
  const PostRankingView({super.key});

  @override
  State<PostRankingView> createState() => _PostRankingViewState();
}

class _PostRankingViewState extends State<PostRankingView> {
  final ApiService _apiService = ApiService();

  String _periodType = 'weekly';
  List<dynamic> _rankingPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final posts = await _apiService.getRanking(_periodType);
      if (mounted) {
        setState(() {
          _rankingPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rankingPosts = [];
          _isLoading = false;
        });
      }
    }
  }

  void _changePeriod(String type) {
    if (_periodType == type) return;
    setState(() {
      _periodType = type;
    });
    _fetchRanking();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 切り替えタブ
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.grey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTabButton('週間', 'weekly'),
              const SizedBox(width: 16),
              _buildTabButton('月間', 'monthly'),
            ],
          ),
        ),

        // ランキングリスト
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rankingPosts.isEmpty
              ? const EmptyState(
                  title: 'ランクインした投稿はありません',
                  message: 'リアクションをもらうと\nここに表示されます',
                  icon: Icons.emoji_events_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _fetchRanking,
                  child: ListView.builder(
                    itemCount: _rankingPosts.length,
                    itemBuilder: (context, index) {
                      final post = _rankingPosts[index];
                      final rank = index + 1;

                      final int likeCount = post['likeCount'] ?? 0;
                      final int copyCount = post['copyCount'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          // 順位
                          leading: _buildRankBadge(rank),

                          // 投稿内容 (画像+名前+本文)
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['content'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (post['imageUrl'] != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: PostImage(
                                        imageUrl: post['imageUrl'],
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      '${post['author']?['displayName'] ?? '匿名'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // ▼▼▼ 修正: 数値は右端(trailing)に固定表示する ▼▼▼
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // 真似したい数
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lightbulb,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 24, // 数字の幅を固定して揃える
                                    child: Text(
                                      '$copyCount',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // いいね数
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '$likeCount',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/post_detail',
                              arguments: post,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, String type) {
    final isSelected = _periodType == type;
    return GestureDetector(
      onTap: () => _changePeriod(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bgColor;
    if (rank == 1) {
      bgColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      bgColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      bgColor = const Color(0xFFCD7F32);
    } else {
      bgColor = Colors.blueGrey[100]!;
    }

    return CircleAvatar(
      backgroundColor: bgColor,
      radius: 18,
      child: Text(
        '$rank',
        style: TextStyle(
          color: rank <= 3 ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
