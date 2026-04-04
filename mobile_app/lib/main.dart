import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/auth_provider.dart';
import 'utils/theme.dart';
import 'screens/common/startup_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/student/student_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_US';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Attendance App',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/startup',
        routes: {
          '/startup': (context) => const StartupScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/student_dashboard': (context) => const StudentDashboard(),
        },
      ),
    );
  }
}

