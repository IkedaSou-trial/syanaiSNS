import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // 設定は「全開放」のまま（これが一番読み取り確率が高いため）
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 500,
    formats: const [BarcodeFormat.all],
    cameraResolution: null,
    facing: CameraFacing.back,
  );

  bool _isScanning = true;
  bool _isProcessingScan = false;

  final TextEditingController _manualIdController = TextEditingController();
  final TextEditingController _manualPassController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _scannerController.start();
          setState(() {
            _isScanning = true;
            _isProcessingScan = false;
            _errorMessage = '';
          });
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

  void _navigateAfterLogin(Map<String, dynamic> user) {
    final categories = user['interestedCategories'];
    if (categories != null && categories is List && categories.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/home', arguments: user);
    } else {
      Navigator.of(
        context,
      ).pushReplacementNamed('/category_selection', arguments: user);
    }
  }

  Future<void> _handleScan(String barcode) async {
    if (_isProcessingScan) return;

    // ゴミデータ排除
    final numericOnly = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.length < 3) return;

    String employeeId = numericOnly;
    // インストアコード(2から始まる13桁)の処理
    if (numericOnly.length == 13 && numericOnly.startsWith('2')) {
      try {
        employeeId = int.parse(numericOnly.substring(1, 12)).toString();
      } catch (e) {
        /* ignore */
      }
    }

    setState(() {
      _isProcessingScan = true;
      _isLoading = true;
      _errorMessage = ''; // エラー表示をリセット
    });

    try {
      final checkResult = await _apiService.checkUserExists(employeeId);

      if (!mounted) return;

      if (checkResult != null) {
        final bool exists = checkResult['exists'] ?? false;
        if (exists) {
          _showPasswordDialog(employeeId);
        } else {
          _scannerController.stop();
          setState(() => _isScanning = false);
          Navigator.of(context).pushNamed('/signup', arguments: employeeId);
        }
      } else {
        setState(() {
          _errorMessage = '未登録のIDです: $employeeId';
          _isProcessingScan = false;
          _isLoading = false;
        });
        // 2秒後に再度スキャン可能にする
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isScanning) {
            setState(() => _errorMessage = '');
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '通信エラーが発生しました';
        _isProcessingScan = false;
        _isLoading = false;
      });
    }
  }

  void _showPasswordDialog(String userId) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('パスワード入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '社員番号: $userId',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isProcessingScan = false;
                  _isLoading = false;
                });
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performLogin(userId, passwordController.text);
              },
              child: const Text('ログイン'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogin(String id, String pass) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await _apiService.loginManual(id, pass);
      if (!mounted) return;

      if (user != null) {
        _navigateAfterLogin(user);
      } else {
        setState(() {
          _errorMessage = 'パスワードが間違っています';
          _isProcessingScan = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました';
        _isProcessingScan = false;
        _isLoading = false;
      });
    }
  }

  void _handleManualButton() {
    if (_manualIdController.text.isEmpty ||
        _manualPassController.text.isEmpty) {
      setState(() => _errorMessage = 'IDとパスワードを入力してください');
      return;
    }
    _performLogin(_manualIdController.text, _manualPassController.text);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenHeight - 50),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // ロゴ
                    SizedBox(
                      height: 80,
                      width: 80,
                      child: Image.asset(
                        'assets/icon/unnamed.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Toragram',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 20),

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
                            Tab(text: 'ログイン'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // コンテンツ
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return _tabController.index == 0
                            ? _buildScanTab()
                            : _buildLoginTab();
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // きれいに整理したスキャンタブ
  Widget _buildScanTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // スキャナーエリア
        Container(
          height: 280,
          width: 280,
          decoration: BoxDecoration(
            color: Colors.black, // カメラロード前は黒背景
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  fit: BoxFit.cover,
                  // ▼▼▼ 修正: 引数を (context, error) の2つにしました ▼▼▼
                  errorBuilder: (context, error) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            color: Colors.white54,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'カメラを起動できません',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  },
                  onDetect: (capture) {
                    if (_isProcessingScan) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _handleScan(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),

                // シンプルなスキャン枠（装飾）
                Center(
                  child: Container(
                    width: 240,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // 読み込み中インジケーター
                if (_isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          '枠内にバーコードを合わせてください',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'カメラに近づけすぎるとピントが合いません\n少し離して調整してください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),

        // エラーメッセージ（必要な時だけ表示）
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.red[800],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ログインタブ
  Widget _buildLoginTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
            keyboardType: TextInputType.visiblePassword,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleManualButton,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'ログイン',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/signup'),
            child: const Text('アカウントをお持ちでない方はこちら'),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
