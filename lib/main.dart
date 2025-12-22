import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'theme/custom_colors.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 파스텔 배경색 (폴센트 스타일)
  static const Color _backgroundColor = Color(0xFFF2F4F7);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하우머치',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        extensions: const <ThemeExtension<dynamic>>[
          CustomColors(
            priceUp: Color(0xFF34C759),
            priceDown: Color(0xFFFF453A),
          ),
        ],
      ),
      home: const HomeScreen(),
      // 데스크탑/웹에서 모바일 스타일 레이아웃
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        const maxWidth = 480.0;

        // 화면이 충분히 넓으면 모바일 스타일 적용
        if (screenWidth > maxWidth + 40) {
          return Container(
            color: _backgroundColor,
            child: Center(
              child: Container(
                width: maxWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          );
        }
        return child!;
      },
    );
  }
}
