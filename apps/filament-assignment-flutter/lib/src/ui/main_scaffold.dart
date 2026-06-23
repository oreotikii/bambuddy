import 'dart:async';

import 'package:floaty_nav_bar/floaty_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../data/assignment_repository.dart';
import 'assign_screen.dart';
import 'design_effects.dart';
import 'home_screen.dart';
import 'scanner_sheet.dart';
import 'weigh_screen.dart';

/// Bottom-nav shell for the three primary surfaces (Status / Weigh / Assign),
/// replacing the original per-screen activities.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, this.repository, this.scannerLauncher});

  final AssignmentRepository? repository;
  final CodeScannerLauncher? scannerLauncher;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _weighKey = GlobalKey<WeighScreenState>();
  final _assignKey = GlobalKey<AssignScreenState>();
  int _index = 0;
  int _homeRefreshNonce = 0;
  int _weighRefreshNonce = 0;
  int _assignRefreshNonce = 0;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
      if (index == 0) _homeRefreshNonce += 1;
      if (index == 1) _weighRefreshNonce += 1;
      if (index == 2) _assignRefreshNonce += 1;
    });
  }

  void _scanWeighQr() {
    final state = _weighKey.currentState;
    if (state == null) return;
    unawaited(state.scanQr());
  }

  void _scanAssignQr() {
    final state = _assignKey.currentState;
    if (state == null) return;
    unawaited(state.scanQr());
  }

  FloatyActionButton _scanQrButton(
    ColorScheme cs, {
    required String heroTag,
    required VoidCallback onTap,
  }) {
    return FloatyActionButton(
      heroTag: heroTag,
      tooltip: 'Scan QR',
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      icon: Icon(Icons.qr_code_scanner, size: 28, color: cs.onPrimary),
      onTap: onTap,
    );
  }

  // Returns only the icon widget; color is applied by _NavTab via IconTheme.
  Widget _tabIcon({
    required int index,
    required IconData selectedIcon,
    required IconData icon,
    required String tooltip,
  }) {
    final selected = _index == index;
    return Tooltip(
      message: tooltip,
      child: Icon(selected ? selectedIcon : icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => context.read<AppModel>().pingActivity(),
        child: SmoothTabStage(
          index: _index,
          children: [
            HomeScreen(refreshNonce: _homeRefreshNonce),
            WeighScreen(
              key: _weighKey,
              repository: widget.repository,
              scannerLauncher: widget.scannerLauncher,
              refreshNonce: _weighRefreshNonce,
            ),
            AssignScreen(
              key: _assignKey,
              repository: widget.repository,
              scannerLauncher: widget.scannerLauncher,
              refreshNonce: _assignRefreshNonce,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SpacedCircularFloatyNavBar(
        selectedTab: _index,
        height: 74,
        tabSpacing: 6,
        margin: const EdgeInsetsDirectional.only(top: 10, bottom: 18),
        backgroundColor: cs.surfaceContainerLow,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.56),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 4),
          ),
        ],
        shape: const CircleShape(),
        tabs: [
          FloatyTab(
            isSelected: _index == 0,
            title: 'Status',
            icon: _tabIcon(
              index: 0,
              selectedIcon: Icons.dashboard,
              icon: Icons.dashboard_outlined,
              tooltip: 'Status',
            ),
            selectedColor: cs.primary,
            unselectedColor: cs.surfaceContainerLow,
            onTap: () => _selectTab(0),
          ),
          FloatyTab(
            isSelected: _index == 1,
            title: 'Weigh',
            icon: _tabIcon(
              index: 1,
              selectedIcon: Icons.scale,
              icon: Icons.scale_outlined,
              tooltip: 'Weigh',
            ),
            selectedColor: cs.primary,
            unselectedColor: cs.surfaceContainerLow,
            floatyActionButton: _scanQrButton(
              cs,
              heroTag: 'scan-qr-weigh',
              onTap: _scanWeighQr,
            ),
            onTap: () => _selectTab(1),
          ),
          FloatyTab(
            isSelected: _index == 2,
            title: 'Assign',
            icon: _tabIcon(
              index: 2,
              selectedIcon: Icons.assignment_turned_in,
              icon: Icons.assignment_turned_in_outlined,
              tooltip: 'Assign',
            ),
            selectedColor: cs.primary,
            unselectedColor: cs.surfaceContainerLow,
            floatyActionButton: _scanQrButton(
              cs,
              heroTag: 'scan-qr-assign',
              onTap: _scanAssignQr,
            ),
            onTap: () => _selectTab(2),
          ),
        ],
        gap: 18,
      ),
    );
  }
}

class _SpacedCircularFloatyNavBar extends StatelessWidget {
  const _SpacedCircularFloatyNavBar({
    required this.tabs,
    required this.selectedTab,
    this.height = 60,
    this.gap = 16,
    this.tabSpacing = 8,
    this.margin = const EdgeInsetsDirectional.symmetric(vertical: 16),
    this.backgroundColor,
    this.boxShadow,
    this.shape = const CircleShape(),
  });

  final List<FloatyTab> tabs;
  final int selectedTab;
  final double height;
  final double gap;
  final double tabSpacing;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final FloatyShape shape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionButton = tabs[selectedTab].floatyActionButton;

    return SafeArea(
      child: Container(
        height: height,
        margin: margin,
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: backgroundColor ?? cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  boxShadow: boxShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < tabs.length; i++) ...[
                      if (i > 0) SizedBox(width: tabSpacing),
                      _NavTab(tab: tabs[i], selected: i == selectedTab),
                    ],
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: actionButton == null
                  ? const SizedBox.shrink()
                  : SizedBox(width: gap),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              child: actionButton == null
                  ? const SizedBox.shrink()
                  : Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.50),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.20),
                            blurRadius: 48,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        elevation: 0,
                        highlightElevation: 2,
                        shape: actionButton.shape,
                        backgroundColor: actionButton.backgroundColor,
                        foregroundColor: actionButton.foregroundColor,
                        onPressed: actionButton.onTap,
                        heroTag: actionButton.heroTag,
                        autofocus: actionButton.autofocus,
                        clipBehavior: actionButton.clipBehavior,
                        enableFeedback: actionButton.enableFeedback,
                        focusColor: actionButton.focusColor,
                        hoverColor: actionButton.hoverColor,
                        splashColor: actionButton.splashColor,
                        tooltip: actionButton.tooltip,
                        focusNode: actionButton.focusNode,
                        isExtended: actionButton.isExtended,
                        key: ValueKey(actionButton.icon.hashCode),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        mouseCursor: actionButton.mouseCursor,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: KeyedSubtree(
                            key: ValueKey(actionButton.icon.hashCode),
                            child: actionButton.icon,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Individual tab chip — constant button shape with a physical LED dot above
// the icon. The LED glows green when the tab is active.
class _NavTab extends StatelessWidget {
  const _NavTab({required this.tab, required this.selected});

  final FloatyTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00C853);
    const dim = Color(0xFF52525B);

    return GestureDetector(
      onTap: tab.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF252528),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? const Color(0xFF1A4030) : const Color(0xFF2E2E34),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // LED bar — dark when off, blooming green when active.
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 20,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? green : const Color(0xFF2E2E33),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? green.withValues(alpha: 0.90)
                        : Colors.transparent,
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: selected
                        ? green.withValues(alpha: 0.40)
                        : Colors.transparent,
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    blurRadius: 14,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: selected ? Colors.white : dim,
                  size: 22,
                ),
                child: tab.icon,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: selected ? Colors.white : dim,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1.0,
                fontFamily: 'Plus Jakarta Sans',
                shadows: selected
                    ? [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.30),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Text(tab.title),
            ),
          ],
        ),
      ),
    );
  }
}
