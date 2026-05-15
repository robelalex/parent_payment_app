// lib/widgets/payment_options_footer.dart
import 'package:flutter/material.dart';

class PaymentOptionsFooter extends StatelessWidget {
  const PaymentOptionsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, size: 18, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              Text(
                'Payment Options',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildOption(Icons.phone_android, 'Telebirr'),
              _buildOption(Icons.payment, 'Chapa'),
              _buildOption(Icons.account_balance, 'Bank Transfer'),
              _buildOption(Icons.upload_file, 'Bank Slip Upload'),
              _buildOption(Icons.lock, 'Secure & Encrypted'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.indigo.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
        ),
      ],
    );
  }
}