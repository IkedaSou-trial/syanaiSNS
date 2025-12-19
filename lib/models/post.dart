class Post {
  final String id; // intからStringに変更されているはずです
  final String content;
  final String? imageUrl;
  final String authorName;
  final String? authorImage;
  final String? authorStore;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final DateTime createdAt;
  final bool isMine;
  final String authorId;
  // ▼▼▼ 追加 ▼▼▼
  final String category;
  final String postType; // 'INDIVIDUAL' or 'STORE'

  Post({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.authorName,
    this.authorImage,
    this.authorStore,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByMe,
    required this.createdAt,
    required this.isMine,
    required this.authorId,
    // ▼▼▼ 追加 (デフォルト値 'その他') ▼▼▼
    this.category = 'その他',
    this.postType = 'INDIVIDUAL',
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      authorName: json['author']['displayName'] ?? 'Unknown',
      authorImage: json['author']['profileImageUrl'],
      authorStore: json['author']['storeCode'],
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      isLikedByMe: json['isLikedByMe'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      isMine: json['isMine'] ?? false,
      authorId: json['author']['id'].toString(),
      // ▼▼▼ 追加 ▼▼▼
      category: json['category'] ?? 'その他',
      postType: json['postType'] ?? 'INDIVIDUAL',
    );
  }
}
