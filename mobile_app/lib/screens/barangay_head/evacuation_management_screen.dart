import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';

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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();
  String _gender = 'Male';

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

  Future<void> _registerEvacuee() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) return;
    
    final user = context.read<AuthProvider>().currentUser;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center/register'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'evacuationCenterId': widget.center['id'],
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'age': _ageController.text,
          'gender': _gender,
          'medicalNotes': _notesController.text,
          'addedById': user!.id,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _firstNameController.clear();
        _lastNameController.clear();
        _ageController.clear();
        _notesController.clear();
        _fetchEvacuees();
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      debugPrint('Error registering evacuee: $e');
    }
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REGISTER RESCUED PERSON'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _gender,
                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _gender = val!),
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Medical Notes'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _registerEvacuee, child: const Text('Register')),
        ],
      ),
    );
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
                    child: ElevatedButton.icon(
                      onPressed: _showRegisterDialog,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('REGISTER RESCUED PERSON'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
