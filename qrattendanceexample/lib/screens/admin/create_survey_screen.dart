import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/survey.dart';
import '../../models/event.dart';
import '../../providers/survey_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class CreateSurveyScreen extends StatefulWidget {
  final Event event;

  const CreateSurveyScreen({super.key, required this.event});

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<SurveyQuestion> _questions = [];

  void _addQuestion() {
    setState(() {
      _questions.add(SurveyQuestion(text: '', type: 'single_choice', options: []));
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final surveyProvider = Provider.of<SurveyProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Survey'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Survey Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Question'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_questions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('No questions yet. Add one to get started.'),
                ),
              ..._questions.asMap().entries.map((entry) {
                final index = entry.key;
                final q = entry.value;
                final textController = TextEditingController(text: q.text);
                String selectedType = q.type;
                final List<TextEditingController> optionControllers = q.options.map((o) => TextEditingController(text: o.text)).toList();

                return StatefulBuilder(
                  builder: (context, setInner) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: textController,
                                    decoration: const InputDecoration(
                                      labelText: 'Question text',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      _questions[index] = _questions[index].copyWith(text: val);
                                    },
                                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter question' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: selectedType,
                                  items: const [
                                    DropdownMenuItem(value: 'single_choice', child: Text('Single choice')),
                                    DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple choice')),
                                    DropdownMenuItem(value: 'text', child: Text('Text')),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setInner(() => selectedType = val);
                                    _questions[index] = _questions[index].copyWith(type: val, options: val == 'text' ? [] : _questions[index].options);
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _removeQuestion(index),
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                ),
                              ],
                            ),
                            if (selectedType != 'text') ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...optionControllers.asMap().entries.map((optEntry) {
                                    final optIndex = optEntry.key;
                                    final optController = optEntry.value;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 220,
                                          child: TextFormField(
                                            controller: optController,
                                            decoration: const InputDecoration(
                                              labelText: 'Option',
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              final updatedOptions = List<SurveyOption>.from(_questions[index].options);
                                              updatedOptions[optIndex] = SurveyOption(text: val);
                                              _questions[index] = _questions[index].copyWith(options: updatedOptions);
                                            },
                                            validator: (value) {
                                              if (selectedType != 'text' && (value == null || value.trim().isEmpty)) return 'Required';
                                              return null;
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            final updatedOptions = List<SurveyOption>.from(_questions[index].options);
                                            updatedOptions.removeAt(optIndex);
                                            setInner(() {
                                              optionControllers.removeAt(optIndex);
                                              _questions[index] = _questions[index].copyWith(options: updatedOptions);
                                            });
                                          },
                                          icon: const Icon(Icons.close, size: 18),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setInner(() {
                                        optionControllers.add(TextEditingController());
                                        final updatedOptions = List<SurveyOption>.from(_questions[index].options)..add(SurveyOption(text: ''));
                                        _questions[index] = _questions[index].copyWith(options: updatedOptions);
                                      });
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add option'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: surveyProvider.isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          final title = _titleController.text.trim();
                          final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
                          final createdBy = auth.currentUser?.id ?? '';
                          if (createdBy.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('You must be logged in')), 
                            );
                            return;
                          }

                          // Validate options for choice questions
                          for (final q in _questions) {
                            if (q.type != 'text' && q.options.where((o) => o.text.trim().isNotEmpty).length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Each choice question needs at least 2 options.')),
                              );
                              return;
                            }
                          }

                          final ok = await surveyProvider.createSurvey(
                            eventId: widget.event.id,
                            title: title,
                            description: description,
                            createdBy: createdBy,
                            questions: _questions,
                          );
                          if (ok) {
                            if (mounted) {
                              Navigator.of(context).pop(true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Survey created'),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            }
                          } else {
                            final msg = surveyProvider.error ?? 'Failed to create survey';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          }
                        },
                  child: surveyProvider.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Survey'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

