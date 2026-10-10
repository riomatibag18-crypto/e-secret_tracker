import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:e_secret_tracker/services/app_theme_service.dart';
import 'package:e_secret_tracker/services/auth_service.dart';
import 'package:e_secret_tracker/services/user_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _authService = AuthService();
  final _userDataService = UserDataService();
  final _imagePicker = ImagePicker();

  bool get _isDarkMode => AppThemeService.instance.isDarkMode;

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    return 'User';
  }

  String get _userEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF111111) : const Color(0xFFF4F4F4);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _primaryTextColor =>
      _isDarkMode ? Colors.white : const Color(0xFF111111);
  Color get _secondaryTextColor =>
      _isDarkMode ? const Color(0xFF9A9A9A) : const Color(0xFF666666);
  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF343434) : const Color(0xFFE2E2E2);
  Color get _tileIconBackground =>
      _isDarkMode ? const Color(0xFF2B2118) : const Color(0xFFFFF0E2);
  Color get _tileIconColor => const Color(0xFFFF8A2A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: _primaryTextColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              _buildProfileHeader(),
              const SizedBox(height: 32),
              _sectionLabel('APPEARANCE'),
              const SizedBox(height: 12),
              _SettingsCard(
                backgroundColor: _cardColor,
                borderColor: _borderColor,
                child: Row(
                  children: [
                    _SettingIcon(
                      backgroundColor: _tileIconBackground,
                      icon: Icons.nights_stay_outlined,
                      iconColor: _tileIconColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDarkMode ? 'Dark Mode' : 'Light Mode',
                            style: TextStyle(
                              color: _primaryTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isDarkMode ? 'Enabled' : 'Enabled',
                            style: TextStyle(
                              color: _secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isDarkMode,
                      activeThumbColor: const Color(0xFFFF8A2A),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
                      onChanged: (value) async {
                        await AppThemeService.instance.setDarkMode(value);
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _sectionLabel('ACCOUNT'),
              const SizedBox(height: 12),
              _SettingsCard(
                backgroundColor: _cardColor,
                borderColor: _borderColor,
                onTap: _showEditProfileSheet,
                child: _ListTileContent(
                  backgroundColor: _tileIconBackground,
                  icon: Icons.person_outline,
                  iconColor: _tileIconColor,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  primaryTextColor: _primaryTextColor,
                  secondaryTextColor: _secondaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                backgroundColor: _cardColor,
                borderColor: _borderColor,
                onTap: _openUserGuide,
                child: _ListTileContent(
                  backgroundColor: _tileIconBackground,
                  icon: Icons.menu_book_outlined,
                  iconColor: _tileIconColor,
                  title: 'User Guide',
                  subtitle: 'Learn how to use E-Secret Tracker',
                  primaryTextColor: _primaryTextColor,
                  secondaryTextColor: _secondaryTextColor,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: _secondaryTextColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                backgroundColor: _cardColor,
                borderColor: _borderColor,
                onTap: _showAboutDialog,
                child: _ListTileContent(
                  backgroundColor: _tileIconBackground,
                  icon: Icons.info_outline,
                  iconColor: _tileIconColor,
                  title: 'About E-Secret Tracker',
                  subtitle: 'App version, features, and details',
                  primaryTextColor: _primaryTextColor,
                  secondaryTextColor: _secondaryTextColor,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: _secondaryTextColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _sectionLabel('SECURITY'),
              const SizedBox(height: 12),
              _SettingsCard(
                backgroundColor: _cardColor,
                borderColor: _borderColor,
                onTap: _showChangePasswordSheet,
                child: _ListTileContent(
                  backgroundColor: _tileIconBackground,
                  icon: Icons.lock_outline,
                  iconColor: _tileIconColor,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  primaryTextColor: _primaryTextColor,
                  secondaryTextColor: _secondaryTextColor,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: _secondaryTextColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _SettingsCard(
                backgroundColor: _cardColor,
                borderColor: _borderColor,
                onTap: _handleSignOut,
                child: _ListTileContent(
                  backgroundColor: _tileIconBackground,
                  icon: Icons.logout,
                  iconColor: Colors.redAccent,
                  title: 'Sign Out',
                  subtitle: 'Log out of your account',
                  primaryTextColor: Colors.redAccent,
                  secondaryTextColor: _secondaryTextColor,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: _secondaryTextColor,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: _secondaryTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userDataService.watchUserProfile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final fullName =
            (profile?['fullName'] as String?)?.trim().isNotEmpty == true
            ? (profile?['fullName'] as String).trim()
            : (user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : 'User');
        final email = (profile?['email'] as String?)?.trim().isNotEmpty == true
            ? (profile?['email'] as String).trim()
            : (user.email ?? '');
        final photoBase64 = (profile?['photoBase64'] as String?)?.trim();

        return Center(
          child: Column(
            children: [
              _buildAvatar(
                fullName: fullName,
                photoBase64: photoBase64,
                size: 108,
              ),
              const SizedBox(height: 18),
              Text(
                fullName,
                style: TextStyle(
                  color: _primaryTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: TextStyle(color: _secondaryTextColor, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await _showSignOutConfirmation();
    if (!confirmed) {
      return;
    }

    try {
      await _authService.signOut();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authService.mapAuthError(error))));
    }
  }

  Future<bool> _showSignOutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text('Sign Out?', style: TextStyle(color: _primaryTextColor)),
          content: Text(
            'Are you sure you want to sign out from your account?',
            style: TextStyle(color: _secondaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFFAAAAAA)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<String?> _pickProfileImageAsBase64() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxHeight: 512,
      maxWidth: 512,
    );

    if (picked == null) {
      return null;
    }

    final bytes = await picked.readAsBytes();
    return base64Encode(bytes);
  }

  Widget _buildAvatar({
    required String fullName,
    required String? photoBase64,
    required double size,
  }) {
    final imageData = photoBase64 ?? '';
    final hasPhoto = imageData.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF8A2A),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFF2F2F2F)
              : const Color(0xFFE7E7E7),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.memory(base64Decode(imageData), fit: BoxFit.cover)
            : Center(
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.31,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String? selectedPhotoBase64;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _borderColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: _primaryTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: _buildAvatar(
                      fullName: nameController.text.trim().isEmpty
                          ? _userName
                          : nameController.text.trim(),
                      photoBase64: selectedPhotoBase64,
                      size: 84,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final imageBase64 = await _pickProfileImageAsBase64();
                        if (imageBase64 == null) {
                          return;
                        }
                        setSheetState(() => selectedPhotoBase64 = imageBase64);
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Change photo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _primaryTextColor),
                    decoration: _bottomSheetFieldDecoration(
                      'Full name',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    style: TextStyle(color: _primaryTextColor),
                    readOnly: true,
                    decoration: _bottomSheetFieldDecoration(
                      'Email address',
                      Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (user == null) {
                          return;
                        }

                        final fullName = nameController.text.trim();
                        if (fullName.isEmpty) {
                          return;
                        }

                        try {
                          await user.updateDisplayName(fullName);
                          await user.reload();
                          await _userDataService.updateUserProfile(
                            uid: user.uid,
                            fullName: fullName,
                            email: user.email ?? '',
                            photoBase64: selectedPhotoBase64,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated')),
                          );
                          setState(() {});
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_authService.mapAuthError(error)),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A2A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _bottomSheetFieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _secondaryTextColor),
      prefixIcon: Icon(icon, color: _secondaryTextColor),
      filled: true,
      fillColor: _isDarkMode
          ? const Color(0xFF262626)
          : const Color(0xFFF2F2F2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFFF8A2A)),
      ),
    );
  }

  void _openUserGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('User Guide', style: TextStyle(color: _primaryTextColor)),
        content: Text(
          'Use the app to track routes, manage alerts, edit your profile, and keep your account secure.',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFF8A2A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'About E-Secret Tracker',
          style: TextStyle(color: _primaryTextColor),
        ),
        content: Text(
          'E-Secret Tracker is designed to help you secure and monitor your routes with a clean, simple experience.',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFF8A2A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _borderColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Change Password',
                      style: TextStyle(
                        color: _primaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      style: TextStyle(color: _primaryTextColor),
                      decoration: _bottomSheetPasswordDecoration(
                        hint: 'Current password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setSheetState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                          icon: Icon(
                            obscureCurrentPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: _secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      style: TextStyle(color: _primaryTextColor),
                      decoration: _bottomSheetPasswordDecoration(
                        hint: 'New password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setSheetState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: _secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      style: TextStyle(color: _primaryTextColor),
                      decoration: _bottomSheetPasswordDecoration(
                        hint: 'Confirm new password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setSheetState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: _secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final currentPassword =
                              currentPasswordController.text;
                          final newPassword = newPasswordController.text;
                          final confirmPassword =
                              confirmPasswordController.text;

                          if (currentPassword.isEmpty ||
                              newPassword.isEmpty ||
                              confirmPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill in all password fields.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (newPassword.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'New password must be at least 6 characters.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'New password and confirmation do not match.',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await _authService.changePassword(
                              currentPassword: currentPassword,
                              newPassword: newPassword,
                            );

                            if (!mounted || !sheetContext.mounted) {
                              return;
                            }

                            Navigator.of(sheetContext).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully.'),
                              ),
                            );
                          } catch (error) {
                            if (!mounted || !sheetContext.mounted) {
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(_authService.mapAuthError(error)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Update Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _bottomSheetPasswordDecoration({
    required String hint,
    required Widget suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _secondaryTextColor),
      prefixIcon: Icon(Icons.lock_outline, color: _secondaryTextColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _isDarkMode
          ? const Color(0xFF262626)
          : const Color(0xFFF2F2F2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFFF8A2A)),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
    this.onTap,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }
}

class _ListTileContent extends StatelessWidget {
  const _ListTileContent({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    this.trailing = const SizedBox.shrink(),
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SettingIcon(
          backgroundColor: backgroundColor,
          icon: icon,
          iconColor: iconColor,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: secondaryTextColor, fontSize: 14),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
