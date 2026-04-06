import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class PendingMembersScreen extends StatefulWidget {
  const PendingMembersScreen({super.key});

  @override
  State<PendingMembersScreen> createState() => _PendingMembersScreenState();
}

class _PendingMembersScreenState extends State<PendingMembersScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final headId = context.read<AuthProvider>().currentUser?.id;
    if (headId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/barangay/membership-requests?headId=$headId');
      final response = await http.get(uri, headers: {'ngrok-skip-browser-warning': 'true'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['pending'] as List<dynamic>?) ?? [];
        setState(() {
          _pending = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Could not load requests'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Could not load requests'; _loading = false; });
    }
  }

  Future<void> _decide(String residentId, String decision) async {
    final headId = context.read<AuthProvider>().currentUser?.id;
    if (headId == null) return;
    setState(() => _busyIds.add(residentId));
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/barangay/membership-requests');
      final response = await http.post(
        uri,
        headers: { 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true' },
        body: jsonEncode({ 'headId': headId, 'residentId': residentId, 'decision': decision }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(decision == 'approve' ? 'Member verified' : 'Request declined')));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(residentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_pending.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final r = _pending[i];
                    final id = r['id'] as String;
                    final name = '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'.trim();
                    final busy = _busyIds.contains(id);
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.black.withOpacity(0.05))),
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(name.isEmpty ? 'NEW RESIDENT' : name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.2))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF0D47A1).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Text('PENDING', style: TextStyle(color: Color(0xFF0D47A1), fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(r['email']?.toString() ?? 'No email provided', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                            if (r['address'] != null && r['address'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, color: Colors.grey[400], size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(r['address'].toString(), style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: busy ? null : () => _decide(id, 'reject'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      side: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5, color: Colors.red)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: busy ? null : () => _decide(id, 'approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D47A1),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: busy
                                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('VERIFY MEMBER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                    },
                    childCount: _pending.length,
                  ),
                ),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false, pinned: true,
      backgroundColor: const Color(0xFF0D47A1),
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -20, bottom: -20, child: Icon(Icons.how_to_reg_rounded, size: 200, color: Colors.white.withOpacity(0.08))),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VERIFICATION', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('CITIZEN MEMBERSHIP REQUESTS', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_add_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text('${_pending.length} REQUESTS', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_reg_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text('NO PENDING REQUESTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text('New resident sign-ups will appear here for verification.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
