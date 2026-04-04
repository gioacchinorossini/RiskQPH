import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/survey_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/officer/officer_dashboard.dart';
import 'utils/theme.dart';
import 'screens/common/startup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_US';
  final preloadedAuth = AuthProvider();
  await preloadedAuth.loadUserFromStorage();
  runApp(AttendanceApp(preloadedAuth: preloadedAuth));
}

class AttendanceApp extends StatelessWidget {
  final AuthProvider preloadedAuth;

  const AttendanceApp({super.key, required this.preloadedAuth});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: preloadedAuth),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
      ],
      child: MaterialApp(
        title: 'Attendance App',
        locale: const Locale('en', 'US'),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/startup',
        routes: {
          '/startup': (context) => const StartupScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/student_dashboard': (context) => const StudentDashboard(),
          '/admin_dashboard': (context) => const AdminDashboard(),
          '/officer_dashboard': (context) => const OfficerDashboard(),
        },
      ),
    );
  }
} 