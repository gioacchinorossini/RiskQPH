import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import 'evacuation_qr_scanner_screen.dart';

class EvacuationManagementScreen extends StatefulWidget {
  const EvacuationManagementScreen({super.key});

  @override
  State<EvacuationManagementScreen> createState() => _EvacuationManagementScreenState();
}

class _EvacuationManagementScreenState extends State<EvacuationManagementScreen> {
  List<dynamic> _centers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCenters();
  }

  Future<void> _fetchCenters() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.barangay == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center?barangay=${user!.barangay}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _centers = data['centers'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching ECs: $e');
      setState(() => _isLoading = false);
    }
  }


  IconData _getCenterIcon(String? type) {
    switch (type) {
      case 'Building': return Icons.domain;
      case 'Home': return Icons.home;
      case 'Medical': return Icons.monitor_heart;
      case 'School': return Icons.school;
      case 'Church': return Icons.church;
      case 'Activity': return Icons.query_stats;
      default: return Icons.account_balance;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('EVACUATION CENTERS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan resident QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EvacuationQrScannerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: _centers.isEmpty
                        ? const Center(child: Text('No evacuation centers found.'))
                        : ListView.builder(
                            itemCount: _centers.length,
                            itemBuilder: (context, index) {
                              final center = _centers[index];
                              return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green,
                                    child: Icon(_getCenterIcon(center['type']), color: Colors.white),
                                  ),
                                  title: Text(center['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Capacity: ${center['_count']['evacuees']} / ${center['capacity'] ?? "∞"}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EvacueeRegistryScreen(center: center),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class EvacueeRegistryScreen extends StatefulWidget {
  final Map<String, dynamic> center;
  const EvacueeRegistryScreen({super.key, required this.center});

  @override
  State<EvacueeRegistryScreen> createState() => _EvacueeRegistryScreenState();
}

class _EvacueeRegistryScreenState extends State<EvacueeRegistryScreen> {
  List<dynamic> _evacuees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvacuees();
  }

  Future<void> _fetchEvacuees() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center/residents?evacuationCenterId=${widget.center['id']}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _evacuees = data['evacuees'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching evacuees: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.center['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('EVACUEE REGISTRY', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, letterSpacing: 1.5)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(label: 'Total Registered', value: '${_evacuees.length}', color: Colors.blue),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Capacity', value: '${widget.center['capacity'] ?? "∞"}', color: Colors.grey),
                    ],
                  ),
                ),
                Expanded(
                  child: _evacuees.isEmpty
                      ? const Center(child: Text('No persons registered yet.'))
                      : ListView.builder(
                          itemCount: _evacuees.length,
                          itemBuilder: (context, index) {
                            final evacuee = _evacuees[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(evacuee['firstName'][0], style: const TextStyle(color: Colors.blue)),
                              ),
                              title: Text('${evacuee['firstName']} ${evacuee['lastName']}'),
                              subtitle: Text('${evacuee['gender']} • Age: ${evacuee['age'] ?? "?"}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  if (await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm De-registration'),
                                      content: const Text('Are you sure you want to remove this person from the registry?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  )) {
                                    await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center/residents?id=${evacuee['id']}'));
                                    _fetchEvacuees();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Resident evacuees are registered only by scanning their personal QR in the evacuation scanner. Registration syncs across the app for all users.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EvacuationQrScannerScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('OPEN QR SCANNER'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
