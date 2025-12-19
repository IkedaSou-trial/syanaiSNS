import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/store_selection_modal.dart'; // 店舗選択用

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  // 店舗用
  final _storeCodeController = TextEditingController();
  String _selectedStoreName = '';

  final ApiService _apiService = ApiService();
  bool _isLoading = false;

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

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // API呼び出し
      final user = await _apiService.signup(
        _usernameController.text,
        _passwordController.text,
        _displayNameController.text,
        _storeCodeController.text,
      );

      setState(() => _isLoading = false);

      if (user != null && mounted) {
        // 登録成功 -> ホームへ
        Navigator.of(context).pushReplacementNamed('/home', arguments: user);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登録に失敗しました（IDが既にあるかも？）')),
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
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'ユーザーID (英数字)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ユーザーIDを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'パスワード (4文字以上)'),
                // ▼▼▼ 修正: 文字入力用キーボードに変更 ▼▼▼
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  // ▼▼▼ 修正: 4文字以上ならOK (数字縛りを削除) ▼▼▼
                  if (value.length < 4) {
                    return 'パスワードは4文字以上で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: '表示名 (ニックネーム)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '表示名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 店舗選択ボタン
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
              // 店舗コードのバリデーション用 (非表示のTextFormFieldを使うテクニック)
              SizedBox(
                height: 0,
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
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('登録する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
