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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/barangay/membership-requests?headId=$headId',
      );
      final response = await http.get(
        uri,
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['pending'] as List<dynamic>?) ?? [];
        setState(() {
          _pending = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load requests';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load requests';
        _loading = false;
      });
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
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'headId': headId,
          'residentId': residentId,
          'decision': decision,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'approve' ? 'Member verified' : 'Request declined',
            ),
          ),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(residentId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member verification'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  )
                : _pending.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 48),
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending requests',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'New resident sign-ups for your barangay will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _pending.length,
                        itemBuilder: (context, i) {
                          final r = _pending[i];
                          final id = r['id'] as String;
                          final name =
                              '${r['firstName'] ?? ''} ${r['middleName'] ?? ''} ${r['lastName'] ?? ''}'
                                  .replaceAll(RegExp(r'\s+'), ' ')
                                  .trim();
                          final busy = _busyIds.contains(id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'Resident' : name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r['email']?.toString() ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (r['address'] != null &&
                                      r['address'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      r['address'].toString(),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => _decide(id, 'reject'),
                                          child: const Text('Decline'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: busy
                                              ? null
                                              : () => _decide(id, 'approve'),
                                          child: busy
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text('Verify'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
