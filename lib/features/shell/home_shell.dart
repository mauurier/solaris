import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../main.dart';
import '../dashboard/dashboard_screen.dart';
import '../projects/projects_screen.dart';
import '../profile/profile_screen.dart';
import '../visits/visits_tab.dart';
import 'quick_capture_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    (Icons.space_dashboard_rounded, Icons.space_dashboard_outlined, 'Inicio'),
    (Icons.folder_rounded, Icons.folder_outlined, 'Proyectos'),
    (Icons.event_note_rounded, Icons.event_note_outlined, 'Visitas'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onSeeProjects: () => setState(() => _index = 1)),
            const ProjectsScreen(),
            const VisitsTab(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(
        index: _index,
        items: _items,
        onTap: (i) => setState(() => _index = i),
        onCapture: () => showQuickCapture(context),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.items,
    required this.onTap,
    required this.onCapture,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE60A0D12),
            border: Border(top: BorderSide(color: AppColors.borderSoft)),
          ),
          padding: EdgeInsets.only(top: 8, bottom: bottom > 0 ? bottom - 2 : 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _tab(0),
              _tab(1),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onCapture,
                      child: Container(
                        width: 50,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.solarGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Color(0xFF1B1200), size: 25),
                      ),
                    ),
                  ],
                ),
              ),
              _tab(2),
              _tab(3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final sel = index == i;
    final item = items[i];
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sel ? item.$1 : item.$2,
                size: 21,
                color: sel ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                item.$3,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  color: sel ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado reutilizable de las pestañas principales.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.actions, this.leading});
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.h1),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: T.small),
                ],
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

/// Botón circular de acción en encabezados.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton(this.icon, {super.key, this.onTap, this.badge, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 19, color: color ?? AppColors.textSecondary),
          ),
          if (badge != null)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.bg, width: 1.6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Indicador de conexión / sincronización usado en varias pantallas.
class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final offline = s.offlineMode;
    return GestureDetector(
      onTap: onTap ??
          () {
            s.toggleOffline();
            (context as Element).markNeedsBuild();
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: (offline ? AppColors.warning : AppColors.success).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (offline ? AppColors.warning : AppColors.success).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              size: 13,
              color: offline ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: 6),
            Text(
              offline ? 'Offline' : 'En línea',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: offline ? AppColors.warning : AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Página secundaria con encabezado consistente.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.bottomBar,
    this.showGlow = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        showGlow: showGlow,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: T.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!,
                                style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    if (actions != null) ...[const SizedBox(width: 8), ...actions!],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomBar == null ? null : BottomBar(child: bottomBar!),
    );
  }
}

void openPage(BuildContext context, Widget page) => push(context, page);
