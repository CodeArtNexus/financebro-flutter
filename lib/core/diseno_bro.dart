import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'apariencia.dart';

import '../app/tema.dart';

class FondoBro extends ConsumerWidget {
  const FondoBro({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temporada = decoracionVigente(ref.watch(decoracionProvider).value);
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF6EE), fondoFinanceBro, Color(0xFFF0EFFB)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -130,
          right: -140,
          child: _luz(const Color(0xFFFFBD98)),
        ),
        Positioned(
          bottom: -160,
          left: -160,
          child: _luz(const Color(0xFFC7C3EC)),
        ),
        if (temporada != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TemporadaBro(temporada['tema'] as String),
              ),
            ),
          ),
        child,
      ],
    );
  }

  Widget _luz(Color color) => Container(
    width: 420,
    height: 420,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .5), color.withValues(alpha: 0)],
      ),
    ),
  );
}

class CristalBro extends StatelessWidget {
  const CristalBro({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
    this.radio = 28,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radio;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radio),
      boxShadow: [
        BoxShadow(
          color: tintaBro.withValues(alpha: .045),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: MediaQuery.highContrastOf(context)
                ? Colors.white
                : color ?? Colors.white.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(radio),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  );
}

class MarcaBro extends StatelessWidget {
  const MarcaBro({super.key, this.compacta = false});
  final bool compacta;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compacta ? 36 : 46,
        height: compacta ? 36 : 46,
        decoration: BoxDecoration(
          color: naranjaFinanceBro,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            'fb.',
            style: TextStyle(
              fontSize: compacta ? 20 : 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              color: tintaBro,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'financebro',
        style: TextStyle(
          fontSize: compacta ? 19 : 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -.9,
          color: tintaBro,
        ),
      ),
      const Text(' •', style: TextStyle(color: naranjaTextoBro, fontSize: 24)),
    ],
  );
}

class EntradaBro extends StatelessWidget {
  const EntradaBro({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (_, valor, child) => Opacity(
        opacity: valor,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - valor)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class EncabezadoBro extends StatelessWidget {
  const EncabezadoBro(this.titulo, {super.key, this.subtitulo, this.accion});
  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
              if (subtitulo != null)
                Text(
                  subtitulo!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF686C7D),
                  ),
                ),
            ],
          ),
        ),
        ?accion,
      ],
    ),
  );
}

class VolverBro extends StatelessWidget {
  const VolverBro({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Volver',
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () {
      final router = GoRouter.maybeOf(context);
      if (router == null) {
        Navigator.maybePop(context);
        return;
      }
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/inicio');
      }
    },
  );
}

class _TemporadaBro extends CustomPainter {
  const _TemporadaBro(this.tema);
  final String tema;
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color =
          (tema == 'navidad'
                  ? const Color(0xFF47826A)
                  : const Color(0xFFAE8B48))
              .withValues(alpha: .12)
      ..strokeWidth = 2;
    for (var i = 0; i < 18; i++) {
      final x = (i * 137.0 + 35) % size.width,
          y = (i * 211.0 + 65) % size.height;
      for (var j = 0; j < 3; j++) {
        final a = j * 3.14159265 / 3;
        final vector = Offset.fromDirection(a, 7);
        canvas.drawLine(Offset(x, y) - vector, Offset(x, y) + vector, pintura);
      }
    }
  }

  @override
  bool shouldRepaint(_TemporadaBro old) => old.tema != tema;
}
