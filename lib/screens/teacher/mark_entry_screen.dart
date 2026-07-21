// lib/screens/teacher/mark_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';

class MarkEntryScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final int grade;
  final String section;
  final int? academicYearId;

  const MarkEntryScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    required this.section,
    required this.academicYearId,
  });

  @override
  State<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<MarkEntryScreen> {
  final _apiService = ApiService();
  bool _isLoadingAssessments = true;
  bool _isLoadingRoster = false;
  bool _isSaving = false;
  String? _error;
  List<dynamic> _assessmentTypes = [];
  int? _selectedAssessmentId;
  num? _maxScore;
  List<dynamic> _students = [];
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadAssessmentTypes();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAssessmentTypes() async {
    if (widget.academicYearId == null) {
      setState(() { _error = 'No academic year set for your school'; _isLoadingAssessments = false; });
      return;
    }
    try {
      final response = await _apiService.getAssessmentTypes(widget.academicYearId!);
      if (!mounted) return;
      if (response['success'] == true) {
        final list = response['data'] as List;
        setState(() {
          _assessmentTypes = list;
          _isLoadingAssessments = false;
          if (list.isNotEmpty) {
            _selectedAssessmentId = list.first['id'];
            _maxScore = list.first['max_score'];
          }
        });
        // Runs after the setState above so _selectedAssessmentId is
        // committed before _loadRoster reads it, and stays outside the
        // setState callback so its own try/catch can actually catch.
        if (list.isNotEmpty) {
          await _loadRoster();
        }
      } else {
        setState(() { _error = response['error']; _isLoadingAssessments = false; });
      }
    } catch (e) {
      // A thrown NativeHttpException (timeout, dropped connection, etc.)
      // used to leave _isLoadingAssessments stuck at true forever — an
      // endless spinner with no way for the teacher to tell what's wrong.
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. Check your connection and try again.';
        _isLoadingAssessments = false;
      });
    }
  }

  Future<void> _loadRoster() async {
    if (_selectedAssessmentId == null) return;
    setState(() { _isLoadingRoster = true; _error = null; });

    try {
      final response = await _apiService.getMarkRoster(
        subjectId: widget.subjectId, assessmentTypeId: _selectedAssessmentId!,
        grade: widget.grade, section: widget.section,
      );
      if (!mounted) return;

      if (response['success'] == true) {
        final students = response['students'] as List;
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        for (final s in students) {
          _controllers[s['student_id']] = TextEditingController(
            text: s['score'] != null ? s['score'].toString() : '',
          );
        }
        setState(() { _students = students; _isLoadingRoster = false; });
      } else {
        setState(() { _error = response['error']; _isLoadingRoster = false; });
      }
    } catch (e) {
      // Same fix as _loadAssessmentTypes: a thrown exception from the
      // native HTTP layer must never leave _isLoadingRoster stuck at
      // true, or the roster screen spins forever with no explanation.
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. Check your connection and try again.';
        _isLoadingRoster = false;
      });
    }
  }

  Future<void> _save({bool submit = false}) async {
    setState(() { _isSaving = true; _error = null; });

    try {
      final entries = _students.map((s) {
        final text = _controllers[s['student_id']]!.text.trim();
        return {'student_id': s['student_id'], 'score': text.isEmpty ? null : num.tryParse(text)};
      }).toList();

      final response = await _apiService.saveMarks(
        subjectId: widget.subjectId, assessmentTypeId: _selectedAssessmentId!,
        grade: widget.grade, section: widget.section, entries: entries,
      );

      if (response['success'] == true) {
        if (submit) {
          final submitResponse = await _apiService.submitMarks(
            subjectId: widget.subjectId, assessmentTypeId: _selectedAssessmentId!,
            grade: widget.grade, section: widget.section,
          );
          if (mounted && submitResponse['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Submitted ${submitResponse['submitted']} marks for homeroom review')),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved ${response['saved']} marks')),
          );
        }
        await _loadRoster();
      } else {
        if (!mounted) return;
        setState(() => _error = response['error']);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.subjectName),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingAssessments
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _assessmentTypes.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: SelectableText(_error!)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DropdownButtonFormField<int>(
                        value: _selectedAssessmentId,
                        decoration: InputDecoration(
                          labelText: lang.t('teacher_select_assessment'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true, fillColor: Colors.white,
                        ),
                        items: _assessmentTypes
                            .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(
                                  value: a['id'],
                                  child: Text('${a['name']} (out of ${a['max_score']})'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          final a = _assessmentTypes.firstWhere((x) => x['id'] == value);
                          setState(() { _selectedAssessmentId = value; _maxScore = a['max_score']; });
                          _loadRoster();
                        },
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: SelectableText(_error!, style: TextStyle(color: Colors.red.shade700)),
                        ),
                      ),
                    Expanded(
                      child: _isLoadingRoster
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _students.length,
                              itemBuilder: (context, index) {
                                final s = _students[index];
                                final status = s['status'] as String;
                                final locked = status == 'submitted' || status == 'accepted';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(s['student_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Text(s['student_id_display'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            lang.t('teacher_status_$status'),
                                            style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 70,
                                          child: TextField(
                                            controller: _controllers[s['student_id']],
                                            enabled: !locked,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              hintText: '/ $_maxScore',
                                              isDense: true,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: locked,
                                              fillColor: Colors.grey.shade100,
                                            ),
                                          ),
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
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : () => _save(submit: false),
                                child: Text(lang.t('teacher_save')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                                onPressed: _isSaving ? null : () => _save(submit: true),
                                child: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(lang.t('teacher_submit_for_review'), style: const TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}