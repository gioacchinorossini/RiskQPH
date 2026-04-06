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
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))))
          else if (_centers.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('No evacuation centers found.')))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final center = _centers[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.black.withOpacity(0.05))),
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                          child: Icon(_getCenterIcon(center['type']), color: const Color(0xFF1B5E20), size: 24),
                        ),
                        title: Text(center['name'].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.2)),
                        subtitle: Text('Capacity: ${center['_count']['evacuees']} / ${center['capacity'] ?? "∞"}', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EvacueeRegistryScreen(center: center)));
                        },
                      ),
                    );
                  },
                  childCount: _centers.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EvacuationQrScannerScreen())),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text('SCAN RESIDENT QR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Colors.white, width: 2)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false, pinned: true,
      backgroundColor: const Color(0xFF1B5E20),
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _fetchCenters),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -20, bottom: -20, child: Icon(Icons.shield_rounded, size: 200, color: Colors.white.withOpacity(0.08))),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EVACUATION', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('DISASTER SHELTER MANAGEMENT', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.domain_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text('${_centers.length} ACTIVE CENTERS', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildCenterAppBar(),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))))
          else if (_evacuees.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('No persons registered yet.')))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final evacuee = _evacuees[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.black.withOpacity(0.05))),
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                          child: Text(evacuee['firstName'][0], style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                        ),
                        title: Text('${evacuee['firstName']} ${evacuee['lastName']}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.2)),
                        subtitle: Text('${evacuee['gender']} • AGE: ${evacuee['age'] ?? "?"}', style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          onPressed: () async {
                            if (await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                title: const Text('DE-REGISTER?'),
                                content: const Text('Remove this person from the active registry?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('REMOVE', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            )) {
                              await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center/residents?id=${evacuee['id']}'));
                              _fetchEvacuees();
                            }
                          },
                        ),
                      ),
                    );
                  },
                  childCount: _evacuees.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCenterAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false, pinned: true,
      backgroundColor: const Color(0xFF1B5E20),
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -20, bottom: -20, child: Icon(Icons.home_work_rounded, size: 200, color: Colors.white.withOpacity(0.08))),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.center['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    const Text('OFFICIAL REGISTRY TERMINAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatChip(Icons.people_alt_rounded, '${_evacuees.length} REGISTERED'),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.door_front_door_rounded, 'CAP ${widget.center['capacity'] ?? "∞"}'),
                      ],
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

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
