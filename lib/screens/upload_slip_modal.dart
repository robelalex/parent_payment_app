// lib/screens/upload_slip_modal.dart
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;  // ✅ ADD THIS
import 'package:shared_preferences/shared_preferences.dart';  // ✅ ADD THIS
import '../services/api_service.dart';
import '../models/student.dart';
import '../models/payment.dart';

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
  final _apiService = ApiService();
  final _bankNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _transactionDateController = TextEditingController();
  String? _imagePreview;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.payment.amount.toString();
  }

  Future<void> _pickImage() async {
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((e) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((e) {
          final dataUrl = reader.result as String;
          setState(() {
            _imagePreview = dataUrl;
            // Convert data URL to Uint8List
            final base64String = dataUrl.split(',').last;
            _imageBytes = base64Decode(base64String);
          });
        });
      }
    });
  }

Future<void> _submitUpload() async {
  if (_imageBytes == null) {
    setState(() => _error = 'Please select a bank slip image');
    return;
  }

  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    // Get school ID from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final schoolId = prefs.getInt('schoolId');
    
    print('🔍 School ID from prefs: $schoolId');
    
    if (schoolId == null) {
      setState(() => _error = 'School information missing. Please logout and login again.');
      setState(() => _isLoading = false);
      return;
    }
    
    // Create multipart request
    final uri = Uri.parse('${ApiService.baseUrl}/slips/upload/');
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers with school ID
    request.headers.addAll({
      'X-School-ID': schoolId.toString(),
    });
    
    // Add form fields
    request.fields['student_id'] = widget.student.studentId;
    request.fields['deadline_id'] = widget.payment.id.toString();
    request.fields['amount'] = _amountController.text;
    request.fields['bank_name'] = _bankNameController.text;
    request.fields['uploaded_by'] = widget.student.fullName;
    
    // Add image file
    final multipartFile = http.MultipartFile.fromBytes(
      'slip_image',
      _imageBytes!,
      filename: 'slip_${widget.student.studentId}_${widget.payment.id}.jpg',
    );
    request.files.add(multipartFile);
    
    print('📤 Uploading slip to: $uri');
    print('📤 Headers: X-School-ID = ${schoolId.toString()}');
    print('📤 Student ID: ${widget.student.studentId}');
    
    // Send request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: $responseBody');
    
    if (response.statusCode == 201) {
      final responseData = jsonDecode(responseBody);
      setState(() => _success = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Slip uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onSuccess();
          Navigator.pop(context);
        }
      });
    } else {
      final errorData = jsonDecode(responseBody);
      setState(() => _error = errorData['error'] ?? 'Upload failed');
    }
  } catch (e) {
    print('❌ Upload error: $e');
    setState(() => _error = 'Upload failed: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: _success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, size: 48, color: Colors.green.shade700),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Uploaded Successfully!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your bank slip has been submitted for verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
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
                          child: Icon(Icons.upload_file, color: Colors.indigo.shade700),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Upload Bank Slip',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('Student', widget.student.fullName),
                    _buildInfoRow('Student ID', widget.student.studentId),
                    _buildInfoRow('Month', widget.payment.monthName ?? 'N/A'),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _imagePreview != null && _imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _imageBytes!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 32, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to upload slip image',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (Birr)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _transactionDateController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          _transactionDateController.text =
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        }
                      },
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
                            Icon(Icons.error, color: Colors.red.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                              ),
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
                            onPressed: _isLoading ? null : _submitUpload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
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
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}