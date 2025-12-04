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
      FocusScope.of(context).unfocus(); // キーボードを閉じる
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
      appBar: AppBar(title: Text(author['displayName'] ?? '投稿詳細')),
      body: Column(
        children: [
          // --- 1. 投稿内容 (スクロール可能にするためにExpandedに入れるか、ここは固定するか) ---
          // 今回はコメントリストと一緒にスクロールさせるのではなく、
          // 「投稿部分」は上に固定し、「コメント部分」だけスクロールするUIにします
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: _getImageProvider(
                        _post['author']['profileImageUrl'],
                      ),
                      child: _post['author']['profileImageUrl'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _post['author']['displayName'] ?? '不明なユーザー',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          DateFormatter.timeAgo(_post['createdAt']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _post['content'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_post['imageUrl'] != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                      image: _getImageProvider(_post['imageUrl'])!,
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(thickness: 1, height: 1),

          // --- 2. コメント一覧 ---
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _commentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'コメントはまだありません。\n一番乗りでコメントしよう！',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final commentAuthor = comment['author'] ?? {};
                    // バックエンドから返ってきた isMine フラグを使用
                    final isMyComment = comment['isMine'] ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: _getImageProvider(
                          commentAuthor['profileImageUrl'],
                        ),
                        child: commentAuthor['profileImageUrl'] == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(
                            commentAuthor['displayName'] ?? '不明',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.timeAgo(comment['createdAt']),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(comment['content'] ?? ''),
                      trailing: isMyComment
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                              ),
                              onPressed: () async {
                                final shouldDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('削除確認'),
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

                                if (shouldDelete == true) {
                                  final success = await _apiService
                                      .deleteComment(_postId, comment['id']);
                                  if (success) {
                                    _refreshComments();
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
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          // --- 3. コメント入力エリア ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'コメントを入力...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
