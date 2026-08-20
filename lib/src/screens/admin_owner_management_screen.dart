import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/admin_dashboard_service.dart';
import '../services/auth_service.dart';
import '../services/voice_owner_parser.dart';

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
      appBar: AppBar(
        title: const Text('Owners'),
        actions: [
          IconButton(onPressed: _loadOwners, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOwnerDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Owner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (value) {
                setState(() => _query = value.trim());
                _loadOwners();
              },
              decoration: InputDecoration(
                hintText: 'Search owners by name, phone, or business',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                    _loadOwners();
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _owners.isEmpty
                      ? const Center(child: Text('No owners found.'))
                      : ListView.builder(
                          itemCount: _owners.length,
                          itemBuilder: (context, index) {
                            final owner = _owners[index];
                            final statusColor = switch (owner.approvalStatus) {
                              'approved' => Colors.green,
                              'rejected' => Colors.red,
                              _ => Colors.orange,
                            };

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(owner.ownerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${owner.ownerPhone}\n${owner.businessName}\nStatus: ${owner.approvalStatus.toUpperCase()} • ${owner.isActive ? 'ACTIVE' : 'INACTIVE'}\nCustomers: ${owner.customerCount}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditOwnerDialog(owner);
                                      return;
                                    }
                                    if (value == 'approve') {
                                      _setOwnerState(owner, status: 'approved', isActive: true);
                                      return;
                                    }
                                    if (value == 'reject') {
                                      _setOwnerState(owner, status: 'rejected', isActive: false);
                                      return;
                                    }
                                    if (value == 'activate') {
                                      _setOwnerState(owner, status: owner.approvalStatus, isActive: true);
                                      return;
                                    }
                                    if (value == 'deactivate') {
                                      _setOwnerState(owner, status: owner.approvalStatus, isActive: false);
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
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(alpha: 0.15),
                                  child: Icon(Icons.storefront, color: statusColor),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
