import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kshqjckdahhiqniphppd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzaHFqY2tkYWhoaXFuaXBocHBkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0Nzg5MjIsImV4cCI6MjA3MjA1NDkyMn0.4XOlS4rBLhbIbwhrThb_NREuQ6ytPpx2wiRx-UmC-cw', // replace with your Supabase anon key
  );

  await Hive.initFlutter();
  await Hive.openBox('missing_local');
  await Hive.openBox('found_local');

  final session = Supabase.instance.client.auth.currentSession;
  final startRoute = (session == null) ? AppRoutes.AUTH : '/';

  runApp(MyApp(initialRoute: startRoute));

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.signedIn) {
      Get.offAllNamed('/');
    } else if (event == AuthChangeEvent.signedOut) {
      Get.offAllNamed(AppRoutes.AUTH);
    }
  });
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SAWT - Family Reconnection',
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      debugShowCheckedModeBanner: false,
    );
  }
}
