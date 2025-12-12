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

  // ▼▼▼ 追加: カテゴリーの選択肢と初期値 ▼▼▼
  final List<String> _categories = [
    '惣菜',
    '精肉',
    '青果',
    '鮮魚',
    'グロサリー',
    'デイリー',
    '生活',
    'ライフスタイル',
    'ソフト',
    'ハード',
    '家電',
    'ペット',
    '後方',
  ];
  String _selectedCategory = '惣菜'; // 初期値

  // 引数で source (カメラ or ギャラリー) を受け取る
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, maxWidth: 800);
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

  // 選択肢を表示するメソッド
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
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿内容を入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // ▼▼▼ 修正: カテゴリーをAPIに渡す ▼▼▼
    final success = await _apiService.createPostWithFile(
      _contentController.text,
      imageFile: _imageFile,
      category: _selectedCategory, // 👈 追加
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
        backgroundColor: const Color(0xFF1A237E), // ネイビーで統一
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: const Text(
              '投稿',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  // ▼▼▼ 追加: カテゴリー選択ドロップダウン ▼▼▼
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        hint: const Text('カテゴリーを選択'),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF1A237E),
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                      ),
                    ),
                  ),

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

                  // 画像がない場合、選択肢シートを表示
                  _imageFile == null
                      ? ElevatedButton.icon(
                          onPressed: _showImageSourceSelector,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('写真を追加'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                          ),
                        )
                      : Column(
                          children: [
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Image.file(
                                  _imageFile!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _imageFile = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.grey,
                                    size: 30,
                                  ),
                                ),
                              ],
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
