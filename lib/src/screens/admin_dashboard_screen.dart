import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/admin_dashboard_service.dart';
import '../services/auth_service.dart';
import '../widgets/brand_logo.dart';
import 'admin_business_list_screen.dart';
import 'admin_customer_list_screen.dart';
import 'admin_owner_management_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<_AdminDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminDashboardData> _load() async {
    final summary = await AdminDashboardService.fetchSummary();
    return _AdminDashboardData(
      summary: summary,
      backendReady: AdminDashboardService.backendReady,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Insights'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_AdminDashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 80),
                  const Center(child: BrandLogo(size: 84, showLabel: false)),
                  const SizedBox(height: 20),
                  const Text(
                    'Dashboard unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load dashboard: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.95),
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrandLogo(size: 64, showLabel: false),
                      SizedBox(height: 12),
                      Text(
                        'Business Overview',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track total owners and customer growth at a glance.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!data.backendReady || !appState.backendReady)
                  _BackendWarningCard(message: appState.backendStatus),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminOwnerManagementScreen()),
                      );
                    },
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('Manage Owners'),
                  ),
                ),
                const SizedBox(height: 8),
                _SummaryGrid(summary: data.summary),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final AdminDashboardSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricConfig(
        label: 'Owners',
        value: summary.totalOwners.toString(),
        icon: Icons.manage_accounts,
        color: Colors.green,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOwnerManagementScreen())),
      ),
      _MetricConfig(
        label: 'Total customers',
        value: summary.totalCustomers.toString(),
        icon: Icons.groups_2,
        color: Colors.indigo,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: false))),
      ),
      _MetricConfig(
        label: 'Businesses',
        value: summary.totalBusinesses.toString(),
        icon: Icons.store_mall_directory,
        color: Colors.teal,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBusinessListScreen())),
      ),
      _MetricConfig(
        label: 'Active customers',
        value: summary.activeCustomers.toString(),
        icon: Icons.verified_user,
        color: Colors.orange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomerListScreen(onlyActive: true))),
      ),
    ];

    return GridView.builder(
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 2 : 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.55,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _MetricCard(
          label: metric.label,
          value: metric.value,
          icon: metric.icon,
          color: metric.color,
          onTap: metric.onTap,
        );
      },
    );
  }
}

class _MetricConfig {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricConfig({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(label, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDashboardData {
  final AdminDashboardSummary summary;
  final bool backendReady;

  const _AdminDashboardData({
    required this.summary,
    required this.backendReady,
  });
}

class _BackendWarningCard extends StatelessWidget {
  final String message;

  const _BackendWarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}