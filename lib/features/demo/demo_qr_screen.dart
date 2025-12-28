import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockspot/shared/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Demo QR Screen for Presentation
/// Shows QR codes for judges to download/access the app
class DemoQRScreen extends StatelessWidget {
  const DemoQRScreen({super.key});

  // GitHub Release URLs
  static const String apkDownloadUrl = 'https://github.com/Hambozo17/LockSpot/releases/latest/download/app-release.apk';
  static const String webAppUrl = 'https://hambozo17.github.io/LockSpot'; // GitHub Pages or your deployed URL
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.officerk.lockspot';
  static const String repoUrl = 'https://github.com/Hambozo17/LockSpot';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('Download LockSpot'),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Logo
            Image.asset(
              'assets/images/logoandlogotextstackedV.png',
              height: 120,
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              '📱 Try LockSpot Now!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the QR code or tap to download',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Option 1: Direct APK Download
            _buildDownloadCard(
              context,
              icon: Icons.android,
              iconColor: Colors.green,
              title: 'Android APK',
              subtitle: 'Direct download (No Play Store needed)',
              qrData: apkDownloadUrl,
              onTap: () => _launchUrl(apkDownloadUrl),
            ),

            const SizedBox(height: 16),

            // Option 2: Web App
            _buildDownloadCard(
              context,
              icon: Icons.language,
              iconColor: Colors.blue,
              title: 'Web App',
              subtitle: 'Try instantly in your browser',
              qrData: webAppUrl,
              onTap: () => _launchUrl(webAppUrl),
            ),

            const SizedBox(height: 32),

            // Demo Credentials
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.key, size: 32, color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text(
                    '🔐 Demo Credentials',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCredentialRow('Email', 'demo@lockspot.com', context),
                  const SizedBox(height: 8),
                  _buildCredentialRow('Password', 'demo123', context),
                  const SizedBox(height: 16),
                  Text(
                    'Or create your own account!',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Features showcase
            const Text(
              '✨ What you can try:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureChip('📍 Browse locker locations'),
            _buildFeatureChip('🔒 Book a smart locker'),
            _buildFeatureChip('📱 Scan QR to unlock'),
            _buildFeatureChip('⏱️ Real-time countdown'),
            _buildFeatureChip('📜 View rental history'),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String qrData,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Real QR Code using qr_flutter
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 72,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: iconColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied!'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureChip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
