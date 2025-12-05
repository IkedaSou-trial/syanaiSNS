import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final ApiService _apiService = ApiService();

  // デフォルトは週間ランキング
  String _periodType = 'weekly'; // 'weekly' or 'monthly'
  List<dynamic> _rankingPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  // APIからランキングデータを取得
  Future<void> _fetchRanking() async {
    setState(() => _isLoading = true);

    try {
      final posts = await _apiService.getRanking(_periodType);
      // 💡 修正: ダミーデータ生成処理を削除し、APIの結果をそのまま使う
      _rankingPosts = posts;
    } catch (e) {
      print('ランキング取得エラー: $e');
      _rankingPosts = []; // エラー時は空にする
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 期間切り替え
  void _changePeriod(String type) {
    if (_periodType == type) return;
    setState(() {
      _periodType = type;
    });
    _fetchRanking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('人気投稿ランキング'), centerTitle: true),
      body: Column(
        children: [
          // 1. 切り替えタブエリア
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('週間', 'weekly'),
                const SizedBox(width: 16),
                _buildTabButton('月間', 'monthly'),
              ],
            ),
          ),

          // 2. ランキングリスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rankingPosts.isEmpty
                // 💡 修正: データがない場合のメッセージを表示
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '集計期間中の投稿はありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _rankingPosts.length,
                    itemBuilder: (context, index) {
                      final post = _rankingPosts[index];
                      final rank = index + 1;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          // 順位バッジ
                          leading: _buildRankBadge(rank),
                          // 投稿内容
                          title: Text(
                            post['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${post['author']?['displayName'] ?? '匿名'}',
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: Colors.pink[300],
                                ),
                                Text(' ${post['likeCount'] ?? 0}'),
                              ],
                            ),
                          ),
                          // タップしたら詳細へ
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
        ],
      ),
    );
  }

  // タブボタンの見た目
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

  // 順位バッジの見た目
  Widget _buildRankBadge(int rank) {
    Color bgColor;
    if (rank == 1)
      bgColor = const Color(0xFFFFD700); // 金
    else if (rank == 2)
      bgColor = const Color(0xFFC0C0C0); // 銀
    else if (rank == 3)
      bgColor = const Color(0xFFCD7F32); // 銅
    else
      bgColor = Colors.blueGrey[100]!; // その他

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
