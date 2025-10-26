import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../services/progress_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/loading_overlay.dart';
import 'package:lottie/lottie.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _location = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String _initialName = '';
  String _initialAge = '';
  String? _photoUrl;
  String? _photoBase64;
  File? _localPhoto;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ProgressService>().getUserProfile();
      _name.text = (data['name'] ?? '') as String;
      final dynamic ageVal = data['age'];
      _age.text = ageVal == null ? '' : ageVal.toString();
      _bio.text = (data['bio'] ?? '') as String;
      _phone.text = (data['phone'] ?? '') as String;
      _location.text = (data['location'] ?? '') as String;
      _photoUrl = data['photoUrl'] as String?;
      _photoBase64 = data['photoBase64'] as String?;
      _initialName = _name.text;
      _initialAge = _age.text;
      _ensureRealtimeListener();
    } catch (e) {
      _message = 'Unable to load profile. You can still edit and save.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ensureRealtimeListener() {
    if (_profileSub != null) return;
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final data = snap.data() ?? <String, dynamic>{};
          final String nextUrl = (data['photoUrl'] as String?) ?? '';
          final String nextB64 = (data['photoBase64'] as String?) ?? '';
          if (nextUrl != _photoUrl || nextB64 != _photoBase64) {
            setState(() {
              _photoUrl = nextUrl;
              _photoBase64 = nextB64;
            });
          }
        });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    LoadingOverlay.show(context, message: 'Saving profile...');
    final int? age = int.tryParse(_age.text.trim());
    String? uploadedUrl = _photoUrl;
    try {
      if (_localPhoto != null) {
        String? uid = context.read<AuthService>().currentUser?.uid;
        if (uid == null) {
          final user = await context.read<AuthService>().signInAnonymously();
          uid = user?.uid;
        }
        if (uid == null) {
          throw FirebaseException(
            plugin: 'auth',
            code: 'no-user',
            message: 'No uid available',
          );
        }
        try {
          final String path = 'profile_photos/$uid/avatar.jpg';
          final ref = FirebaseStorage.instance.ref(path);
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=3600',
          );
          final TaskSnapshot snap = await ref.putFile(_localPhoto!, metadata);
          if (snap.bytesTransferred <= 0) {
            throw FirebaseException(
              plugin: 'firebase_storage',
              code: 'upload-empty',
              message: 'No bytes uploaded',
            );
          }
          uploadedUrl = await ref.getDownloadURL();
        } on FirebaseException catch (_) {
          // Storage disabled/unavailable: fall back to storing a small base64
          // thumbnail in Firestore so avatars still work without Storage costs.
          final bytes = await _localPhoto!.readAsBytes();
          // compress by re-encoding JPEG at lower quality if needed later; for now just base64
          final String base64Str = base64Encode(bytes);
          await context.read<ProgressService>().updateUserProfile(
            photoBase64: base64Str,
          );
        }
        // No debug snackbar
      }
      await context.read<ProgressService>().updateUserProfile(
        name: _name.text.trim(),
        age: age,
        photoUrl: uploadedUrl,
        bio: _bio.text.trim(),
        phone: _phone.text.trim(),
        location: _location.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Saved';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Save failed: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      LoadingOverlay.hide(context);
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadius * 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animations/tick.json',
                  repeat: false,
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 8),
                const Text('Profile updated successfully!'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Great'),
                ),
              ],
            ),
          ),
        );
      },
    );
    Navigator.pop(context); // go back after save + success dialog
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _bio.dispose();
    _phone.dispose();
    _location.dispose();
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ImageProvider<Object>? avatarProvider() {
      if (_localPhoto != null) return FileImage(_localPhoto!);
      if ((_photoUrl ?? '').isNotEmpty) return NetworkImage(_photoUrl!);
      if ((_photoBase64 ?? '').isNotEmpty) {
        try {
          final bytes = base64Decode(_photoBase64!);
          return MemoryImage(bytes);
        } catch (_) {}
      }
      return null;
    }

    Widget? avatarFallback() {
      if (_localPhoto == null &&
          (_photoUrl == null || _photoUrl!.isEmpty) &&
          (_photoBase64 == null || _photoBase64!.isEmpty)) {
        return const Icon(Icons.person, size: 40);
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final hasChanges =
                _name.text != _initialName || _age.text != _initialAge;
            if (!hasChanges) {
              Navigator.pop(context);
              return;
            }
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
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Profile', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: avatarProvider(),
                            child: avatarFallback(),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt_rounded),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  imageQuality: 85,
                                );
                                if (picked != null) {
                                  setState(
                                    () => _localPhoto = File(picked.path),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter your name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        hintText: 'Enter your age',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: '+60 12-345 6789',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _location,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'City, Country',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell us a bit about yourself',
                      ),
                    ),
                    const SizedBox(height: 24),
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
