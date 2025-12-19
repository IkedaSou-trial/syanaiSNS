import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/post_image.dart';
import '../widgets/post_skeleton.dart';

class CopiedPostsScreen extends StatefulWidget {
  const CopiedPostsScreen({super.key});

  @override
  State<CopiedPostsScreen> createState() => _CopiedPostsScreenState();
}

class _CopiedPostsScreenState extends State<CopiedPostsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final posts = await _apiService.getCopiedPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // リアクション切り替え
  Future<void> _toggleReaction(String postId, String type) async {
    final index = _posts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    final post = _posts[index];
    final bool isLiked = post['isLikedByMe'] ?? false;
    final bool isCopied = post['isCopiedByMe'] ?? false;

    // UIを先に更新
    setState(() {
      if (type == 'LIKE') {
        post['isLikedByMe'] = !isLiked;
        post['likeCount'] = (post['likeCount'] ?? 0) + (!isLiked ? 1 : -1);
      } else if (type == 'COPY') {
        post['isCopiedByMe'] = !isCopied;
        post['copyCount'] = (post['copyCount'] ?? 0) + (!isCopied ? 1 : -1);

        // 「真似したい」を解除した場合、リストから削除するかどうかの判断
        // ここでは即座に消さず、ボタンの状態だけ変えて、画面を出入りした時に反映される方がUX的に優しい
        // (誤操作で消えた時にすぐ戻せるようにするため)
      }
    });

    // サーバー通信
    final success = await _apiService.toggleReaction(postId, type);
    if (!success && mounted) {
      // 失敗したら戻す
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '真似したいリスト',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const PostSkeleton(),
            )
          : _posts.isEmpty
          ? const Center(child: Text('「真似したい」した投稿はありません'))
          : RefreshIndicator(
              onRefresh: _fetchPosts,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  return _buildPostItem(_posts[index]);
                },
              ),
            ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final author = post['author'];
    final category = post['category'] ?? 'その他';

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
              // ヘッダー
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (author?['username'] != null) {
                        Navigator.of(
                          context,
                        ).pushNamed('/profile', arguments: author['username']);
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
                ],
              ),
              const SizedBox(height: 8),

              // 本文
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

              // 画像
              if (post['imageUrl'] != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PostImage(
                    imageUrl: post['imageUrl'],
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // リアクションボタン
              Row(
                children: [
                  _ReactionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    count: likeCount,
                    label: 'いいね',
                    onTap: () => _toggleReaction(post['id'], 'LIKE'),
                  ),
                  const SizedBox(width: 24),
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
}

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
