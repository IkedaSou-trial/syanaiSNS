import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Shimmerでラップしてキラキラさせる
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー部分（アイコンと名前）
              Row(
                children: [
                  const CircleAvatar(radius: 18, backgroundColor: Colors.white),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 14, color: Colors.white),
                      const SizedBox(height: 6),
                      Container(width: 60, height: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 本文（2行分）
              Container(
                width: double.infinity,
                height: 14,
                color: Colors.white,
              ),
              const SizedBox(height: 6),
              Container(width: 200, height: 14, color: Colors.white),
              const SizedBox(height: 12),

              // 画像エリア
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
