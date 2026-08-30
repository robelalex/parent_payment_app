// lib/screens/report_cards_screen.dart
//
// ✅ NEW — parity with web ParentDashboard.js's "Report Cards" section.
// Lists this one child's RELEASED report cards (never drafts — enforced
// server-side by ReportCardViewSet.get_queryset's parent-scoping) and
// opens the PDF externally on tap.
//
// The PDF itself is stored on Cloudinary (see backend
// report_cards/models.py's `pdf_file` field + core/settings.py's
// DEFAULT_FILE_STORAGE), so `pdf_url` is already a public, directly-
// fetchable CDN link — no auth header needed to open it, which is why a
// plain external browser launch (url_launcher) is enough here. This is
// different from the Class Results Excel export, which needs a Bearer
// token and can't be opened this way (see class_results_screen.dart).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/media_url.dart';

class ReportCardsScreen extends StatefulWidget {
  final int studentDbId;
  final String studentName;

  const ReportCardsScreen({
    super.key,
    required this.studentDbId,
    required this.studentName,
  });

  @override
  State<ReportCardsScreen> createState() => _ReportCardsScreenState();
}

class _ReportCardsScreenState extends State<ReportCardsScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _reportCards = [];
  String? _openingCardId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await _apiService.getReportCards(widget.studentDbId);
    if (!mounted) return;
    if (response['success'] == true) {
      setState(() {
        _reportCards = (response['data'] as List?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response['error']?.toString() ?? 'Failed to load report cards';
        _isLoading = false;
      });
    }
  }

  String _cardTitle(Map card) {
    if (card['report_type'] == 'cumulative') {
      return '${card['academic_year_name'] ?? ''} — Year-End Report';
    }
    final period = card['term_name'] ?? card['semester_name'] ?? 'Term';
    return '$period — ${card['academic_year_name'] ?? ''}';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openPdf(Map card) async {
    final url = mediaUrl(card['pdf_url'] as String?);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available for this report card yet.')),
      );
      return;
    }
    setState(() => _openingCardId = card['id'].toString());
    try {
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the PDF on this device.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingCardId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Report Cards — ${widget.studentName}'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      SelectableText(_error!, style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _reportCards.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No report cards have been released yet.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reportCards.length,
                        itemBuilder: (context, index) {
                          final card = _reportCards[index] as Map;
                          final isOpening = _openingCardId == card['id'].toString();
                          final average = card['overall_average'];
                          final letterGrade = card['letter_grade'];
                          final releasedAt = card['released_at'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.description, color: Colors.indigo.shade700),
                              ),
                              title: Text(_cardTitle(card), style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 12,
                                  children: [
                                    if (average != null)
                                      Text('Average: ${double.tryParse(average.toString())?.toStringAsFixed(1) ?? average}%',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    if (letterGrade != null && letterGrade.toString().isNotEmpty)
                                      Text('Grade: $letterGrade', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    if (releasedAt != null && releasedAt.isNotEmpty)
                                      Text('Released ${_formatDate(releasedAt)}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                              ),
                              trailing: isOpening
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.download, color: Colors.indigo.shade700),
                              onTap: isOpening ? null : () => _openPdf(card),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
