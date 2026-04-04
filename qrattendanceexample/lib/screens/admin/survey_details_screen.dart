import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/survey_provider.dart';
import '../../models/survey.dart';
import 'survey_statistics_screen.dart';
import 'survey_responses_screen.dart';

class SurveyDetailsScreen extends StatefulWidget {
  final String surveyId;
  const SurveyDetailsScreen({super.key, required this.surveyId});

  @override
  State<SurveyDetailsScreen> createState() => _SurveyDetailsScreenState();
}

class _SurveyDetailsScreenState extends State<SurveyDetailsScreen> {
  Survey? _survey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<SurveyProvider>(context, listen: false);
      final s = await provider.fetchSurveyDetails(surveyId: widget.surveyId);
      setState(() {
        _survey = s;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'View Statistics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SurveyStatisticsScreen(surveyId: widget.surveyId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Responses',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SurveyResponsesScreen(surveyId: widget.surveyId),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _survey == null
              ? const Center(child: Text('Failed to load survey'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text(_survey!.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      if ((_survey!.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_survey!.description!),
                      ],
                      const SizedBox(height: 16),
                      Text('Questions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._survey!.questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final q = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${index + 1}. ${q.text}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Type: ${q.type}'),
                                if (q.options.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text('Options:'),
                                  const SizedBox(height: 4),
                                  ...q.options.map((o) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text('• ${o.text}'),
                                      )),
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
}

