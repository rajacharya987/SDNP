import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';
import 'tools/tools_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    HistoryScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    (icon: AppIcons.home, activeIcon: AppIcons.homeFilled),
    (icon: AppIcons.history, activeIcon: AppIcons.history),
    (icon: AppIcons.tools, activeIcon: AppIcons.tools),
    (icon: AppIcons.settings, activeIcon: AppIcons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: _pages),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 12 + bottomInset * 0.35,
            child: _PillNavBar(
              index: _index,
              items: _items,
              onChanged: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillNavBar extends StatelessWidget {
  const _PillNavBar({
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final int index;
  final List<({IconData icon, IconData activeIcon})> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDeep.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < items.length; i++)
            _PillNavItem(
              icon: items[i].icon,
              activeIcon: items[i].activeIcon,
              selected: index == i,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.ink : Colors.transparent,
        ),
        child: Icon(
          selected ? activeIcon : icon,
          size: 22,
          color: selected ? AppColors.white : AppColors.ink,
        ),
      ),
    );
  }
}
