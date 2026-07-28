// lib/presentation/legal/TechnicianTermsScreen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

class TechnicianTermsScreen extends StatelessWidget {
  const TechnicianTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Technician Terms & Conditions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header Banner
            _buildHeader(),

            // Terms Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSection(
                    icon: Icons.info_outline,
                    title: 'About ThumbTech',
                    content:
                        'ThumbTech is a platform that helps independent technicians connect with nearby customers looking for home and appliance services.\n\nJoining ThumbTech gives technicians an opportunity to receive customer leads and grow their local business reach.',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.engineering,
                    title: 'Independent Service Provider',
                    content:
                        'All technicians on ThumbTech work independently and are not employees, partners, or permanent staff members of ThumbTech.\n\nTechnicians are fully responsible for:\n• Service quality\n• Pricing\n• Communication\n• Tools & equipment\n• Professional behavior\n• Safety measures\n• Work completed for customers',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.verified,
                    title: 'Professional Conduct',
                    content:
                        'Technicians are expected to:\n• Behave professionally\n• Communicate respectfully\n• Provide genuine services\n• Avoid misleading or fraudulent activities\n\nAny misuse, fake commitments, abusive behavior, spam, or suspicious activity may lead to temporary suspension or permanent removal from the platform.',
                    color: Colors.green,
                    warning: true,
                  ),
                  const SizedBox(height: 20),

                  _buildSubscriptionCard(),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.payment,
                    title: 'Pricing & Payments',
                    content:
                        'Service pricing may be discussed directly between technician and customer unless specifically mentioned inside the platform.\n\nTechnicians are responsible for managing their own earnings, taxes, and service-related commitments.',
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.star_rate,
                    title: 'Customer Ratings & Reviews',
                    content:
                        'Customer ratings and reviews help maintain service quality on the platform.\n\nRepeated complaints, poor behavior, fake reviews, or dishonest practices may affect technician visibility or account access.',
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 20),

                  _buildNoGuaranteeCard(),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.gavel,
                    title: 'Platform Rights',
                    content:
                        'ThumbTech reserves the right to:\n• Approve or reject technician registrations\n• Suspend accounts\n• Remove profiles\n• Update platform policies at any time to maintain platform quality and safety',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.verified_user,
                    title: 'Verification & Safety',
                    content:
                        'Technicians may be asked to provide identity or business-related details for verification and safety purposes.',
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.how_to_reg,
                    title: 'Acceptance',
                    content:
                        'By using ThumbTech as a technician/service provider, you confirm that you understand and agree to these terms and conditions.',
                    color: Colors.indigo,
                  ),

                  const SizedBox(height: 30),

                  // Accept Button
                  _buildAcceptButton(context),

                  const SizedBox(height: 16),

                  // Contact Support
                  _buildContactSupport(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.1),
            const Color(0xFF2563EB).withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.engineering,
                    size: 28,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ThumbTech India',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Technician Agreement',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please read all terms carefully before registering as a technician on ThumbTech platform.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    bool warning = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: warning
                  ? Colors.red.shade50
                  : color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warning
                        ? Colors.red.shade100
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: warning ? Colors.red.shade700 : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: warning
                          ? Colors.red.shade700
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.subscriptions,
                    size: 20,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Subscription & Membership',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some ThumbTech features or lead access may require a paid subscription or membership plan.\n\nBy purchasing a subscription:',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                _buildBulletPoint(
                  'Technicians agree to the selected pricing and duration',
                ),
                _buildBulletPoint(
                  'Subscription fees are generally non-refundable',
                ),
                _buildBulletPoint(
                  'Platform access/features may vary based on the active plan',
                ),
                const SizedBox(height: 12),
                Text(
                  'ThumbTech reserves the right to:\n• Update subscription pricing\n• Modify plans\n• Limit features\n• Discontinue offers at any time\n\nFailure to renew a subscription may result in limited access to leads or platform features.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoGuaranteeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    size: 20,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No Guaranteed Earnings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ThumbTech works to provide service opportunities and customer connections but does not guarantee:\n• Fixed income\n• Minimum bookings\n• Continuous work\n\nBooking availability may vary depending on:',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                _buildBulletPoint('Demand in your area'),
                _buildBulletPoint('Your service location'),
                _buildBulletPoint('Customer ratings & reviews'),
                _buildBulletPoint('Response time to requests'),
                _buildBulletPoint('Your subscription plan'),
                _buildBulletPoint('Service quality & professionalism'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 14, color: Color(0xFF2563EB)),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildAcceptButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context, true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          'I Agree to Technician Terms & Conditions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildContactSupport() {
    return GestureDetector(
      onTap: () => _showContactDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Have questions? Contact Support',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For any questions or concerns regarding technician terms and conditions, please contact us at:',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchEmail(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.email, color: Color(0xFF2563EB)),
                    SizedBox(width: 12),
                    Text('technician@thumstech.com'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchPhone(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone, color: Color(0xFF2563EB)),
                    SizedBox(width: 12),
                    Text('+91 98765 43210'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'technician@thumstech.com',
      queryParameters: {
        'subject': 'Question about Technician Terms & Conditions',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+919876543210');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
