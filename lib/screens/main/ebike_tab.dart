import 'package:e_secret_tracker/models/ebike.dart';
import 'package:e_secret_tracker/services/user_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EbikeTab extends StatefulWidget {
  const EbikeTab({super.key});

  @override
  State<EbikeTab> createState() => _EbikeTabState();
}

class _EbikeTabState extends State<EbikeTab> {
  final _userDataService = UserDataService();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _modalBackground =>
    _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFDFDFD);

  Color get _modalSurface =>
    _isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F4);

  Color get _modalBorder =>
    _isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);

  Color get _modalTextPrimary => _isDark ? Colors.white : const Color(0xFF1A1A1A);

  Color get _modalTextSecondary =>
    _isDark ? const Color(0xFFB8B8B8) : const Color(0xFF666666);

  String _describeWriteError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Write blocked by Firebase. Check Firestore rules and App Check enforcement.';
    }

    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }

    return message;
  }

  void _showActionError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_describeWriteError(error))),
    );
  }

  String _describeLoadError(Object? error) {
    final message = error?.toString() ?? 'Unknown error';
    if (message.contains('permission-denied')) {
      return 'Firestore denied access for this account. Check that you are signed in and the Firestore rules are deployed.';
    }

    if (message.contains('failed-precondition') ||
        message.contains('index') ||
        message.contains('requires an index')) {
      return 'Firestore needs an index for this e-bike query.';
    }

    if (message.contains('unavailable') || message.contains('network')) {
      return 'Firestore is currently unavailable or offline.';
    }

    return message;
  }

  static InputDecoration _inputDecoration({
    required String hint,
    required Color hintColor,
    required Color fillColor,
    required Color borderColor,
    required Color focusedBorderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: focusedBorderColor),
      ),
    );
  }

  Future<void> _openAddEbikeSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _modalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddEbikeSheet(
        userUid: user.uid,
        userDataService: _userDataService,
        onActionError: _showActionError,
        backgroundColor: _modalBackground,
        surfaceColor: _modalSurface,
        borderColor: _modalBorder,
        primaryTextColor: _modalTextPrimary,
        secondaryTextColor: _modalTextSecondary,
      ),
    );
  }

  Future<void> _deleteEbike(String ebikeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _userDataService.deleteEbike(uid: user.uid, ebikeId: ebikeId);
    } catch (error) {
      _showActionError(error);
    }
  }

  Future<void> _setKillSwitchState({
    required String ebikeId,
    required bool isTurnedOff,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _userDataService.setEbikeKillSwitchState(
        uid: user.uid,
        ebikeId: ebikeId,
        isTurnedOff: isTurnedOff,
      );
    } catch (error) {
      _showActionError(error);
    }
  }

  Future<void> _showKillSwitchConfirmDialog(Ebike ebike) async {
    final shouldTurnOff = !ebike.isTurnedOff;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _modalBackground,
          title: Text(
            shouldTurnOff ? 'Turn off e-bike?' : 'Turn on e-bike?',
            style: TextStyle(color: _modalTextPrimary),
          ),
          content: Text(
            shouldTurnOff
                ? 'This will mark the e-bike as turned off and save the status to your account.'
                : 'This will mark the e-bike as active again.',
            style: TextStyle(color: _modalTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: _modalTextSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: shouldTurnOff
                    ? const Color(0xFFFF4D3D)
                    : const Color(0xFFFF8A2A),
              ),
              child: Text(shouldTurnOff ? 'Turn Off' : 'Turn On'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _setKillSwitchState(ebikeId: ebike.id, isTurnedOff: shouldTurnOff);
    }
  }

  Future<void> _openEbikeDetailsSheet(Ebike ebike) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _modalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
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
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF2B231A)
                          : const Color(0xFFFFF1E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      ebike.isTurnedOff ? Icons.power_off : Icons.electric_bike,
                      color: ebike.isTurnedOff
                          ? const Color(0xFFFF4D3D)
                          : const Color(0xFFFF8A2A),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ebike.name,
                          style: TextStyle(
                            color: _modalTextPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ebike.note.isEmpty ? 'No note added' : ebike.note,
                          style: TextStyle(
                            color: _modalTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _modalSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _modalBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      ebike.isTurnedOff ? Icons.lock_outline : Icons.lock_open,
                      color: ebike.isTurnedOff
                          ? const Color(0xFFFF4D3D)
                          : const Color(0xFFFF8A2A),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ebike.isTurnedOff
                            ? 'Kill switch is ON'
                            : 'Kill switch is OFF',
                        style: TextStyle(
                          color: _modalTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (ebike.turnedOffAt != null)
                Text(
                  'Last turned off: ${ebike.turnedOffAt}',
                  style: TextStyle(
                    color: _modalTextSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(Duration.zero);
                    if (!mounted) {
                      return;
                    }
                    await _showKillSwitchConfirmDialog(ebike);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ebike.isTurnedOff
                        ? const Color(0xFFFF8A2A)
                        : const Color(0xFFFF4D3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    ebike.isTurnedOff ? Icons.play_arrow : Icons.power_off,
                  ),
                  label: Text(ebike.isTurnedOff ? 'Turn On' : 'Turn Off'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(Duration.zero);
                    if (!mounted) {
                      return;
                    }
                    await _deleteEbike(ebike.id);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4D3D),
                    side: const BorderSide(color: Color(0xFFFF4D3D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete E-bike'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEbikeCard(
    Ebike ebike,
    Color cardBg,
    Color border,
    Color primaryText,
    Color secondaryText,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openEbikeDetailsSheet(ebike),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: ebike.isTurnedOff
                    ? const Color(0xFF3A2323)
                  : (_isDark ? const Color(0xFF2B231A) : const Color(0xFFFFF1E2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                ebike.isTurnedOff ? Icons.power_off : Icons.electric_bike,
                color: ebike.isTurnedOff
                    ? const Color(0xFFFF4D3D)
                    : const Color(0xFFFF8A2A),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ebike.name,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: ebike.isTurnedOff
                              ? const Color(0xFF3A2323)
                              : const Color(0xFF2B231A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          ebike.isTurnedOff ? 'Turned Off' : 'Active',
                          style: TextStyle(
                            color: ebike.isTurnedOff
                                ? const Color(0xFFFF4D3D)
                                : const Color(0xFFFF8A2A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ebike.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ebike.note,
                      style: TextStyle(color: secondaryText, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Tap for controls',
                    style: TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: secondaryText),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFF4F4F4);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final border = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryText = isDark
        ? const Color(0xFF8E8E8E)
        : const Color(0xFF666666);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: user == null
            ? const Center(
                child: Text(
                  'Sign in to manage your e-bikes.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : StreamBuilder<List<Ebike>>(
                stream: _userDataService.watchEbikes(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF8A2A),
                      ),
                    );
                  }

                  final errorText = snapshot.hasError
                      ? 'Unable to load your e-bikes.\n\n${_describeLoadError(snapshot.error)}'
                      : null;

                  final ebikes = snapshot.data ?? const <Ebike>[];

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'E-bike List',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap a bike to manage its kill switch and details.',
                          style: TextStyle(color: secondaryText, fontSize: 15),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A2323),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF4D3D)),
                            ),
                            child: Text(
                              errorText,
                              style: const TextStyle(
                                color: Color(0xFFFFB5AE),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Expanded(
                          child: ebikes.isEmpty
                              ? Center(
                                  child: Text(
                                    errorText == null
                                        ? 'No e-bike yet. Add one to get started.'
                                        : 'No e-bike loaded yet. You can still try adding one below.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: ebikes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _buildEbikeCard(
                                      ebikes[index],
                                      cardBg,
                                      border,
                                      primaryText,
                                      secondaryText,
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _openAddEbikeSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8A2A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add E-bike'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddEbikeSheet extends StatefulWidget {
  const _AddEbikeSheet({
    required this.userUid,
    required this.userDataService,
    required this.onActionError,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  final String userUid;
  final UserDataService userDataService;
  final void Function(Object error) onActionError;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  @override
  State<_AddEbikeSheet> createState() => _AddEbikeSheetState();
}

class _AddEbikeSheetState extends State<_AddEbikeSheet> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.userDataService.addEbike(
        uid: widget.userUid,
        ebike: Ebike(
          id: '',
          name: name,
          note: _noteController.text.trim(),
          isTurnedOff: false,
          turnedOffAt: null,
          createdAt: null,
        ),
      );

      if (!mounted) {
        return;
      }

      FocusScope.of(context).unfocus();
      Navigator.of(context).pop();
    } catch (error) {
      widget.onActionError(error);
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                color: widget.borderColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Add E-bike',
            style: TextStyle(
              color: widget.primaryTextColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            style: TextStyle(color: widget.primaryTextColor),
            decoration: _EbikeTabState._inputDecoration(
              hint: 'E-bike name',
              hintColor: widget.secondaryTextColor,
              fillColor: widget.surfaceColor,
              borderColor: widget.borderColor,
              focusedBorderColor: const Color(0xFFFF8A2A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            style: TextStyle(color: widget.primaryTextColor),
            decoration: _EbikeTabState._inputDecoration(
              hint: 'Note (plate/model)',
              hintColor: widget.secondaryTextColor,
              fillColor: widget.surfaceColor,
              borderColor: widget.borderColor,
              focusedBorderColor: const Color(0xFFFF8A2A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A2A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save E-bike'),
            ),
          ),
        ],
      ),
    );
  }
}
