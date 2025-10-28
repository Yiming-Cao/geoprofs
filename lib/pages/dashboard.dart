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
  int _remainingLeaveDays = 28; // Default until fetched

  // Form controllers
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // View toggles
  bool _showWorkWeek = false;

  // Rate limiting
  DateTime? _lastSubmitTime;
  DateTime? _lastDeleteTime;
  static const _rateLimitDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _fetchLeaveBalance();
  }

  // Validate session
  Future<bool> _validateSession() async {
    final session = supabase.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        await supabase.auth.refreshSession();
        return supabase.auth.currentSession != null;
      } catch (e) {
        debugPrint('Session refresh failed: $e');
        return false;
      }
    }
    return true;
  }

  // Fetch leave balance
  Future<void> _fetchLeaveBalance() async {
    if (!await _validateSession()) {
      setState(() {
        _error = 'Session expired. Please log in again.';
      });
      return;
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _error = 'Not logged in.';
      });
      return;
    }

    try {
      final response = await supabase
          .from('leave_balance')
          .select('total_days, used_days')
          .eq('user_id', userId)
          .eq('year', DateTime.now().year)
          .maybeSingle();

      if (response != null) {
        final totalDays = response['total_days'] as int? ?? 28;
        final usedDays = response['used_days'] as int? ?? 0;
        setState(() {
          _remainingLeaveDays = totalDays - usedDays;
          _error = null;
        });
        debugPrint('Fetched balance: total_days=$totalDays, used_days=$usedDays, remaining=$_remainingLeaveDays');
      } else {
        try {
          await supabase.from('leave_balance').insert({
            'user_id': userId,
            'total_days': 28,
            'used_days': 0,
            'year': DateTime.now().year,
          });
          setState(() {
            _remainingLeaveDays = 28;
            _error = null;
          });
          debugPrint('Initialized balance for user_id: $userId');
        } catch (e) {
          setState(() {
            _error = 'Failed to initialize leave balance. Contact support.';
          });
          debugPrint('Initialize balance error: $e');
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load leave balance. Contact support.';
      });
      debugPrint('Fetch balance error: $e');
    }
  }

  // Fetch requests
  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    if (!await _validateSession()) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Session expired. Please log in again.';
      });
      return;
    }
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
        _events = _buildEventsMap(requests);
        _isLoadingRequests = false;
        _error = null;
      });
      debugPrint('Fetched ${_requests.length} requests:');
      for (var req in _requests) {
        debugPrint('Request id=${req['id']}, approved=${req['approved']}, days_count=${req['days_count']}');
      }
    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Unable to load requests. Contact support.';
      });
      debugPrint('Fetch error: $e');
    }
  }

  // Build events map
  Map<DateTime, List<Map<String, dynamic>>> _buildEventsMap(
      List<Map<String, dynamic>> requests) {
    final Map<DateTime, List<Map<String, dynamic>>> events = {};

    for (final req in requests) {
      final startStr = req['start'] as String?;
      final endStr = req['end_time'] as String?;

      if (startStr == null || endStr == null) {
        debugPrint('Skipping request with null start/end: $req');
        continue;
      }

      final start = DateTime.tryParse(startStr);
      final end = DateTime.tryParse(endStr);

      if (start == null || end == null) {
        debugPrint('Invalid date format in request: $req');
        continue;
      }

      final startDate = DateTime.utc(start.year, start.month, start.day);
      final endDate = DateTime.utc(end.year, end.month, end.day);

      debugPrint(
          'Processing request: ${req['id']} from $startDate to $endDate, approved=${req['approved']}, days_count=${req['days_count']}');

      var current = startDate;
      while (!current.isAfter(endDate)) {
        final key = DateTime.utc(current.year, current.month, current.day);
        final currentEvents = events.putIfAbsent(key, () => []);
        if (!currentEvents.any((e) => e['id'] == req['id'])) {
          currentEvents.add(req);
        }
        current = current.add(const Duration(days: 1));
      }
    }

    debugPrint('Events map: ${events.keys.length} dates populated');
    return events;
  }

  // Calculate workdays (excluding weekends)
  int _calculateWorkdays(DateTime start, DateTime end) {
    int days = 0;
    var current = DateTime.utc(start.year, start.month, start.day);
    final endDate = DateTime.utc(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        days++;
      }
      current = current.add(const Duration(days: 1));
    }
    debugPrint('Calculated workdays: $days for start=$start, end=$end');
    return days;
  }

  // Submit request
  Future<void> _submitRequest() async {
    if (_lastSubmitTime != null &&
        DateTime.now().difference(_lastSubmitTime!) < _rateLimitDuration) {
      _showSnackBar('Please wait before submitting again.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    _lastSubmitTime = DateTime.now();

    if (!await _validateSession()) {
      _showSnackBar('Session expired. Please log in again.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Not logged in.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    final startDate = _startDateController.text.trim();
    final endDate = _endDateController.text.trim();
    final reason = _reasonController.text.trim();

    // Validate inputs
    if (startDate.isEmpty || endDate.isEmpty || reason.isEmpty) {
      _showSnackBar('Please fill all fields.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    final dateFormat = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateFormat.hasMatch(startDate) || !dateFormat.hasMatch(endDate)) {
      _showSnackBar('Invalid date format. Use YYYY-MM-DD.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    if (reason.length > 200) {
      _showSnackBar('Reason must be 200 characters or less.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    if (RegExp(r'[<>{}]').hasMatch(reason)) {
      _showSnackBar('Reason cannot contain <, >, or {}.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final startDt = DateTime.parse(startDate);
      final endDt = DateTime.parse(endDate);
      if (endDt.isBefore(startDt)) {
        _showSnackBar('End date must be after start date.', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // Calculate workdays for the request
      final daysRequested = _calculateWorkdays(startDt, endDt);
      debugPrint('Submitting request: start=$startDate, end=$endDate, days_count=$daysRequested, approved=false, user_id=$userId');
      if (daysRequested > _remainingLeaveDays) {
        _showSnackBar(
            'Not enough leave days remaining ($_remainingLeaveDays available).',
            isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      final startTimestamp =
          DateTime.utc(startDt.year, startDt.month, startDt.day)
              .toIso8601String();
      final endTimestamp = DateTime.utc(endDt.year, endDt.month, endDt.day)
          .toIso8601String();

      final response = await supabase.from('verlof').insert({
        'start': startTimestamp,
        'end_time': endTimestamp,
        'type': reason,
        'approved': false,
        'user_id': userId,
        'days_count': daysRequested,
      }).select().single();

      debugPrint('Inserted request: id=${response['id']}, days_count=${response['days_count']}, approved=${response['approved']}');
      _showSnackBar('Request submitted successfully!');
      _clearForm();
      _fetchRequests();
      _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to submit request: $e', isError: true);
      debugPrint('Submit error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Delete request
  Future<void> _deleteRequest(String requestId) async {
    if (_lastDeleteTime != null &&
        DateTime.now().difference(_lastDeleteTime!) < _rateLimitDuration) {
      _showSnackBar('Please wait before deleting again.', isError: true);
      return;
    }
    _lastDeleteTime = DateTime.now();

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
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      debugPrint('Attempting to delete request: id=$requestId');
      await supabase.from('verlof').delete().eq('id', requestId).select().single();
      _showSnackBar('Request deleted successfully.');
      debugPrint('Deleted request: id=$requestId');
      _fetchRequests();
      _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to delete request: $e', isError: true);
      debugPrint('Delete error: $e');
    }
  }

  // UI helpers
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

  String _sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'[<>{}]'), '');
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchRequests();
              _fetchLeaveBalance();
            },
          ),
        ],
      ),
      body: _isLoadingRequests
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Calendar
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _calendarFormat = _calendarFormat == CalendarFormat.month
                                        ? CalendarFormat.week
                                        : CalendarFormat.month;
                                  });
                                },
                                child: Text(_calendarFormat == CalendarFormat.month
                                    ? 'Week View'
                                    : 'Month View'),
                              ),
                              Row(
                                children: [
                                  const Text('Work Week'),
                                  Switch(
                                    value: _showWorkWeek,
                                    onChanged: (val) => setState(() => _showWorkWeek = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // TableCalendar
                          TableCalendar(
                            firstDay: DateTime.now().subtract(const Duration(days: 365)),
                            lastDay: DateTime.now().add(const Duration(days: 365)),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              _focusedDay = focusedDay;
                              setState(() {});
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
                            eventLoader: (day) => _getEventsForDay(day),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                if (events.isEmpty) return null;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: events.take(3).map((event) {
                                    final req = event as Map<String, dynamic>;
                                    final approved = req['approved'] == true;
                                    final denied = req['approved'] == null;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
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
                            enabledDayPredicate: _showWorkWeek
                                ? (day) =>
                                    day.weekday != DateTime.saturday &&
                                    day.weekday != DateTime.sunday
                                : null,
                          ),
                          const Divider(),
                          // Events for selected day
                          if (_selectedDay != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requests on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ..._getEventsForDay(_selectedDay!).map((req) {
                                  final start = DateTime.tryParse(req['start'] ?? '')?.toLocal();
                                  final end = DateTime.tryParse(req['end_time'] ?? '')?.toLocal();
                                  final status = req['approved'] == true
                                      ? 'Approved'
                                      : req['approved'] == false
                                          ? 'Pending'
                                          : 'Denied';
                                  final daysCount = req['days_count'] as int? ?? 0;
                                  return Card(
                                    child: ListTile(
                                      dense: true,
                                      title: Text(_sanitizeInput(req['type'] ?? 'No reason')),
                                      subtitle: Text(
                                          '${start != null ? DateFormat('MMM dd').format(start) : 'N/A'} - '
                                          '${end != null ? DateFormat('MMM dd').format(end) : 'N/A'}\n'
                                          'Status: $status\nDays: $daysCount'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteRequest(req['id']),
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
                  // Submit Form
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remaining Leave Days: $_remainingLeaveDays',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Text('New Leave Request',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  // All Requests List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('All Requests', style: Theme.of(context).textTheme.titleLarge),
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
                            final start = DateTime.tryParse(req['start'] ?? '')?.toLocal();
                            final end = DateTime.tryParse(req['end_time'] ?? '')?.toLocal();
                            final status = req['approved'] == true
                                ? 'Approved'
                                : req['approved'] == false
                                    ? 'Pending'
                                    : 'Denied';
                            final daysCount = req['days_count'] as int? ?? 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text(_sanitizeInput(req['type'] ?? 'N/A')),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (start != null)
                                      Text('Start: ${DateFormat('yyyy-MM-dd').format(start)}'),
                                    if (end != null)
                                      Text('End: ${DateFormat('yyyy-MM-dd').format(end)}'),
                                    Text('Status: $status'),
                                    Text('Days: $daysCount'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRequest(req['id']),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20),
                ],
              ),
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