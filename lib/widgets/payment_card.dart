// lib/widgets/payment_card.dart
import 'package:flutter/material.dart';
import '../models/payment.dart';

class PaymentCard extends StatelessWidget {
  final Payment payment;
  final bool isProcessing;
  final VoidCallback onPayNow;
  final VoidCallback onBankTransfer;
  final VoidCallback onUploadSlip;
  final int daysRemaining;

  const PaymentCard({
    super.key,
    required this.payment,
    required this.isProcessing,
    required this.onPayNow,
    required this.onBankTransfer,
    required this.onUploadSlip,
    required this.daysRemaining,
  });

  String _getStatusText() {
    if (daysRemaining <= 0) return 'Overdue';
    if (daysRemaining <= 10) return '$daysRemaining days reminder';
    return '';
  }

  Color _getStatusColor() {
    if (daysRemaining <= 0) return Colors.red;
    if (daysRemaining <= 10) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText();
    final showStatus = statusText.isNotEmpty && daysRemaining <= 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    payment.monthName ?? 'Monthly Fee',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (payment.dueDate != null)
              Text(
                'Due: ${_formatDate(payment.dueDate!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ETB ${payment.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.payment,
                      label: 'Pay Now',
                      color: Colors.indigo,
                      onPressed: onPayNow,
                      isLoading: isProcessing,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.account_balance,
                      label: 'Bank',
                      color: Colors.blue,
                      onPressed: onBankTransfer,
                      isLoading: false,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.upload_file,
                      label: 'Slip',
                      color: Colors.grey,
                      onPressed: onUploadSlip,
                      isLoading: false,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}