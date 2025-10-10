import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  // Fetch user's leave requests from verlof table
  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Not logged in. Please log in again.';
      });
      return;
    }
    try {
      final response = await supabase
          .from('verlof')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      setState(() {
        _requests = List<Map<String, dynamic>>.from(response);
        _isLoadingRequests = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
        _error = 'Failed to fetch requests: $e';
      });
    }
  }

  // Submit a new leave request
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
      _showSnackBar('Please fill all fields.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }
    try {
      final startTimestamp = DateTime.parse('$startDate 00:00:00Z').toIso8601String();
      final endTimestamp = DateTime.parse('$endDate 00:00:00Z').toIso8601String();
      await supabase.from('verlof').insert({
        'start': startTimestamp,
        'end_time': endTimestamp,
        'type': reason,
        'approved': false,
        'user_id': userId,
      });
      _showSnackBar('Request submitted successfully!');
      _clearForm();
      _fetchRequests(); // Refresh list
    } catch (e) {
      _showSnackBar('Failed to submit request: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Cancel a leave request by ID
  Future<void> _cancelRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from('verlof').delete().eq('id', requestId);
      _showSnackBar('Request cancelled successfully!');
      _fetchRequests();
    } catch (e) {
      _showSnackBar('Failed to cancel request: $e', isError: true);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard - Leave Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _isLoadingRequests
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Submit Form
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Submit New Leave Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _startDateController,
                          decoration: const InputDecoration(
                            labelText: 'Start Date (YYYY-MM-DD)',
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
                            labelText: 'End Date (YYYY-MM-DD)',
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
                                : const Text('Submit Request'),
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
                // Requests List
                Expanded(
                  child: _requests.isEmpty
                      ? const Center(child: Text('No leave requests yet. Submit one above!'))
                      : ListView.builder(
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            final startDate = DateTime.tryParse(request['start'] ?? '')?.toLocal();
                            final endDate = DateTime.tryParse(request['end_time'] ?? '')?.toLocal();
                            String status;
                            if (request['approved'] == true) {
                              status = 'Approved';
                            } else if (request['approved'] == false) {
                              status = 'Pending';
                            } else {
                              status = 'Denied';
                            }
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text('Reason: ${request['type'] ?? 'N/A'}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (startDate != null) Text('Start: ${DateFormat('yyyy-MM-dd').format(startDate)}'),
                                    if (endDate != null) Text('End: ${DateFormat('yyyy-MM-dd').format(endDate)}'),
                                    Text('Status: $status'),
                                    ...request.entries.where((entry) => entry.key != 'id' && entry.key != 'start' && entry.key != 'end_time' && entry.key != 'type' && entry.key != 'approved' && entry.key != 'user_id' && entry.key != 'created_at').map((entry) => Text('${entry.key}: ${entry.value ?? 'N/A'}')),
                                  ],
                                ),
                                trailing: status == 'Pending'
                                    ? IconButton(
                                        icon: const Icon(Icons.cancel, color: Colors.red),
                                        onPressed: () => _cancelRequest(request['id']),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
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