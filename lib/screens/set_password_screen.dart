import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SetPasswordScreen extends StatefulWidget {
  final String username;
  final String displayName;
  final String storeCode;

  const SetPasswordScreen({
    super.key,
    required this.username,
    required this.displayName,
    required this.storeCode,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _register() async {
    final password = _passwordController.text;
    if (password.isEmpty || password.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードは4文字以上で設定してください')));
      return;
    }
    if (password != _confirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードが一致しません')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.signup(
        widget.username,
        password,
        widget.displayName,
        widget.storeCode,
      );

      if (!mounted) return;

      if (result != null) {
        // 成功時はユーザー情報が返る
        // 登録＆ログイン成功
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false, arguments: result);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登録に失敗しました')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワード設定')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '初回ログインのため、\nパスワードを設定してください。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '社員番号: ${widget.username}\n名前: ${widget.displayName}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(
                labelText: 'パスワード（確認）',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('設定してログイン'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
