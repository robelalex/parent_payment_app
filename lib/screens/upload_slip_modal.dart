// lib/screens/upload_slip_modal.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../models/student.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class UploadSlipModal extends StatefulWidget {
  final Student student;
  final Payment payment;
  final VoidCallback onSuccess;

  const UploadSlipModal({
    super.key,
    required this.student,
    required this.payment,
    required this.onSuccess,
  });

  @override
  State<UploadSlipModal> createState() => _UploadSlipModalState();
}

class _UploadSlipModalState extends State<UploadSlipModal> {
  static const _channel = MethodChannel('com.example.parent_payment_app/http');
  static const _hostname = 'felege-selam-payment-system.onrender.com';
  final _apiService = ApiService();

  // ✅ NEW (requested): matches the web's UploadSlipModal.js exactly —
  // a bank account picker (so the parent can see/confirm which school
  // account they paid into) and a transaction reference field that's
  // auto-filled by the same AI slip-reading endpoint the web uses.
  // Amount is no longer editable — same as web, it's fixed from the
  // deadline, not something the parent can change.
  final _transactionReferenceController = TextEditingController();
  List<Map<String, dynamic>> _bankAccounts = [];
  String? _selectedBankAccountId; // null = 'auto', let the backend's own OCR detect it
  bool _loadingBankAccounts = true;
  bool _extracting = false;
  bool _aiDetected = false;
  bool _showManualInput = false;

  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;
  bool _success = false;
  final ImagePicker _picker = ImagePicker();

  // ✅ Same behavior as the web's PaymentPage.js: upload just queues the
  // slip for automatic bank verification — it doesn't confirm anything by
  // itself. The app used to show "Uploaded Successfully!" and close after
  // 2 seconds regardless of what actually happened next, so a slip that
  // failed CBE verification looked identical to one that succeeded. Now
  // it polls the same way the web does and shows the real outcome.
  int? _slipId;
  String _verificationStatus = 'queued'; // queued | verified | failed | manual_review | timeout
  String _verificationMessage = '';
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 24; // 24 x 5s = 2 minutes

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _transactionReferenceController.dispose();
    super.dispose();
  }

  // ✅ NEW: same call the web makes on mount — lets the parent see and
  // confirm which of the school's real bank accounts they sent money to.
  Future<void> _loadBankAccounts() async {
    final result = await _apiService.getBankAccounts();
    if (!mounted) return;
    final accounts = (result['accounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    Map<String, dynamic>? primary;
    for (final acc in accounts) {
      if (acc['is_primary'] == true) { primary = acc; break; }
    }
    setState(() {
      _bankAccounts = accounts;
      _selectedBankAccountId = primary != null ? primary['id'].toString() : null;
      _loadingBankAccounts = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _transactionReferenceController.clear();
          _aiDetected = false;
          _showManualInput = false;
          _error = null;
        });
        await _autoExtractFromImage(bytes);
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  // ✅ NEW (requested): same AI slip-reading step the web does at
  // /slips/extract-data/ — reads the transaction reference straight off
  // the photo so the parent usually doesn't have to type anything.
  // Built as a raw multipart platform-channel call, same technique
  // already proven for the slip upload itself below, since this also
  // needs to send an image file, not JSON.
  Future<void> _autoExtractFromImage(Uint8List imageBytes) async {
    setState(() { _extracting = true; _error = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final schoolIdRaw = prefs.get('school_id');
      final schoolId = schoolIdRaw?.toString().replaceAll('"', '') ?? '';

      final boundary = '----FlutterBoundary${DateTime.now().millisecondsSinceEpoch}';
      final List<int> bodyBytes = [];
      bodyBytes.addAll(
        '--$boundary\r\nContent-Disposition: form-data; name="slip_image"; '
                'filename="slip_extract.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'
            .codeUnits,
      );
      bodyBytes.addAll(imageBytes);
      bodyBytes.addAll('\r\n--$boundary--\r\n'.codeUnits);

      final result = await _channel.invokeMapMethod<String, dynamic>(
        'POST',
        {
          'url': 'https://$_hostname/api/slips/extract-data/',
          'headers': {
            'Content-Type': 'multipart/form-data; boundary=$boundary',
            if (schoolId.isNotEmpty) 'X-School-ID': schoolId,
          },
          'bodyBytes': bodyBytes,
        },
      );

      final statusCode = result?['statusCode'] as int? ?? 0;
      final responseBody = result?['body'] as String? ?? '';

      if (statusCode == 200) {
        final data = jsonDecode(responseBody);
        final extracted = data['extracted'] as Map<String, dynamic>?;
        final ref = extracted?['transaction_reference']?.toString();
        if (data['success'] == true && ref != null && ref.isNotEmpty) {
          setState(() {
            _transactionReferenceController.text = ref;
            _aiDetected = true;
            _showManualInput = false;
          });
        } else {
          setState(() {
            _showManualInput = true;
            _error = 'Could not detect reference number. Please enter it manually below.';
          });
        }
      } else {
        setState(() {
          _showManualInput = true;
          _error = 'Auto-detection failed. Please enter reference number manually.';
        });
      }
    } catch (e) {
      setState(() {
        _showManualInput = true;
        _error = 'Auto-detection failed. Please enter reference number manually.';
      });
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _submitUpload() async {
    if (_imageBytes == null) {
      setState(() => _error = 'Please select a bank slip image');
      return;
    }
    // ✅ NEW: required now, matching the web — a slip can't be submitted
    // without a reference number, whether AI-filled or typed manually.
    if (_transactionReferenceController.text.trim().isEmpty) {
      setState(() => _error = 'Transaction reference is required');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final schoolIdRaw = prefs.get('school_id');
      final schoolId = schoolIdRaw?.toString().replaceAll('"', '') ?? '';

      if (schoolId.isEmpty) {
        setState(() => _error = 'School information missing. Please logout and login again.');
        setState(() => _isLoading = false);
        return;
      }

      // ✅ NEW: resolve which bank account was picked, matching the
      // web's exact logic — a real account sends its name + id, 'auto'
      // (nothing picked) lets the backend's own OCR detect it instead.
      String bankName = 'auto';
      String? bankAccountId;
      if (_selectedBankAccountId != null) {
        final chosen = _bankAccounts.firstWhere(
          (a) => a['id'].toString() == _selectedBankAccountId,
          orElse: () => <String, dynamic>{},
        );
        bankName = chosen['bank_name']?.toString() ?? 'auto';
        bankAccountId = _selectedBankAccountId;
      }

      // Build multipart body manually and send via OkHttp platform channel
      final boundary = '----FlutterBoundary${DateTime.now().millisecondsSinceEpoch}';
      final List<int> bodyBytes = [];

      void addField(String name, String value) {
        bodyBytes.addAll(
          '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n$value\r\n'
              .codeUnits,
        );
      }

      addField('student_id', widget.student.studentId);
      addField('deadline_id', widget.payment.id.toString());
      addField('amount', widget.payment.amount.toString());
      addField('bank_name', bankName);
      if (bankAccountId != null) addField('bank_account_id', bankAccountId);
      addField('transaction_reference', _transactionReferenceController.text.trim());
      addField('uploaded_by', widget.student.fullName);

      // Add image part
      bodyBytes.addAll(
        '--$boundary\r\nContent-Disposition: form-data; name="slip_image"; '
                'filename="slip_${widget.student.studentId}_${widget.payment.id}.jpg"\r\n'
                'Content-Type: image/jpeg\r\n\r\n'
            .codeUnits,
      );
      bodyBytes.addAll(_imageBytes!);
      bodyBytes.addAll('\r\n--$boundary--\r\n'.codeUnits);

      final result = await _channel.invokeMapMethod<String, dynamic>(
        'POST',
        {
          'url': 'https://$_hostname/api/slips/upload/',
          'headers': {
            'Content-Type': 'multipart/form-data; boundary=$boundary',
            'X-School-ID': schoolId,
          },
          'bodyBytes': bodyBytes,
        },
      );

      final statusCode = result?['statusCode'] as int? ?? 0;
      final responseBody = result?['body'] as String? ?? '';

      if (statusCode == 201) {
        final responseData = jsonDecode(responseBody);
        final slipId = responseData['slip_id'] as int?;
        final initialStatus = responseData['verification_status']?.toString();

        if (initialStatus == 'manual_review') {
          // Backend already knows this needs a human — no point polling.
          setState(() {
            _verificationStatus = 'manual_review';
            _verificationMessage = (responseData['ai_details']?['message'] ??
                    'Could not detect the reference number automatically. '
                        'The school will verify this manually.')
                .toString();
            _success = true;
          });
        } else if (slipId != null) {
          setState(() {
            _slipId = slipId;
            _success = true;
            _verificationStatus = 'queued';
            _verificationMessage = 'Uploaded! Verifying with the bank automatically...';
          });
          _startPolling(slipId);
        } else {
          setState(() {
            _success = true;
            _verificationStatus = 'queued';
            _verificationMessage = responseData['message']?.toString() ?? 'Slip uploaded successfully!';
          });
        }
      } else {
        final errorData = jsonDecode(responseBody);
        setState(() => _error = errorData['error'] ?? 'Upload failed ($statusCode)');
      }
    } on PlatformException catch (e) {
      setState(() => _error = 'Upload failed: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Same cadence as the web's PaymentPage.js — check every 5 seconds
  /// until the bank verification actually resolves, instead of assuming
  /// success the moment the upload itself completes.
  void _startPolling(int slipId) {
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _pollAttempts++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        setState(() {
          _verificationStatus = 'timeout';
          _verificationMessage = "This is taking longer than usual. The school will still verify it — "
              "you don't need to re-upload. Check back later from your dashboard.";
        });
        return;
      }

      final response = await _apiService.getSlipStatus(slipId);
      if (response['success'] != true) return; // transient network hiccup — just try again next tick

      final status = response['verification_status']?.toString() ?? 'queued';

      if (status == 'verified') {
        timer.cancel();
        final payer = response['payer_name']?.toString();
        final amount = response['bank_amount']?.toString();
        setState(() {
          _verificationStatus = 'verified';
          _verificationMessage = 'Verified!'
              '${payer != null ? ' Payer: $payer.' : ''}'
              '${amount != null ? ' Amount: $amount Birr.' : ''}'
              ' You\'ll get an SMS confirmation shortly.';
        });
      } else if (['failed', 'timeout', 'manual_review'].contains(status)) {
        timer.cancel();
        setState(() {
          _verificationStatus = status;
          _verificationMessage = response['error']?.toString() ??
              'Verification $status — the school will check this manually.';
        });
      }
      // else: still queued/pending — keep polling silently, matching web.
    });
  }

  Color _statusColor() {
    switch (_verificationStatus) {
      case 'verified': return Colors.green.shade700;
      case 'failed': return Colors.red.shade700;
      case 'manual_review': return Colors.orange.shade700;
      case 'timeout': return Colors.orange.shade700;
      default: return Colors.blue.shade700;
    }
  }

  IconData _statusIcon() {
    switch (_verificationStatus) {
      case 'verified': return Icons.check_circle;
      case 'failed': return Icons.error;
      case 'manual_review': return Icons.hourglass_top;
      case 'timeout': return Icons.schedule;
      default: return Icons.cloud_upload;
    }
  }

  String _statusTitle() {
    switch (_verificationStatus) {
      case 'verified': return 'Payment Verified!';
      case 'failed': return 'Verification Failed';
      case 'manual_review': return 'Pending Manual Review';
      case 'timeout': return 'Still Checking';
      default: return 'Uploaded — Verifying...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: _success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(), size: 48, color: _statusColor()),
                  ),
                  const SizedBox(height: 16),
                  Text(_statusTitle(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    _verificationMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ref: ${_transactionReferenceController.text}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_verificationStatus == 'queued')
                    const Center(child: CircularProgressIndicator())
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                        onPressed: () {
                          widget.onSuccess();
                          Navigator.pop(context);
                        },
                        child: const Text('Done', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.upload_file,
                              color: Colors.indigo.shade700),
                        ),
                        const SizedBox(width: 12),
                        const Text('Upload Bank Slip',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ✅ Student summary — amount now shown here as
                    // read-only info, same as the web, not an editable
                    // field, since it's fixed by the deadline.
                    _buildInfoRow('Student', widget.student.fullName),
                    _buildInfoRow('Student ID', widget.student.studentId),
                    _buildInfoRow('Month', widget.payment.monthName ?? 'N/A'),
                    _buildInfoRow('Amount', '${widget.payment.amount} Birr'),
                    const SizedBox(height: 16),

                    // ✅ NEW: bank account picker — same as web, lets the
                    // parent confirm which of the school's real accounts
                    // they sent money to.
                    if (_loadingBankAccounts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_bankAccounts.isNotEmpty) ...[
                      const Text('Which account did you pay into?',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._bankAccounts.map((acc) {
                        final id = acc['id'].toString();
                        final selected = _selectedBankAccountId == id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBankAccountId = id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected ? Colors.indigo : Colors.grey.shade300,
                                width: selected ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: selected ? Colors.indigo.shade50 : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: selected ? Colors.indigo : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(acc['bank_name']?.toString() ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(
                                        '${acc['account_number'] ?? ''} · ${acc['account_holder'] ?? ''}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                                      ),
                                      if ((acc['display_label']?.toString() ?? '').isNotEmpty)
                                        Text('"${acc['display_label']}"',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    GestureDetector(
                      onTap: _extracting ? null : _pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _extracting
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Reading slip…', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              )
                            : _imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(_imageBytes!,
                                        width: double.infinity,
                                        fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt,
                                          size: 32,
                                          color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text('Tap to upload slip image',
                                          style: TextStyle(
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ NEW: transaction reference field, AI-filled where
                    // possible — the one field the web version always had
                    // that this screen was missing entirely before.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transaction Reference *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (_aiDetected)
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: Colors.green.shade600),
                              const SizedBox(width: 3),
                              Text('AI Detected',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _transactionReferenceController,
                      enabled: !_extracting,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.tag, size: 18),
                        hintText: _extracting ? 'Detecting…' : 'e.g., FSPAY-FS-2019-0003-57-xxx',
                        border: const OutlineInputBorder(),
                        filled: _aiDetected,
                        fillColor: _aiDetected ? Colors.green.shade50 : null,
                      ),
                    ),
                    if (!_aiDetected && !_showManualInput && _imageBytes != null && !_extracting)
                      TextButton.icon(
                        onPressed: () => setState(() => _showManualInput = true),
                        icon: const Icon(Icons.help_outline, size: 14),
                        label: const Text("Can't see reference? Enter manually", style: TextStyle(fontSize: 12)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _aiDetected
                            ? '✓ Found: "${_transactionReferenceController.text}". Please verify it matches your slip.'
                            : _showManualInput
                                ? 'Enter the reference number exactly as shown on your bank receipt.'
                                : "We'll auto-detect this from your photo once you upload it.",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error,
                                color: Colors.red.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isLoading || _extracting || _imageBytes == null) ? null : _submitUpload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Upload Slip'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}