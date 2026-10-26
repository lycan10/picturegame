import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/game_data.dart';
import '../theme/app_theme.dart';

/// Preset emoji avatars for users without a photo.
const kAvatarEmojis = [
  '🧑', '👩', '👨', '🦸', '🦹', '🧙', '🧚', '🐱', '🐶', '🦊',
  '🐼', '🐸', '🦄', '🌟', '🌈', '🍀', '⚡', '🔥',
];

/// Edit Profile: display name, username, emoji avatar and profile photo
/// (uploaded to the backend, served from /avatars/...).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GameData game = GameData.instance;
  late final TextEditingController nameController;
  late final TextEditingController usernameController;
  String? avatarEmoji;
  bool busy = false;
  bool uploading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: game.displayName);
    usernameController = TextEditingController(text: game.username);
    avatarEmoji = game.avatarEmoji;
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      file = null;
    }
    if (file == null) return;

    // image_picker normalizes to JPEG when re-encoding (imageQuality set).
    final contentType = file.mimeType == 'image/png' ? 'image/png' : 'image/jpeg';
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected image.')),
        );
      }
      return;
    }

    setState(() => uploading = true);
    final err = await game.uploadAvatar(bytes, contentType);
    if (!mounted) return;
    setState(() => uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Profile photo updated!'),
    ));
  }

  Future<void> _removePhoto() async {
    setState(() => uploading = true);
    final err = await game.updateProfile(clearAvatar: true);
    if (!mounted) return;
    setState(() => uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Photo removed — back to your emoji.'),
    ));
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final username = usernameController.text.trim().toLowerCase();
    if (name.isEmpty) {
      setState(() => error = 'Display name cannot be empty');
      return;
    }
    if (username.isNotEmpty && !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      setState(() => error = 'Username must be 3-20 characters: a-z, 0-9, underscore');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final err = await game.updateProfile(
      displayName: name,
      username: username,
      avatarEmoji: avatarEmoji,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    } else {
      setState(() {
        busy = false;
        error = err;
      });
    }
  }

  Future<void> _chooseAvatar() async {
    final hasPhoto = game.avatarUrl != null;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUploadPhoto();
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removePhoto();
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in kAvatarEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        setState(() => avatarEmoji = emoji);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
      ),
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _avatar()),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: uploading ? null : _chooseAvatar,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    game.avatarUrl == null ? 'Add photo' : 'Change photo',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  helperText: '3-20 characters: a-z, 0-9, underscore',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy || uploading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  minimumSize: const Size(0, 52),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final photoUrl = game.avatarNetworkUrl();
    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.purple, width: 3),
            color: Colors.white,
          ),
          child: ClipOval(
            child: uploading
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            avatarEmoji ?? '🧑',
                            style: const TextStyle(fontSize: 52),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          avatarEmoji ?? '🧑',
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 2,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD76A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.edit_rounded, size: 15, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}
