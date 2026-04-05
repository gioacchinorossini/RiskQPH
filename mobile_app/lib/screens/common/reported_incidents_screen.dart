import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../widgets/view_on_map_button.dart';
import '../user/incident_report_screen.dart';

class ReportedIncidentsScreen extends StatefulWidget {
  const ReportedIncidentsScreen({super.key});

  @override
  State<ReportedIncidentsScreen> createState() => _ReportedIncidentsScreenState();
}

class _ReportedIncidentsScreenState extends State<ReportedIncidentsScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/reports'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reports = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reports: $e");
      setState(() => _isLoading = false);
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
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.red)),
            )
          else if (_reports.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildReportCard(_reports[index]),
                  childCount: _reports.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IncidentReportScreen()),
          ).then((value) {
            if (value == true) {
              _fetchReports();
            }
          });
        },
        backgroundColor: Colors.red[900],
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text("REPORT INCIDENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.red[900],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.red[700]!, Colors.red[900]!],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -20,
              child: Icon(Icons.report_gmailerrorred, size: 180, color: Colors.white.withOpacity(0.05)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "REPORTED INCIDENTS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "REAL-TIME CITIZEN INCIDENT LOGS",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(dynamic report) {
    final rep = report as Map<String, dynamic>;
    final String type = rep['type'] ?? 'Unknown';
    final String desc = rep['description'] ?? 'No description provided.';
    final String reporter = rep['reporterName'] ?? 'Anonymous';
    final DateTime createdAt = DateTime.parse(rep['createdAt']);
    final String dateStr = DateFormat('MMM dd, HH:mm').format(createdAt);
    final bool isResolved = rep['isResolved'] == true;

    final IconData icon = _disasterIcons[type] ?? Icons.report_problem;
    final Color color = _disasterColors[type] ?? Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: isResolved ? Colors.green : color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "BY: ${reporter.split(' ')[0].toUpperCase()}",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _showReportDetails(rep),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              "DETAILS",
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ViewOnMapButton(
                            locationData: rep,
                            label: "MAP",
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (_disasterColors[report['type']] ?? Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report['type'].toString().toUpperCase(),
                        style: TextStyle(
                          color: _disasterColors[report['type']] ?? Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      report['type'].toString(),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "REPORT DESCRIPTION",
                      style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report['description'] ?? 'No additional description provided for this incident.',
                      style: TextStyle(color: Colors.grey[800], fontSize: 16, height: 1.6, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (report['imageUrl'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "VISUAL EVIDENCE",
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200, width: 1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Image.network(
                            '${ApiConfig.baseUrl}${report['imageUrl']}',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey[100],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  final Map<String, IconData> _disasterIcons = {
    'Flooding': Icons.water,
    'Fire': Icons.local_fire_department,
    'Collapsed buildings': Icons.home_work,
    'Landslide / soil erosion': Icons.landscape,
    'Volcanic activity': Icons.volcano,
    'Power outage': Icons.power_off,
    'Water supply disruption': Icons.water_damage,
    'Signal failure (cell network down)': Icons.cell_tower,
    'Road blockage / impassable routes': Icons.traffic,
    'Other (custom entry)': Icons.more_horiz,
  };

  final Map<String, Color> _disasterColors = {
    'Flooding': Colors.blue,
    'Fire': Colors.red,
    'Collapsed buildings': Colors.brown,
    'Landslide / soil erosion': Colors.orange,
    'Volcanic activity': Colors.deepOrange,
    'Power outage': Colors.amber,
    'Water supply disruption': Colors.lightBlue,
    'Signal failure (cell network down)': Colors.grey,
    'Road blockage / impassable routes': Colors.deepPurple,
    'Other (custom entry)': Colors.blueGrey,
  };



  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "NO REPORTS YET",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "System status: Secure and operational",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
