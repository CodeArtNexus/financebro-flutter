import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../app/tema.dart';
import '../../core/diseno_bro.dart';

class BienvenidaPantalla extends ConsumerWidget {
  const BienvenidaPantalla({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recuerdo = ref.watch(recuerdoAccesoProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: EntradaBro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MarcaBro()),
                    const SizedBox(height: 46),
                    Transform.rotate(
                      angle: -.055,
                      child: CristalBro(
                        color: const Color(0x99FFD7BD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: naranjaTextoBro,
                                ),
                                Spacer(),
                                Text(
                                  'TU COMPA FINANCIERO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 68,
                              color: tintaBro,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              recuerdo == null
                                  ? 'Un lugar para tus próximos planes.'
                                  : 'Hola, ${recuerdo.saludo}.\nQué bueno tenerte aquí.',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.8,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'financebro •',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      recuerdo == null
                          ? 'Tus finanzas,\na tu ritmo.'
                          : 'Tu financebro\nde confianza.',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Menos vueltas. Más claridad. Un espacio para cuidar tu dinero y dar forma a lo que viene.',
                      style: TextStyle(color: Color(0xFF686C7D), height: 1.7),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () => context.go(
                        recuerdo == null ? '/registrar' : '/ingresar',
                      ),
                      label: Text(
                        recuerdo == null ? 'Empezar' : 'Volver a mi espacio',
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    TextButton(
                      onPressed: () => context.go('/ingresar'),
                      child: const Text('Ya tengo una cuenta'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Demo con datos financieros de prueba.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF686C7D)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
