import 'dart:convert';
import 'dart:typed_data';
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
  Uint8List? _imageBytes;

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
    '後方',
  ];
  String _selectedCategory = '惣菜';

  // ▼▼▼ 削除: _selectedPostType (選択不要のため) ▼▼▼

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      print('画像選択エラー: $e');
    }
  }

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
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('アルバムから選択'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isEmpty && _imageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿内容を入力してください')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? base64Image;
      if (_imageBytes != null) {
        base64Image = 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}';
      }

      final success = await _apiService.createPost(
        _contentController.text,
        base64Image,
        category: _selectedCategory,
        // ▼▼▼ 修正: 選択UIを消したので、固定で 'STORE' (店舗) として送ります ▼▼▼
        // もし 'INDIVIDUAL' (個人) にしたい場合はここを書き換えてください
        postType: 'STORE',
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('投稿に失敗しました')));
        }
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規投稿'),
        backgroundColor: const Color(0xFF1A237E),
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
                  // ▼▼▼ 削除: SegmentedButton (個人/店舗の選択ボタン) ▼▼▼

                  // カテゴリー選択
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
                          setState(() => _selectedCategory = newValue!);
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

                  _imageBytes == null
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _imageBytes!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() => _imageBytes = null);
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
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
