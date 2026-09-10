// lib/screens/bank_transfer_modal.dart
import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class BankTransferModal extends StatefulWidget {
  final Payment payment;
  final Student student;
  final VoidCallback onUploadSlip;

  const BankTransferModal({
    super.key,
    required this.payment,
    required this.student,
    required this.onUploadSlip,
  });

  @override
  State<BankTransferModal> createState() => _BankTransferModalState();
}

class _BankTransferModalState extends State<BankTransferModal> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  // ✅ NEW (requested): same /bank-accounts/ call the web makes — shows
  // EVERY account the school has on file, not just one hardcoded set of
  // fields. Falls back to the old single-account student fields only if
  // the school hasn't added any accounts yet, same as web's fallback.
  Future<void> _loadAccounts() async {
    final result = await _apiService.getBankAccounts();
    if (!mounted) return;
    final accounts = (result['accounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    setState(() {
      _accounts = accounts.isNotEmpty
          ? accounts
          : [
              {
                'bank_name': widget.student.bankName ?? 'Commercial Bank of Ethiopia',
                'account_holder': widget.student.bankAccountHolder ?? widget.student.schoolName ?? 'School Name',
                'account_number': widget.student.bankAccountNumber ?? 'Not provided',
                'is_primary': true,
              },
            ];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bank Transfer Instructions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Transfer the amount to any of the accounts below, then upload your slip.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // ✅ NEW: every account shown as its own card, same as web —
              // was previously only ever one hardcoded account here.
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._accounts.map((acc) {
                  final isPrimary = acc['is_primary'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isPrimary ? Colors.blue.shade300 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: isPrimary ? Colors.blue.shade50 : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(acc['bank_name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (isPrimary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('Primary',
                                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Account Name: ${acc['account_holder'] ?? ''}', style: const TextStyle(fontSize: 13)),
                              Text('Account No: ${acc['account_number'] ?? ''}',
                                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  border: Border.all(color: Colors.yellow.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reference: Use your student ID ${widget.student.studentId}',
                        style: TextStyle(fontSize: 13, color: Colors.yellow.shade900)),
                    const SizedBox(height: 2),
                    Text('Month: ${widget.payment.monthName}',
                        style: TextStyle(fontSize: 13, color: Colors.yellow.shade900)),
                  ],
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onUploadSlip();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 18),
                          SizedBox(width: 8),
                          Text('Upload Bank Slip'),
                        ],
                      ),
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
}