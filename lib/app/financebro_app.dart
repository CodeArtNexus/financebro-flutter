import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'rutas.dart';
import 'tema.dart';

class FinanceBroApp extends ConsumerWidget {
  const FinanceBroApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'FinanceBro',
    debugShowCheckedModeBanner: false,
    theme: crearTema(),
    locale: const Locale('es', 'EC'),
    supportedLocales: const [Locale('es', 'EC')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(rutasProvider),
  );
}
