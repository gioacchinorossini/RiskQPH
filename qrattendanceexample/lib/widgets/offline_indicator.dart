import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class OfflineIndicator extends StatelessWidget {
  final VoidCallback? onRefresh;
  final Widget child;

  const OfflineIndicator({
    super.key,
    this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Only show offline indicator if not connected
        if (auth.isConnected) {
          return child;
        }

        return Column(
          children: [
            // Offline mode indicator bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.offline_bolt,
                    color: Colors.orange[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Using cached data',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (onRefresh != null) ...[
                    GestureDetector(
                      onTap: onRefresh,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[700],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sync',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
} 