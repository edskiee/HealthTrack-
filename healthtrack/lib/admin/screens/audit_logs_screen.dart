import 'package:flutter/material.dart';
import 'package:healthtrack/admin/services/admin_preferences_api_service.dart';
import 'package:intl/intl.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  bool loading = true;
  String? error;
  List<dynamic> rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await AdminPreferencesApi.fetchAuditLogs(limit: 150);
      if (!mounted) return;
      setState(() {
        rows = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _friendly(e);
        loading = false;
      });
    }
  }

  String _friendly(Object e) {
    if (e is AdminPreferencesApiException) return e.message;
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.substring(11);
    return 'Something went wrong while loading audit records.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Audit Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child:
                        Text(error!, style: const TextStyle(color: Colors.red)))
                : rows.isEmpty
                    ? const Center(child: Text('No audit records yet'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final row =
                              rows[idx] as Map<dynamic, dynamic>? ?? {};
                          final action = row['action']?.toString() ?? '—';
                          final ip =
                              row['ip_address']?.toString() ?? 'Unknown IP';
                          final ua =
                              row['user_agent']?.toString().trim() ?? '';
                          DateTime? when;
                          if (row['created_at'] != null) {
                            when =
                                DateTime.tryParse(row['created_at'].toString());
                          }
                          final formatted = when != null
                              ? DateFormat('MMM d, y • hh:mm a').format(when)
                              : '';

                          return ListTile(
                            dense: false,
                            title: Text(action,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Operator ID: '
                                      '${row['admin_id'] ?? 'system'} • $ip'),
                                  if (formatted.isNotEmpty)
                                    Text(formatted,
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                  if (ua.isNotEmpty)
                                    Text(
                                      ua,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
