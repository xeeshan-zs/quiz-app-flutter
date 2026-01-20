import 'package:flutter/material.dart';

class AdaptiveDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AdaptiveLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveDestination> destinations;
  final Widget? floatingActionButton;
  final Widget? railTrailing;
  final Widget? railLeading;
  final PreferredSizeWidget? mobileAppBar;

  const AdaptiveLayout({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.floatingActionButton,
    this.railTrailing,
    this.railLeading,
    this.mobileAppBar,
  });

  @override
  Widget build(BuildContext context) {
    // Determine screen width - consistent breakpoint
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: mobileAppBar, // Use the top bar on desktop too
        body: body, // No side rail, just content
        floatingActionButton: floatingActionButton,
      );
    } else {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: mobileAppBar,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          destinations: destinations.map((d) {
            return NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            );
          }).toList(),
        ),
        floatingActionButton: floatingActionButton,
      );
    }
  }
}
