import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/admin_dashboard_service.dart';
import '../services/auth_service.dart';
import '../services/voice_owner_parser.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_flat_bottom_nav.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_voice_bottom_nav.dart' show AppNavItem;
import 'admin_business_list_screen.dart';
import 'admin_customer_list_screen.dart';

class AdminOwnerManagementScreen extends StatefulWidget {
  const AdminOwnerManagementScreen({super.key});

  @override
  State<AdminOwnerManagementScreen> createState() => _AdminOwnerManagementScreenState();
}

class _AdminOwnerManagementScreenState extends State<AdminOwnerManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _ownerVoice = stt.SpeechToText();
  bool _loading = true;
  String _query = '';
  List<AdminOwnerRecord> _owners = const <AdminOwnerRecord>[];

  @override
  void initState() {
    super.initState();
    _loadOwners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ownerVoice.stop();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    setState(() => _loading = true);
    try {
      final owners = await AdminDashboardService.listOwners(query: _query.isEmpty ? null : _query);
      if (!mounted) return;
      setState(() => _owners = owners);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load owners: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showAddOwnerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final businessController = TextEditingController();
    final addressController = TextEditingController();
    String status = 'pending';
    bool submitting = false;
    bool listening = false;
    String voiceStatus = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> toggleVoiceFill() async {
              if (listening) {
                await _ownerVoice.stop();
                setDialogState(() {
                  listening = false;
                  voiceStatus = 'Stopped.';
                });
                return;
              }

              final permission = await Permission.microphone.request();
              if (!context.mounted) return;

              if (permission.isDenied || permission.isPermanentlyDenied) {
                setDialogState(() => voiceStatus = 'Microphone permission denied.');
                return;
              }

              final available = _ownerVoice.isAvailable || await _ownerVoice.initialize();
              if (!context.mounted) return;

              if (!available) {
                setDialogState(() => voiceStatus = 'Speech recognition unavailable.');
                return;
              }

              setDialogState(() {
                listening = true;
                voiceStatus = 'Listening... say owner name, mobile number, business name, and status.';
              });

              await _ownerVoice.listen(
                onResult: (result) {
                  if (!context.mounted) return;
                  if (result.finalResult) {
                    final draft = VoiceOwnerParser.parse(result.recognizedWords);
                    setDialogState(() {
                      listening = false;
                      voiceStatus = 'Heard: "${result.recognizedWords}"';
                      if (draft.ownerName != null) nameController.text = draft.ownerName!;
                      if (draft.phone != null) phoneController.text = draft.phone!;
                      if (draft.businessName != null) businessController.text = draft.businessName!;
                      if (draft.status != null) status = draft.status!;
                    });
                  }
                },
                listenFor: const Duration(seconds: 12),
                pauseFor: const Duration(seconds: 3),
                partialResults: false,
              );
            }

            return AlertDialog(
              title: const Text('Add Owner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: submitting ? null : toggleVoiceFill,
                        icon: Icon(listening ? Icons.stop : Icons.mic),
                        label: Text(listening ? 'Stop listening' : 'Speak to fill'),
                      ),
                    ),
                    if (voiceStatus.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(voiceStatus, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Owner name'),
                    ),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile number'),
                    ),
                    TextField(
                      controller: businessController,
                      decoration: const InputDecoration(labelText: 'Business / Shop name'),
                    ),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address (optional)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          _ownerVoice.stop();
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          await _ownerVoice.stop();
                          final normalizedPhone = AuthService.normalizeIndianPhone(phoneController.text.trim());
                          if (nameController.text.trim().isEmpty ||
                              normalizedPhone == null ||
                              !AuthService.isValidIndianPhone(normalizedPhone) ||
                              businessController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill valid owner details.')),
                            );
                            return;
                          }

                          setDialogState(() => submitting = true);
                          try {
                            await AdminDashboardService.createOwner(
                              ownerName: nameController.text.trim(),
                              phone: normalizedPhone,
                              businessName: businessController.text.trim(),
                              address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                              status: status,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadOwners();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Owner added successfully.')),
                            );
                          } catch (error) {
                            setDialogState(() => submitting = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Unable to add owner: $error')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add owner'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setOwnerState(AdminOwnerRecord owner, {required String status, required bool isActive}) async {
    try {
      await AdminDashboardService.setOwnerState(
        profileId: owner.profileId,
        status: status,
        isActive: isActive,
      );
      await _loadOwners();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner status updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update owner state: $error')),
      );
    }
  }

  Future<void> _showEditOwnerDialog(AdminOwnerRecord owner) async {
    final nameController = TextEditingController(text: owner.ownerName);
    final phoneController = TextEditingController(text: owner.ownerPhone);
    final businessController = TextEditingController(text: owner.businessName);
    final addressController = TextEditingController(text: owner.businessAddress ?? '');
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Owner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Owner name'),
                    ),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile number'),
                    ),
                    TextField(
                      controller: businessController,
                      decoration: const InputDecoration(labelText: 'Business / Shop name'),
                    ),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address (optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final normalizedPhone = AuthService.normalizeIndianPhone(phoneController.text.trim());
                          if (nameController.text.trim().isEmpty ||
                              normalizedPhone == null ||
                              !AuthService.isValidIndianPhone(normalizedPhone) ||
                              businessController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill valid owner details.')),
                            );
                            return;
                          }

                          setDialogState(() => submitting = true);
                          try {
                            await AdminDashboardService.updateOwner(
                              profileId: owner.profileId,
                              ownerName: nameController.text.trim(),
                              phone: normalizedPhone,
                              businessName: businessController.text.trim(),
                              address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadOwners();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Owner updated successfully.')),
                            );
                          } catch (error) {
                            setDialogState(() => submitting = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Unable to update owner: $error')),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.textPrimary,
                      ),
                      const Expanded(child: Text('Owners', style: AppTextStyles.heading)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (value) {
                        setState(() => _query = value.trim());
                        _loadOwners();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search owners by name, phone, or business',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            _loadOwners();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadOwners,
                child: _loading
                    ? const AppLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        children: [
                          if (_owners.isEmpty)
                            const AppEmptyState(icon: Icons.manage_accounts_outlined, title: 'No Owners Found', message: 'Try a different search, or add a new owner.')
                          else
                            ..._owners.map(
                              (owner) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OwnerCard(
                                  owner: owner,
                                  onEdit: () => _showEditOwnerDialog(owner),
                                  onApprove: () => _setOwnerState(owner, status: 'approved', isActive: true),
                                  onReject: () => _setOwnerState(owner, status: 'rejected', isActive: false),
                                  onActivate: () => _setOwnerState(owner, status: owner.approvalStatus, isActive: true),
                                  onDeactivate: () => _setOwnerState(owner, status: owner.approvalStatus, isActive: false),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: AppPrimaryButton(label: 'Add Owner', icon: Icons.person_add_alt_1, onPressed: _showAddOwnerDialog),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppFlatBottomNav(
        accentColor: AppColors.adminPrimary,
        items: [
          AppNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', onTap: () => Navigator.maybePop(context)),
          const AppNavItem(icon: Icons.manage_accounts_rounded, label: 'Owners', active: true),
          AppNavItem(icon: Icons.store_mall_directory_outlined, label: 'Businesses', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBusinessListScreen()))),
          AppNavItem(icon: Icons.groups_2_outlined, label: 'Customers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: false)))),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onActivate,
    required this.onDeactivate,
  });

  final AdminOwnerRecord owner;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyleFor(owner.approvalStatus);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: statusStyle.fg.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.storefront_rounded, color: statusStyle.fg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.ownerName, style: AppTextStyles.subheading),
                const SizedBox(height: 2),
                Text(owner.businessName, style: AppTextStyles.bodyMuted),
                const SizedBox(height: 2),
                Text(owner.ownerPhone, style: AppTextStyles.bodyMuted),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusStyle.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(statusStyle.label, style: TextStyle(color: statusStyle.fg, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: owner.isActive ? const Color(0xFFE1F7E8) : AppColors.divider,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        owner.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: owner.isActive ? const Color(0xFF2E7D32) : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'approve':
                  onApprove();
                case 'reject':
                  onReject();
                case 'activate':
                  onActivate();
                case 'deactivate':
                  onDeactivate();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit owner')),
              PopupMenuItem(value: 'approve', child: Text('Approve')),
              PopupMenuItem(value: 'reject', child: Text('Reject')),
              PopupMenuItem(value: 'activate', child: Text('Activate')),
              PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            ],
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyleFor(String status) {
    switch (status) {
      case 'approved':
        return const _StatusStyle('Approved', Color(0xFFE1F7E8), Color(0xFF2E7D32));
      case 'rejected':
        return const _StatusStyle('Rejected', Color(0xFFFCE4E4), Color(0xFFC62828));
      default:
        return const _StatusStyle('Pending', Color(0xFFFFF1DC), Color(0xFFC9820A));
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}
