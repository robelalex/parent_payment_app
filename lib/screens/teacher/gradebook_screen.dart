// lib/screens/teacher/gradebook_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';

/// One table, two modes:
///  - Subject teacher (isHomeroomView = false): editable score cells,
///    per-row "Send" and a top "Send All" bulk button.
///  - Homeroom (isHomeroomView = true): read-only scores, per-row
///    "Accept"/"Reject" and top bulk "Accept All"/"Reject All" buttons.
/// Same data shape either way — students as rows, every assessment in
/// the selected term as a column, plus a computed Total column.
class GradebookScreen extends StatefulWidget {
  final int subjectId;
  final String subjectName;
  final int grade;
  final String section;
  final int? academicYearId;
  final bool isHomeroomView;

  const GradebookScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    required this.section,
    required this.academicYearId,
    this.isHomeroomView = false,
  });

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  final _apiService = ApiService();

  bool _isLoadingTerms = true;
  bool _isLoadingGradebook = false;
  bool _isActing = false;
  String? _error;

  List<dynamic> _terms = [];
  int? _selectedTermId;

  List<dynamic> _assessmentTypes = [];
  List<dynamic> _students = [];
  final Map<String, TextEditingController> _controllers = {}; // key: "studentId:assessmentTypeId"

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTerms() async {
    if (widget.academicYearId == null) {
      setState(() { _error = 'No academic year set for your school'; _isLoadingTerms = false; });
      return;
    }
    setState(() { _isLoadingTerms = true; _error = null; });
    try {
      final response = await _apiService.getTerms(widget.academicYearId!);
      if (response['success'] == true) {
        final list = response['data'] as List;
        setState(() {
          _terms = list;
          _isLoadingTerms = false;
          if (list.isNotEmpty) _selectedTermId = list.first['id'];
        });
        if (list.isNotEmpty) await _loadGradebook();
      } else {
        setState(() { _error = response['error']?.toString() ?? 'Failed to load terms'; _isLoadingTerms = false; });
      }
    } catch (e, stack) {
      debugPrint('[GradebookScreen] _loadTerms exception: $e\n$stack');
      setState(() { _error = 'Could not load terms.\n\nDetails: $e'; _isLoadingTerms = false; });
    }
  }

  Future<void> _loadGradebook() async {
    if (_selectedTermId == null) return;
    setState(() { _isLoadingGradebook = true; _error = null; });
    try {
      final response = await _apiService.getGradebook(
        subjectId: widget.subjectId, termId: _selectedTermId!,
        grade: widget.grade, section: widget.section,
      );
      if (response['success'] == true) {
        final assessmentTypes = response['assessment_types'] as List;
        final students = response['students'] as List;

        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        for (final s in students) {
          final columns = s['columns'] as Map;
          for (final a in assessmentTypes) {
            final col = columns[a['id'].toString()] ?? columns[a['id']];
            final score = col is Map ? col['score'] : null;
            _controllers['${s['student_id']}:${a['id']}'] = TextEditingController(
              text: score != null ? score.toString() : '',
            );
          }
        }

        setState(() { _assessmentTypes = assessmentTypes; _students = students; _isLoadingGradebook = false; });
      } else {
        setState(() { _error = response['error']?.toString() ?? 'Failed to load gradebook'; _isLoadingGradebook = false; });
      }
    } catch (e, stack) {
      debugPrint('[GradebookScreen] _loadGradebook exception: $e\n$stack');
      setState(() { _error = 'Could not load the gradebook.\n\nDetails: $e'; _isLoadingGradebook = false; });
    }
  }

  Map<String, dynamic>? _columnFor(Map student, int assessmentTypeId) {
    final columns = student['columns'] as Map;
    final col = columns[assessmentTypeId.toString()] ?? columns[assessmentTypeId];
    return col == null ? null : Map<String, dynamic>.from(col as Map);
  }

  // ===== Subject teacher actions =====

  Future<void> _saveAllVisible() async {
    setState(() => _isActing = true);
    try {
      for (final a in _assessmentTypes) {
        final entries = _students.map((s) {
          final key = '${s['student_id']}:${a['id']}';
          final text = _controllers[key]?.text.trim() ?? '';
          return {'student_id': s['student_id'], 'score': text.isEmpty ? null : num.tryParse(text)};
        }).toList();

        await _apiService.saveMarks(
          subjectId: widget.subjectId, assessmentTypeId: a['id'],
          grade: widget.grade, section: widget.section, entries: entries,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
      await _loadGradebook();
    } catch (e) {
      setState(() => _error = 'Could not save.\n\nDetails: $e');
    }
    setState(() => _isActing = false);
  }

  Future<void> _sendStudent(int studentId) async {
    setState(() => _isActing = true);
    try {
      // Save this student's current cell values first, then submit them.
      for (final a in _assessmentTypes) {
        final key = '$studentId:${a['id']}';
        final text = _controllers[key]?.text.trim() ?? '';
        await _apiService.saveMarks(
          subjectId: widget.subjectId, assessmentTypeId: a['id'],
          grade: widget.grade, section: widget.section,
          entries: [{'student_id': studentId, 'score': text.isEmpty ? null : num.tryParse(text)}],
        );
      }
      final response = await _apiService.submitStudent(
        subjectId: widget.subjectId, termId: _selectedTermId!,
        grade: widget.grade, section: widget.section, studentId: studentId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['success'] == true ? 'Sent to homeroom' : (response['error']?.toString() ?? 'Failed'))),
        );
      }
      await _loadGradebook();
    } catch (e) {
      setState(() => _error = 'Could not send.\n\nDetails: $e');
    }
    setState(() => _isActing = false);
  }

  Future<void> _sendAll() async {
    setState(() => _isActing = true);
    try {
      await _saveAllVisible();
      for (final a in _assessmentTypes) {
        await _apiService.submitMarks(
          subjectId: widget.subjectId, assessmentTypeId: a['id'],
          grade: widget.grade, section: widget.section,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent all to homeroom')));
      }
      await _loadGradebook();
    } catch (e) {
      setState(() => _error = 'Could not send all.\n\nDetails: $e');
    }
    setState(() => _isActing = false);
  }

  // ===== Homeroom actions =====

  Future<void> _decideStudent(int studentId, bool accept) async {
    setState(() => _isActing = true);
    try {
      final student = _students.firstWhere((s) => s['student_id'] == studentId);
      for (final a in _assessmentTypes) {
        final col = _columnFor(student, a['id']);
        if (col != null && col['status'] == 'submitted') {
          await _apiService.homeroomDecide(
            accept: accept, subjectId: widget.subjectId, assessmentTypeId: a['id'],
            grade: widget.grade, section: widget.section, studentId: studentId,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Accepted' : 'Sent back to teacher')),
        );
      }
      await _loadGradebook();
    } catch (e) {
      setState(() => _error = 'Could not update.\n\nDetails: $e');
    }
    setState(() => _isActing = false);
  }

  Future<void> _decideAll(bool accept) async {
    setState(() => _isActing = true);
    try {
      for (final a in _assessmentTypes) {
        await _apiService.homeroomDecide(
          accept: accept, subjectId: widget.subjectId, assessmentTypeId: a['id'],
          grade: widget.grade, section: widget.section,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Accepted all' : 'Sent all back to teacher')),
        );
      }
      await _loadGradebook();
    } catch (e) {
      setState(() => _error = 'Could not update.\n\nDetails: $e');
    }
    setState(() => _isActing = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey.shade400;
    }
  }

  String _formatTotal(Map student) {
    if (student['weighted_percent'] != null) {
      final v = num.tryParse(student['weighted_percent'].toString());
      return v != null ? '${v.toStringAsFixed(1)}%' : '-';
    }
    if (student['raw_total'] != null && student['raw_max_total'] != null) {
      return '${student['raw_total']} / ${student['raw_max_total']}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.subjectName} — Grade ${widget.grade}${widget.section.isNotEmpty ? ' ${widget.section}' : ''}'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingTerms
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ===== Term selector =====
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<int>(
                    value: _selectedTermId,
                    decoration: InputDecoration(
                      labelText: 'Term',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true, fillColor: Colors.white,
                    ),
                    items: _terms
                        .map<DropdownMenuItem<int>>((t) => DropdownMenuItem(value: t['id'], child: Text(t['name'])))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedTermId = value);
                      _loadGradebook();
                    },
                  ),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(_error!, style: TextStyle(color: Colors.red.shade700)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _isLoadingGradebook ? null : _loadGradebook,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_terms.isEmpty && !_isLoadingTerms)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No terms have been set up yet. Ask your school admin to create one in Academics Setup.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _isLoadingGradebook
                        ? const Center(child: CircularProgressIndicator())
                        : _buildTable(),
                  ),

                if (_terms.isNotEmpty && _students.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.isHomeroomView
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.undo, size: 18, color: Colors.red),
                                    label: const Text('Reject All', style: TextStyle(color: Colors.red)),
                                    onPressed: _isActing ? null : () => _decideAll(false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                    icon: _isActing
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.check, size: 18, color: Colors.white),
                                    label: const Text('Accept All', style: TextStyle(color: Colors.white)),
                                    onPressed: _isActing ? null : () => _decideAll(true),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isActing ? null : _saveAllVisible,
                                    child: Text(lang.t('teacher_save')),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                                    onPressed: _isActing ? null : _sendAll,
                                    child: _isActing
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Send All', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTable() {
    if (_students.isEmpty) {
      return Center(
        child: Text('No students in this class.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
          columns: [
            const DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
            ..._assessmentTypes.map((a) => DataColumn(
                  label: Text('${a['name']}\n(/ ${a['max_score']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _students.map<DataRow>((s) {
            return DataRow(cells: [
              DataCell(SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s['student_name'], style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    Text(s['student_id_display'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              )),
              ..._assessmentTypes.map((a) {
                final col = _columnFor(s, a['id']);
                final status = col?['status'] ?? 'draft';
                final locked = widget.isHomeroomView || status == 'submitted' || status == 'accepted';
                final key = '${s['student_id']}:${a['id']}';
                return DataCell(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _controllers[key],
                          enabled: !locked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            filled: locked,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      if (status != 'draft')
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              }),
              DataCell(Text(_formatTotal(s), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(
                widget.isHomeroomView
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            tooltip: 'Reject',
                            onPressed: _isActing ? null : () => _decideStudent(s['student_id'], false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green, size: 20),
                            tooltip: 'Accept',
                            onPressed: _isActing ? null : () => _decideStudent(s['student_id'], true),
                          ),
                        ],
                      )
                    : TextButton(
                        onPressed: _isActing ? null : () => _sendStudent(s['student_id']),
                        child: const Text('Send'),
                      ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
