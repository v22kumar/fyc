import 'package:flutter/material';
import 'blood_donors_screen.dart';
import 'membership_card_screen.dart';
import 'issue_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'வணக்கம்! / Vanakkam!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero impact banner
              Card(
                color: const Color(0xFF064E3B),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Together\nWe Build\nBetter Tomorrow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Image.network(
                        'https://img.icons8.com/color/96/sprout.png',
                        width: 70,
                        height: 70,
                        errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: Colors.white, size: 60),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Quick Access Grid
              const Text(
                'விரைவு அணுகல் / Quick Access',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildQuickAccessItem(
                    icon: Icons.bloodtype,
                    color: Colors.red[800]!,
                    label: 'இரத்த தானம்\nBlood',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BloodDonorsScreen()));
                    },
                  ),
                  _buildQuickAccessItem(
                    icon: Icons.report_problem,
                    color: Colors.amber[800]!,
                    label: 'புகார்\nPublic Issues',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const IssueReportScreen()));
                    },
                  ),
                  _buildQuickAccessItem(
                    icon: Icons.card_membership,
                    color: Colors.green[800]!,
                    label: 'உறுப்பினர் அட்டை\nID Card',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipCardScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Statistics Metrics Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'எங்கள் தாக்கம் / Our Impact',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('1500+', 'மரங்கள்\nTrees'),
                          _buildStatItem('1200+', 'கொடையாளர்\nDonors'),
                          _buildStatItem('80+', 'நிகழ்வுகள்\nEvents'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF064E3B),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.update), label: 'Updates'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Quick'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
