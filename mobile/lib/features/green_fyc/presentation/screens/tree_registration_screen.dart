import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/drive_entity.dart';
import '../bloc/green_bloc.dart';
import '../bloc/green_event.dart';
import '../bloc/green_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/success_snackbar.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class TreeRegistrationScreen extends StatefulWidget {
  const TreeRegistrationScreen({super.key});

  @override
  State<TreeRegistrationScreen> createState() => _TreeRegistrationScreenState();
}

class _TreeRegistrationScreenState extends State<TreeRegistrationScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  final _speciesTaCtrl = TextEditingController();
  final _speciesEnCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();

  DateTime _plantedDate = DateTime.now();
  String? _selectedDriveId;
  String? _pickedPhotoPath;

  @override
  void initState() {
    super.initState();
    // Load drives so the user can optionally associate the tree with one.
    context.read<GreenBloc>().add(const GreenFetchRequested());
    _loadDraft();
    _speciesTaCtrl.addListener(_saveDraft);
    _speciesEnCtrl.addListener(_saveDraft);
    _notesCtrl.addListener(_saveDraft);
    _latCtrl.addListener(_saveDraft);
    _lonCtrl.addListener(_saveDraft);
  }

  void _loadDraft() {
    final storage = sl<LocalStorage>();
    _speciesTaCtrl.text = storage.getDraft('tree_draft_ta') ?? '';
    _speciesEnCtrl.text = storage.getDraft('tree_draft_en') ?? '';
    _notesCtrl.text = storage.getDraft('tree_draft_notes') ?? '';
    _latCtrl.text = storage.getDraft('tree_draft_lat') ?? '';
    _lonCtrl.text = storage.getDraft('tree_draft_lon') ?? '';
  }

  void _saveDraft() {
    final storage = sl<LocalStorage>();
    storage.saveDraft('tree_draft_ta', _speciesTaCtrl.text);
    storage.saveDraft('tree_draft_en', _speciesEnCtrl.text);
    storage.saveDraft('tree_draft_notes', _notesCtrl.text);
    storage.saveDraft('tree_draft_lat', _latCtrl.text);
    storage.saveDraft('tree_draft_lon', _lonCtrl.text);
  }

  @override
  void dispose() {
    _speciesTaCtrl.dispose();
    _speciesEnCtrl.dispose();
    _notesCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _plantedDate = picked);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedPhotoPath = image.path);
    }
  }

  String? _trim(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  void _submit() {
    context.read<GreenBloc>().add(
          GreenTreeRegistered(
            driveId: _selectedDriveId,
            speciesTa: _trim(_speciesTaCtrl),
            speciesEn: _trim(_speciesEnCtrl),
            latitude: double.tryParse(_latCtrl.text.trim()),
            longitude: double.tryParse(_lonCtrl.text.trim()),
            plantedDate: _plantedDate,
            photoFilePath: _pickedPhotoPath,
            notes: _trim(_notesCtrl),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    final dateFmt = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(trId('register_a_tree')),
      ),
      body: BlocConsumer<GreenBloc, GreenState>(
        listener: (context, state) {
          if (state is GreenTreeRegisteredSuccess) {
            final storage = sl<LocalStorage>();
            storage.clearDraft('tree_draft_ta');
            storage.clearDraft('tree_draft_en');
            storage.clearDraft('tree_draft_notes');
            storage.clearDraft('tree_draft_lat');
            storage.clearDraft('tree_draft_lon');
            SuccessSnackbar.show(
              context,
              title: trId('success'),
              message: trId('tree_registered_successfully'),
            );
            context.pop();
          }
          if (state is GreenFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
                action: SnackBarAction(
                  label: trId('retry_4'),
                  textColor: AppColors.background,
                  onPressed: _submit,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          // Drives may have loaded via GreenLoaded; otherwise show none.
          final drives =
              state is GreenLoaded ? state.drives : const <DriveEntity>[];
          final isSubmitting = state is GreenLoading;

          return SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(
                  text: trId('planted_date'),
                ),
                SizedBox(height: 8),
                _DatePickerField(
                  label: dateFmt.format(_plantedDate),
                  onTap: _pickDate,
                ),
                SizedBox(height: 20),
                _Label(
                  text: trId('species_tamil_optional'),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _speciesTaCtrl,
                  decoration: InputDecoration(
                    hintText: trId('e_g'),
                  ),
                ),
                SizedBox(height: 20),
                _Label(
                  text: trId('species_english_optional'),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _speciesEnCtrl,
                  decoration: InputDecoration(
                    hintText: trId('e_g_neem'),
                  ),
                ),
                SizedBox(height: 20),
                if (drives.isNotEmpty) ...[
                  _Label(
                    text: trId('drive_optional'),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedDriveId,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          trId('none'),
                        ),
                      ),
                      ...drives.map(
                        (d) => DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(
                            d.displayTitle(lang),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedDriveId = v),
                  ),
                  SizedBox(height: 20),
                ],
                _Label(
                  text: trId('location_optional'),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          hintText: trId('latitude'),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lonCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          hintText: trId('longitude'),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _Label(
                  text: trId('notes_optional_2'),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: trId('additional_details'),
                  ),
                ),
                SizedBox(height: 20),
                _Label(
                  text: trId('photo_optional'),
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: _pickedPhotoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              File(_pickedPhotoPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 8),
                              Text(
                                trId('tap_to_add_photo'),
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                trId('optional_helps_verify_the_planting'),
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? CircularProgressIndicator(color: AppColors.background)
                        : Text(
                            trId('register_tree'),
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DatePickerField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
