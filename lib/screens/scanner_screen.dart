import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // 読み取りが重複しないようにするためのフラグ
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('バーコードをスキャン')),
      body: MobileScanner(
        // 検出時のコールバック
        onDetect: (capture) {
          if (_isScanned) return; // すでに読み取り済みなら何もしない

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              setState(() {
                _isScanned = true;
              });

              // 読み取った値を前の画面（ログイン画面）に戻す
              Navigator.of(context).pop(barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}
