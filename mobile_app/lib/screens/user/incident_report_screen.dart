import 'package:flutter/material.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  String? _selectedType;
  final TextEditingController _customDescriptionController = TextEditingController();
  final TextEditingController _otherTypeController = TextEditingController();

  final List<Map<String, dynamic>> _incidentTypes = [
    {'label': 'Flooding', 'icon': Icons.water, 'color': Colors.blue},
    {'label': 'Fire', 'icon': Icons.local_fire_department, 'color': Colors.red},
    {'label': 'Collapsed buildings', 'icon': Icons.home_work, 'color': Colors.brown},
    {'label': 'Landslide / soil erosion', 'icon': Icons.landscape, 'color': Colors.orange},
    {'label': 'Volcanic activity', 'icon': Icons.volcano, 'color': Colors.deepOrange},
    {'label': 'Power outage', 'icon': Icons.power_off, 'color': Colors.amber},
    {'label': 'Water supply disruption', 'icon': Icons.water_damage, 'color': Colors.lightBlue},
    {'label': 'Signal failure (cell network down)', 'icon': Icons.cell_tower, 'color': Colors.grey},
    {'label': 'Road blockage / impassable routes', 'icon': Icons.traffic, 'color': Colors.deepPurple},
    {'label': 'Other (custom entry)', 'icon': Icons.more_horiz, 'color': Colors.blueGrey},
  ];

  @override
  void dispose() {
    _customDescriptionController.dispose();
    _otherTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Incident Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'What kind of emergency or incident are you reporting?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Circular Grid selection
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 15,
                childAspectRatio: 0.85,
              ),
              itemCount: _incidentTypes.length,
              itemBuilder: (context, index) {
                final type = _incidentTypes[index];
                final isSelected = _selectedType == type['label'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = type['label'];
                    });
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? type['color'] : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: isSelected 
                              ? type['color'].withOpacity(0.1) 
                              : Colors.grey[100],
                          child: Icon(
                            type['icon'],
                            color: isSelected ? type['color'] : Colors.grey[600],
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        type['label'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            if (_selectedType == 'Other (custom entry)') ...[
              const Text(
                'Specify Other Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _otherTypeController,
                decoration: InputDecoration(
                  hintText: 'e.g., Gas leak, Chemical spill...',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              'Additional Details (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customDescriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Provide more information to help responders (e.g., location specifics, immediate danger level)...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedType == null ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType == 'Other' ? Colors.blueGrey : 
                      (_selectedType != null ? _incidentTypes.firstWhere((t) => t['label'] == _selectedType)['color'] : primaryColor),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'SUBMIT INCIDENT REPORT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport() {
    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Submitted'),
        content: const Text('Responders have been notified of this incident. Please stay safe.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
