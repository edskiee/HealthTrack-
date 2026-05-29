import 'dart:async';
import 'package:flutter/material.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final bool showLiveClock;

  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    this.showLiveClock = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Title Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          
          // Right: Action Buttons
          Row(
            children: [
              if (showLiveClock) ...[
                const _LiveClock(),
                const SizedBox(width: 12),
              ],
              // Refresh Button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
              ),
              const SizedBox(width: 12),
              
              // Notifications Button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF475569)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications feature coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Notifications',
                ),
              ),
              const SizedBox(width: 12),
              
              // User Profile
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Admin User",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  String _time = '';
  String _period = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    var hours = now.hour;
    final minutes = now.minute.toString().padLeft(2, '0');
    final seconds = now.second.toString().padLeft(2, '0');
    final ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12;
    if (hours == 0) hours = 12;
    setState(() {
      _time = '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
      _period = ampm;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF059669),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _time,
            style: const TextStyle(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _period,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
