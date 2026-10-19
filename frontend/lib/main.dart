import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'core/utils.dart';
import 'pages/login_page.dart';
import 'pages/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const WayaApp()));
}

class WayaApp extends StatelessWidget {
  const WayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'JPX Finance',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: !s.ready
            ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Palette.brand)))
            : (s.loggedIn ? const Shell(key: ValueKey('shell')) : const LoginPage(key: ValueKey('login'))),
      ),
    );
  }
}
