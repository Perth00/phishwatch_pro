import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/progress_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/loading_overlay.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await context.read<ProgressService>().getUserProfile();
    _name.text = (data['name'] ?? '') as String;
    final dynamic ageVal = data['age'];
    _age.text = ageVal == null ? '' : ageVal.toString();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    LoadingOverlay.show(context, message: 'Saving profile...');
    final int? age = int.tryParse(_age.text.trim());
    await context.read<ProgressService>().updateUserProfile(
      name: _name.text.trim(),
      age: age,
    );
    setState(() {
      _saving = false;
      _message = 'Saved';
    });
    LoadingOverlay.hide(context);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder:
                  (_) => ConfirmDialog(
                    title: 'Discard changes?',
                    message: 'Unsaved changes will be lost.',
                    confirmText: 'Discard',
                    cancelText: 'Stay',
                    onConfirm: () {},
                  ),
            );
            if (confirmed == true) Navigator.pop(context);
          },
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                    const Spacer(),
                    if (_message != null)
                      Text(
                        _message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.successColor,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child:
                          _saving
                              ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Save'),
                    ),
                  ],
                ),
              ),
    );
  }
}
