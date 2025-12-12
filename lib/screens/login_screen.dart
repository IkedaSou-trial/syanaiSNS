import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // バーコード用
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isScanning = true;

  // 手動入力用
  final TextEditingController _manualIdController = TextEditingController();
  final TextEditingController _manualPassController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // タブ切り替え時にカメラのON/OFFを制御
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _scannerController.start();
          setState(() => _isScanning = true);
        } else {
          _scannerController.stop();
          setState(() => _isScanning = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualIdController.dispose();
    _manualPassController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // 共通: ログイン後の遷移判定ロジック
  void _navigateAfterLogin(Map<String, dynamic> user) {
    final categories = user['interestedCategories'];

    // ▼▼▼ 修正: カテゴリーが設定済みならホームへ、未設定なら選択画面へ ▼▼▼
    if (categories != null && categories is List && categories.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/home', arguments: user);
    } else {
      Navigator.of(
        context,
      ).pushReplacementNamed('/category_selection', arguments: user);
    }
  }

  // バーコードスキャン処理
  Future<void> _handleScanLogin(String barcode) async {
    String employeeId = barcode;
    if (barcode.length == 13 && barcode.startsWith('2')) {
      try {
        employeeId = int.parse(barcode.substring(1, 12)).toString();
      } catch (e) {
        // 変換失敗時はそのまま
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _apiService.loginWithBarcode(employeeId);

      if (!mounted) return;

      if (result != null && result['status'] == 'success') {
        final user = result['user'];
        _navigateAfterLogin(user); // 共通メソッドで遷移
      } else if (result != null && result['status'] == 'unregistered') {
        // 初回: パスワード入力ダイアログ
        _showPasswordDialog(employeeId);
      } else {
        setState(() {
          _errorMessage = result?['message'] ?? 'ログインに失敗しました';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPasswordDialog(String userId) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('初回認証'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('社員番号: $userId'),
              const SizedBox(height: 16),
              const Text('初回のみパスワード認証が必要です。'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleManualLoginWithParams(userId, passwordController.text);
              },
              child: const Text('認証してログイン'),
            ),
          ],
        );
      },
    );
  }

  // 手動ログインボタン処理
  Future<void> _handleManualLogin() async {
    final id = _manualIdController.text;
    final pass = _manualPassController.text;

    if (id.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'IDとパスワードを入力してください');
      return;
    }
    await _handleManualLoginWithParams(id, pass);
  }

  // 手動ログイン処理 (共通)
  Future<void> _handleManualLoginWithParams(String id, String pass) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await _apiService.loginManual(id, pass);

      if (!mounted) return;

      if (user != null) {
        _navigateAfterLogin(user); // 共通メソッドで遷移
      } else {
        setState(() => _errorMessage = 'IDまたはパスワードが間違っています');
      }
    } catch (e) {
      setState(() => _errorMessage = 'エラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // ロゴ表示
            SizedBox(
              height: 100,
              width: 100,
              child: Image.asset(
                'assets/icon/unnamed.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Toragram',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 24),

            // タブバー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: const Color(0xFF1A237E),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'スキャン'),
                    Tab(text: '手動入力'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // タブの中身
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // スワイプ無効化
                children: [
                  // 1. スキャン画面
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 250,
                        width: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF1A237E),
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (barcode.rawValue != null) {
                                  _handleScanLogin(barcode.rawValue!);
                                  break; // 1つ読めたら終了
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '社員証のバーコードを\nスキャンしてください',
                        textAlign: TextAlign.center,
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),

                  // 2. 手動入力画面
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _manualIdController,
                          decoration: const InputDecoration(
                            labelText: '社員番号',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _manualPassController,
                          decoration: const InputDecoration(
                            labelText: 'パスワード',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleManualLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'ログイン',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
