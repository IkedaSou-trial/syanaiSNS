import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/post_image.dart'; // 画像表示用
import '../widgets/store_selection_modal.dart'; // 店舗選択用

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser; // 前の画面からユーザー情報を受け取る

  const EditProfileScreen({super.key, required this.currentUser});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _apiService = ApiService();
  late TextEditingController _displayNameController = TextEditingController();

  // 店舗用
  final TextEditingController _storeCodeController = TextEditingController();
  String _selectedStoreName = ''; // 店舗名表示用

  // 画像用
  final ImagePicker _picker = ImagePicker();
  Uint8List? _newImageBytes; // 新しく選んだ画像データ
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 既存のデータをセット
    _displayNameController.text = widget.currentUser['displayName'] ?? '';
    _storeCodeController.text = widget.currentUser['storeCode'] ?? '';

    String initialName = widget.currentUser['displayName'] ?? '';
    // 全角「＠」または半角「@」が含まれていたら、それより前の部分だけを使う
    if (initialName.contains('＠')) {
      initialName = initialName.split('＠')[0];
    } else if (initialName.contains('@')) {
      initialName = initialName.split('@')[0];
    }

    _displayNameController = TextEditingController(text: initialName);

    // 現在の店舗コードから、店舗名を取得して表示するための処理
    _fetchCurrentStoreName();
  }

  // 既存の店舗コードから名前を探し出す
  Future<void> _fetchCurrentStoreName() async {
    final currentCode = widget.currentUser['storeCode'];
    if (currentCode == null || currentCode.isEmpty) return;

    // 店舗リストを全取得して検索 (件数が少なければこれでOK)
    final stores = await _apiService.getStores();
    final foundStore = stores.firstWhere(
      (s) => s['code'] == currentCode,
      orElse: () => null,
    );

    if (foundStore != null && mounted) {
      setState(() {
        _selectedStoreName = foundStore['name'];
      });
    }
  }

  // 画像選択 (Web対応)
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _newImageBytes = bytes;
        });
      }
    } catch (e) {
      print('画像選択エラー: $e');
    }
  }

  // 店舗選択モーダルを開く
  void _showStoreSelector() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const StoreSelectionModal(),
    );

    if (result != null) {
      setState(() {
        _storeCodeController.text = result['code'];
        _selectedStoreName = result['name'];
      });
    }
  }

  // 保存処理
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      String? base64Image;
      if (_newImageBytes != null) {
        base64Image = 'data:image/jpeg;base64,${base64Encode(_newImageBytes!)}';
      }

      final success = await _apiService.updateProfile(
        _displayNameController.text,
        base64Image, // 画像が変わっていなければ null
        _storeCodeController.text,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true); // 成功したら戻る
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
        }
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // --- 画像アイコン ---
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          child: ClipOval(
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: _newImageBytes != null
                                  ? Image.memory(
                                      _newImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : PostImage(
                                      imageUrl:
                                          widget.currentUser['profileImageUrl'],
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- 表示名 ---
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: '表示名',
                      border: OutlineInputBorder(),
                      helperText: 'タイムラインに表示される名前です',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 店舗選択 (ここを変更！) ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '所属店舗',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showStoreSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _storeCodeController.text.isEmpty
                                  ? '店舗を選択してください'
                                  : _selectedStoreName.isNotEmpty
                                  ? '$_selectedStoreName (${_storeCodeController.text})'
                                  : '店舗コード: ${_storeCodeController.text}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _storeCodeController.text.isEmpty
                                    ? Colors.grey[600]
                                    : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
