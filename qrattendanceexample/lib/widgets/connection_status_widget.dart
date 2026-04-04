import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final bool showRetryButton;
  final VoidCallback? onRetry;

  const ConnectionStatusWidget({
    super.key,
    this.showRetryButton = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isConnected) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi,
                  size: 16,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 6),
                Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off,
                size: 16,
                color: Colors.red[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Disconnected',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showRetryButton) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRetry ?? () => auth.refreshConnection(),
                  child: Icon(
                    Icons.refresh,
                    size: 14,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ConnectionErrorDialog extends StatelessWidget {
  final String? customMessage;

  const ConnectionErrorDialog({
    super.key,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.red),
          SizedBox(width: 8),
          Text('Connection Error'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customMessage ?? 'Unable to connect to the server. Please check your network connection.',
          ),
          const SizedBox(height: 16),
          Text(
            'Server URL:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          Text(
            ApiConfig.baseUrl,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Provider.of<AuthProvider>(context, listen: false).refreshConnection();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }
} 