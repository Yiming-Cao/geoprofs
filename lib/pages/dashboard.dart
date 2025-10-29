import 'package:flutter/material.dart';
import 'package:geoprof/components/protected_route.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/background_container.dart';
import 'package:geoprof/components/header_bar.dart';

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
  int _remainingLeaveDays = 28;

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  bool _showWorkWeek = false;

  DateTime? _lastSubmitTime;
  DateTime? _lastDeleteTime;
  static const _rateLimitDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _fetchLeaveBalance();
  }

  Future<bool> _validateSession() async {
    final session = supabase.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        await supabase.auth.refreshSession();
        return supabase.auth.currentSession != null;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  Future<void> _fetchLeaveBalance() async {
    if (!await _validateSession()) {
      setState(() => _error = 'Session expired. Please log in again.');
      return;
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'Not logged in.');
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
        final total = response['total_days'] as int? ?? 28;
        final used = response['used_days'] as int? ?? 0;
        setState(() {
          _remainingLeaveDays = total - used;
          _error = null;
        });
      } else {
        await supabase.from('leave_balance').insert({
          'user_id': userId,
          'total_days': 28,
          'used_days': 0,
          'year': DateTime.now().year,
        });
        setState(() => _remainingLeaveDays = 28);
      }
    } catch (e) {
      setState(() => _error = 'Failed to load leave balance.');
    }
  }

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
    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Unable to load requests.';
      });
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _buildEventsMap(
      List<Map<String, dynamic>> requests) {
    final Map<DateTime, List<Map<String, dynamic>>> events = {};
    for (final req in requests) {
      final startStr = req['start'] as String?;
      final endStr = req['end_time'] as String?;
      if (startStr == null || endStr == null) continue;
      final startUtc = DateTime.tryParse(startStr);
      final endUtc = DateTime.tryParse(endStr);
      if (startUtc == null || endUtc == null) continue;
      var current = DateTime(startUtc.year, startUtc.month, startUtc.day)
          .add(const Duration(days: 1));
      final end = DateTime(endUtc.year, endUtc.month, endUtc.day)
          .add(const Duration(days: 1));
      while (!current.isAfter(end)) {
        final key = DateTime(current.year, current.month, current.day);
        events.putIfAbsent(key, () => []).add(req);
        current = current.add(const Duration(days: 1));
      }
    }
    return events;
  }

  int _calculateWorkdays(DateTime start, DateTime end) {
    int days = 0;
    var cur = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(endDate)) {
      if (cur.weekday != DateTime.saturday && cur.weekday != DateTime.sunday) {
        days++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

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
    final startTxt = _startDateController.text.trim();
    final endTxt = _endDateController.text.trim();
    final reason = _reasonController.text.trim();
    if (startTxt.isEmpty || endTxt.isEmpty || reason.isEmpty) {
      _showSnackBar('Please fill all fields.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    final startDt = DateTime.parse(startTxt);
    final endDt = DateTime.parse(endTxt);
    if (endDt.isBefore(startDt)) {
      _showSnackBar('End date must be after start date.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    final daysRequested = _calculateWorkdays(startDt, endDt);
    if (daysRequested > _remainingLeaveDays) {
      _showSnackBar(
          'Not enough leave days ($_remainingLeaveDays available).',
          isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    final startUtc =
        DateTime(startDt.year, startDt.month, startDt.day).toUtc().toIso8601String();
    final endUtc =
        DateTime(endDt.year, endDt.month, endDt.day).toUtc().toIso8601String();
    try {
      await supabase.from('verlof').insert({
        'start': startUtc,
        'end_time': endUtc,
        'type': reason,
        'approved': false,
        'user_id': userId,
        'days_count': daysRequested,
      }).select();
      _showSnackBar('Request submitted successfully!');
      _clearForm();
      _fetchRequests();
      _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to submit request: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRequest(dynamic requestId) async {
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
      await supabase.from('verlof').delete().eq('id', requestId);
      _showSnackBar('Request deleted successfully.');
      _fetchRequests();
      _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to delete request: $e', isError: true);
    }
  }

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

  String _sanitizeInput(String input) =>
      input.replaceAll(RegExp(r'[<>{}]'), '');

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, child: HeaderBar()),
            _isLoadingRequests
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(
                        top: 80, left: 16, right: 16, bottom: 100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: TableCalendar(
                                  firstDay: DateTime.now()
                                      .subtract(const Duration(days: 365)),
                                  lastDay: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  focusedDay: _focusedDay,
                                  calendarFormat: CalendarFormat.month,
                                  headerStyle: const HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                    titleTextStyle: TextStyle(
                                        color: Colors.white, fontSize: 16),
                                    leftChevronIcon: Icon(Icons.chevron_left,
                                        color: Colors.white),
                                    rightChevronIcon: Icon(Icons.chevron_right,
                                        color: Colors.white),
                                  ),
                                  daysOfWeekStyle: const DaysOfWeekStyle(
                                    weekdayStyle: TextStyle(color: Colors.white70),
                                    weekendStyle:
                                        TextStyle(color: Colors.redAccent),
                                  ),
                                  calendarStyle: const CalendarStyle(
                                    outsideDaysVisible: false,
                                    weekendTextStyle:
                                        TextStyle(color: Colors.redAccent),
                                    defaultTextStyle:
                                        TextStyle(color: Colors.white),
                                    selectedDecoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle),
                                    todayDecoration: BoxDecoration(
                                        color: Color(0xFFFF9800),
                                        shape: BoxShape.circle),
                                  ),
                                  startingDayOfWeek: StartingDayOfWeek.monday,
                                  selectedDayPredicate: (d) =>
                                      isSameDay(_selectedDay, d),
                                  onDaySelected: (s, f) => setState(() {
                                    _selectedDay = s;
                                    _focusedDay = f;
                                  }),
                                  onPageChanged: (f) =>
                                      setState(() => _focusedDay = f),
                                  eventLoader: _getEventsForDay,
                                  calendarBuilders: CalendarBuilders(
                                    markerBuilder: (c, day, ev) {
                                      if (ev.isEmpty) return null;
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: ev.take(3).map((e) {
                                          final req =
                                              e as Map<String, dynamic>;
                                          final approved =
                                              req['approved'] == true;
                                          final denied =
                                              req['approved'] == null;
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
                                            width: 5,
                                            height: 5,
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
                                    defaultBuilder: (c, day, f) {
                                      final ev = _getEventsForDay(day);
                                      if (ev.isEmpty) return null;
                                      return Tooltip(
                                        message: ev
                                            .map((e) {
                                              final start = DateTime.tryParse(
                                                      e['start'] ?? '')
                                                  ?.toLocal()
                                                  .add(const Duration(days: 1));
                                              final end = DateTime.tryParse(
                                                      e['end_time'] ?? '')
                                                  ?.toLocal()
                                                  .add(const Duration(days: 1));
                                              final status =
                                                  e['approved'] == true
                                                      ? 'Approved'
                                                      : e['approved'] == false
                                                          ? 'Pending'
                                                          : 'Denied';
                                              return '${e['type']}\n${start != null ? DateFormat('MMM dd').format(start) : ''} - ${end != null ? DateFormat('MMM dd').format(end) : ''}\nStatus: $status';
                                            })
                                            .join('\n\n'),
                                        preferBelow: false,
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        textStyle: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                        child: Container(
                                          margin: const EdgeInsets.all(6),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              color: day.weekday ==
                                                          DateTime.saturday ||
                                                      day.weekday ==
                                                          DateTime.sunday
                                                  ? Colors.redAccent
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Remaining Leave Days: $_remainingLeaveDays',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy')
                                          .format(_focusedDay),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    ToggleButtons(
                                      borderRadius: BorderRadius.circular(20),
                                      selectedColor: Colors.white,
                                      fillColor: Colors.grey[700],
                                      color: Colors.grey[600],
                                      constraints: const BoxConstraints(
                                          minHeight: 32, minWidth: 60),
                                      isSelected: [
                                        _calendarFormat == CalendarFormat.month,
                                        _calendarFormat == CalendarFormat.week,
                                      ],
                                      onPressed: (i) => setState(() => _calendarFormat =
                                          i == 0
                                              ? CalendarFormat.month
                                              : CalendarFormat.week),
                                      children: const [
                                        Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text('Month')),
                                        Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text('Week')),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('Work Week'),
                                    Switch(
                                      value: _showWorkWeek,
                                      onChanged: (v) =>
                                          setState(() => _showWorkWeek = v),
                                      activeColor: Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1, thickness: 1),
                                const SizedBox(height: 16),
                                TableCalendar(
                                  firstDay: DateTime.now()
                                      .subtract(const Duration(days: 365)),
                                  lastDay: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  focusedDay: _focusedDay,
                                  calendarFormat: _calendarFormat,
                                  startingDayOfWeek: StartingDayOfWeek.monday,
                                  headerVisible: false,
                                  selectedDayPredicate: (d) =>
                                      isSameDay(_selectedDay, d),
                                  onDaySelected: (s, f) => setState(() {
                                    _selectedDay = s;
                                    _focusedDay = f;
                                  }),
                                  onPageChanged: (f) =>
                                      setState(() => _focusedDay = f),
                                  eventLoader: _getEventsForDay,
                                  enabledDayPredicate: _showWorkWeek
                                      ? (d) =>
                                          d.weekday != DateTime.saturday &&
                                          d.weekday != DateTime.sunday
                                      : null,
                                  calendarStyle: CalendarStyle(
                                    outsideDaysVisible: false,
                                    weekendTextStyle: TextStyle(
                                      color: _showWorkWeek
                                          ? Colors.grey[400]
                                          : Colors.red,
                                    ),
                                    disabledTextStyle:
                                        TextStyle(color: Colors.grey[400]),
                                  ),
                                  calendarBuilders: CalendarBuilders(
                                    markerBuilder: (c, day, ev) {
                                      if (ev.isEmpty) return null;
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: ev.take(3).map((e) {
                                          final req =
                                              e as Map<String, dynamic>;
                                          final approved =
                                              req['approved'] == true;
                                          final denied =
                                              req['approved'] == null;
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
                                ),
                                const SizedBox(height: 32),
                                const Text('New Leave Request',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
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
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isSubmitting ? null : _submitRequest,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: _isSubmitting
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text('Submit',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text('All Requests',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                _requests.isEmpty
                                    ? const Text('No requests yet.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _requests.length,
                                        itemBuilder: (c, i) {
                                          final req = _requests[i];
                                          final start = DateTime.tryParse(
                                                  req['start'] ?? '')
                                              ?.toLocal()
                                              .add(const Duration(days: 1));
                                          final end = DateTime.tryParse(
                                                  req['end_time'] ?? '')
                                              ?.toLocal()
                                              .add(const Duration(days: 1));
                                          final status = req['approved'] == true
                                              ? 'Approved'
                                              : req['approved'] == false
                                                  ? 'Pending'
                                                  : 'Denied';
                                          final days = req['days_count'] as int? ?? 0;
                                          return Card(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            child: ListTile(
                                              title: Text(
                                                  _sanitizeInput(req['type'] ?? 'N/A')),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (start != null)
                                                    Text(
                                                        'Start: ${DateFormat('yyyy-MM-dd').format(start)}'),
                                                  if (end != null)
                                                    Text(
                                                        'End: ${DateFormat('yyyy-MM-dd').format(end)}'),
                                                  Text('Status: $status'),
                                                  Text('Days: $days'),
                                                ],
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _deleteRequest(req['id']),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: Navbar()),
            ),
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