// lib/widgets/attendance_summary_panel.dart
//
// ✅ NEW — parity with web's AttendanceSummaryPanel (shared by
// TeacherAttendance.js and TeacherSubjectAttendance.js): per-student
// present/absent/late/excused counts + attendance rate over a date
// range. Shared by both AttendanceScreen (daily/homeroom) and
// SubjectAttendanceScreen (per-subject) via the [fetchRecords]
// callback, same as the web shares one component between both pages.
//
// Aggregation happens client-side from the flat day-by-day record list,
// same approach as the web — no new backend endpoint needed, just the
// existing list endpoints' date_from/date_to filters.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceSummaryPanel extends StatefulWidget {
  /// Fetches the flat list of attendance records for [dateFrom]..[dateTo]
  /// (both yyyy-MM-dd). Expected to return the same envelope shape as
  /// ApiService's other calls: {'success': true, 'data': [...]} or
  /// {'success': false, 'error': '...'}.
  final Future<Map<String, dynamic>> Function(String dateFrom, String dateTo) fetchRecords;

  const AttendanceSummaryPanel({super.key, required this.fetchRecords});

  @override
  State<AttendanceSummaryPanel> createState() => _AttendanceSummaryPanelState();
}

class _AttendanceSummaryPanelState extends State<AttendanceSummaryPanel> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await widget.fetchRecords(_fmt(_from), _fmt(_to));
      if (response['success'] != true) {
        setState(() { _error = response['error']?.toString() ?? 'Failed to load attendance summary'; _isLoading = false; });
        return;
      }
      final records = (response['data'] as List?) ?? [];

      final byStudent = <int, Map<String, dynamic>>{};
      for (final r in records) {
        final studentId = r['student'] as int;
        final entry = byStudent.putIfAbsent(studentId, () => {
              'studentId': studentId,
              'name': r['student_name'],
              'studentIdDisplay': r['student_id_display'],
              'present': 0, 'absent': 0, 'late': 0, 'excused': 0,
            });
        final status = r['status'] as String?;
        if (status != null && entry.containsKey(status)) {
          entry[status] = (entry[status] as int) + 1;
        }
      }

      final rows = byStudent.values.map((s) {
        final total = (s['present'] as int) + (s['absent'] as int) + (s['late'] as int) + (s['excused'] as int);
        final rate = total > 0 ? (((s['present'] as int) + (s['late'] as int)) / total * 100).round() : null;
        return {...s, 'total': total, 'rate': rate};
      }).toList()
        ..sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

      setState(() { _rows = rows; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load attendance summary: $e'; _isLoading = false; });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context, initialDate: _from, firstDate: DateTime(2020), lastDate: _to,
    );
    if (picked != null) { setState(() => _from = picked); _load(); }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context, initialDate: _to, firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null) { setState(() => _to = picked); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _pickFrom,
                child: Text('From: ${_fmt(_from)}', style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _pickTo,
                child: Text('To: ${_fmt(_to)}', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
          )
        else if (_isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
        else if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No attendance recorded for this range yet.', style: TextStyle(color: Colors.grey.shade600))),
          )
        else ...[
          ..._rows.map((row) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(row['studentIdDisplay'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                row['rate'] != null ? '${row['rate']}%' : '—',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                              ),
                              Text('attendance rate', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _countChip('Present', row['present'], Colors.green),
                          const SizedBox(width: 6),
                          _countChip('Absent', row['absent'], Colors.red),
                          const SizedBox(width: 6),
                          _countChip('Late', row['late'], Colors.orange),
                          const SizedBox(width: 6),
                          _countChip('Excused', row['excused'], Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${_rows.length} student(s) with recorded attendance in this range.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
        ],
      ],
    );
  }

  Widget _countChip(String label, dynamic count, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color.shade700, fontSize: 13)),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
