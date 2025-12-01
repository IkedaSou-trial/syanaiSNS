import 'package:flutter/material.dart';

class DateFormatter {
  static String timeAgo(dynamic date) {
    if (date == null) return '';

    DateTime inputDate;
    try {
      if (date is DateTime) {
        inputDate = date;
      } else {
        inputDate = DateTime.parse(date.toString());
      }
      // タイムゾーンを現地時間（日本時間など）に合わせる
      inputDate = inputDate.toLocal();
    } catch (e) {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(inputDate);

    if (difference.inSeconds < 60) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      // 1週間以上前なら日付を表示 (例: 2025/11/20)
      return '${inputDate.year}/${inputDate.month.toString().padLeft(2, '0')}/${inputDate.day.toString().padLeft(2, '0')}';
    }
  }
}
