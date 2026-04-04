import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/offline_indicator.dart';

class SimpleOfflineExample extends StatelessWidget {
  const SimpleOfflineExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Offline Example'),
        backgroundColor: Colors.blue,
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Offline Mode Active'),
                  subtitle: const Text('This screen shows the offline indicator when disconnected'),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.wifi),
                  title: const Text('Connection Status'),
                  subtitle: Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return Text(
                        auth.isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color: auth.isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Pull to Refresh'),
                  subtitle: const Text('Pull down from the top to attempt reconnection'),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Quick Sync'),
                  subtitle: const Text('Tap the sync button in the offline bar'),
                ),
              ),
              const SizedBox(height: 100), // Extra space for pull to refresh
            ],
          ),
        ),
      ),
    );
  }
} 