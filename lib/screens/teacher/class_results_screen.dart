// lib/screens/teacher/class_results_screen.dart
//
// ✅ NEW — parity with web TeacherClassResults.js, the homeroom "Check
// Result and Award" screen. Shows every term (or, for quarter-structure
// schools, every semester) side by side per student, plus the overall
// average and homeroom rank — and lets the teacher drill into a single
// period for a clean ranked list.
//
// Rendered as a per-student card list rather than the web's wide table
// (a multi-column table doesn't fit a phone screen), but pulls from the
// exact same endpoints and fields, so the numbers can never disagree
// with the web app.
//
// ⚠️ Deliberately NOT included: the "Download Excel" button the web
// version has. That export endpoint requires the same Bearer-token auth
// as everything else here, but this app's whole networking layer
// (NativeHttpClient, see services/native_http_client.dart) only ever
// returns response bodies as decoded JSON strings — it has no path for
// raw binary data, and forcing an .xlsx file through it would corrupt
// it. Building this properly needs a different fetch path plus a file
// -saving package (e.g. path_provider), neither of which exist in this
// app today. Left out rather than shipped half-working — teachers can
// still get the Excel export from the web app in the meantime.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';

class ClassResultsScreen extends StatefulWidget {
  final int grade;
  final String section;
  final int? academicYearId;

  const ClassResultsScreen({
    super.key,
    required this.grade,
    required this.section,
    required this.academicYearId,
  });

  @override
  State<ClassResultsScreen> createState() => _ClassResultsScreenState();
}

class _ClassResultsScreenState extends State<ClassResultsScreen> {
  final _apiService = ApiService();

  String _termStructure = 'semester'; // 'semester' | 'quarter' — from School.term_structure
  String _periodType = 'term'; // 'term' | 'semester' — which overview is showing
  List<dynamic> _terms = [];
  List<dynamic> _semesters = [];
  List<dynamic> _results = [];
  bool _isLoading = true;
  String? _error;

  int? _selectedTermId;
  int? _selectedSemesterId;

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
    _load();
  }

  Future<void> _loadSchoolInfo() async {
    final response = await _apiService.getSchoolInfo();
    if (!mounted) return;
    if (response['success'] == true) {
      final school = response['data'] as Map?;
      setState(() => _termStructure = school?['term_structure']?.toString() ?? 'semester');
    }
    // Best-effort, same as web — if this fails we just stay on the
    // term-only view.
  }

  Future<void> _load() async {
    if (widget.academicYearId == null) {
      setState(() { _error = 'No academic year set for your school'; _isLoading = false; });
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      if (_periodType == 'semester' && _selectedSemesterId != null) {
        final response = await _apiService.getClassResultsBySemester(
          semesterId: _selectedSemesterId!, grade: widget.grade, section: widget.section,
        );
        if (response['success'] != true) throw response['error'] ?? 'Failed to load results';
        final list = List<dynamic>.from(response['data'] as List);
        list.sort((a, b) => (a['homeroom_rank'] ?? 999999).compareTo(b['homeroom_rank'] ?? 999999));
        setState(() { _results = list; _isLoading = false; });
      } else if (_periodType == 'semester') {
        final response = await _apiService.getClassResultsBySemesters(
          grade: widget.grade, section: widget.section, academicYearId: widget.academicYearId!,
        );
        if (response['success'] != true) throw response['error'] ?? 'Failed to load results';
        setState(() {
          _semesters = (response['semesters'] as List?) ?? [];
          _results = (response['results'] as List?) ?? [];
          _isLoading = false;
        });
      } else if (_selectedTermId != null) {
        final response = await _apiService.getClassResults(
          termId: _selectedTermId!, grade: widget.grade, section: widget.section,
        );
        if (response['success'] != true) throw response['error'] ?? 'Failed to load results';
        final list = List<dynamic>.from(response['data'] as List);
        list.sort((a, b) => (a['homeroom_rank'] ?? 999999).compareTo(b['homeroom_rank'] ?? 999999));
        setState(() { _results = list; _isLoading = false; });
      } else {
        final response = await _apiService.getClassResultsByTerms(
          grade: widget.grade, section: widget.section, academicYearId: widget.academicYearId!,
        );
        if (response['success'] != true) throw response['error'] ?? 'Failed to load results';
        setState(() {
          _terms = (response['terms'] as List?) ?? [];
          _results = (response['results'] as List?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _setPeriodType(String value) {
    if (value == _periodType) return;
    setState(() {
      _periodType = value;
      _selectedTermId = null;
      _selectedSemesterId = null;
    });
    _load();
  }

  String _formatPct(dynamic v) => v != null ? '${double.tryParse(v.toString())?.toStringAsFixed(1) ?? v}%' : '—';

  String _rankDisplay(Map r) {
    final rank = r['homeroom_rank'];
    if (rank == null) return '—';
    final total = r['homeroom_rank_total'];
    return total != null ? '$rank / $total' : '$rank';
  }

  Widget _passFailBadge(Map r) {
    final isPassing = r['is_passing'];
    if (isPassing == null) {
      return Text('Not yet available', style: TextStyle(fontSize: 11, color: Colors.grey.shade500));
    }
    final pass = isPassing == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pass ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pass ? 'Pass' : 'Fail',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pass ? Colors.green.shade700 : Colors.red.shade700),
      ),
    );
  }

  bool get _isDrilledDown => (_periodType == 'term' && _selectedTermId != null) || (_periodType == 'semester' && _selectedSemesterId != null);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final columns = _periodType == 'semester' ? _semesters : _terms;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${lang.t('teacher_class_results')} — Grade ${widget.grade}${widget.section.isNotEmpty ? ' ${widget.section}' : ''}'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_termStructure == 'quarter')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'term', label: Text('Quarter')),
                    ButtonSegment(value: 'semester', label: Text('Semester')),
                  ],
                  selected: {_periodType},
                  onSelectionChanged: (s) => _setPeriodType(s.first),
                ),
              ),

            if (_periodType == 'term' && _terms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int?>(
                  value: _selectedTermId,
                  decoration: InputDecoration(
                    labelText: _termStructure == 'quarter' ? 'View a single quarter' : 'View a single term',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(_termStructure == 'quarter' ? 'All quarters (overview)' : 'All terms (overview)')),
                    ..._terms.map((t) => DropdownMenuItem<int?>(value: t['id'], child: Text(t['name']))),
                  ],
                  onChanged: (v) { setState(() => _selectedTermId = v); _load(); },
                ),
              ),

            if (_periodType == 'semester' && _semesters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int?>(
                  value: _selectedSemesterId,
                  decoration: const InputDecoration(
                    labelText: 'View a single semester',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All semesters (overview)')),
                    ..._semesters.map((s) => DropdownMenuItem<int?>(value: s['id'], child: Text(s['name']))),
                  ],
                  onChanged: (v) { setState(() => _selectedSemesterId = v); _load(); },
                ),
              ),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(_error!, style: TextStyle(color: Colors.red.shade700)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
                    ),
                  ],
                ),
              ),

            if (_isLoading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
            else if (_isDrilledDown) ...[
              if (_results.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No students in this class.')))
              else
                ..._results.map((r) => _buildDrillDownCard(r as Map)),
            ] else if (columns.isEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    _periodType == 'semester'
                        ? 'No semesters have been set up yet. Ask your school admin to create them in Academics Setup.'
                        : 'No terms have been set up yet. Ask your school admin to create one in Academics Setup.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_results.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No students in this class.')))
            else
              ..._results.map((r) => _buildOverviewCard(r as Map)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillDownCard(Map r) {
    final rank = r['homeroom_rank'];
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: medal != null ? Colors.amber.shade100 : Colors.indigo.shade50,
          child: Text(medal ?? _rankDisplay(r).split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(r['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(r['student_id_display'] ?? '', style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatPct(r['overall_average']), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
            if (r['letter_grade'] != null && r['letter_grade'].toString().isNotEmpty)
              Text(r['letter_grade'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            _passFailBadge(r),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(Map r) {
    final periods = _periodType == 'semester'
        ? (r['semesters'] as List? ?? [])
        : (r['terms'] as List? ?? []);
    final overall = _periodType == 'semester' ? r['average_of_semesters'] : r['average_of_terms'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(_rankDisplay(r).split(' ')[0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(r['student_id_display'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatPct(overall), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                    _passFailBadge(r),
                  ],
                ),
              ],
            ),
            if (periods.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: periods.map<Widget>((p) {
                  final name = p['term_name'] ?? p['semester_name'] ?? '';
                  return Chip(
                    label: Text('$name: ${_formatPct(p['average'])}', style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.grey.shade100,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
