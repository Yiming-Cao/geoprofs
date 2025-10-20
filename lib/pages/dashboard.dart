import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoadingRequests = true;
  bool _isSubmitting = false;
  String? _error;

  // Form controllers
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month; // user-controlled
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // View toggles
  bool _showWorkWeek = false; // false = full week, true = Mon-Fri

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  // ------------------------------------------------------------
  // 1. FETCH + REBUILD EVENTS (covers *all* dates)
  // ------------------------------------------------------------
  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Not logged in.';
      });
      return;
    }

    try {
      final response = await supabase
          .from('verlof')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> requests =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        _requests = requests;
        _events = _buildEventsMap(requests); // <-- rebuilds every date
        _isLoadingRequests = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Failed to load requests: $e';
      });
    }
  }

  // Build a map {date → [request1, request2, …]} for *every* day in a range
  Map<DateTime, List<Map<String, dynamic>>> _buildEventsMap(
      List<Map<String, dynamic>> requests) {
    final Map<DateTime, List<Map<String, dynamic>>> events = {};

    for (final req in requests) {
      final startStr = req['start'] as String?;
      final endStr = req['end_time'] as String?;

      if (startStr == null || endStr == null) continue;

      final start = DateTime.tryParse(startStr)?.toLocal();
      final end = DateTime.tryParse(endStr)?.toLocal();

      if (start == null || end == null) continue;

      // Normalise to midnight (ignore time-of-day)
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);

      var current = startDate;
      while (!current.isAfter(endDate)) {
        events.putIfAbsent(current, () => []).add(req);
        current = current.add(const Duration(days: 1));
      }
    }
    return events;
  }

  // ------------------------------------------------------------
  // 2. SUBMIT / DELETE (unchanged, just kept for completeness)
  // ------------------------------------------------------------
  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Not logged in.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    final startDate = _startDateController.text.trim();
    final endDate = _endDateController.text.trim();
    final reason = _reasonController.text.trim();

    if (startDate.isEmpty || endDate.isEmpty || reason.isEmpty) {
      _showSnackBar('Fill all fields.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final startTimestamp =
          DateTime.parse('$startDate 00:00:00Z').toIso8601String();
      final endTimestamp =
          DateTime.parse('$endDate 00:00:00Z').toIso8601String();

      await supabase.from('verlof').insert({
        'start': startTimestamp,
        'end_time': endTimestamp,
        'type': reason,
        'approved': false,
        'user_id': userId,
      });

      _showSnackBar('Request submitted!');
      _clearForm();
      _fetchRequests();
    } catch (e) {
      _showSnackBar('Submit failed: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('This cannot be undone. Proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('verlof').delete().eq('id', requestId);
      _showSnackBar('Request deleted.');
      _fetchRequests();
    } catch (e) {
      _showSnackBar('Delete failed: $e', isError: true);
    }
  }

  // ------------------------------------------------------------
  // 3. UI HELPERS
  // ------------------------------------------------------------
  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void _clearForm() {
    _startDateController.clear();
    _endDateController.clear();
    _reasonController.clear();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  // ------------------------------------------------------------
  // 4. BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRequests),
        ],
      ),
      body: _isLoadingRequests
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ---------- Submit Form ----------
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New Leave Request',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _startDateController,
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _pickDate(_startDateController),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _endDateController,
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _pickDate(_endDateController),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reasonController,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitRequest,
                              child: _isSubmitting
                                  ? const CircularProgressIndicator()
                                  : const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),

                  // ---------- Calendar ----------
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ---- Controls ----
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _calendarFormat =
                                        _calendarFormat == CalendarFormat.month
                                            ? CalendarFormat.week
                                            : CalendarFormat.month;
                                  });
                                },
                                child: Text(
                                    _calendarFormat == CalendarFormat.month
                                        ? 'Week View'
                                        : 'Month View'),
                              ),
                              Row(
                                children: [
                                  const Text('Work Week'),
                                  Switch(
                                    value: _showWorkWeek,
                                    onChanged: (val) =>
                                        setState(() => _showWorkWeek = val),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // ---- TableCalendar ----
                          TableCalendar(
                            firstDay: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDay:
                                DateTime.now().add(const Duration(days: 365)),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat, // **user-controlled**
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },

                            // **Removed onFormatChanged** – prevents auto-flip
                            // onFormatChanged: (format) { ... }

                            onPageChanged: (focusedDay) {
                              _focusedDay = focusedDay;
                            },
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            availableCalendarFormats: const {
                              CalendarFormat.month: 'Month',
                              CalendarFormat.week: 'Week',
                            },
                            calendarStyle: const CalendarStyle(
                              outsideDaysVisible: false,
                              weekendTextStyle: TextStyle(color: Colors.red),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                            ),
                            // ---- Markers (show on *every* day) ----
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                final dayEvents = _getEventsForDay(day);
                                if (dayEvents.isEmpty) return null;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dayEvents.take(3).map((req) {
                                    final approved = req['approved'] == true;
                                    final denied = req['approved'] == null;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: approved
                                            ? Colors.green
                                            : denied
                                                ? Colors.red
                                                : Colors.orange,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            // Hide weekends when “Work Week” is on
                            enabledDayPredicate: _showWorkWeek
                                ? (day) =>
                                    day.weekday != DateTime.saturday &&
                                    day.weekday != DateTime.sunday
                                : null,
                          ),

                          const Divider(),

                          // ---- Events for the selected day ----
                          if (_selectedDay != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requests on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ..._getEventsForDay(_selectedDay!).map((req) {
                                  final start = DateTime.tryParse(
                                          req['start'] ?? '')!
                                      .toLocal();
                                  final end = DateTime.tryParse(
                                          req['end_time'] ?? '')!
                                      .toLocal();
                                  final status = req['approved'] == true
                                      ? 'Approved'
                                      : req['approved'] == false
                                          ? 'Pending'
                                          : 'Denied';

                                  return Card(
                                    child: ListTile(
                                      dense: true,
                                      title: Text(req['type'] ?? 'No reason'),
                                      subtitle: Text(
                                          '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}\nStatus: $status'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deleteRequest(req['id']),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                if (_getEventsForDay(_selectedDay!).isEmpty)
                                  const Text('No requests on this day.'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------- All Requests List ----------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('All Requests',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 8),

                  _requests.isEmpty
                      ? const Center(child: Text('No requests yet.'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
                            final start = DateTime.tryParse(req['start'] ?? '')
                                ?.toLocal();
                            final end = DateTime.tryParse(req['end_time'] ?? '')
                                ?.toLocal();
                            final status = req['approved'] == true
                                ? 'Approved'
                                : req['approved'] == false
                                    ? 'Pending'
                                    : 'Denied';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text(req['type'] ?? 'N/A'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (start != null)
                                      Text(
                                          'Start: ${DateFormat('yyyy-MM-dd').format(start)}'),
                                    if (end != null)
                                      Text(
                                          'End: ${DateFormat('yyyy-MM-dd').format(end)}'),
                                    Text('Status: $status'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteRequest(req['id']),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/'),
        child: const Icon(Icons.home),
      ),
    );
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}