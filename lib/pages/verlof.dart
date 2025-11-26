import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:geoprof/components/navbar.dart';
import 'package:geoprof/components/background_container.dart';
import 'package:geoprof/components/header_bar.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class VerlofPage extends StatelessWidget {
  const VerlofPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return const MobileLayout();
    }
    return const DesktopLayout();
  }
}

// ====================== MOBILE LAYOUT ======================
class MobileLayout extends StatefulWidget {
  const MobileLayout({super.key});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
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
  bool _isManager = false;
  String? _selectedVerlofType;
  final List<String> _verlofTypes = ['sick', 'holiday', 'personal'];
  Set<int> _selectedRequestIds = <int>{};
  bool _isBulkMode = false;
  bool _isSubmittingQuickSick = false;

  @override
  void initState() {
    super.initState();
    _checkManagerAndFetch();
    _fetchLeaveBalance();
  }

  Future<void> _checkManagerAndFetch() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      setState(() => _error = 'Not logged in.');
      return;
    }
    try {
      final jwt = session.accessToken;
      final payload = Jwt.parseJwt(jwt);
      final roleFromJwt = payload['app_metadata']?['user_role'] as String? ??
          payload['user_role'] as String?;
      if (roleFromJwt != null) {
        final isManager = roleFromJwt == 'manager';
        setState(() => _isManager = isManager);
        await _fetchRequests();
        return;
      }
      print('JWT has no user_role. Falling back to permissions table...');
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'No user ID';
      final response = await supabase
          .from('permissions')
          .select('role')
          .eq('user_uuid', userId)
          .maybeSingle();
      final roleFromDb = response?['role'] as String?;
      final isManager = roleFromDb == 'manager';
      setState(() => _isManager = isManager);
      await _fetchRequests();
    } catch (e, st) {
      print('ERROR in _checkManagerAndFetch: $e');
      print(st);
      setState(() => _error = 'Failed to check permissions: $e');
    }
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
    try {
      final response = await supabase
          .from('my_leave_balance')
          .select('remaining_days')
          .single();

      setState(() {
        _remainingLeaveDays = response['remaining_days'] as int;
        _error = null;
      });
    } catch (e) {
      print('Balance fetch error: $e');
      setState(() => _error = 'Failed to load leave balance');
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
      print('Fetching requests for user: $userId | isManager: $_isManager');
      late final PostgrestList response;
      if (_isManager) {
        response = await supabase
            .from('verlof')
            .select('*')
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('verlof')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      }
      print('Fetched ${response.length} requests');
      final List<Map<String, dynamic>> requests = List.from(response);
      setState(() {
        _requests = requests;
        _events = _buildEventsMap(requests);
        _isLoadingRequests = false;
        _error = null;
      });
    } catch (e, st) {
      print('ERROR in _fetchRequests: $e');
      print(st);
      setState(() {
        _isLoadingRequests = false;
        _error = 'Failed to load requests: $e';
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
      var current = DateTime.utc(startUtc.year, startUtc.month, startUtc.day);
      final end = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
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
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    
    while (!current.isAfter(endDate)) {
      final weekday = current.weekday;
      if (weekday != DateTime.saturday && weekday != DateTime.sunday) {
        days++;
      }
      current = current.add(const Duration(days: 1));
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
    final customReason = _reasonController.text.trim();
    final quickType = _selectedVerlofType;
    if (startTxt.isEmpty || endTxt.isEmpty) {
      _showSnackBar('Please select start and end date.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    if (quickType == null && customReason.isEmpty) {
      _showSnackBar('Please select a type or enter a reason.', isError: true);
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
    final startUtc =
        DateTime(startDt.year, startDt.month, startDt.day).toUtc().toIso8601String();
    final endUtc =
        DateTime(endDt.year, endDt.month, endDt.day).toUtc().toIso8601String();
    final String reasonText = customReason.isNotEmpty
        ? customReason
        : (quickType == 'personal' ? 'Personal reason' : quickType!);

    try {
      await supabase.from('verlof').insert({
        'start': startUtc,
        'end_time': endUtc,
        'reason': reasonText,
        'verlof_type': quickType,
        'verlof_state': 'pending',
        'user_id': userId,
        'days_count': daysRequested,
      }).select();
      _showSnackBar('Request submitted successfully!');
      _clearForm();
      setState(() => _selectedVerlofType = null);
      await _fetchRequests();
      _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to submit request: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRequest(dynamic requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final id = requestId is int ? requestId : int.tryParse(requestId.toString());
      if (id == null) throw 'Invalid ID';

      await supabase.from('verlof').delete().eq('id', id);

      _showSnackBar('Request deleted');
      await _fetchRequests();
      await _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to delete', isError: true);
    }
  }
  
  Future<void> _updateRequestStatus(int id, String action) async {
    final newState = action == 'approve' ? 'approved' : 'denied';
    
    try {
      await supabase
          .from('verlof')
          .update({'verlof_state': newState})
          .eq('id', id);

      _showSnackBar('Request $newState!');
      await _fetchRequests();
      await _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed: $e', isError: true);
    }
  }
  
  Future<void> _bulkUpdateStatus(String action) async {
    if (_selectedRequestIds.isEmpty) {
      _showSnackBar('No requests selected', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Bulk ${action == 'approve' ? 'Approve' : 'Deny'}'),
        content: Text('Update ${_selectedRequestIds.length} request(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action == 'approve' ? 'Approve All' : 'Deny All', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingRequests = true);
    final newState = action == 'approve' ? 'approved' : 'denied';

    try {
      // ONE SINGLE BULK UPDATE — DB trigger does ALL the balance logic
      await supabase
          .from('verlof')
          .update({'verlof_state': newState})
          .inFilter('id', _selectedRequestIds.toList());

      _showSnackBar('Bulk ${action == 'approve' ? 'approved' : 'denied'} ${_selectedRequestIds.length} requests!');
      setState(() {
        _selectedRequestIds.clear();
        _isBulkMode = false;
      });
      await _fetchRequests();
      await _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Bulk action failed: $e', isError: true);
    } finally {
      setState(() => _isLoadingRequests = false);
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

  Future<void> _submitQuickSick() async {
    if (_isSubmittingQuickSick) return;

    setState(() => _isSubmittingQuickSick = true);

    // Rate limiting
    if (_lastSubmitTime != null &&
        DateTime.now().difference(_lastSubmitTime!) < _rateLimitDuration) {
      _showSnackBar('Please wait a moment before submitting again.', isError: true);
      setState(() => _isSubmittingQuickSick = false);
      return;
    }
    _lastSubmitTime = DateTime.now();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Not logged in.', isError: true);
      setState(() => _isSubmittingQuickSick = false);
      return;
    }

    // TODAY only - normalized to date only (ignore time)
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final todayUtc = todayDateOnly.toUtc().toIso8601String();

    // Check for existing sick request today (pending or approved)
    final existing = await supabase
        .from('verlof')
        .select('id')
        .eq('user_id', userId)
        .eq('verlof_type', 'sick')
        .inFilter('verlof_state', ['pending', 'approved'])
        .gte('start', todayUtc)
        .lte('start', todayUtc.substring(0, 10) + 'T23:59:59.999Z');

    if (existing.isNotEmpty) {
      _showSnackBar('You have already called in sick for today.', isError: true);
      setState(() => _isSubmittingQuickSick = false);
      return;
    }

    final daysCount = _calculateWorkdays(todayDateOnly, todayDateOnly);

    try {
      await supabase.from('verlof').insert({
        'start': todayUtc,
        'end_time': todayUtc,
        'reason': 'Sick',
        'verlof_type': 'sick',
        'verlof_state': 'pending',
        'user_id': userId,
        'days_count': daysCount,
      });

      _showSnackBar('Called in sick for today');
      await _fetchRequests();
      await _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to submit sick day: $e', isError: true);
    } finally {
      setState(() => _isSubmittingQuickSick = false);
    }
  }
  
  void _clearForm() {
    _startDateController.clear();
    _endDateController.clear();
    _reasonController.clear();
    _selectedVerlofType = null;
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

  String _getDisplayTitle(Map<String, dynamic> req) {
    final verlofType = req['verlof_type'] as String?;
    final reasonText = req['reason'] as String?;
    if (verlofType != null) {
      final capitalized = verlofType[0].toUpperCase() + verlofType.substring(1);
      return reasonText != null && reasonText.toLowerCase() != verlofType
          ? '$capitalized: $reasonText'
          : capitalized;
    }
    return _sanitizeInput(reasonText ?? 'N/A');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: Stack(
          children: [
            // ==================== 滚动内容层 ====================
            Column(
              children: [
                HeaderBar(),
                Expanded(
                  child: _isLoadingRequests
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(
                              top: 0, left: 16, right: 16, bottom: 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('MMMM yyyy').format(_focusedDay),
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        ToggleButtons(
                                          borderRadius: BorderRadius.circular(20),
                                          selectedColor: Colors.white,
                                          fillColor: Colors.grey[700],
                                          color: Colors.grey[600],
                                          constraints: const BoxConstraints(minHeight: 36, minWidth: 70),
                                          isSelected: [
                                            _calendarFormat == CalendarFormat.month,
                                            _calendarFormat == CalendarFormat.week,
                                          ],
                                          onPressed: (i) => setState(() => _calendarFormat =
                                              i == 0 ? CalendarFormat.month : CalendarFormat.week),
                                          children: const [
                                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Month')),
                                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Week')),
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
                                          onChanged: (v) => setState(() => _showWorkWeek = v),
                                          activeColor: Colors.red,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    TableCalendar(
                                      firstDay: DateTime.now(),
                                      lastDay: DateTime.now().add(const Duration(days: 365)),
                                      focusedDay: _focusedDay,
                                      calendarFormat: _calendarFormat,
                                      startingDayOfWeek: StartingDayOfWeek.monday,
                                      headerVisible: false,
                                      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                                      onDaySelected: (s, f) => setState(() {
                                        _selectedDay = s;
                                        _focusedDay = f;
                                      }),
                                      onPageChanged: (f) => setState(() => _focusedDay = f),
                                      eventLoader: _getEventsForDay,
                                      enabledDayPredicate: _showWorkWeek
                                          ? (d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday
                                          : null,
                                      calendarStyle: CalendarStyle(
                                        outsideDaysVisible: false,
                                        weekendTextStyle: TextStyle(
                                            color: _showWorkWeek ? Colors.grey[400] : Colors.red),
                                        disabledTextStyle: TextStyle(color: Colors.grey[400]),
                                      ),
                                      calendarBuilders: CalendarBuilders(
                                        markerBuilder: (c, day, ev) {
                                          if (ev.isEmpty) return null;
                                          return Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: ev.take(3).map((e) {
                                              final req = e as Map<String, dynamic>;
                                              final state = req['verlof_state'] as String?;
                                              final approved = state == 'approved';
                                              final denied = state == 'denied';
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
                                    ),
                                    const SizedBox(height: 32),
                                    if (!_isManager)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.red.shade200, width: 1.5),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.sick, color: Colors.red, size: 28),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Quick Sick',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Instantly call in sick for 1 day (today or any date)',
                                              style: TextStyle(color: Colors.redAccent),
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: _isSubmittingQuickSick ? null : _submitQuickSick,
                                                icon: _isSubmittingQuickSick
                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                    : const Icon(Icons.sick, color: Colors.white),
                                                label: Text(
                                                  _isSubmittingQuickSick
                                                      ? 'Submitting...'
                                                      : 'Call in Sick Today',
                                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(height: 32),

                                    if (!_isManager) ...[
                                      Text('New Leave Request', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      DropdownButtonFormField<String>(
                                        value: _selectedVerlofType,
                                        decoration: const InputDecoration(
                                          labelText: 'Quick Type',
                                          border: OutlineInputBorder(),
                                        ),
                                        hint: const Text('Select type (optional)'),
                                        items: _verlofTypes.map((type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type[0].toUpperCase() + type.substring(1)),
                                        )).toList(),
                                        onChanged: (value) {
                                          setState(() => _selectedVerlofType = value);
                                          if (value != null && value != 'personal') {
                                            _reasonController.text = value;
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _reasonController,
                                        decoration: const InputDecoration(
                                          labelText: 'Custom Reason',
                                          hintText: 'e.g. Dentist, Wedding, etc. (optional if quick type selected)',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 3,
                                      ),
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
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _isSubmitting ? null : _submitRequest,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: _isSubmitting
                                              ? const CircularProgressIndicator(color: Colors.white)
                                              : const Text('Submit', style: TextStyle(fontSize: 16, color: Colors.white)),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                    ],
                                    Text(
                                      _isManager ? 'Team Requests' : 'My Requests',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    _requests.isEmpty
                                        ? const Text('No requests yet.')
                                        : Column(
                                            children: [
                                              // BULK ACTION BAR
                                              if (_isManager && _isBulkMode && _selectedRequestIds.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  margin: const EdgeInsets.only(bottom: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.blue),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Text('${_selectedRequestIds.length} selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                      const Spacer(),
                                                      ElevatedButton.icon(
                                                        icon: const Icon(Icons.check, size: 18),
                                                        label: const Text('Approve All'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        onPressed: () => _bulkUpdateStatus('approve'),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      ElevatedButton.icon(
                                                        icon: const Icon(Icons.close, size: 18),
                                                        label: const Text('Deny All'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        onPressed: () => _bulkUpdateStatus('deny'),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      TextButton(
                                                        onPressed: () => setState(() {
                                                          _selectedRequestIds.clear();
                                                          _isBulkMode = false;
                                                        }),
                                                        child: const Text(
                                                          'Cancel',
                                                          style: TextStyle(color: Colors.black),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                              // BULK MODE CONTROLS
                                              if (_isManager)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    children: [
                                                      if (!_isBulkMode)
                                                        ElevatedButton.icon(
                                                          icon: const Icon(Icons.library_add_check_outlined),
                                                          label: const Text('Bulk Actions'),
                                                          onPressed: () => setState(() => _isBulkMode = true),
                                                        ),
                                                      if (_isBulkMode) ...[
                                                        TextButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              _selectedRequestIds = _requests
                                                                  .where((r) => r['verlof_state'] != 'approved' && r['user_id'] != supabase.auth.currentUser?.id)
                                                                  .map((r) => r['id'] as int)
                                                                  .toSet();
                                                            });
                                                          },
                                                          child: const Text('Select All unapproved'),
                                                        ),
                                                        TextButton(onPressed: () => setState(() => _selectedRequestIds.clear()), child: const Text('Clear')),
                                                        TextButton(onPressed: () => setState(() => _isBulkMode = false), child: const Text('Exit Bulk Mode')),
                                                      ],
                                                    ],
                                                  ),
                                                ),

                                              // THE ACTUAL LIST WITH SELECTION
                                              ListView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: _requests.length,
                                                itemBuilder: (context, i) {
                                                  final req = _requests[i];
                                                  final id = req['id'] as int;
                                                  final state = req['verlof_state'] as String?;
                                                  final isOwn = req['user_id'] == supabase.auth.currentUser?.id;
                                                  final isSelected = _selectedRequestIds.contains(id);
                                                  final canSelect = _isManager && !isOwn && state != 'approved';

                                                  return Card(
                                                    color: isSelected ? Colors.blue.shade50 : null,
                                                    child: ListTile(
                                                      onTap: _isBulkMode && canSelect
                                                          ? () => setState(() => isSelected ? _selectedRequestIds.remove(id) : _selectedRequestIds.add(id))
                                                          : null,
                                                      onLongPress: _isManager && !isOwn && !_isBulkMode ? () => setState(() => _isBulkMode = true) : null,
                                                      leading: _isBulkMode && canSelect
                                                          ? Checkbox(
                                                              value: isSelected,
                                                              onChanged: (v) => setState(() => v == true ? _selectedRequestIds.add(id) : _selectedRequestIds.remove(id)),
                                                            )
                                                          : null,
                                                      title: Text(_getDisplayTitle(req)),
                                                      subtitle: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (DateTime.tryParse(req['start'] ?? '') != null)
                                                            Text('Start: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(req['start']).toLocal())}'),
                                                          if (DateTime.tryParse(req['end_time'] ?? '') != null)
                                                            Text('End: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(req['end_time']).toLocal())}'),
                                                          Text('Status: ${state == 'approved' ? 'Approved' : state == 'denied' ? 'Denied' : 'Pending'}'),
                                                          Text('Days: ${req['days_count']}'),
                                                          if (_isManager) Text('User: ${req['user_id']}'),
                                                        ],
                                                      ),
                                                      trailing: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (_isManager && !isOwn && !_isBulkMode) ...[
                                                            if (state != 'approved')
                                                              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _updateRequestStatus(id, 'approve'), tooltip: 'Approve'),
                                                            if (state != 'denied')
                                                              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _updateRequestStatus(id, 'deny'), tooltip: 'Deny'),
                                                          ],
                                                          if (isOwn || _isManager)
                                                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRequest(id), tooltip: 'Delete'),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),

            // ==================== 浮动 Navbar 层（样式 100% 不变）================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Navbar(),
                ),
              ),
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

// ====================== DESKTOP LAYOUT（保留原逻辑）======================
class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
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
  bool _isManager = false;
  String? _selectedVerlofType;
  final List<String> _verlofTypes = ['sick', 'holiday', 'personal'];
  Set<int> _selectedRequestIds = <int>{};
  bool _isBulkMode = false;
  bool _isSubmittingQuickSick = false;

  @override
  void initState() {
    super.initState();
    _checkManagerAndFetch();
    _fetchLeaveBalance();
  }

  Future<void> _checkManagerAndFetch() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      setState(() => _error = 'Not logged in.');
      return;
    }
    try {
      final jwt = session.accessToken;
      final payload = Jwt.parseJwt(jwt);
      final roleFromJwt = payload['app_metadata']?['user_role'] as String? ??
          payload['user_role'] as String?;
      if (roleFromJwt != null) {
        final isManager = roleFromJwt == 'manager';
        setState(() => _isManager = isManager);
        await _fetchRequests();
        return;
      }
      print('JWT has no user_role. Falling back to permissions table...');
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'No user ID';
      final response = await supabase
          .from('permissions')
          .select('role')
          .eq('user_uuid', userId)
          .maybeSingle();
      final roleFromDb = response?['role'] as String?;
      final isManager = roleFromDb == 'manager';
      setState(() => _isManager = isManager);
      await _fetchRequests();
    } catch (e, st) {
      print('ERROR in _checkManagerAndFetch: $e');
      print(st);
      setState(() => _error = 'Failed to check permissions: $e');
    }
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
    try {
      final response = await supabase
          .from('my_leave_balance')
          .select('remaining_days')
          .single();

      setState(() {
        _remainingLeaveDays = response['remaining_days'] as int;
        _error = null;
      });
    } catch (e) {
      print('Balance fetch error: $e');
      setState(() => _error = 'Failed to load leave balance');
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
      print('Fetching requests for user: $userId | isManager: $_isManager');
      late final PostgrestList response;
      if (_isManager) {
        response = await supabase
            .from('verlof')
            .select('*')
            .order('created_at', ascending: false);
      } else {
        response = await supabase
            .from('verlof')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      }
      print('Fetched ${response.length} requests');
      final List<Map<String, dynamic>> requests = List.from(response);
      setState(() {
        _requests = requests;
        _events = _buildEventsMap(requests);
        _isLoadingRequests = false;
        _error = null;
      });
    } catch (e, st) {
      print('ERROR in _fetchRequests: $e');
      print(st);
      setState(() {
        _isLoadingRequests = false;
        _error = 'Failed to load requests: $e';
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
      var current = DateTime.utc(startUtc.year, startUtc.month, startUtc.day);
      final end = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
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
    final customReason = _reasonController.text.trim();
    final quickType = _selectedVerlofType;
    if (startTxt.isEmpty || endTxt.isEmpty) {
      _showSnackBar('Please select start and end date.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    if (quickType == null && customReason.isEmpty) {
      _showSnackBar('Please select a type or enter a reason.', isError: true);
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
    final startUtc =
        DateTime(startDt.year, startDt.month, startDt.day).toUtc().toIso8601String();
    final endUtc =
        DateTime(endDt.year, endDt.month, endDt.day).toUtc().toIso8601String();
    final String reasonText = customReason.isNotEmpty
        ? customReason
        : (quickType == 'personal' ? 'Personal reason' : quickType!);

    try {
      await supabase.from('verlof').insert({
        'start': startUtc,
        'end_time': endUtc,
        'reason': reasonText,
        'verlof_type': quickType,
        'verlof_state': 'pending',
        'user_id': userId,
        'days_count': daysRequested,
      }).select();
      _showSnackBar('Request submitted successfully!');
      _clearForm();
      setState(() => _selectedVerlofType = null);
      await _fetchRequests();
      _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to submit request: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRequest(dynamic requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final id = requestId is int ? requestId : int.tryParse(requestId.toString());
      if (id == null) throw 'Invalid ID';

      await supabase.from('verlof').delete().eq('id', id);

      _showSnackBar('Request deleted');
      await _fetchRequests();
      await _fetchLeaveBalance(); 
    } catch (e) {
      _showSnackBar('Failed to delete', isError: true);
    }
  }
  
  Future<void> _updateRequestStatus(int id, String action) async {
    final newState = action == 'approve' ? 'approved' : 'denied';
    
    try {
      await supabase
          .from('verlof')
          .update({'verlof_state': newState})
          .eq('id', id);

      _showSnackBar('Request $newState!');
      await _fetchRequests();
      await _fetchLeaveBalance(); // auto-updates via DB trigger
    } catch (e) {
      _showSnackBar('Failed: $e', isError: true);
    }
  }
    
  Future<void> _bulkUpdateStatus(String action) async {
    if (_selectedRequestIds.isEmpty) {
      _showSnackBar('No requests selected', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Bulk ${action == 'approve' ? 'Approve' : 'Deny'}'),
        content: Text('Update ${_selectedRequestIds.length} request(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action == 'approve' ? 'Approve All' : 'Deny All', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingRequests = true);
    final newState = action == 'approve' ? 'approved' : 'denied';

    try {
      // ONE SINGLE BULK UPDATE — DB trigger does ALL the balance logic
      await supabase
          .from('verlof')
          .update({'verlof_state': newState})
          .inFilter('id', _selectedRequestIds.toList());

      _showSnackBar('Bulk ${action == 'approve' ? 'approved' : 'denied'} ${_selectedRequestIds.length} requests!');
      setState(() {
        _selectedRequestIds.clear();
        _isBulkMode = false;
      });
      await _fetchRequests();
      await _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Bulk action failed: $e', isError: true);
    } finally {
      setState(() => _isLoadingRequests = false);
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

  Future<void> _submitQuickSick() async {
    if (_isSubmittingQuickSick) return;

    setState(() => _isSubmittingQuickSick = true);

    // Rate limiting
    if (_lastSubmitTime != null &&
        DateTime.now().difference(_lastSubmitTime!) < _rateLimitDuration) {
      _showSnackBar('Please wait a moment before submitting again.', isError: true);
      setState(() => _isSubmittingQuickSick = false);
      return;
    }
    _lastSubmitTime = DateTime.now();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Not logged in.', isError: true);
      setState(() => _isSubmittingQuickSick = false);
      return;
    }

    // TODAY only - normalized to date only (ignore time)
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final todayUtc = todayDateOnly.toUtc().toIso8601String();

    // Check for existing sick request today (pending or approved)
    final existing = await supabase
        .from('verlof')
        .select('id')
        .eq('user_id', userId)
        .eq('verlof_type', 'sick')
        .inFilter('verlof_state', ['pending', 'approved'])
        .gte('start', todayUtc)
        .lte('start', todayUtc.substring(0, 10) + 'T23:59:59.999Z');

    if (existing.isNotEmpty) {
      _showSnackBar('You have already called in sick for today.', isError: true);
      setState(() => _isSubmittingQuickSick = false);
      return;
    }

    final daysCount = _calculateWorkdays(todayDateOnly, todayDateOnly);

    try {
      await supabase.from('verlof').insert({
        'start': todayUtc,
        'end_time': todayUtc,
        'reason': 'Sick',
        'verlof_type': 'sick',
        'verlof_state': 'pending',
        'user_id': userId,
        'days_count': daysCount,
      });

      _showSnackBar('Called in sick for today');
      await _fetchRequests();
      await _fetchLeaveBalance();
    } catch (e) {
      _showSnackBar('Failed to submit sick day: $e', isError: true);
    } finally {
      setState(() => _isSubmittingQuickSick = false);
    }
  }
  
  void _clearForm() {
    _startDateController.clear();
    _endDateController.clear();
    _reasonController.clear();
    _selectedVerlofType = null;
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

  String _getDisplayTitle(Map<String, dynamic> req) {
    final verlofType = req['verlof_type'] as String?;
    final reasonText = req['reason'] as String?;
    if (verlofType != null) {
      final capitalized = verlofType[0].toUpperCase() + verlofType.substring(1);
      return reasonText != null && reasonText.toLowerCase() != verlofType
          ? '$capitalized: $reasonText'
          : capitalized;
    }
    return _sanitizeInput(reasonText ?? 'N/A');
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
                                  firstDay: DateTime.now(),
                                  lastDay: DateTime.now().add(const Duration(days: 365)),
                                  focusedDay: _focusedDay,
                                  calendarFormat: CalendarFormat.month,
                                  headerStyle: const HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                    titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                                  ),
                                  daysOfWeekStyle: const DaysOfWeekStyle(
                                    weekdayStyle: TextStyle(color: Colors.white70),
                                    weekendStyle: TextStyle(color: Colors.redAccent),
                                  ),
                                  calendarStyle: const CalendarStyle(
                                    outsideDaysVisible: false,
                                    weekendTextStyle: TextStyle(color: Colors.redAccent),
                                    defaultTextStyle: TextStyle(color: Colors.white),
                                    selectedDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    todayDecoration: BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle),
                                  ),
                                  startingDayOfWeek: StartingDayOfWeek.monday,
                                  selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                                  onDaySelected: (s, f) => setState(() {
                                    _selectedDay = s;
                                    _focusedDay = f;
                                  }),
                                  onPageChanged: (f) => setState(() => _focusedDay = f),
                                  eventLoader: _getEventsForDay,
                                  calendarBuilders: CalendarBuilders(
                                    markerBuilder: (c, day, ev) {
                                      if (ev.isEmpty) return null;
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: ev.take(3).map((e) {
                                          final req = e as Map<String, dynamic>;
                                          final state = req['verlof_state'] as String?;
                                          final approved = state == 'approved';
                                          final denied = state == 'denied';
                                          return Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
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
                                              final start = DateTime.tryParse(e['start'] ?? '')?.toLocal();
                                              final end = DateTime.tryParse(e['end_time'] ?? '')?.toLocal();
                                              final state = e['verlof_state'] as String?;
                                              final status = state == 'approved'
                                                  ? 'Approved'
                                                  : state == 'denied'
                                                      ? 'Denied'
                                                      : 'Pending';
                                              final title = _getDisplayTitle(e);
                                              return '$title\n${start != null ? DateFormat('MMM dd').format(start) : ''} - ${end != null ? DateFormat('MMM dd').format(end) : ''}\nStatus: $status';
                                            })
                                            .join('\n\n'),
                                        preferBelow: false,
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                                        child: Container(
                                          margin: const EdgeInsets.all(6),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              color: day.weekday == DateTime.saturday ||
                                                      day.weekday == DateTime.sunday
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.sick, color: Colors.red, size: 28),
                                        SizedBox(width: 12),
                                        Text(
                                          'Quick Sick',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Call in sick for today or pick another date',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                      onPressed: _isSubmittingQuickSick ? null : _submitQuickSick,
                                        icon: _isSubmittingQuickSick
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : const Icon(Icons.sick, color: Colors.white),
                                        label: Text(
                                          _isSubmittingQuickSick
                                              ? 'Submitting...'
                                              : 'Call in Sick Today',
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy').format(_focusedDay),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    ToggleButtons(
                                      borderRadius: BorderRadius.circular(20),
                                      selectedColor: Colors.white,
                                      fillColor: Colors.grey[700],
                                      color: Colors.grey[600],
                                      constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                                      isSelected: [
                                        _calendarFormat == CalendarFormat.month,
                                        _calendarFormat == CalendarFormat.week,
                                      ],
                                      onPressed: (i) => setState(() => _calendarFormat =
                                          i == 0 ? CalendarFormat.month : CalendarFormat.week),
                                      children: const [
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Month')),
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Week')),
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
                                      onChanged: (v) => setState(() => _showWorkWeek = v),
                                      activeColor: Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1, thickness: 1),
                                const SizedBox(height: 16),
                                TableCalendar(
                                  firstDay: DateTime.now(),
                                  lastDay: DateTime.now().add(const Duration(days: 365)),
                                  focusedDay: _focusedDay,
                                  calendarFormat: _calendarFormat,
                                  startingDayOfWeek: StartingDayOfWeek.monday,
                                  headerVisible: false,
                                  selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                                  onDaySelected: (s, f) => setState(() {
                                    _selectedDay = s;
                                    _focusedDay = f;
                                  }),
                                  onPageChanged: (f) => setState(() => _focusedDay = f),
                                  eventLoader: _getEventsForDay,
                                  enabledDayPredicate: _showWorkWeek
                                      ? (d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday
                                      : null,
                                  calendarStyle: CalendarStyle(
                                    outsideDaysVisible: false,
                                    weekendTextStyle: TextStyle(
                                        color: _showWorkWeek ? Colors.grey[400] : Colors.red),
                                    disabledTextStyle: TextStyle(color: Colors.grey[400]),
                                  ),
                                  calendarBuilders: CalendarBuilders(
                                    markerBuilder: (c, day, ev) {
                                      if (ev.isEmpty) return null;
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: ev.take(3).map((e) {
                                          final req = e as Map<String, dynamic>;
                                          final state = req['verlof_state'] as String?;
                                          final approved = state == 'approved';
                                          final denied = state == 'denied';
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
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  _isManager ? 'All Team Requests' : 'New Leave Request',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedVerlofType,
                                    decoration: const InputDecoration(
                                      labelText: 'Quick Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    hint: const Text('Select type (optional)'),
                                    items: _verlofTypes.map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type[0].toUpperCase() + type.substring(1)),
                                    )).toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedVerlofType = value);
                                      if (value != null && value != 'personal') {
                                        _reasonController.text = value;
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _reasonController,
                                    decoration: const InputDecoration(
                                      labelText: 'Custom Reason',
                                      hintText: 'e.g. Dentist, Wedding, etc. (optional if quick type selected)',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                  ),
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
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting ? null : _submitRequest,
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _isSubmitting
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text('Submit', style: TextStyle(fontSize: 16, color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                Text(
                                  _isManager ? 'Team Requests' : 'My Requests',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                _requests.isEmpty
                                ? const Text('No requests yet.')
                                : Column(
                                    children: [
                                      // BULK ACTION BAR
                                      if (_isManager && _isBulkMode && _selectedRequestIds.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue),
                                          ),
                                          child: Row(
                                            children: [
                                              Text('${_selectedRequestIds.length} selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const Spacer(),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.check, size: 18),
                                                label: const Text('Approve All'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => _bulkUpdateStatus('approve'),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.close, size: 18),
                                                label: const Text('Deny All'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => _bulkUpdateStatus('deny'),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton(
                                                onPressed: () => setState(() {
                                                  _selectedRequestIds.clear();
                                                  _isBulkMode = false;
                                                }),
                                                child: const Text(
                                                  'Cancel',
                                                  style: TextStyle(color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // BULK MODE CONTROLS
                                      if (_isManager)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Wrap(
                                            spacing: 8,
                                            children: [
                                              if (!_isBulkMode)
                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.library_add_check_outlined),
                                                  label: const Text('Bulk Actions'),
                                                  onPressed: () => setState(() => _isBulkMode = true),
                                                ),
                                              if (_isBulkMode) ...[
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedRequestIds = _requests
                                                          .where((r) => r['verlof_state'] != 'approved' && r['user_id'] != supabase.auth.currentUser?.id)
                                                          .map((r) => r['id'] as int)
                                                          .toSet();
                                                    });
                                                  },
                                                  child: const Text('Select All Pending'),
                                                ),
                                                TextButton(onPressed: () => setState(() => _selectedRequestIds.clear()), child: const Text('Clear')),
                                                TextButton(onPressed: () => setState(() => _isBulkMode = false), child: const Text('Exit Bulk Mode')),
                                              ],
                                            ],
                                          ),
                                        ),

                                      // THE ACTUAL LIST WITH SELECTION
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _requests.length,
                                        itemBuilder: (context, i) {
                                          final req = _requests[i];
                                          final id = req['id'] as int;
                                          final state = req['verlof_state'] as String?;
                                          final isOwn = req['user_id'] == supabase.auth.currentUser?.id;
                                          final isSelected = _selectedRequestIds.contains(id);
                                          final canSelect = _isManager && !isOwn && state != 'approved';

                                          return Card(
                                            color: isSelected ? Colors.blue.shade50 : null,
                                            child: ListTile(
                                              onTap: _isBulkMode && canSelect
                                                  ? () => setState(() => isSelected ? _selectedRequestIds.remove(id) : _selectedRequestIds.add(id))
                                                  : null,
                                              onLongPress: _isManager && !isOwn && !_isBulkMode ? () => setState(() => _isBulkMode = true) : null,
                                              leading: _isBulkMode && canSelect
                                                  ? Checkbox(
                                                      value: isSelected,
                                                      onChanged: (v) => setState(() => v == true ? _selectedRequestIds.add(id) : _selectedRequestIds.remove(id)),
                                                    )
                                                  : null,
                                              title: Text(_getDisplayTitle(req)),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (DateTime.tryParse(req['start'] ?? '') != null)
                                                    Text('Start: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(req['start']).toLocal())}'),
                                                  if (DateTime.tryParse(req['end_time'] ?? '') != null)
                                                    Text('End: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(req['end_time']).toLocal())}'),
                                                  Text('Status: ${state == 'approved' ? 'Approved' : state == 'denied' ? 'Denied' : 'Pending'}'),
                                                  Text('Days: ${req['days_count']}'),
                                                  if (_isManager) Text('User: ${req['user_id']}'),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (_isManager && !isOwn && !_isBulkMode) ...[
                                                    if (state != 'approved')
                                                      IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _updateRequestStatus(id, 'approve'), tooltip: 'Approve'),
                                                    if (state != 'denied')
                                                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _updateRequestStatus(id, 'deny'), tooltip: 'Deny'),
                                                  ],
                                                  if (isOwn || _isManager)
                                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteRequest(id), tooltip: 'Delete'),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
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