import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

/// Barangay membership verification status (replaces old "History" tab for residents).
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final User? user = auth.currentUser;
        final status = user?.barangayMemberStatus ?? 'verified';
        final barangay = user?.barangay;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Track your barangay membership request.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await auth.refreshCurrentUser();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatusCard(
              status: status,
              barangay: barangay,
              address: user?.address,
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 20),
              Text(
                'What happens next',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your barangay captain will review your registration. '
                'Tap Refresh after they approve or decline.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final String? barangay;
  final String? address;

  const _StatusCard({
    required this.status,
    this.barangay,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color accent;
    final String title;
    final String subtitle;

    switch (status) {
      case 'pending':
        icon = Icons.hourglass_top_rounded;
        accent = AppTheme.warningColor;
        title = 'Awaiting verification';
        subtitle =
            'Your request for ${barangay ?? "your barangay"} is with the barangay captain.';
        break;
      case 'rejected':
        icon = Icons.cancel_outlined;
        accent = AppTheme.errorColor;
        title = 'Not verified';
        subtitle =
            'Your barangay captain did not verify this account for ${barangay ?? "the selected barangay"}. '
            'You may contact the barangay hall for help.';
        break;
      default:
        icon = Icons.verified_outlined;
        accent = AppTheme.successColor;
        title = 'Verified member';
        subtitle =
            'You are recognized as a member of ${barangay ?? "your barangay"}.';
    }

    return Card(
      elevation: 0,
      color: accent.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
            ),
            if (address != null && address!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Address on file',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                address!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
