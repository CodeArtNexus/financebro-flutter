import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/proveedores.dart';

final decoracionProvider = StreamProvider<Map<String, dynamic>>((ref) {
  if (ref.watch(sesionProvider).value == null) return Stream.value(const {});
  return ref
      .watch(datosProvider)
      .doc('experiencias/decoracion')
      .snapshots()
      .map((d) => d.data() ?? {});
});
Map<String, dynamic>? decoracionVigente(
  Map<String, dynamic>? d, {
  DateTime? ahora,
}) {
  if (d == null ||
      d['activa'] != true ||
      !['navidad', 'aniversario'].contains(d['tema'])) {
    return null;
  }
  final fecha = (ahora ?? DateTime.now())
      .toUtc()
      .subtract(const Duration(hours: 5))
      .toIso8601String()
      .substring(0, 10);
  if (d['desde'] is! String ||
      d['hasta'] is! String ||
      fecha.compareTo(d['desde'] as String) < 0 ||
      fecha.compareTo(d['hasta'] as String) > 0) {
    return null;
  }
  return d;
}

/// Preferencia del dispositivo, independiente de la sesión y sin consultas remotas.
final modoTemaProvider = NotifierProvider<ModoTemaBro, ThemeMode>(
  ModoTemaBro.new,
);

class ModoTemaBro extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => switch (ref
      .read(preferenciasLocalesProvider)
      .getString('apariencia_bro_v1')) {
    'claro' => ThemeMode.light,
    'oscuro' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    await ref.read(preferenciasLocalesProvider).setString(
      'apariencia_bro_v1',
      switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'oscuro',
        ThemeMode.system => 'sistema',
      },
    );
  }
}
