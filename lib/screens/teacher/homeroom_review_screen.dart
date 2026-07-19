// lib/screens/teacher/homeroom_review_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';

class HomeroomReviewScreen extends StatefulWidget {
  final int grade;
  final String section;

  const HomeroomReviewScreen({super.key, required this.grade, required this.section});

  @override
  State<HomeroomReviewScreen> createState() => _HomeroomReviewScreenState();
}

class _HomeroomReviewScreenState extends State<HomeroomReviewScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  bool _isActing = false;
  String? _error;
  List<dynamic> _marks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final response = await _apiService.getHomeroomPending(grade: widget.grade, section: widget.section);
    if (response['success'] == true) {
      setState(() { _marks = response['data'] as List; _isLoading = false; });
    } else {
      setState(() { _error = response['error']; _isLoading = false; });
    }
  }

  // Group the flat list of Mark rows by (subject, assessment_type) so the
  // homeroom teacher accepts/rejects a whole class submission at once,
  // matching how the subject teacher submitted it.
  Map<String, List<dynamic>> get _grouped {
    final Map<String, List<dynamic>> groups = {};
    for (final m in _marks) {
      final key = '${m['subject']}|${m['assessment_type']}|${m['subject_name']}|${m['assessment_type_name']}';
      groups.putIfAbsent(key, () => []).add(m);
    }
    return groups;
  }

  Future<void> _decide(String key, bool accept) async {
    final parts = key.split('|');
    final subjectId = int.parse(parts[0]);
    final assessmentTypeId = int.parse(parts[1]);

    setState(() => _isActing = true);
    final response = await _apiService.homeroomDecide(
      accept: accept, subjectId: subjectId, assessmentTypeId: assessmentTypeId,
      grade: widget.grade, section: widget.section,
    );
    if (response['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Accepted' : 'Sent back to teacher')),
      );
      await _load();
    } else {
      setState(() => _error = response['error']);
    }
    setState(() => _isActing = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final groups = _grouped;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Grade ${widget.grade} - ${widget.section}'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: groups.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(lang.t('teacher_no_pending'), style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: groups.entries.map((entry) {
                        final parts = entry.key.split('|');
                        final subjectName = parts[2];
                        final assessmentName = parts[3];
                        final rows = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$subjectName - $assessmentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${rows.length} students', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                const Divider(),
                                ...rows.map((m) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(m['student_name'] ?? ''),
                                          Text('${m['score'] ?? '-'} / ${m['max_score']}'),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.undo, size: 18, color: Colors.red),
                                        label: Text(lang.t('teacher_reject'), style: const TextStyle(color: Colors.red)),
                                        onPressed: _isActing ? null : () => _decide(entry.key, false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                        icon: const Icon(Icons.check, size: 18, color: Colors.white),
                                        label: Text(lang.t('teacher_accept'), style: const TextStyle(color: Colors.white)),
                                        onPressed: _isActing ? null : () => _decide(entry.key, true),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
    );
  }
}
