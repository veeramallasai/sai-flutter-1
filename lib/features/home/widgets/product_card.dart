import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shared ADD / quantity control used by Home and Category product cards.
/// Quantity zero shows ADD; decreasing one to zero returns to ADD automatically.
class ProductQuantityControl extends StatelessWidget {
  const ProductQuantityControl({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onDecrease,
    required this.onIncrease,
    this.loading = false,
    this.enabled = true,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool loading;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double height = compact ? 32 : 36;
    if (quantity <= 0) {
      return SizedBox(
        height: height,
        width: compact ? 60 : 72,
        child: FilledButton(
          onPressed: enabled && !loading ? onAdd : null,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: const Color(0xFF1B5E20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'ADD',
                  style: TextStyle(fontSize: 10.5, letterSpacing: 0.3, fontWeight: FontWeight.w900),
                ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      width: compact ? 86 : 108,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x260B7A3E), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: _StepButton(
                    icon: quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                    onTap: enabled ? onDecrease : null,
                  ),
                ),
                Container(width: 1, height: 14, color: const Color(0x44FFFFFF)),
                SizedBox(
                  width: compact ? 24 : 32,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
                Container(width: 1, height: 14, color: const Color(0x44FFFFFF)),
                Expanded(
                  child: _StepButton(
                    icon: Icons.add_rounded,
                    onTap: enabled ? onIncrease : null,
                  ),
                ),
              ],
            ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Icon(
            icon,
            color: onTap == null ? Colors.white38 : Colors.white,
            size: 18,
          ),
        ),
      );
}

class PremiumProductImage extends StatelessWidget {
  const PremiumProductImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
  });

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.trim().isEmpty) return const _ImageFallback();
    final Widget image = path.startsWith('http://') || path.startsWith('https://')
        ? Image.network(path, width: double.infinity, height: double.infinity, fit: fit, errorBuilder: _error)
        : Image.asset(path, width: double.infinity, height: double.infinity, fit: fit, errorBuilder: _error);
    return ClipRRect(borderRadius: BorderRadius.circular(17), child: image);
  }

  Widget _error(BuildContext context, Object error, StackTrace? stackTrace) => const _ImageFallback();
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFE8F5E9),
        child: Center(child: Icon(Icons.eco_rounded, color: AppColors.primary, size: 48)),
      );
}
