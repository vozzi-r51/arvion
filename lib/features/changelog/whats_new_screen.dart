import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What's New in BizManager v2.5")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          _buildReleaseHeader(
              'BizManager ERP v2.5 Enterprise Edition', '2026 Release'),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.qr_code,
            color: Colors.green,
            title: 'FBR Digital POS Invoicing',
            description:
                '18-Digit FBR POS Invoice Number generation aur thermal receipt QR code verification Pakistan compliance ke liye.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.account_balance_wallet,
            color: Colors.orange,
            title: 'JazzCash, EasyPaisa & Raast Wallets',
            description:
                'Mobile Wallet payments support with Transaction Reference ID (TRX ID) tracking across sales & purchases.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.qr_code_scanner,
            color: Colors.blue,
            title: 'USB / Bluetooth Hardware Barcode Scanner',
            description:
                'Dedicated barcode scanner hardware listener for high-speed POS checkout terminals.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.shopping_bag,
            color: Colors.purple,
            title: 'E-commerce Sync (Daraz & WhatsApp)',
            description:
                'Daraz Pakistan Store orders sync aur WhatsApp Business Catalog CSV export.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.security,
            color: Colors.red,
            title: 'SQLCipher AES-256 DB Encryption & RBAC',
            description:
                'Android KeyStore encrypted SQLite database aur 9-permission granular Role-Based Access Control.',
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseHeader(String title, String subtitle) {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.indigo.shade900)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.indigo.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(description,
              style: const TextStyle(fontSize: 12, height: 1.3)),
        ),
      ),
    );
  }
}
