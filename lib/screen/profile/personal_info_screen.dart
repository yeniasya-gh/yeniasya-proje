import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth/auth_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/app_user_avatar.dart';
import '../../utils/asset_image_picker.dart';
import '../../utils/phone_formatter.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _uploadingAvatar = false;
  bool _removingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.name ?? "";
    _phoneCtrl.text = user?.phone ?? "";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? null
            : normalizePhoneNumber(_phoneCtrl.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kişisel bilgiler güncellendi.")),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar || _removingAvatar) return;

    try {
      final picked = await AssetImagePicker.pickImageFile();
      if (picked == null) return;

      setState(() => _uploadingAvatar = true);
      final uploadedUrl = await UploadService().uploadPublic(
        type: UploadFileType.profile,
        bytes: picked.bytes,
        filename: picked.name,
      );
      if (!mounted) return;

      await context.read<AuthProvider>().updateAvatar(avatarUrl: uploadedUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil fotoğrafı güncellendi.")),
      );
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parsed)));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_uploadingAvatar || _removingAvatar) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Profil Fotoğrafını Kaldır"),
        content: const Text(
          "Mevcut profil fotoğrafını kaldırmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Kaldır", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingAvatar = true);
    try {
      await context.read<AuthProvider>().removeAvatar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil fotoğrafı kaldırıldı.")),
      );
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parsed)));
    } finally {
      if (mounted) setState(() => _removingAvatar = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.changePassword(
        currentPassword: _currentPasswordCtrl.text.trim(),
        newPassword: _newPasswordCtrl.text.trim(),
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Mevcut şifre hatalı.")));
        }
        return;
      }
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Şifreniz başarıyla değiştirildi.")),
        );
      }
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parsed)));
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final hasAvatar = user?.avatarUrl?.trim().isNotEmpty == true;
    final avatarBusy = _uploadingAvatar || _removingAvatar;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Kişisel Bilgiler"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Profil Bilgileri",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            AppUserAvatar(
                              radius: 44,
                              imageUrl: user?.avatarUrl,
                              busy: avatarBusy,
                              onEditTap: _pickAvatar,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: avatarBusy ? null : _pickAvatar,
                                  icon: const Icon(Icons.upload_outlined),
                                  label: Text(
                                    hasAvatar
                                        ? "Fotoğrafı Değiştir"
                                        : "Fotoğraf Yükle",
                                  ),
                                ),
                                if (hasAvatar)
                                  TextButton.icon(
                                    onPressed:
                                        avatarBusy ? null : _removeAvatar,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text("Kaldır"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration:
                            const InputDecoration(labelText: "Ad Soyad"),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? "Zorunlu" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: "Telefon"),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _savingProfile ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: _savingProfile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Kaydet",
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Şifre Güncelle",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _currentPasswordCtrl,
                        decoration: const InputDecoration(
                          labelText: "Mevcut Şifre",
                        ),
                        obscureText: true,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? "Zorunlu" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordCtrl,
                        decoration: const InputDecoration(
                          labelText: "Yeni Şifre",
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Zorunlu";
                          if (v.trim().length < 6) return "En az 6 karakter";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        decoration: const InputDecoration(
                          labelText: "Yeni Şifre (Tekrar)",
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Zorunlu";
                          if (v.trim() != _newPasswordCtrl.text.trim()) {
                            return "Şifreler eşleşmiyor";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _savingPassword ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: _savingPassword
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Şifreyi Güncelle",
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
