import 'package:flutter/material.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const AdminAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: const Color(0xFF1565C0), // Professional blue
      foregroundColor: Colors.white,
      actions: actions,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}