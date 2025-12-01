import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../utils/date_formatter.dart';

class PostDetailScreen extends StatefulWidget {
  // ホーム画面から投稿データ（Map）を受け取る
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ApiService _apiService = ApiService();
  final _commentController = TextEditingController();

  // コメント一覧を管理するためのState
  late Future<List<dynamic>> _commentsFuture;

  // 投稿データにアクセスしやすくするための getter
  Map<String, dynamic> get _post => widget.post;
  String get _postId => _post['id'];

  @override
  void initState() {
    super.initState();
    // 画面初期化時にコメントを取得
    _refreshComments();
  }

  // コメント一覧をリフレッシュするメソッド
  void _refreshComments() {
    setState(() {
      _commentsFuture = _apiService.getComments(_postId);
    });
  }

  // コメントを投稿するメソッド
  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) return;

    final success = await _apiService.createComment(
      _postId,
      _commentController.text,
    );

    if (success) {
      _commentController.clear(); // 入力欄をクリア
      _refreshComments(); // コメント一覧をリフレッシュ
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('コメントの投稿に失敗しました')));
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

  @override
  Widget build(BuildContext context) {
    final author = _post['author'] ?? {};

    return Scaffold(
      appBar: AppBar(title: Text(author['displayName'] ?? '投稿')),
      body: Column(
        children: [
          // --- 1. 投稿内容 ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: _getImageProvider(
                        _post['author']['profileImageUrl'],
                      ),
                      child: _post['author']['profileImageUrl'] == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _post['author']['displayName'] ?? '不明なユーザー',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      DateFormatter.timeAgo(_post['createdAt']),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _post['content'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),

                // 💡 投稿画像があれば表示
                if (_post['imageUrl'] != null) ...[
                  const SizedBox(height: 10),
                  Image(
                    image: _getImageProvider(_post['imageUrl'])!,
                    fit: BoxFit.cover,
                    height: 250, // 詳細画面では少し大きく
                    width: double.infinity,
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Divider(),

          // --- 2. コメント一覧 (スクロール可能) ---
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _commentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('まだコメントはありません'));
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final commentAuthor = comment['author'] ?? {};
                    // 💡 isMine を取得 (バックエンドが対応していれば取得可能)
                    final isMyComment = comment['isMine'] ?? false;

                    return ListTile(
                      title: Text(commentAuthor['displayName'] ?? '不明'),
                      subtitle: Text(comment['content'] ?? ''),
                      // 💡 自分のコメントなら削除ボタンを表示
                      trailing: isMyComment
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () async {
                                // 💡 確認ダイアログを表示
                                final shouldDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('削除の確認'),
                                      content: const Text('このコメントを削除しますか？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text(
                                            '削除',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                // 「削除」が選ばれた場合のみ実行
                                if (shouldDelete == true) {
                                  final success = await _apiService
                                      .deleteComment(_postId, comment['id']);
                                  if (success) {
                                    _refreshComments(); // コメント一覧を更新
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('コメントを削除しました'),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            )
                          : null, // 自分以外のコメントには何も表示しない
                    );
                  },
                );
              },
            ),
          ),

          // --- 3. コメント入力欄 ---
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'コメントを追加...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
