import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  // 💡 修正: 引数で source (カメラ or ギャラリー) を受け取るように変更
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source, // ここを変更
        maxWidth: 800,
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

  // 💡 追加: 選択肢を表示するメソッド
  void _showImageSourceSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('カメラで撮影'),
                onTap: () {
                  Navigator.pop(context); // シートを閉じる
                  _pickImage(ImageSource.camera); // カメラを起動
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('アルバムから選択'),
                onTap: () {
                  Navigator.pop(context); // シートを閉じる
                  _pickImage(ImageSource.gallery); // ギャラリーを開く
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    // ... (変更なし) ...
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿内容を入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _apiService.createPostWithFile(
      _contentController.text,
      imageFile: _imageFile,
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
                      labelText: '投稿内容',
                      hintText: '今、何してる？',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                    minLines: 3,
                  ),
                  const SizedBox(height: 16.0),

                  // 💡 修正: 画像がない場合、選択肢シートを表示するように変更
                  _imageFile == null
                      ? ElevatedButton.icon(
                          onPressed: _showImageSourceSelector, // ここを変更
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('写真を追加'),
                        )
                      : Column(
                          children: [
                            Image.file(
                              _imageFile!,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _imageFile = null;
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
