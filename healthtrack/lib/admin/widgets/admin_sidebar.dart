import 'package:flutter/material.dart';

class SidebarMenuItem {
  final String title;
  final IconData icon;

  const SidebarMenuItem({
    required this.title,
    required this.icon,
  });
}

class AdminSidebar extends StatelessWidget {
  final List<SidebarMenuItem> menuItems;
  final int selectedIndex;
  final bool isCollapsed;
  final String username;
  final ValueChanged<int> onMenuTap;
  final VoidCallback onToggleCollapse;
  final VoidCallback onLogoutTap;

  const AdminSidebar({
    super.key,
    required this.menuItems,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.username,
    required this.onMenuTap,
    required this.onToggleCollapse,
    required this.onLogoutTap,
  });

  static const double expandedWidth = 260;
  static const double collapsedWidth = 88;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: isCollapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _SidebarActionItem(
                  title: item.title,
                  icon: item.icon,
                  selected: selectedIndex == index,
                  isCollapsed: isCollapsed,
                  onTap: () => onMenuTap(index),
                );
              },
            ),
          ),
          _SidebarActionItem(
            title: 'Logout',
            icon: Icons.logout,
            selected: false,
            isCollapsed: isCollapsed,
            onTap: onLogoutTap,
            isDanger: true,
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 118,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 6 : 12,
          vertical: 10,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  'assets/images/logoadmin.png',
                  width: 42,
                  height: 42,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HealthTrack',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Welcome, $username',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  onPressed: onToggleCollapse,
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: isCollapsed ? 30 : 40,
                    minHeight: isCollapsed ? 30 : 40,
                  ),
                  splashRadius: isCollapsed ? 18 : 22,
                  tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (isCollapsed) {
      return const SizedBox(height: 12);
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        children: [
          Text(
            'HealthTrack System',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            'v1.0.0 • Secure & Reliable',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SidebarActionItem extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final bool isDanger;

  const _SidebarActionItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.isCollapsed,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_SidebarActionItem> createState() => _SidebarActionItemState();
}

class _SidebarActionItemState extends State<_SidebarActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDanger = widget.isDanger;
    final Color itemBg = isDanger
        ? (_isHovered
            ? const Color(0xFFE53935)
            : const Color(0xFFD32F2F))
        : (widget.selected
            ? Colors.white.withOpacity(0.20)
            : _isHovered
                ? Colors.white.withOpacity(0.10)
                : Colors.transparent);

    final Color textAndIconColor = isDanger
        ? Colors.white
        : (widget.selected ? Colors.white : Colors.white70);

    final item = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 0 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: widget.isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(widget.icon, color: textAndIconColor, size: 20),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: textAndIconColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!widget.isCollapsed) {
      return item;
    }

    return Tooltip(
      message: widget.title,
      waitDuration: const Duration(milliseconds: 350),
      child: item,
    );
  }
}
