import 'package:flutter/material';
import 'package:qr_flutter/qr_flutter.dart';

class MembershipCardScreen extends StatelessWidget {
  const MembershipCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock user details matching seeded DB superadmin
    const String memberName = "சூப்பர் அட்மின் / Super Admin";
    const String memberNo = "FYC-2026-0001";
    const String designation = "முதன்மை நிர்வாகி / Super Admin";

    return Scaffold(
      appBar: AppBar(
        title: const Text('உறுப்பினர் அட்டை / Membership Card'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glassmorphic Card (Mock design using standard BoxDecoration)
              Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F5132), Color(0xFF064E3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF064E3B).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    )
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          const Text(
                            'FRIENDS YOUTH CLUB',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.yellow[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FYC',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF064E3B)),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        memberName,
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        designation,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MEMBER NO', style: TextStyle(color: Colors.white60, fontSize: 8)),
                              Text(memberNo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Text(
                            'ESTD. 2000',
                            style: TextStyle(color: Colors.white60, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // QR Verification Block
              const Text(
                'சரிபார்ப்பு குறியீடு / Verification QR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: QrImageView(
                    data: "https://fycconnect.org/verify/member/$memberNo",
                    version: QrVersions.auto,
                    size: 180.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR குறியீட்டை ஸ்கேன் செய்து சரிபார்க்கவும்.\nScan QR code to validate identity.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
