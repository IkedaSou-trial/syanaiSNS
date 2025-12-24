import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/post_image.dart';
import '../screens/edit_post_screen.dart';

class PostItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function() onPostUpdated; // 編集・削除・リアクション時に親を更新するためのコールバック

  const PostItem({super.key, required this.post, required this.onPostUpdated});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  final ApiService _apiService = ApiService();

  // ▼▼▼ 追加: 拡大画像を閉じるための処理 ▼▼▼
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.black.withOpacity(0.8)),
            ),
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(imageUrl),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  // リアクション処理
  Future<void> _toggleReaction(String type) async {
    // 楽観的UI更新（サーバー通信前に見た目だけ変える）
    setState(() {
      final bool isLiked = widget.post['isLikedByMe'] ?? false;
      final bool isCopied = widget.post['isCopiedByMe'] ?? false;

      if (type == 'LIKE') {
        widget.post['isLikedByMe'] = !isLiked;
        widget.post['likeCount'] =
            (widget.post['likeCount'] ?? 0) + (!isLiked ? 1 : -1);
      } else if (type == 'COPY') {
        widget.post['isCopiedByMe'] = !isCopied;
        widget.post['copyCount'] =
            (widget.post['copyCount'] ?? 0) + (!isCopied ? 1 : -1);
      }
    });

    // API通信
    final success = await _apiService.toggleReaction(widget.post['id'], type);
    if (!success && mounted) {
      // 失敗したら親をリロードして元に戻す
      widget.onPostUpdated();
    }
  }

  // 削除処理
  Future<void> _deletePostProcess() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );

    if (shouldDelete == true) {
      final success = await _apiService.deletePost(widget.post['id']);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
        widget.onPostUpdated(); // 親リストを更新
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['author'];
    final bool isMine = post['isMine'] ?? false;
    final String category = post['category'] ?? 'その他';

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
                          ),
                        ),
                      ),
                      if (isMine)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.grey,
                          ),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditPostScreen(post: post),
                                ),
                              );
                              if (result == true) widget.onPostUpdated();
                            } else if (value == 'delete') {
                              _deletePostProcess();
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
                onTagTap: (tag) => Navigator.of(
                  context,
                ).pushNamed('/search', arguments: {'tag': tag}),
              ),

              // --- 画像 (タップで拡大) ---
              if (post['imageUrl'] != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  // ▼▼▼ ここで拡大ダイアログを呼び出し ▼▼▼
                  onTap: () => _showImageDialog(context, post['imageUrl']),
                  child: Hero(
                    tag: post['id'],
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PostImage(imageUrl: post['imageUrl'], height: 250),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // --- リアクションボタン ---
              Row(
                children: [
                  _ReactionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    count: likeCount,
                    label: 'いいね',
                    onTap: () => _toggleReaction('LIKE'),
                  ),
                  const SizedBox(width: 24),
                  _ReactionButton(
                    icon: isCopied ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: isCopied ? Colors.orange : Colors.grey,
                    count: copyCount,
                    label: '真似したい',
                    onTap: () => _toggleReaction('COPY'),
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
