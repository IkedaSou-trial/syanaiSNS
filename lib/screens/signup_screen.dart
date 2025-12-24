import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 数字のみ制限のために必要
import '../services/api_service.dart';
import '../widgets/store_selection_modal.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // コントローラー名は変えなくても動きますが、中身は「社員番号」になります
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  final _storeCodeController = TextEditingController();
  String _selectedStoreName = '';

  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    // スキャン機能などから社員番号が渡された場合の処理
    if (args is String && _usernameController.text.isEmpty) {
      _usernameController.text = args;
    }
  }

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

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // バックエンドには username として社員番号を送ります
      final user = await _apiService.signup(
        _usernameController.text,
        _passwordController.text,
        _displayNameController.text,
        _storeCodeController.text,
      );

      setState(() => _isLoading = false);

      if (user != null && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/category_selection',
          (route) => false,
          arguments: user,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登録に失敗しました（社員番号が既にあるかも？）')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ▼▼▼ 修正: 社員番号（数字のみ）の入力欄 ▼▼▼
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '社員番号', // 表示変更
                  hintText: '数字のみ入力してください',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number, // 数字キーボードを表示
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // 数字以外を弾く
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '社員番号を入力してください';
                  }
                  return null;
                },
              ),

              // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'パスワード (4文字以上)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  if (value.length < 4) {
                    return 'パスワードは4文字以上で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: '表示名 (ニックネーム)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '表示名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

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
                              : '$_selectedStoreName (${_storeCodeController.text})',
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
              Offstage(
                offstage: true, // これで完全に姿を消します
                child: TextFormField(
                  controller: _storeCodeController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '店舗を選択してください';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('登録する', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
