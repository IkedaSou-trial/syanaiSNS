import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class HashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Function(String tag) onTagTap; // タップ時の処理

  const HashtagText({
    super.key,
    required this.text,
    this.style,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    // 日本語対応のハッシュタグ正規表現
    final regex = RegExp(r"(#\S+)");
    final spans = <TextSpan>[];

    text.splitMapJoin(
      regex,
      onMatch: (Match match) {
        final String tag = match.group(0)!;
        spans.add(
          TextSpan(
            text: tag,
            style: (style ?? const TextStyle()).copyWith(
              color: Colors.blue, // リンク色
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // #を取り除いてコールバック
                onTagTap(tag.substring(1));
              },
          ),
        );
        return tag;
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: style));
        return nonMatch;
      },
    );

    return RichText(
      text: TextSpan(
        children: spans,
        style: style ?? DefaultTextStyle.of(context).style,
      ),
    );
  }
}
