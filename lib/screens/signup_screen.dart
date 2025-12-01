import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _apiService = ApiService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  // 店舗コードの選択肢 (EditProfileScreenと同じ)
  final List<String> _storeCodes = ['A101', 'A102', 'B201', 'B202', 'C301'];
  String _selectedStoreCode = 'A101'; // デフォルト値

  bool _isLoading = false;

  Future<void> _handleSignup() async {
    // 入力チェック
    if (_usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _displayNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('全ての項目を入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _apiService.signup(
      _usernameController.text,
      _passwordController.text,
      _displayNameController.text,
      _selectedStoreCode,
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      // 成功したらメッセージを表示してログイン画面に戻る
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('アカウントを作成しました！ログインしてください')));
      Navigator.of(context).pop(); // 前の画面（ログイン画面）に戻る
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウント作成に失敗しました（ユーザー名が重複している可能性があります）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント作成')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'ユーザーID (ログイン用)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: '表示名 (ニックネーム)',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStoreCode,
              decoration: const InputDecoration(
                labelText: '所属店舗',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
              items: _storeCodes.map((code) {
                return DropdownMenuItem(value: code, child: Text(code));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStoreCode = value;
                  });
                }
              },
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleSignup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('登録する', style: TextStyle(fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }
}
