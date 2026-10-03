import 'package:flutter/material.dart';

import 'tema.dart';

class FinanceBroApp extends StatelessWidget {
  const FinanceBroApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FinanceBro',
    debugShowCheckedModeBanner: false,
    theme: crearTema(),
    home: const BienvenidaInicial(),
  );
}

class BienvenidaInicial extends StatelessWidget {
  const BienvenidaInicial({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 72,
                  color: naranjaFinanceBro,
                ),
                const SizedBox(height: 24),
                Text(
                  'FinanceBro',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tus finanzas, a tu ritmo.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Una experiencia financiera simple, personal y siempre contigo.',
                ),
                const SizedBox(height: 32),
                const Text(
                  'Entorno de evaluación. Los datos financieros son de prueba.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
