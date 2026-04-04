import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _navigated = false;
  bool _connectionTested = false;
  bool _showOfflineButton = false;

  @override
  void initState() {
    super.initState();
    
    // Start the bootstrap process
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Set a timer to show offline button after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_navigated) {
        setState(() {
          _showOfflineButton = true;
        });
      }
    });
    
    // Start connection test
    final isConnected = await auth.testConnection();
    _connectionTested = true;
    
    if (!mounted) return;
    
    // If connection succeeds, proceed with normal flow
    if (isConnected) {
      await _proceedWithNavigation();
    } else {
      // If connection fails, show offline button immediately
      if (mounted && !_navigated) {
        setState(() {
          _showOfflineButton = true;
        });
      }
    }
  }

  // Debug function to simulate connection failure for testing
  Future<void> _simulateConnectionFailure() async {
    setState(() {
      _connectionTested = true;
      _showOfflineButton = true;
    });
  }

  Future<void> _proceedWithNavigation() async {
    if (_navigated) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Load user from storage
    await auth.loadUserFromStorage();
    if (!mounted || _navigated) return;
    
    setState(() {
      _navigated = true;
    });

    if (auth.isAuthenticated) {
      final role = auth.currentUser!.role;
      if (!mounted) return;
      if (role.toString().contains('admin')) {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (role.toString().contains('officer')) {
        Navigator.pushReplacementNamed(context, '/officer_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student_dashboard');
      }
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _enterOfflineMode() async {
    // Go directly to the app without showing offline mode screen
    await _proceedWithNavigation();
  }

  Future<void> _retryConnection() async {
    setState(() {
      _navigated = false;
      _connectionTested = false;
      _showOfflineButton = false;
    });
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.clearConnectionCache();
    
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildLoadingScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular loading animation
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Status text
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              String statusText = 'Connecting to server...';
              if (_connectionTested) {
                if (auth.isConnected) {
                  statusText = 'Connected';
                } else {
                  statusText = 'Connection failed';
                }
              }
              
              return Text(
                statusText,
                style: TextStyle(
                  fontSize: 16,
                  color: _connectionTested && !auth.isConnected ? Colors.orange[700] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
          
          // Offline mode button (appears after 5 seconds)
          if (_showOfflineButton) ...[
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _connectionTested ? 'Use offline mode to continue' : 'Taking longer than expected?',
                    style: TextStyle(
                      fontSize: 14,
                      color: _connectionTested ? Colors.orange[700] : Colors.grey[600],
                      fontWeight: _connectionTested ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _enterOfflineMode,
                    icon: const Icon(Icons.offline_bolt),
                    label: const Text('Use Offline Mode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Continue with cached data',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Debug button (remove in production)
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _simulateConnectionFailure,
              child: const Text('Debug: Simulate Connection Failure'),
            ),
          ],
        ],
      ),
    );
  }

}

