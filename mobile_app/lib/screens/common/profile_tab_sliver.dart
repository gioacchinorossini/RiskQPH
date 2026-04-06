import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../../widgets/barangay_verification_section.dart';
import '../user/edit_profile_screen.dart';
import 'settings_screen.dart';

/// Shared Profile tab content for resident, responder, and barangay head dashboards.
class ProfileTabSliver extends StatelessWidget {
  final User? user;
  final VoidCallback onLogout;
  /// Matches each dashboard’s primary theme (buttons / accents).
  final Color actionColor;

  const ProfileTabSliver({
    super.key,
    required this.user,
    required this.onLogout,
    required this.actionColor,
  });

  static String roleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.barangay_head:
        return 'Barangay Head';
      case UserRole.responder:
        return 'Emergency Responder';
      case UserRole.resident:
        return 'Resident';
      case UserRole.student:
        return 'Student';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.officer:
        return 'Officer';
    }
  }

  static IconData _roleAvatarIcon(UserRole role) {
    switch (role) {
      case UserRole.barangay_head:
        return Icons.admin_panel_settings_outlined;
      case UserRole.responder:
        return Icons.health_and_safety_outlined;
      case UserRole.resident:
      case UserRole.student:
        return Icons.person_outline;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (user?.name ?? '').trim().isEmpty ? 'User' : user!.name;
    final email = user?.email ?? '';
    final role = user?.role ?? UserRole.resident;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  actionColor,
                  Color.lerp(actionColor, AppTheme.secondaryColor, 0.35) ??
                      AppTheme.secondaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _roleAvatarIcon(role),
                    size: 40,
                    color: actionColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleDisplayName(role),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (role == UserRole.resident) ...[
            Text(
              'Barangay verification',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            const BarangayVerificationSection(),
            const SizedBox(height: 20),
          ],
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _infoRow(context, 'Role', roleDisplayName(role)),
                  if (user?.barangay != null && user!.barangay!.trim().isNotEmpty)
                    _infoRow(context, 'Barangay', user!.barangay!.trim()),
                  if (user?.address != null && user!.address!.trim().isNotEmpty)
                    _infoRow(context, 'Address', user!.address!.trim()),
                  if (user?.studentId != null && user!.studentId!.trim().isNotEmpty)
                    _infoRow(context, 'ID', user!.studentId!.trim()),
                  _infoRow(
                    context,
                    'Member since',
                    user?.createdAt != null
                        ? dateFormat.format(user!.createdAt)
                        : '—',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: actionColor),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings_outlined, color: actionColor),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: onLogout,
            ),
          ),
          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
