import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/post_image.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post; // 編集対象のデータを受け取る

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _contentController = TextEditingController();

  String _selectedCategory = 'その他';
  File? _newImageFile; // 新しく選んだ画像
  String? _currentImageUrl; // 現在の画像URL
  bool _isLoading = false;

  final List<String> _categories = [
    '売上報告',
    '接客',
    '商品管理',
    '売り場作り',
    'トラブル対応',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    // 初期値をセット
    _contentController.text = widget.post['content'] ?? '';
    _selectedCategory = widget.post['category'] ?? 'その他';
    _currentImageUrl = widget.post['imageUrl'];

    // カテゴリーリストにないものが保存されていた場合の対策
    if (!_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  // 画像を削除する（現在の画像も、新しく選んだ画像もクリア）
  void _clearImage() {
    setState(() {
      _newImageFile = null;
      _currentImageUrl = null;
    });
  }

  Future<void> _updatePost() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿内容を入力してください')));
      return;
    }

    setState(() => _isLoading = true);

    String? base64Image;
    if (_newImageFile != null) {
      final bytes = await _newImageFile!.readAsBytes();
      final String base64String = base64Encode(bytes);
      // 拡張子簡易判定
      String ext = _newImageFile!.path.split('.').last;
      base64Image = 'data:image/$ext;base64,$base64String';
    } else if (_currentImageUrl == null) {
      // もともと画像があったのに削除された場合、nullを送る
      // (バックエンド側で null を受け取ったら画像を消す処理が必要ですが、
      //  今回のバックエンド実装では null を送ると画像削除するようにしてあります)
      base64Image = null;
    }

    final data = {
      'content': _contentController.text,
      'category': _selectedCategory,
      'imageBase64': base64Image, // 変更がなければ undefined (送信しない) にしたいが、今回は簡易的に
    };

    // 画像が変わっていない(newFileがnull) かつ 元画像がある場合は imageBase64を送らない
    if (_newImageFile == null && _currentImageUrl != null) {
      data.remove('imageBase64');
    }

    final success = await _apiService.updatePost(widget.post['id'], data);

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true); // trueを返して更新を通知
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿を更新しました')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿を編集'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updatePost,
            child: Text(
              '保存',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _isLoading ? Colors.grey : const Color(0xFF1A237E),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カテゴリー選択
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'カテゴリー',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),

            // テキスト入力
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'いまどうしてる？（#タグ も使えます）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 画像表示エリア
            if (_newImageFile != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_newImageFile!, height: 200),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      onPressed: _clearImage,
                      icon: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_currentImageUrl != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PostImage(
                      imageUrl: _currentImageUrl!,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      onPressed: _clearImage,
                      icon: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // 画像選択ボタン
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('画像を変更する'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
