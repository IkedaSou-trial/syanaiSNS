import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentDisplayName;
  final String? currentImageUrl;
  final String currentStoreCode; // 現在の店舗コード

  const EditProfileScreen({
    super.key,
    required this.currentDisplayName,
    this.currentImageUrl,
    required this.currentStoreCode,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _apiService = ApiService();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  File? _imageFile;
  bool _isLoading = false;

  // 💡 削除: 店舗コードの選択機能は不要になったため変数を削除

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentDisplayName;
  }

  // 画像を選択する処理
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('画像選択エラー: $e');
    }
  }

  // 保存処理
  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    String? base64Image;
    if (_imageFile != null) {
      final bytes = await _imageFile!.readAsBytes();
      base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final success = await _apiService.updateProfile(
      _nameController.text,
      base64Image,
      widget.currentStoreCode, // 💡 修正: 変更せず、元のコードをそのまま送る
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
        ).showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (widget.currentImageUrl != null) {
      if (widget.currentImageUrl!.startsWith('data:')) {
        final base64Str = widget.currentImageUrl!.split(',')[1];
        imageProvider = MemoryImage(base64Decode(base64Str));
      } else {
        imageProvider = NetworkImage(widget.currentImageUrl!);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('保存', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? const Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '画像をタップして変更',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // 名前入力
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '表示名',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 💡 修正: 店舗コードは編集不可のテキストフィールドとして表示
                  TextField(
                    enabled: false, // 編集不可にする
                    controller: TextEditingController(
                      text: widget.currentStoreCode,
                    ),
                    decoration: InputDecoration(
                      labelText: '所属店舗 (変更不可)',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[200], // 変更できないことを色で表現
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
