// lib/screens/teacher/subject_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';

/// Subject-teacher period attendance — 'was this student in today's Math
/// class' — a different question from homeroom's daily attendance
/// (AttendanceScreen), which is 'were they in school today at all'.
class SubjectAttendanceScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final int grade;
  final String section;

  const SubjectAttendanceScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    required this.section,
  });

  @override
  State<SubjectAttendanceScreen> createState() => _SubjectAttendanceScreenState();
}

class _SubjectAttendanceScreenState extends State<SubjectAttendanceScreen> {
  final _apiService = ApiService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<dynamic> _students = [];
  final Map<int, String> _statuses = {};

  static const _statusOptions = ['present', 'absent', 'late', 'excused'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await _apiService.getSubjectAttendanceRoster(
        subjectId: widget.subjectId, grade: widget.grade, section: widget.section, date: _dateStr,
      );
      if (response['success'] == true) {
        final students = response['students'] as List;
        _statuses.clear();
        for (final s in students) {
          _statuses[s['student_id']] = s['status'];
        }
        setState(() { _students = students; _isLoading = false; });
      } else {
        setState(() { _error = response['error']?.toString() ?? 'Failed to load attendance'; _isLoading = false; });
      }
    } catch (e, stack) {
      debugPrint('[SubjectAttendanceScreen] _load exception: $e\n$stack');
      setState(() { _error = 'Could not load attendance.\n\nDetails: $e'; _isLoading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _save() async {
    setState(() { _isSaving = true; _error = null; });
    try {
      final entries = _students
          .map((s) => {'student_id': s['student_id'], 'status': _statuses[s['student_id']] ?? 'present'})
          .toList();

      final response = await _apiService.saveSubjectAttendance(
        subjectId: widget.subjectId, grade: widget.grade, section: widget.section, date: _dateStr, entries: entries,
      );

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved attendance for ${response['saved']} students')),
        );
      } else {
        setState(() => _error = response['error']?.toString() ?? 'Failed to save attendance');
      }
    } catch (e, stack) {
      debugPrint('[SubjectAttendanceScreen] _save exception: $e\n$stack');
      setState(() => _error = 'Could not save attendance.\n\nDetails: $e');
    }
    setState(() => _isSaving = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      case 'excused': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.subjectName} — Grade ${widget.grade} ${widget.section}'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.indigo.shade50,
            child: Text(
              DateFormat('EEEE, MMMM d, y').format(_selectedDate),
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade900),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(_error!, style: TextStyle(color: Colors.red.shade700)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final s = _students[index];
                      final current = _statuses[s['student_id']] ?? 'present';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['student_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: _statusOptions.map((status) {
                                  final selected = current == status;
                                  return ChoiceChip(
                                    label: Text(lang.t('teacher_attendance_$status'), style: const TextStyle(fontSize: 12)),
                                    selected: selected,
                                    selectedColor: _statusColor(status).withOpacity(0.2),
                                    labelStyle: TextStyle(color: selected ? _statusColor(status) : Colors.grey.shade700),
                                    onSelected: (_) => setState(() => _statuses[s['student_id']] = status),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(lang.t('teacher_save'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
