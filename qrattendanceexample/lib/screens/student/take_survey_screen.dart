import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/survey.dart';
import '../../providers/survey_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class TakeSurveyScreen extends StatefulWidget {
  final String surveyId;
  final String eventTitle;

  const TakeSurveyScreen({super.key, required this.surveyId, required this.eventTitle});

  @override
  State<TakeSurveyScreen> createState() => _TakeSurveyScreenState();
}

class _TakeSurveyScreenState extends State<TakeSurveyScreen> {
  Survey? _survey;
  final Map<String, dynamic> _answers = {}; // questionId -> optionIds[] or text
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final surveyProvider = Provider.of<SurveyProvider>(context, listen: false);
    final s = await surveyProvider.fetchSurveyDetails(
      surveyId: widget.surveyId,
      userId: auth.currentUser?.id,
    );
    setState(() {
      _survey = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Survey • ${widget.eventTitle}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _survey == null
              ? const Center(child: Text('Failed to load survey'))
              : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final s = _survey!;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<SurveyProvider>(context);

    if (s.hasSubmitted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 40),
            SizedBox(height: 8),
            Text('You have already submitted this survey.'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (s.description != null && s.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: s.questions.length,
              itemBuilder: (ctx, i) {
                final q = s.questions[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${q.text}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (q.type == 'text')
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Your answer',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              _answers[q.id!] = val;
                            },
                          )
                        else if (q.type == 'single_choice')
                          Column(
                            children: q.options.asMap().entries.map((e) {
                              final opt = e.value;
                              return RadioListTile<String>(
                                title: Text(opt.text),
                                value: opt.id ?? opt.text,
                                groupValue: _answers[q.id!] as String?,
                                onChanged: (val) {
                                  setState(() { _answers[q.id!] = val; });
                                },
                              );
                            }).toList(),
                          )
                        else
                          Column(
                            children: q.options.map((opt) {
                              final selectedList = (_answers[q.id!] as List?) ?? <String>[];
                              final optionId = opt.id ?? opt.text;
                              final isSelected = selectedList.contains(optionId);
                              return CheckboxListTile(
                                title: Text(opt.text),
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    final list = List<String>.from(selectedList);
                                    if (val == true) {
                                      list.add(optionId);
                                    } else {
                                      list.remove(optionId);
                                    }
                                    _answers[q.id!] = list;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : () async {
                // Build answers payload
                final payload = <Map<String, dynamic>>[];
                for (final q in s.questions) {
                  final ans = _answers[q.id!];
                  if (q.type == 'text') {
                    if (ans != null && (ans as String).trim().isNotEmpty) {
                      payload.add({'question_id': q.id, 'answer_text': ans});
                    }
                  } else if (q.type == 'single_choice') {
                    if (ans != null) {
                      payload.add({'question_id': q.id, 'option_ids': [ans]});
                    }
                  } else {
                    final list = (ans as List?)?.whereType<String>().toList() ?? [];
                    if (list.isNotEmpty) {
                      payload.add({'question_id': q.id, 'option_ids': list});
                    }
                  }
                }

                if (payload.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer at least one question.')));
                  return;
                }

                final ok = await provider.submitSurveyResponses(
                  surveyId: s.id,
                  userId: auth.currentUser!.id,
                  answers: payload,
                );
                if (ok && mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey submitted'), backgroundColor: AppTheme.successColor));
                } else if (!ok) {
                  final msg = provider.error ?? 'Failed to submit survey';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: provider.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

