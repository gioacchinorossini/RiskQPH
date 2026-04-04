import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/survey_provider.dart';

class SurveyResponsesScreen extends StatefulWidget {
  final String surveyId;
  const SurveyResponsesScreen({super.key, required this.surveyId});

  @override
  State<SurveyResponsesScreen> createState() => _SurveyResponsesScreenState();
}

class _SurveyResponsesScreenState extends State<SurveyResponsesScreen> {
  List<Map<String, dynamic>> _responses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<SurveyProvider>(context, listen: false);
      final data = await provider.fetchResponses(widget.surveyId);
      setState(() {
        _responses = data ?? const [];
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Survey Responses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _responses.isEmpty
              ? const Center(child: Text('No responses'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _responses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final r = _responses[i];
                    final answers = (r['answers'] as List<dynamic>? ?? []);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User: ${r['user_id']}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Submitted: ${r['submitted_at']}'),
                            const SizedBox(height: 8),
                            ...answers.map((a) {
                              final parts = <String>[];
                              if (a['option_text'] != null) parts.add(a['option_text']);
                              if (a['answer_text'] != null) parts.add(a['answer_text']);
                              final display = parts.isEmpty ? '-' : parts.join(' | ');
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('Q${a['question_id']}: $display'),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

