import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    debugPrint('Startup: Bootstrapping application...');
    
    // 1. Load user from storage FIRST (highest priority)
    await auth.loadUserFromStorage();
    
    // 2. Test connection in background or with a timeout
    // We don't necessarily want to block the entire UI if connection is slow
    // but we check it here for initial status
    await auth.testConnection();

    if (!mounted || _navigated) return;
    
    setState(() {
      _navigated = true;
    });

    if (auth.isAuthenticated) {
      debugPrint('Startup: User is authenticated, navigating to dashboard...');
      final role = auth.currentUser!.role.toString();
      if (role.contains('barangay_head')) {
        Navigator.pushNamedAndRemoveUntil(context, '/barangay_head_dashboard', (route) => false);
      } else if (role.contains('responder')) {
        Navigator.pushNamedAndRemoveUntil(context, '/responder_dashboard', (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/user_dashboard', (route) => false);
      }
    } else {
      debugPrint('Startup: User not authenticated, navigating to login...');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

