import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'scanner_screen.dart'; // ScannerScreenのインポート

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _errorMessage = '';

  // デバッグ入力用のコントローラー
  final TextEditingController _debugBarcodeController = TextEditingController();

  // ★ このフラグが true の時だけデバッグメニューが表示されます
  final bool _isDev = true;

  Future<void> _handleLogin(String barcode) async {
    String employeeId = barcode;

    // JANコード(13桁) かつ "2" で始まる場合 (インストアコード)
    if (barcode.length == 13 && barcode.startsWith('2')) {
      try {
        // 1. 先頭1文字(2)と末尾1文字(チェックデジット)を除去して、真ん中の11文字を取得
        // substring(1, 12) は インデックス1(2文字目) から インデックス11(12文字目) までを取得
        String corePart = barcode.substring(1, 12);

        // 2. 一度「整数(int)」に変換することで、先頭の連続するゼロを取り除く
        int idNumber = int.parse(corePart);

        // 3. 再び文字列に戻す
        employeeId = idNumber.toString();

        print('社員番号抽出[汎用]: $barcode -> $corePart -> $employeeId');
      } catch (e) {
        print('バーコード解析エラー: $e');
        // 解析に失敗した場合は、変換せずにそのままの値を試す
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('ログイン試行: $employeeId');

      final result = await _apiService.loginWithBarcode(employeeId);

      if (!mounted) return;

      if (result is Map<String, dynamic>) {
        final user = result;
        Navigator.of(context).pushReplacementNamed(
          '/home',
          arguments: {
            'username': user['username'],
            'displayName': user['displayName'],
            'storeCode': user['storeCode'],
          },
        );
      } else {
        setState(() {
          _errorMessage = result.toString();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'エラー: $e\n\n接続先: ${_apiService.baseUrl}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // カメラボタンが押された時の処理
  Future<void> _startCamera() async {
    // 1. スキャナー画面に遷移し、結果（バーコード文字列）を待つ
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ScannerScreen()));

    // 2. 結果が返ってきたらログイン処理を実行
    if (result != null && result is String) {
      _handleLogin(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
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
                const Text(
                  '社員証をスキャンして開始',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 48),

                // ❌ ここにあったデバッグボタンを削除し、下に移動しました

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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('手入力機能は開発中です')),
                    );
                  },
                  child: const Text('社員証がない方はこちら（番号入力）'),
                ),

                // ▼▼▼ 開発者用メニュー（ここにボタンを移動しました） ▼▼▼
                if (_isDev) ...[
                  const SizedBox(height: 60),
                  const Divider(),
                  const Text(
                    '開発者用メニュー (PCテスト用)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // 1. 任意のバーコードを入力するフィールド
                  TextField(
                    controller: _debugBarcodeController,
                    decoration: const InputDecoration(
                      labelText: 'バーコードNo.手入力',
                      hintText: '例: 10243633',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),

                  // 2. 入力された値を使ってログインするボタン (ここに配置！)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final code = _debugBarcodeController.text;
                        if (code.isNotEmpty) {
                          _handleLogin(code);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('🛠 入力値でログイン'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
