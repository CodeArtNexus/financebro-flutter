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
        Positioned.fill(
          child: ColoredBox(
            color: oscuroBro(context)
                ? const Color(0xFF111923)
                : fondoFinanceBro,
          ),
        ),
        Positioned(
          top: -120,
          right: -100,
          child: IgnorePointer(
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: naranjaFinanceBro.withValues(
                  alpha: oscuroBro(context) ? .035 : .075,
                ),
              ),
            ),
          ),
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
}

class CristalBro extends StatelessWidget {
  const CristalBro({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.radio = 24,
    this.agrupar = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radio;
  final bool agrupar;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radio),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: oscuroBro(context) ? .12 : .035,
          ),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: BackdropFilter(
        backdropGroupKey: agrupar
            ? BackdropGroup.of(context)?.backdropKey
            : null,
        enabled: !MediaQuery.highContrastOf(context),
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cristalBro(context, color),
            borderRadius: BorderRadius.circular(radio),
            border: Border.all(color: bordeBro(context)),
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
  Widget build(BuildContext context) => Semantics(
    label: 'FinanceBro',
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
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
              color: textoBro(context),
            ),
          ),
          const Text(
            ' •',
            style: TextStyle(color: naranjaTextoBro, fontSize: 24),
          ),
        ],
      ),
    ),
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
      builder: (_, valor, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - valor)),
        child: child,
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
    padding: const EdgeInsets.only(top: 22, bottom: 14),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: secundarioBro(context),
                    height: 1.5,
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

/// Entrada breve: anima solo la marca y deja las superficies de cristal fuera
/// de capas de opacidad para mantener el renderizado nativo de iOS y Android.
class EntradaMarcaBro extends StatefulWidget {
  const EntradaMarcaBro({super.key, required this.child});
  final Widget child;
  @override
  State<EntradaMarcaBro> createState() => _EntradaMarcaEstado();
}

class _EntradaMarcaEstado extends State<EntradaMarcaBro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _termino = false;
  @override
  void initState() {
    super.initState();
    _animacion.addStatusListener((estado) {
      if (estado == AnimationStatus.completed && mounted) {
        setState(() => _termino = true);
      }
    });
    _animacion.forward();
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_termino || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ColoredBox(
            color: oscuroBro(context)
                ? const Color(0xFF111923)
                : fondoFinanceBro,
            child: Center(
              child: AnimatedBuilder(
                animation: _animacion,
                builder: (context, _) {
                  final valor = Curves.easeOutBack.transform(
                    (_animacion.value / .7).clamp(0, 1),
                  );
                  return Transform.scale(
                    scale: .8 + .2 * valor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MarcaBro(),
                        const SizedBox(height: 18),
                        Text(
                          'Contigo, a tu ritmo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: secundarioBro(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AlertaBro extends StatelessWidget {
  const AlertaBro({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
    this.icon,
  });
  final Widget? title, content, icon;
  final List<Widget>? actions;
  final bool scrollable;
  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
    child: AlertDialog(
      icon:
          icon ??
          Icon(Icons.shield_outlined, color: acentoBro(context), size: 30),
      title: title,
      content: content,
      scrollable: scrollable,
      actions: actions,
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      actionsOverflowButtonSpacing: 8,
    ),
  );
}

/// Superficie de lista con separación consistente entre movimientos y avisos.
class TarjetaCristalBro extends StatelessWidget {
  const TarjetaCristalBro({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: CristalBro(padding: EdgeInsets.zero, child: child),
  );
}
