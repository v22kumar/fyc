import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/network/api_client.dart';
import '../../../../service_locator.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// One-time onboarding screen that forces a new user (Google or OTP, on any
/// platform) to supply the mandatory profile data — name, date of birth, gender
/// and a phone number — so no account exists in the database without it. The
/// router gate (app_router) sends any signed-in, non-admin user here until their
/// profile is complete; there is deliberately no skip.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameTa = TextEditingController();
  final _nameEn = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _needsPhone = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      final u = state.user;
      _nameTa.text = u.fullNameTa ?? '';
      _nameEn.text = u.fullNameEn ?? '';
      _gender = u.gender;
      if (u.dateOfBirth != null) _dob = DateTime.tryParse(u.dateOfBirth!);
      // Only ask for a phone when we don't already have one (e.g. Google sign-in).
      _needsPhone = (u.phoneNumber == null || u.phoneNumber!.isEmpty);
    }
  }

  @override
  void dispose() {
    _nameTa.dispose();
    _nameEn.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final nameTa = _nameTa.text.trim();
    final nameEn = _nameEn.text.trim();
    final phone = _phone.text.trim();

    if (nameTa.isEmpty || nameEn.isEmpty || _dob == null || _gender == null ||
        (_needsPhone && phone.isEmpty)) {
      setState(() => _error = trId('fill_required_fields'));
      return;
    }

    setState(() { _saving = true; _error = null; });

    final dobStr = '${_dob!.year.toString().padLeft(4, '0')}-'
        '${_dob!.month.toString().padLeft(2, '0')}-'
        '${_dob!.day.toString().padLeft(2, '0')}';
    final body = <String, dynamic>{
      'full_name_ta': nameTa,
      'full_name_en': nameEn,
      'date_of_birth': dobStr,
      'gender': _gender,
    };
    if (_needsPhone && phone.isNotEmpty) body['phone_number'] = phone;

    try {
      await sl<ApiClient>().dio.patch(ApiConstants.myProfile, data: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trId('profile_saved'))),
      );
      // Re-fetch /me so the (now complete) profile flag refreshes; the
      // BlocListener below navigates to home once that lands, avoiding a race
      // with the router gate.
      context.read<AuthBloc>().add(const AuthCheckRequested());
    } on DioException catch (e) {
      if (!mounted) return;
      // Surface a server message (e.g. "phone already registered") when present.
      String msg = trId('fill_required_fields');
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] is String) {
        msg = detail['detail'] as String;
      }
      setState(() { _saving = false; _error = msg; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _error = trId('fill_required_fields'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F5132);
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthAuthenticated && curr.user.isProfileComplete,
      listener: (context, state) {
        // Profile is now complete (or the user is fine) — enter the app.
        context.go('/home');
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // No back button / no skip — the gate requires completion.
      appBar: AppBar(
        backgroundColor: green,
        automaticallyImplyLeading: false,
        title: Text(trId('complete_your_profile'),
            style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            SizedBox(height: 4),
            Text(trId('complete_profile_hint'),
                style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 13)),
            SizedBox(height: 20),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
              ),
            _label('${trId('full_name_tamil')} *'),
            _field(_nameTa, textInputAction: TextInputAction.next),
            _label('${trId('full_name_english')} *'),
            _field(_nameEn, textInputAction: TextInputAction.next),
            _label('${trId('date_of_birth')} *'),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _decoration(),
                child: Text(
                  _dob == null
                      ? trId('date_of_birth')
                      : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                  style: TextStyle(color: _dob == null ? AppColors.textSecondary : Colors.black87),
                ),
              ),
            ),
            _label('${trId('gender')} *'),
            Row(
              children: [
                _genderChip('MALE', trId('male')),
                SizedBox(width: 8),
                _genderChip('FEMALE', trId('female')),
                SizedBox(width: 8),
                _genderChip('OTHER', trId('other')),
              ],
            ),
            if (_needsPhone) ...[
              _label('${trId('phone_number')} *'),
              _field(_phone, keyboardType: TextInputType.phone, hint: '+919876543210'),
            ],
            SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                    : Text(trId('save_and_continue'),
                        style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  InputDecoration _decoration({String? hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3))),
      );

  Widget _field(TextEditingController c,
          {TextInputType? keyboardType, TextInputAction? textInputAction, String? hint}) =>
      TextField(
        controller: c,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        decoration: _decoration(hint: hint),
      );

  Widget _genderChip(String value, String label) {
    final selected = _gender == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gender = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Color(0xFF0F5132) : AppColors.background,
            border: Border.all(color: selected ? Color(0xFF0F5132) : AppColors.textSecondary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppColors.background : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }
}