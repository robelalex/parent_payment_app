// lib/screens/child_record_screen.dart
//
// ✅ NEW — Jimma request #4 (part 1): "my child's record" — one connected
// screen for daily attendance, subject attendance, and accepted marks,
// scoped strictly to this one student. Backed by
// GET /students/{id}/child_record/, which itself only ever returns data
// for the logged-in parent's OWN child — enforced server-side by
// IsSameSchoolOrOwnParent, same guard already protecting the pending
// payments / payment history screens this app already has.
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChildRecordScreen extends StatefulWidget {
  final int studentDbId;
  final String studentName;

  const ChildRecordScreen({
    super.key,
    required this.studentDbId,
    required this.studentName,
  });

  @override
  State<ChildRecordScreen> createState() => _ChildRecordScreenState();
}

class _ChildRecordScreenState extends State<ChildRecordScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _apiService.getChildRecord(widget.studentDbId);
      if (result['success'] == true) {
        setState(() {
          _data = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to load record';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName}\'s Record'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.event_available), text: 'Attendance'),
            Tab(icon: Icon(Icons.grade), text: 'Marks'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAttendanceTab(),
                    _buildMarksTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance tab ──────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    final attendance = _data?['attendance'] as Map<String, dynamic>? ?? {};
    final daily = attendance['daily'] as Map<String, dynamic>? ?? {};
    final dailySummary = daily['summary'] as Map<String, dynamic>? ?? {};
    final dailyRecords = (daily['records'] as List?) ?? [];
    final subjectGroups = (attendance['subject'] as List?) ?? [];

    if (dailyRecords.isEmpty && subjectGroups.isEmpty) {
      return _buildEmptyState(
        Icons.event_busy,
        'No attendance recorded yet for this academic year.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDailySummaryCard(dailySummary),
          const SizedBox(height: 16),
          if (dailyRecords.isNotEmpty) ...[
            const Text('Recent Daily Attendance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...dailyRecords.take(15).map((r) => _buildAttendanceRow(
                  r['date'],
                  r['status'],
                  r['status_display'],
                )),
          ],
          if (subjectGroups.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('By Subject',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...subjectGroups.map((g) => _buildSubjectAttendanceCard(g)),
          ],
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard(Map<String, dynamic> summary) {
    final rate = summary['attendance_rate'];
    final total = summary['total_days'] ?? 0;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Overall Attendance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (rate != null)
                  Text(
                    '$rate%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: rate >= 90
                          ? Colors.green.shade700
                          : rate >= 75
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$total school day(s) recorded',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _statChip('Present', summary['present'] ?? 0, Colors.green),
                _statChip('Absent', summary['absent'] ?? 0, Colors.red),
                _statChip('Late', summary['late'] ?? 0, Colors.orange),
                _statChip('Excused', summary['excused'] ?? 0, Colors.blueGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int count, MaterialColor color) {
    return Chip(
      label: Text('$label: $count'),
      backgroundColor: color.shade50,
      labelStyle: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.shade200),
    );
  }

  Widget _buildAttendanceRow(String? date, String? status, String? statusDisplay) {
    final color = _statusColor(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(date ?? '')),
          Text(statusDisplay ?? '', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSubjectAttendanceCard(dynamic group) {
    final subject = group['subject'] ?? '';
    final summary = group['summary'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Present: ${summary['present'] ?? 0}  •  Absent: ${summary['absent'] ?? 0}  •  Late: ${summary['late'] ?? 0}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: ((group['records'] as List?) ?? [])
                  .take(10)
                  .map<Widget>((r) => _buildAttendanceRow(
                        r['date'],
                        r['status'],
                        r['status_display'],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'excused':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  // ── Marks tab ────────────────────────────────────────────────────────

  Widget _buildMarksTab() {
    final marks = _data?['marks'] as Map<String, dynamic>? ?? {};
    final terms = (marks['terms'] as List?) ?? [];

    if (terms.isEmpty) {
      return _buildEmptyState(
        Icons.grade_outlined,
        'No marks have been finalized yet for this academic year.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: terms.map<Widget>((t) => _buildTermCard(t)).toList(),
      ),
    );
  }

  Widget _buildTermCard(dynamic term) {
    final termName = term['term'] ?? 'Ungrouped';
    final marksList = (term['marks'] as List?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(termName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...marksList.map((m) => _buildMarkRow(m)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkRow(dynamic m) {
    final score = m['score'];
    final maxScore = m['max_score'];
    final pct = (score != null && maxScore != null && maxScore > 0)
        ? (score / maxScore * 100)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(m['assessment_type'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              score != null ? '$score / $maxScore' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: pct == null
                    ? Colors.grey
                    : pct >= 50
                        ? Colors.green.shade700
                        : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}