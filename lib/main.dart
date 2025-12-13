import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가격 변동 추적',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomeScreen(),
      // 웹에서 모바일 뷰포트 설정
      builder: (context, child) {
        if (kIsWeb) {
          final screenWidth = MediaQuery.of(context).size.width;
          final maxWidth = 600.0;

          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              width: screenWidth > maxWidth ? maxWidth : screenWidth,
              child: child,
            ),
          );
        }
        return child!;
      },
    );
  }
}
