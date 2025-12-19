import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/post_image.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _post;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _post = args;
    }
  }

  // リアクション切り替え
  Future<void> _toggleReaction(String type) async {
    if (_post == null) return;

    final bool isLiked = _post!['isLikedByMe'] ?? false;
    final bool isCopied = _post!['isCopiedByMe'] ?? false;

    // UIを先に更新
    setState(() {
      if (type == 'LIKE') {
        _post!['isLikedByMe'] = !isLiked;
        _post!['likeCount'] = (_post!['likeCount'] ?? 0) + (!isLiked ? 1 : -1);
      } else if (type == 'COPY') {
        _post!['isCopiedByMe'] = !isCopied;
        _post!['copyCount'] = (_post!['copyCount'] ?? 0) + (!isCopied ? 1 : -1);
      }
    });

    // サーバー通信
    final success = await _apiService.toggleReaction(_post!['id'], type);
    if (!success && mounted) {
      // 失敗したら戻す
      setState(() {
        if (type == 'LIKE') {
          _post!['isLikedByMe'] = isLiked;
          _post!['likeCount'] = (_post!['likeCount'] ?? 0) + (isLiked ? 1 : -1);
        } else if (type == 'COPY') {
          _post!['isCopiedByMe'] = isCopied;
          _post!['copyCount'] =
              (_post!['copyCount'] ?? 0) + (isCopied ? 1 : -1);
        }
      });
    }
  }

  // ユーザープロフィールへ遷移
  void _navigateToProfile(String? username) {
    if (username != null) {
      Navigator.of(context).pushNamed('/profile', arguments: username);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) {
      return const Scaffold(body: Center(child: Text('投稿が見つかりません')));
    }

    final author = _post!['author'];
    final category = _post!['category'] ?? 'その他';

    final bool isLiked = _post!['isLikedByMe'] ?? false;
    final int likeCount = _post!['likeCount'] ?? 0;
    final bool isCopied = _post!['isCopiedByMe'] ?? false;
    final int copyCount = _post!['copyCount'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿詳細'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToProfile(author?['username']),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
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
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author?['displayName'] ?? '不明なユーザー',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormatter.timeAgo(_post!['createdAt']),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(category, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 本文
            HashtagText(
              text: _post!['content'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black,
              ),
              onTagTap: (tag) {
                Navigator.of(
                  context,
                ).pushNamed('/search', arguments: {'tag': tag});
              },
            ),

            // 画像
            if (_post!['imageUrl'] != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PostImage(
                  imageUrl: _post!['imageUrl'],
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ],

            const SizedBox(height: 32),
            const Divider(),

            // リアクションボタン
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BigReactionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    count: likeCount,
                    label: 'いいね',
                    onTap: () => _toggleReaction('LIKE'),
                  ),
                  _BigReactionButton(
                    icon: isCopied ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: isCopied ? Colors.orange : Colors.grey,
                    count: copyCount,
                    label: '真似したい',
                    onTap: () => _toggleReaction('COPY'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigReactionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final VoidCallback onTap;

  const _BigReactionButton({
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
