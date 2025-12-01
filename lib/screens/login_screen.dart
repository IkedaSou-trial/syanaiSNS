import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _errorMessage = '';

  // ★ このフラグが true の時だけデバッグボタンが表示されます
  final bool _isDev = true;

  Future<void> _handleLogin(String barcode) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('ログイン試行: $barcode');

      // APIサービス経由でログイン処理
      final success = await _apiService.loginWithBarcode(barcode);

      if (!mounted) return;

      if (success) {
        // ログイン成功！ホーム画面へ移動
        // 💡 MainScreen に渡すためのユーザー情報を引数に追加
        Navigator.of(context).pushReplacementNamed(
          '/home',
          arguments: {
            'username': 'test_store_user', // 本来はAPIから取得した値
            'displayName': 'テスト店長',
            'storeCode': '001',
          },
        );
      } else {
        setState(() {
          _errorMessage = 'ログインに失敗しました (APIエラー)';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ログイン処理中にエラーが発生しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startCamera() {
    print('カメラ起動（未実装）');
    // 実機テスト用: カメラボタンを押しても仮ログインできるようにしておく
    _handleLogin('10260220');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                '店舗VMD共有アプリ',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('社員証をスキャンして開始', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),

              // エラー表示エリア
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.red[50],
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // メイン：スキャンボタン
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _isLoading ? '認証中...' : 'スキャンしてログイン',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('手入力機能は開発中です')));
                },
                child: const Text('社員証がない方はこちら（番号入力）'),
              ),

              // ▼▼▼ ここにデバッグボタンがあります ▼▼▼
              if (_isDev) ...[
                const SizedBox(height: 60),
                const Divider(),
                const Text(
                  '開発者用メニュー (PCテスト用)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleLogin('99999999'),
                    child: const Text('🛠 【Debug】テスト店長としてログイン'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
