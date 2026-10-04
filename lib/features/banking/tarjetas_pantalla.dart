import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/componentes.dart';
import '../../core/errores.dart';
import 'banca.dart';
import 'componentes_banca.dart';
import 'fondos_tarjeta.dart';

const coloresTarjeta = {
  'durazno': Color(0xFFFFCEAE),
  'lavanda': Color(0xFFDDD8F6),
  'menta': Color(0xFFCDE8DB),
  'noche': Color(0xFF323749),
};

class TarjetaVisualBro extends StatelessWidget {
  const TarjetaVisualBro(
    this.tarjeta, {
    super.key,
    this.titular = 'FinanceBro',
    this.onTap,
    this.compacta = false,
  });
  final Map<String, dynamic> tarjeta;
  final String titular;
  final VoidCallback? onTap;
  final bool compacta;
  @override
  Widget build(BuildContext context) {
    final color =
            coloresTarjeta[tarjeta['color']] ?? coloresTarjeta['durazno']!,
        fondo = tarjeta['fondoRuta'] as String?,
        oscuro = tarjeta['color'] == 'noche' || tarjeta['fondoRuta'] != null;
    return Semantics(
      label: 'Tarjeta ${tarjeta['banco']} terminada en ${tarjeta['ultimos4']}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: .72)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (fondo != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FondoTarjeta(fondo),
                  ),
                ),
              if (fondo != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withValues(alpha: .48),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(compacta ? 20 : 24),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: oscuro ? Colors.white : const Color(0xFF242735),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tarjeta['banco'] == 'FinanceBro'
                                  ? 'fb.'
                                  : 'Otro banco',
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          Icon(
                            tarjeta['tipo'] == 'propia'
                                ? Icons.shield_outlined
                                : Icons.credit_card,
                          ),
                        ],
                      ),
                      SizedBox(height: compacta ? 16 : 24),
                      Text(
                        tarjeta['nombre'] as String? ?? 'Mi tarjeta',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '••••  ••••  ••••  ${tarjeta['ultimos4']}',
                          style: const TextStyle(
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: compacta ? 14 : 18),
                      Text(
                        titular.toUpperCase(),
                        style: const TextStyle(fontSize: 10, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tarjeta['tipo'] == 'propia'
                            ? tarjeta['clase'] == 'credito'
                                  ? 'CRÉDITO · FINANCEBRO'
                                  : 'DÉBITO · FINANCEBRO'
                            : 'TARJETA ASOCIADA',
                        style: TextStyle(fontSize: 8, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TarjetasPantalla extends ConsumerStatefulWidget {
  const TarjetasPantalla({super.key});
  @override
  ConsumerState<TarjetasPantalla> createState() => _TarjetasEstado();
}

class _TarjetasEstado extends EstadoBanco<TarjetasPantalla> {
  final nombre = TextEditingController(),
      banco = TextEditingController(),
      ultimos = TextEditingController();
  String tipo = 'externa', color = 'durazno';
  String? cuenta, editar, fondoRuta;
  bool formulario = false;
  @override
  void dispose() {
    nombre.dispose();
    banco.dispose();
    ultimos.dispose();
    super.dispose();
  }

  Future<void> guardar() => trabajar(() async {
    await llamar('guardarTarjeta', {
      'id': editar,
      'tipo': tipo,
      'nombre': nombre.text,
      'banco': banco.text,
      'ultimos4': ultimos.text,
      'cuenta': cuenta,
      'color': color,
      if (tipo == 'propia') 'fondoRuta': fondoRuta,
    });
    if (mounted) setState(() => formulario = false);
  });
  void personalizar(Map<String, dynamic> t) {
    setState(() {
      formulario = true;
      editar = t['id'] as String;
      tipo = t['tipo'] as String;
      nombre.text = t['nombre'] as String;
      banco.text = t['banco'] as String;
      ultimos.text = t['ultimos4'] as String;
      cuenta = t['cuenta'] as String?;
      color = t['color'] as String;
      fondoRuta = t['fondoRuta'] as String?;
    });
  }

  Future<void> subirFondo() => trabajar(() async {
    if (editar == null || tipo != 'propia') return;
    final archivo = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (archivo.isEmpty) return;
    final longitud = await archivo.single.length();
    if (longitud != null && longitud > 2 * 1024 * 1024) {
      throw const FalloApp('Elige una imagen PNG o JPG de hasta 2 MB.');
    }
    final bytes = await archivo.single.readAsBytes();
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw const FalloApp('Elige una imagen PNG o JPG de hasta 2 MB.');
    }
    final png =
        bytes.length > 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpg =
        bytes.length > 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpg) {
      throw const FalloApp('Ese archivo no es una imagen PNG o JPG.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width > 4096 ||
          descriptor.height > 4096 ||
          descriptor.width * descriptor.height > 16000000) {
        throw const FalloApp('Usa una imagen de hasta 4096 píxeles por lado.');
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
    final uid = ref.read(identidadProvider).actual!.uid;
    final ruta =
        'tarjetas/$uid/$editar/fondos/${nuevaReferencia()}.${png ? 'png' : 'jpg'}';
    await ref
        .read(bancaProvider)
        .storage
        .ref(ruta)
        .putData(
          bytes,
          SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
        );
    if (mounted) setState(() => fondoRuta = ruta);
  });
  void abrirTarjeta(Map<String, dynamic> t) {
    if (t['clase'] == 'credito') {
      context.push('/tarjetas/credito/detalle');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TarjetaVisualBro(
                t,
                titular:
                    ref.read(identidadProvider).actual?.nombre ?? 'FinanceBro',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  context.push(
                    t['tipo'] == 'propia'
                        ? '/qr'
                        : '/pagar-externo?tipo=tarjeta&id=${t['id']}',
                  );
                },
                icon: Icon(
                  t['tipo'] == 'propia'
                      ? Icons.qr_code
                      : Icons.payments_outlined,
                ),
                label: Text(
                  t['tipo'] == 'propia' ? 'Transferir con QR' : 'Pagar tarjeta',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  personalizar(t);
                },
                child: const Text('Personalizar diseño'),
              ),
              if (t['tipo'] == 'propia')
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    context.push('/tarjetas/fisica/${t['id']}');
                  },
                  child: const Text('Solicitar copia física'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push(
                    t['tipo'] == 'propia'
                        ? '/cuentas/${t['cuenta']}'
                        : '/historial?tipo=tarjeta&id=${t['id']}',
                  );
                },
                child: const Text('Ver movimientos'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => pagina('Mis tarjetas', [
    const EncabezadoBro(
      'Tu estilo también cuenta',
      subtitulo: 'Personaliza FinanceBro y distingue tus otros bancos.',
    ),
    FilledButton.icon(
      onPressed: () => setState(() {
        formulario = !formulario;
        editar = null;
        tipo = 'externa';
        color = 'durazno';
        nombre.clear();
        banco.clear();
        ultimos.clear();
      }),
      icon: const Icon(Icons.add_card),
      label: const Text('Asociar tarjeta'),
    ),
    if (ref.watch(tarjetasBroProvider).hasValue &&
        !ref
            .watch(tarjetasBroProvider)
            .value!
            .any((t) => t['clase'] == 'credito'))
      OutlinedButton.icon(
        onPressed: () => context.push('/tarjetas/credito'),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text(
          ref
                      .watch(solicitudesBroProvider)
                      .value
                      ?.any(
                        (s) =>
                            s['tipo'] == 'credito' &&
                            !['rechazada', 'cancelada'].contains(s['estado']),
                      ) ==
                  true
              ? 'Ver mi solicitud de crédito'
              : 'Solicitar tarjeta de crédito',
        ),
      ),
    if (formulario)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tipo == 'propia'
                    ? 'Personaliza tu tarjeta FinanceBro'
                    : 'Asocia una tarjeta de otro banco',
              ),
              campo(nombre, 'Nombre de tu tarjeta'),
              if (tipo == 'externa') ...[
                campo(banco, 'Banco emisor'),
                campo(
                  ultimos,
                  'Últimos 4 dígitos',
                  teclado: TextInputType.number,
                  maximo: 4,
                ),
                const Text(
                  'Guarda solo los últimos cuatro dígitos. No ingreses claves ni códigos de seguridad.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: color,
                decoration: const InputDecoration(
                  labelText: 'Color de tu tarjeta',
                ),
                items: coloresTarjeta.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            CircleAvatar(radius: 8, backgroundColor: e.value),
                            const SizedBox(width: 10),
                            Text(e.key),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: ocupado ? null : (v) => setState(() => color = v!),
              ),
              if (tipo == 'propia') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: ocupado ? null : subirFondo,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    fondoRuta == null ? 'Subir mi fondo' : 'Cambiar mi fondo',
                  ),
                ),
                if (fondoRuta != null) ...[
                  const SizedBox(height: 12),
                  TarjetaVisualBro(
                    {
                      'tipo': 'propia',
                      'clase': 'debito',
                      'banco': 'FinanceBro',
                      'nombre': nombre.text,
                      'ultimos4': ultimos.text,
                      'color': color,
                      'fondoRuta': fondoRuta,
                    },
                    titular:
                        ref.read(identidadProvider).actual?.nombre ?? 'Bro',
                  ),
                  OutlinedButton.icon(
                    onPressed: ocupado
                        ? null
                        : () => setState(() => fondoRuta = null),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Usar solo color'),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'PNG o JPG · hasta 2 MB. El diseño físico será revisado antes del envío.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ocupado ? null : guardar,
                child: const Text('Guardar tarjeta'),
              ),
            ],
          ),
        ),
      ),
    ref
        .watch(tarjetasBroProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(mensajeError(e)),
          data: (tarjetas) => Column(
            children: [
              if (tarjetas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Asocia una tarjeta para personalizarla o guardar sus pagos.',
                  ),
                ),
              for (final t in tarjetas)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      TarjetaVisualBro(
                        t,
                        onTap: () => abrirTarjeta(t),
                        titular:
                            ref.watch(sesionProvider).value?.nombre ?? 'Bro',
                      ),
                      if (t['clase'] == 'credito')
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Cupo disponible ${dinero(((t['cupoCentavos'] as num) - (t['deudaCentavos'] as num)).toInt())}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (t['tipo'] == 'externa')
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Tarjeta de otro banco · consulta aquí tus pagos',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          if (t['clase'] == 'credito')
                            FilledButton.icon(
                              onPressed: () => context.push(
                                '/tarjetas/credito/detalle?pagar=true',
                              ),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Pagar mi tarjeta'),
                            ),
                          OutlinedButton(
                            onPressed: () => personalizar(t),
                            child: const Text('Personalizar'),
                          ),
                          if (t['tipo'] == 'externa')
                            OutlinedButton(
                              onPressed: () => context.push(
                                '/pagar-externo?tipo=tarjeta&id=${t['id']}',
                              ),
                              child: const Text('Pagar tarjeta'),
                            ),
                          OutlinedButton(
                            onPressed: () => context.push(
                              t['tipo'] == 'propia'
                                  ? t['clase'] == 'credito'
                                        ? '/historial?tipo=tarjeta&id=${t['id']}'
                                        : '/cuentas/${t['cuenta']}'
                                  : '/historial?tipo=tarjeta&id=${t['id']}',
                            ),
                            child: const Text('Movimientos'),
                          ),
                          if (t['tipo'] == 'propia')
                            OutlinedButton(
                              onPressed: () =>
                                  context.push('/tarjetas/fisica/${t['id']}'),
                              child: Text(
                                ref
                                            .watch(solicitudesBroProvider)
                                            .value
                                            ?.any(
                                              (s) =>
                                                  s['id'] ==
                                                      'fisica_${t['id']}' &&
                                                  ![
                                                    'cancelada',
                                                    'rechazada',
                                                    'entregada',
                                                  ].contains(s['estado']),
                                            ) ==
                                        true
                                    ? 'Seguir mi envío'
                                    : 'Pedir tarjeta física',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
  ]);
}
