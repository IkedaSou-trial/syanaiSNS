import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class PostImage extends StatefulWidget {
  final String? imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  const PostImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  State<PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<PostImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  @override
  void didUpdateWidget(covariant PostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fetchImage();
    }
  }

  Future<void> _fetchImage() async {
    final url = widget.imageUrl;

    // URLがない場合は何もしない
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. すでにBase64データの場合（プレビュー表示など）
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.split(',')[1];
        final bytes = base64Decode(base64Str);
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Base64 decode error: $e');
        if (mounted)
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
      }
      return;
    }

    // 2. URLの場合（http... または /uploads...）
    String fullUrl = url;
    if (!url.startsWith('http')) {
      fullUrl = '${ApiService.baseUrl}$url';
    }

    try {
      // ▼▼▼ ここが重要！ヘッダーをつけて画像を取得 ▼▼▼
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'ngrok-skip-browser-warning': 'true', // ngrok対策
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _imageBytes = response.bodyBytes;
            _isLoading = false;
          });
        }
      } else {
        print('Image load failed: ${response.statusCode}');
        if (mounted)
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
      }
    } catch (e) {
      print('Image fetch error: $e');
      if (mounted)
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height,
        width: widget.width,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _imageBytes == null) {
      return Container(
        height: widget.height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    // 取得したバイナリデータを表示
    return Image.memory(
      _imageBytes!,
      height: widget.height,
      width: double.infinity,
      fit: widget.fit,
    );
  }
}
