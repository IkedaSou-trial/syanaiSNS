import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/category_selection_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/search_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toragram',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],

        // フォント設定
        textTheme: GoogleFonts.notoSansJpTextTheme(Theme.of(context).textTheme),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // ▼▼▼ 追加: SnackBar（通知バー）のデザイン設定 ▼▼▼
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating, // 浮かせる
          backgroundColor: Colors.grey[900], // 濃いグレー
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            // 角丸にする
            borderRadius: BorderRadius.circular(8),
          ),
          insetPadding: const EdgeInsets.all(16), // 画面端からの余白
        ),
        // ▲▲▲ 追加ここまで ▲▲▲
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/create_post': (context) => const CreatePostScreen(),
        '/category_selection': (context) => const CategorySelectionScreen(),
        '/signup': (context) => const SignupScreen(),
        '/search': (context) => const SearchScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final currentUser =
              settings.arguments as Map<String, dynamic>? ??
              {
                'username': 'test_user',
                'displayName': 'テスト店長',
                'storeCode': '001',
              };

          return MaterialPageRoute(
            builder: (context) => MainScreen(currentUser: currentUser),
          );
        }
        if (settings.name == '/post_detail') {
          // post 引数を渡すのをやめる
          return MaterialPageRoute(
            builder: (context) => const PostDetailScreen(),
            settings:
                settings, // 👈 重要: これを渡すことで、詳細画面内で arguments が取得できるようになります
          );
        }
        if (settings.name == '/profile') {
          final username = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ProfileScreen(username: username),
          );
        }
        return null;
      },
    );
  }
}
