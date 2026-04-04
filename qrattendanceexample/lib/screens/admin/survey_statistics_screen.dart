import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/survey_provider.dart';
import '../../utils/theme.dart';

class SurveyStatisticsScreen extends StatefulWidget {
  final String surveyId;
  const SurveyStatisticsScreen({super.key, required this.surveyId});

  @override
  State<SurveyStatisticsScreen> createState() => _SurveyStatisticsScreenState();
}

class _SurveyStatisticsScreenState extends State<SurveyStatisticsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<SurveyProvider>(context, listen: false);
      final data = await provider.fetchStats(widget.surveyId);
      setState(() {
        _stats = data;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Survey Statistics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('Failed to load statistics'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text('Total submissions: ${_stats!['total_submissions'] ?? 0}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...((_stats!['questions'] as List<dynamic>? ?? [])).map((q) {
                        final type = q['type'];
                        final List<dynamic> options = (q['options'] as List<dynamic>? ?? []);
                        final int totalVotes = options.fold<int>(0, (sum, o) => sum + (o['count'] as int? ?? 0));
                        final int maxVotes = options.fold<int>(0, (m, o) => (o['count'] as int? ?? 0) > m ? (o['count'] as int? ?? 0) : m);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q['text'] ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (type == 'text')
                                  Text('Text answers: ${q['text_answer_count'] ?? 0}')
                                else ...[
                                  _buildOptionBars(context, options, totalVotes, maxVotes),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOptionBars(BuildContext context, List<dynamic> options, int totalVotes, int maxVotes) {
    if (options.isEmpty) {
      return const Text('No options');
    }
    return Column(
      children: options.map((o) {
        final String label = (o['text'] as String?) ?? '';
        final int count = (o['count'] as int?) ?? 0;
        final double percent = (totalVotes > 0) ? (count / totalVotes) : 0.0;
        final double widthFactor = (maxVotes > 0) ? (count / maxVotes) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count'),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double fullWidth = constraints.maxWidth;
                  return Stack(
                    children: [
                      Container(
                        width: fullWidth,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: fullWidth * widthFactor,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${(percent * 100).toStringAsFixed(1)}%'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

