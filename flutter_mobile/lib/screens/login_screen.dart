import 'package:flutter/material';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '+919876543210');
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  String _verificationId = '';
  bool _loading = false;

  void _sendOTP() async {
    setState(() {
      _loading = true;
    });

    // In local development/mock environment, we simulate OTP sending
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _loading = false;
      _otpSent = true;
      _verificationId = 'mock_v_id_123';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('முன்மாதிரி OTP: 123456 / Mock OTP: 123456')),
    );
  }

  void _verifyOTP() async {
    if (_otpController.text != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('தவறான குறியீடு / Invalid Code')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _loading = false;
    });

    // Navigate to dashboard
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('உள்நுழைக / Sign In'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              _otpSent 
                ? 'கைபேசிக்கு அனுப்பப்பட்ட OTP குறியீட்டை உள்ளிடவும் / Enter OTP' 
                : 'உங்கள் கைபேசி எண்ணை உள்ளிடவும் / Enter Mobile Number',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            if (!_otpSent)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'கைபேசி எண் / Mobile Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.phone),
                ),
              )
            else
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'OTP குறியீடு / OTP Code',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.lock_clock),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064E3B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _loading 
                ? null 
                : (_otpSent ? _verifyOTP : _sendOTP),
              child: _loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_otpSent ? 'சரிபார்க்கவும் / Verify' : 'OTP பெறுக / Get OTP', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
