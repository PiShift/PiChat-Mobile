import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_motion.dart';
import 'package:pichat/core/theme/app_shadows.dart';
import 'package:pichat/core/theme/app_sizing.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

/// A single entry in [PiBottomNavBar].
class PiNavItem {
  const PiNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

// ─── PiBottomNavBar ──────────────────────────────────────────────────────────

/// Design-system bottom navigation bar.
///
/// Built from Flutter primitives — no Material [BottomNavigationBar].
///
/// Spec (§ 9.8):
/// - Height 60 px + SafeArea bottom
/// - Background: surfaceRaised (white / dark-raised)
/// - Top border: 1 px divider colour
/// - Shadow: shadow2
/// - Active: primary500 icon + label, primary50 pill 40×28 px behind icon
/// - Inactive: ink400 icon + label
/// - Label: labelSmall sp(10) w500
class PiBottomNavBar extends StatelessWidget {
  const PiBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<PiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(top: BorderSide(color: colors.divider)),
        boxShadow: PiShadow.shadow2,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(
              items.length,
              (i) => Expanded(
                child: _PiNavItemTile(
                  item: items[i],
                  isActive: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Internal tile ────────────────────────────────────────────────────────────

class _PiNavItemTile extends StatelessWidget {
  const _PiNavItemTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final PiNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? PiPalette.primary500 : PiPalette.ink400;
    final iconSize = Sz.w(context, 24);

    return Semantics(
      label: item.label,
      selected: isActive,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Icon + active pill ────────────────────────────────────────
            SizedBox(
              width: 48,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Icon (crossfades between active/inactive colour)
                  AnimatedSwitcher(
                    duration: PiMotion.fast,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Icon(
                      item.icon,
                      key: ValueKey('${item.label}_$isActive'),
                      size: iconSize,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // ── Label ─────────────────────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: PiMotion.fast,
              curve: PiMotion.easeOut,
              style: GoogleFonts.plusJakartaSans(
                fontSize: Sz.sp(context, 10),
                fontWeight: FontWeight.w500,
                color: color,
                height: 1,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
