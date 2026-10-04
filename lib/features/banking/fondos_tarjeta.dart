import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'banca.dart';

final fondoTarjetaProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, ruta) => ref
          .watch(bancaProvider)
          .storage
          .ref(ruta)
          .getData(2 * 1024 * 1024)
          .timeout(const Duration(seconds: 10)),
    );

class FondoTarjeta extends ConsumerWidget {
  const FondoTarjeta(this.ruta, {super.key});
  final String ruta;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(fondoTarjetaProvider(ruta))
      .when(
        loading: () => const SizedBox(),
        error: (_, _) => const SizedBox(),
        data: (b) => b == null
            ? const SizedBox()
            : Image.memory(
                b,
                fit: BoxFit.cover,
                cacheWidth: 1024,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
      );
}
