import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/offline_indicator.dart';

class OfflineDemoScreen extends StatelessWidget {
  const OfflineDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode Demo'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: OfflineIndicator(
        onRefresh: () async {
          // Refresh connection
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.refreshConnection();
        },
        child: RefreshIndicator(
          onRefresh: () async {
            // Refresh data
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.refreshConnection();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Offline Mode Features',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            '🔄 Pull to Refresh',
                            'Pull down from the top to attempt reconnection',
                          ),
                          _buildFeatureItem(
                            '📱 Offline Indicator',
                            'Orange bar at the top shows when you\'re offline',
                          ),
                          _buildFeatureItem(
                            '💾 Cached Data',
                            'App continues to work with cached data when offline',
                          ),
                          _buildFeatureItem(
                            '⚡ Quick Sync',
                            'Tap the "Sync" button in the offline bar to reconnect',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to Test',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            '1. Disconnect from internet',
                            'Turn off WiFi or mobile data',
                          ),
                          _buildFeatureItem(
                            '2. Restart the app',
                            'You\'ll see the loading screen with offline option',
                          ),
                          _buildFeatureItem(
                            '3. Try offline features',
                            'The app will work with cached data',
                          ),
                          _buildFeatureItem(
                            '4. Reconnect',
                            'Pull down to refresh or tap sync button',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await authProvider.testConnection();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                authProvider.isConnected 
                                  ? 'Connected to server!' 
                                  : 'Connection failed - offline mode active',
                              ),
                              backgroundColor: authProvider.isConnected 
                                ? Colors.green 
                                : Colors.orange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.wifi),
                      label: const Text('Test Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Extra space for pull to refresh
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 