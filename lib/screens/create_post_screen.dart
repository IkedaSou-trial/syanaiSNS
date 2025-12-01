import 'dart:convert'; // Base64 エンコード用
import 'dart:io'; // File オブジェクト用
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 画像ピッカーをインポート
import '../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker(); // 💡 ImagePicker のインスタンス
  File? _imageFile; // 💡 選択された画像ファイル

  // 💡 画像を選択するメソッド
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // 画像サイズを制限してBase64が巨大になりすぎないように
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('画像選択エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('画像選択に失敗しました: $e')));
      }
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿内容を入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 💡 新しいメソッドを呼ぶ
    final success = await _apiService.createPostWithFile(
      _contentController.text,
      imageFile: _imageFile, // 💡 Fileを直接渡す
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿に失敗しました')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規投稿'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: const Text('投稿', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '投稿内容', // ラベルだけ少しシンプルに
                      hintText: '今、何してる？',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                    minLines: 3,
                    // autofocus: true, // 💡 自動でここにフォーカスが当たるようにしても便利です
                  ),
                  const SizedBox(height: 16.0),
                  // 💡 画像選択ボタン
                  _imageFile == null
                      ? ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('画像を選択'),
                        )
                      : Column(
                          children: [
                            Image.file(
                              _imageFile!,
                              height: 200, // 表示サイズを制限
                              fit: BoxFit.cover,
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _imageFile = null; // 選択解除
                                });
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('画像を削除'),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
    );
  }
}
