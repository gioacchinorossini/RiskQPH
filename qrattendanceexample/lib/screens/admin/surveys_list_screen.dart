import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/survey_provider.dart';
import '../../models/event.dart';
import '../../models/survey.dart';
import '../../utils/theme.dart';
import 'survey_details_screen.dart';

class SurveysListScreen extends StatefulWidget {
  const SurveysListScreen({super.key});

  @override
  State<SurveysListScreen> createState() => _SurveysListScreenState();
}

class _SurveysListScreenState extends State<SurveysListScreen> {
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final events = Provider.of<EventProvider>(context, listen: false).events;
      if (events.isNotEmpty) {
        setState(() {
          _selectedEventId = events.first.id;
        });
        Provider.of<SurveyProvider>(context, listen: false).loadSurveysForEvent(events.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    final surveyProvider = Provider.of<SurveyProvider>(context);
    final List<Event> allEvents = [...eventProvider.getActiveEvents(), ...eventProvider.getPastEvents()];
    final List<DropdownMenuItem<String>> eventItems = allEvents
        .map((e) => DropdownMenuItem<String>(
              value: e.id,
              child: Text(e.title, overflow: TextOverflow.ellipsis),
            ))
        .toList();

    final surveys = _selectedEventId == null ? <Survey>[] : surveyProvider.surveysForEvent(_selectedEventId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surveys'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Event:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEventId,
                    items: eventItems,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) async {
                      setState(() { _selectedEventId = val; });
                      if (val != null) {
                        await surveyProvider.loadSurveysForEvent(val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _selectedEventId == null ? null : () async {
                    await surveyProvider.loadSurveysForEvent(_selectedEventId!);
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedEventId == null)
              const Expanded(
                child: Center(child: Text('No events available')),
              )
            else if (surveyProvider.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (surveys.isEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('No surveys for this event', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: surveys.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final s = surveys[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(s.isActive ? Icons.assignment_turned_in : Icons.assignment, color: s.isActive ? AppTheme.successColor : Colors.grey),
                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(s.description ?? 'No description'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SurveyDetailsScreen(surveyId: s.id),
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

