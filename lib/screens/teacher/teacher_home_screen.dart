// lib/screens/teacher/teacher_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../widgets/language_toggle.dart';
import '../login_screen.dart';
import 'mark_entry_screen.dart';
import 'attendance_screen.dart';
import 'homeroom_review_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final session = await _apiService.getTeacherSession();
    if (session == null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
        );
      }
      return;
    }
    final response = await _apiService.getMyAssignments();
    if (response['success'] == true) {
      setState(() { _data = response; _isLoading = false; });
    } else {
      setState(() { _error = response['error']; _isLoading = false; });
    }
  }

  Future<void> _logout() async {
    await _apiService.clearTeacherSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final homeroom = _data?['homeroom'] as Map<String, dynamic>?;
    final subjectAssignments = (_data?['subject_assignments'] as List?) ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(lang.t('teacher_home_title')),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          const Padding(padding: EdgeInsets.only(right: 4), child: LanguageToggle()),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: lang.t('teacher_logout')),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: SelectableText(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_data?['teacher_name'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _data!['teacher_name'],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),

                      // ===== Homeroom card =====
                      if (homeroom != null) ...[
                        Text(lang.t('teacher_homeroom_label'),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.home, color: Colors.indigo.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Grade ${homeroom['grade']} - ${homeroom['section']}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.checklist),
                                        label: Text(lang.t('teacher_take_attendance'), textAlign: TextAlign.center),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AttendanceScreen(
                                              grade: homeroom['grade'], section: homeroom['section'],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.fact_check),
                                        label: Text(lang.t('teacher_review_marks'), textAlign: TextAlign.center),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HomeroomReviewScreen(
                                              grade: homeroom['grade'], section: homeroom['section'],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ===== Subject assignments =====
                      Text(lang.t('teacher_subjects_label'),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (subjectAssignments.isEmpty && homeroom == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(lang.t('teacher_no_assignments'), style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ...subjectAssignments.map((a) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Icon(Icons.menu_book, color: Colors.indigo.shade700),
                              ),
                              title: Text(a['subject__name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Grade ${a['grade']}${(a['section'] as String).isNotEmpty ? ' - ${a['section']}' : ' (all sections)'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MarkEntryScreen(
                                    subjectId: a['subject_id'],
                                    subjectName: a['subject__name'] ?? '',
                                    grade: a['grade'],
                                    section: a['section'] ?? '',
                                    academicYearId: _data?['current_academic_year_id'],
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}
