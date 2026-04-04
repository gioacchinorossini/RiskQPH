import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import '../admin/event_details_screen.dart';

class CalendarEventsScreen extends StatefulWidget {
  const CalendarEventsScreen({Key? key}) : super(key: key);

  @override
  State<CalendarEventsScreen> createState() => _CalendarEventsScreenState();
}

class _CalendarEventsScreenState extends State<CalendarEventsScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  Map<DateTime, List<Event>> _events = {};
  final ScrollController _dateScrollController = ScrollController();
  bool _showFullCalendar = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
      _scrollToSelectedDate();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _loadEvents() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check connection status and load events accordingly
    if (authProvider.isConnected) {
      await eventProvider.loadEvents();
    } else {
      await eventProvider.loadEventsFromCache();
    }
    
    final events = eventProvider.events;
    
    // Group events by date
    _events.clear();
    for (final event in events) {
      final date = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      if (_events[date] == null) _events[date] = [];
      _events[date]!.add(event);
    }
    
    setState(() {});
  }

  void _scrollToSelectedDate() {
    final today = DateTime.now();
    final allDates = _getAllDates();
    final todayIndex = allDates.indexWhere((date) => 
      date.year == today.year && date.month == today.month && date.day == today.day);
    
    if (todayIndex != -1) {
      final itemWidth = 72.0; // 60 (container width) + 12 (margin)
      final offset = todayIndex * itemWidth;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dateScrollController.hasClients) {
          // Calculate center position to show current date in the middle
          final screenWidth = MediaQuery.of(context).size.width;
          final centerOffset = (screenWidth / 2) - (60 / 2); // Center the 60px container
          final finalOffset = offset - centerOffset;
          
          _dateScrollController.animateTo(
            finalOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  List<Event> _getEventsForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _events[normalizedDate] ?? [];
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _focusedDate = date;
    });
    _scrollToDate(date);
  }

  void _scrollToDate(DateTime date) {
    final allDates = _getAllDates();
    final dateIndex = allDates.indexWhere((d) => 
      d.year == date.year && d.month == date.month && d.day == date.day);
    
    if (dateIndex != -1) {
      final itemWidth = 72.0; // 60 (container width) + 12 (margin)
      final offset = dateIndex * itemWidth;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dateScrollController.hasClients) {
          // Calculate center position to show selected date in the middle
          final screenWidth = MediaQuery.of(context).size.width;
          final centerOffset = (screenWidth / 2) - (60 / 2); // Center the 60px container
          final finalOffset = offset - centerOffset;
          
          _dateScrollController.animateTo(
            finalOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return date.year == _selectedDate.year && 
           date.month == _selectedDate.month && 
           date.day == _selectedDate.day;
  }

  List<DateTime> _getAllDates() {
    final now = DateTime.now();
    final startDate = DateTime(now.year - 1, 1, 1); // Start from last year
    final endDate = DateTime(now.year + 1, 12, 31); // End next year
    
    List<DateTime> dates = [];
    DateTime currentDate = startDate;
    
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          if (eventProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (eventProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading events',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventProvider.error!,
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      if (authProvider.isConnected) {
                        await eventProvider.loadEvents();
                      } else {
                        await eventProvider.loadEventsFromCache();
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Title
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMMM dd, yyyy').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isToday(_selectedDate) ? 'Today' : DateFormat('EEEE').format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Profile Picture Placeholder
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                                         const SizedBox(height: 20),
                     
                     // Calendar Toggle Button
                     Row(
                       children: [
                         Expanded(
                           child: Text(
                             'Date Picker',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.w600,
                               color: Colors.black,
                             ),
                           ),
                         ),
                         GestureDetector(
                           onTap: () {
                             setState(() {
                               _showFullCalendar = !_showFullCalendar;
                             });
                           },
                           child: Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(
                               color: Colors.grey[100],
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Icon(
                               _showFullCalendar ? Icons.view_agenda : Icons.calendar_today,
                               color: Colors.black,
                               size: 20,
                             ),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 16),
                     
                     // Calendar View
                     if (_showFullCalendar) ...[
                       _buildFullCalendar(),
                     ] else ...[
                       // Horizontal Date Picker - Full Year
                       SizedBox(
                         height: 80,
                         child: ListView.builder(
                           controller: _dateScrollController,
                           scrollDirection: Axis.horizontal,
                           itemCount: _getAllDates().length,
                           itemBuilder: (context, index) {
                             final date = _getAllDates()[index];
                          final isSelected = _isSelected(date);
                          final isToday = _isToday(date);
                          final hasEvents = _getEventsForDate(date).isNotEmpty;
                          
                          return Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _onDateSelected(date),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.black : Colors.transparent,
                                      borderRadius: BorderRadius.circular(25),
                                      border: isToday && !isSelected 
                                        ? Border.all(color: Colors.black, width: 2)
                                        : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('E').format(date).substring(0, 3),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (hasEvents)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                                              ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Events Timeline
              Expanded(
                child: _buildEventsTimeline(),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home, color: Colors.grey[600]),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            IconButton(
              icon: Icon(Icons.list, color: Colors.black),
              onPressed: () {},
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 28),
                onPressed: () {
                  // Navigate to create event screen for admins
                  Navigator.of(context).pop();
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.grey[600]),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.person, color: Colors.grey[600]),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
     }

   Widget _buildFullCalendar() {
     final now = DateTime.now();
     final currentMonth = DateTime(now.year, now.month, 1);
     final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
     final firstDayOfWeek = currentMonth.weekday;
     
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(12),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.1),
             blurRadius: 8,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       child: Column(
         children: [
           // Month Header
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               IconButton(
                 icon: Icon(Icons.chevron_left, color: Colors.grey[600]),
                 onPressed: () {
                   // TODO: Navigate to previous month
                 },
               ),
               Text(
                 DateFormat('MMMM yyyy').format(currentMonth),
                 style: const TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: Colors.black,
                 ),
               ),
               IconButton(
                 icon: Icon(Icons.chevron_right, color: Colors.grey[600]),
                 onPressed: () {
                   // TODO: Navigate to next month
                 },
               ),
             ],
           ),
           const SizedBox(height: 16),
           
           // Day Headers
           Row(
             children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                 .map((day) => Expanded(
                       child: Text(
                         day,
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                           color: Colors.grey[600],
                         ),
                       ),
                     ))
                 .toList(),
           ),
           const SizedBox(height: 8),
           
           // Calendar Grid
           ...List.generate((daysInMonth + firstDayOfWeek - 1) ~/ 7 + 1, (weekIndex) {
             return Row(
               children: List.generate(7, (dayIndex) {
                 final dayNumber = weekIndex * 7 + dayIndex - firstDayOfWeek + 1;
                 
                 if (dayNumber < 1 || dayNumber > daysInMonth) {
                   return const Expanded(child: SizedBox());
                 }
                 
                 final date = DateTime(now.year, now.month, dayNumber);
                 final isSelected = _isSelected(date);
                 final isToday = _isToday(date);
                 final hasEvents = _getEventsForDate(date).isNotEmpty;
                 
                 return Expanded(
                   child: GestureDetector(
                     onTap: () => _onDateSelected(date),
                     child: Container(
                       height: 40,
                       margin: const EdgeInsets.all(2),
                       decoration: BoxDecoration(
                         color: isSelected ? Colors.black : Colors.transparent,
                         borderRadius: BorderRadius.circular(8),
                         border: isToday && !isSelected 
                           ? Border.all(color: Colors.black, width: 2)
                           : null,
                       ),
                       child: Stack(
                         children: [
                           Center(
                             child: Text(
                               '$dayNumber',
                               style: TextStyle(
                                 fontSize: 14,
                                 fontWeight: FontWeight.w600,
                                 color: isSelected ? Colors.white : Colors.black,
                               ),
                             ),
                           ),
                           if (hasEvents)
                             Positioned(
                               bottom: 2,
                               right: 2,
                               child: Container(
                                 width: 6,
                                 height: 6,
                                 decoration: BoxDecoration(
                                   color: isSelected ? Colors.white : Colors.black,
                                   shape: BoxShape.circle,
                                 ),
                               ),
                             ),
                         ],
                       ),
                     ),
                   ),
                 );
               }),
             );
           }),
         ],
       ),
     );
   }

   Widget _buildEventsTimeline() {
    final selectedEvents = _getEventsForDate(_selectedDate);
    
    if (selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No events on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Sort events by start time
    selectedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        final isFirst = index == 0;
        final isLast = index == selectedEvents.length - 1;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst ? Colors.black : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 80,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Event Card
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isFirst ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isFirst ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(event.startTime),
                            style: TextStyle(
                              fontSize: 14,
                              color: isFirst ? Colors.white70 : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isFirst ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: isFirst ? Colors.white70 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: isFirst ? Colors.white70 : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (event.organizer != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: isFirst ? Colors.white70 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Organized by: ${event.organizer}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isFirst ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isFirst) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Attendee avatars placeholder
                            ...List.generate(3, (index) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white,
                              ),
                            )),
                            const Spacer(),
                            // Checkmark button
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 