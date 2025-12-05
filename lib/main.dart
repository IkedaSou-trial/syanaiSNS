import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart'; // MainScreenをインポート
import 'screens/create_post_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '店舗VMD共有',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/create_post': (context) => const CreatePostScreen(),
        // ⚠️ 重要: ここに '/home': ... があると下部タブが表示されません。
        // 必ず onGenerateRoute 側に任せるために削除してください。
      },
      onGenerateRoute: (settings) {
        // '/home' に遷移する時、ここが呼ばれます
        if (settings.name == '/home') {
          // ログイン画面から渡されたユーザー情報を受け取る
          final currentUser =
              settings.arguments as Map<String, dynamic>? ??
              {
                'username': 'test_user',
                'displayName': 'テスト店長',
                'storeCode': '001',
              };

          return MaterialPageRoute(
            // ここで MainScreen（下部タブ付き）を表示します
            builder: (context) => MainScreen(currentUser: currentUser),
          );
        }
        if (settings.name == '/post_detail') {
          final post = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: post),
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
