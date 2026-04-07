import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../widgets/view_on_map_button.dart';

class ReportedIncidentsManagementScreen extends StatefulWidget {
  const ReportedIncidentsManagementScreen({super.key});

  @override
  State<ReportedIncidentsManagementScreen> createState() =>
      _ReportedIncidentsManagementScreenState();
}

class _ReportedIncidentsManagementScreenState
    extends State<ReportedIncidentsManagementScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;

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
        final List<dynamic> data = jsonDecode(response.body);
        data.sort((a, b) {
          final dtA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(0);
          final dtB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(0);
          return dtB.compareTo(dtA);
        });
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

  Future<void> _handleReportAction(String id, String action) async {
    try {
      late http.Response response;
      if (action == 'delete') {
        response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/api/reports/$id'),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
      } else {
        response = await http.patch(
          Uri.parse('${ApiConfig.baseUrl}/api/reports/$id'),
          body: json.encode({'action': action}),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        );
      }
      if (response.statusCode == 200) {
        _fetchReports();
        if (mounted) {
          Navigator.pop(context); // Close detail bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Incident ${action == "delete" ? "removed" : action + "d"}',
              ),
              backgroundColor: action == 'delete' ? Colors.red : Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error handling report: $e");
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
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFB71C1C),
                  strokeWidth: 3,
                ),
              ),
            )
          else if (_reports.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 220,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildIncidentCard(_reports[index]),
                  childCount: _reports.length,
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
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF8E0000),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchReports,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8E0000), Color(0xFFB71C1C)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.security,
                  size: 200,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INCIDENT REPORTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reports made by residents',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatsChip(
                          Icons.radar_rounded,
                          '${_reports.where((r) => r['isResolved'] == false).length} Active',
                        ),
                        const SizedBox(width: 12),
                        _buildStatsChip(
                          Icons.check_circle_outline_rounded,
                          '${_reports.where((r) => r['isResolved'] == true).length} Resolved',
                        ),
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

  Widget _buildStatsChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(dynamic report) {
    final rep = report as Map<String, dynamic>;
    final String type = rep['type'] ?? 'Unknown';
    final bool isResolved = rep['isResolved'] == true;
    final bool isFalse = rep['isFalseInfo'] == true;
    final Color color = _disasterColors[type] ?? Colors.red;
    final IconData icon = _disasterIcons[type] ?? Icons.report_problem;
    String timeStr = '';
    try {
      if (rep['createdAt'] != null) {
        final dt = DateTime.parse(rep['createdAt']);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60)
          timeStr = '${diff.inMinutes}M';
        else if (diff.inHours < 24)
          timeStr = '${diff.inHours}H';
        else
          timeStr = '${diff.inDays}D';
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetails(rep),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isResolved
                                    ? Colors.green
                                    : (isFalse ? Colors.orange : color))
                                .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (isResolved
                                      ? Colors.green
                                      : (isFalse ? Colors.orange : color))
                                  .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        isResolved
                            ? 'RESOLVED'
                            : (isFalse ? 'FALSE' : 'ACTIVE'),
                        style: TextStyle(
                          color: (isResolved
                              ? Colors.green
                              : (isFalse ? Colors.orange : color)),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeStr.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isResolved ? Colors.green : color,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isResolved ? Colors.green : color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Color(0xFF263238),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ViewOnMapButton(
                  locationData: rep,
                  label: "TRACK",
                  isPrimary: true,
                ),
                const SizedBox(height: 10),
                Text(
                  "press for more".toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final String type = report['type'] ?? 'Unknown';
    final Color color = _disasterColors[type] ?? Colors.red;
    final IconData icon = _disasterIcons[type] ?? Icons.report_problem;
    final bool isResolved = report['isResolved'] == true;
    final bool isFalse = report['isFalseInfo'] == true;
    final String reporter = report['reporterName'] ?? 'Anonymous';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isResolved ? Colors.green : color,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isResolved ? Colors.green : color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isResolved ? 'RESOLVED' : 'ACTIVE INCIDENT',
                                style: TextStyle(
                                  color: (isResolved ? Colors.green : color)
                                      .withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Reporter'),
                      subtitle: Text(reporter.toUpperCase()),
                    ),
                    const Divider(),
                    const Text(
                      "INCIDENT DESCRIPTION",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report['description'] ?? 'No description provided.',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (report['imageUrl'] != null) ...[
                      const SizedBox(height: 32),
                      const Text(
                        "VISUAL EVIDENCE",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          '${ApiConfig.baseUrl}${report['imageUrl']}',
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      "COMMAND ACTIONS",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons (Uniform Style)
                    if (!isResolved)
                      _buildManagementButton(
                        label: "MARK AS RESOLVED",
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        onPressed: () =>
                            _handleReportAction(report['id'], 'resolve'),
                      ),
                    const SizedBox(height: 12),
                    if (!isFalse)
                      _buildManagementButton(
                        label: "REPORT AS FALSE INFORMATION",
                        icon: Icons.flag_outlined,
                        color: Colors.orange,
                        onPressed: () =>
                            _handleReportAction(report['id'], 'flag'),
                      ),
                    const SizedBox(height: 12),
                    _buildManagementButton(
                      label: "REMOVE INCIDENT REPORT",
                      icon: Icons.delete_forever_rounded,
                      color: Colors.red,
                      onPressed: () =>
                          _handleReportAction(report['id'], 'delete'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text(
                          'CLOSE PANEL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.08),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
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
