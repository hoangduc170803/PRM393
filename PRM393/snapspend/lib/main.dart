import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapspend/pages/welcome_page.dart';
import 'package:snapspend/pages/expenses_summary_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final ocrService = OcrService();
  // await ocrService.llamaService.checkModelExists();

  // final result = await ocrService.llamaService.generateText(
  //   prompt:
  //       'Extract receipt information from the following Vietnamese text and output ONLY valid JSON with English keys.Receipt OCR text:Chuyển tiền thành công | 18/10/2025 19:45 Người gửi: Nguyễn Văn A Ngân hàng: Vietcombank Người nhận: Công ty TNHH B Số tiền: 81,000 VND Phí giao dịch: 0 VND',
  //   // 'who are you?',
  //   onStatusUpdate: (s) => print(s),
  //   onTextUpdate: (t) => print('Generated: $t'),
  //   maxTokens: 512,
  // );

  // print('Final result: $result');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const appBackground = Color(0xFF0A1A2F);
    return MaterialApp(
      title: 'Llama FFI Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: appBackground,
        canvasColor: appBackground,
        useMaterial3: true,
      ),
      home: const _AppStartRouter(),
    );
  }
}

class _AppStartRouter extends StatelessWidget {
  const _AppStartRouter();

  Future<bool> _isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('onboarding_complete') ?? false;
    return !complete;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFirstRun(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1A2F),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
            ),
          );
        }

        final isFirstRun = snapshot.data!;
        return isFirstRun ? const WelcomePage() : const ExpensesSummaryPage();
      },
    );
  }
}
