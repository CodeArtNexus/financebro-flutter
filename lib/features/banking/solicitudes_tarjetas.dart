import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../core/diseno_bro.dart';
import '../../core/componentes.dart';
import '../../app/proveedores.dart';
import 'componentes_banca.dart';
import 'banca.dart';
import 'tarjetas_pantalla.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

DateTime primerEnvio(DateTime ahora) {
  final ecuador = ahora.toUtc().subtract(const Duration(hours: 5));
  return DateTime(ecuador.year, ecuador.month, ecuador.day + 3);
}

String fechaEnvio(DateTime fecha) =>
    '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
const estadosTarjeta = {
  'revision': 'En revisión por un asesor',
  'aprobada': 'Tu tarjeta de crédito está aprobada',
  'preaprobada': 'Preaprobada · un asesor completará la evaluación',
  'rechazada': 'Solicitud no aprobada',
  'revision_diseno': 'Tu diseño está en revisión',
  'preparacion': 'Preparando tu tarjeta',
  'enviada': 'Envío registrado',
  'entregada': 'Entrega registrada',
};
final solicitudTarjetaProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, id) {
      final uid = ref.watch(sesionProvider).value?.uid;
      return uid == null
          ? const Stream.empty()
          : ref
                .watch(datosProvider)
                .doc('usuarios/$uid/solicitudes/$id')
                .snapshots()
                .map((s) => s.data());
    });

class CreditoSolicitudPantalla extends ConsumerStatefulWidget {
  const CreditoSolicitudPantalla({super.key});
  @override
  ConsumerState<CreditoSolicitudPantalla> createState() => _CreditoEstado();
}

class _CreditoEstado extends EstadoBanco<CreditoSolicitudPantalla> {
  final ingresos = TextEditingController(), ocupacion = TextEditingController();
  bool acepta = false;
  @override
  void dispose() {
    ingresos.dispose();
    ocupacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = ref.watch(solicitudTarjetaProvider('credito')).value;
    final pendiente =
        solicitud != null &&
        ['revision', 'preaprobada', 'aprobada'].contains(solicitud['estado']);
    return pagina('Tarjeta de crédito', [
      const EncabezadoBro(
        'Un siguiente paso contigo',
        subtitulo: 'Cuéntanos sobre tus ingresos. Un asesor revisará tu solicitud antes de definir las condiciones y el cupo.',
      ),
      if (solicitud != null)
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                estadosTarjeta[solicitud['estado']] ?? 'Solicitud recibida',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (solicitud['estado'] == 'aprobada') ...[
                Text(
                  'Cupo aprobado: ${dinero((solicitud['cupoCentavos'] as num).toInt())}',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/tarjetas/credito/detalle'),
                  child: const Text('Ver tarjeta y elegir mi corte'),
                ),
              ],
              if (solicitud['nota'] != null) Text(solicitud['nota'] as String),
            ],
          ),
        ),
      if (!pendiente) ...[
        campo(
          ocupacion,
          'Ocupación',
          key: const Key('ocupacion-credito'),
          maximo: 80,
        ),
        campo(
          ingresos,
          'Ingresos mensuales · USD',
          key: const Key('ingresos-credito'),
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),
        CheckboxListTile(
          value: acepta,
          onChanged: ocupado ? null : (v) => setState(() => acepta = v!),
          title: const Text(
            'Autorizo que un asesor revise mis datos e ingresos para evaluar esta solicitud. Solicitarla no garantiza su aprobación.',
          ),
        ),
        FilledButton(
          onPressed: ocupado || !acepta
              ? null
              : () => trabajar(() async {
                  await llamar('solicitarTarjetaCredito', {
                    'ingresosCentavos': montoCentavos(
                      ingresos.text,
                      maximo: 100000000,
                    ),
                    'ocupacion': ocupacion.text,
                    'aceptaEvaluacion': true,
                  });
                }),
          child: const Text('Enviar solicitud'),
        ),
      ],
    ]);
  }
}

class FisicaSolicitudPantalla extends ConsumerStatefulWidget {
  const FisicaSolicitudPantalla(this.tarjeta, {super.key});
  final String tarjeta;
  @override
  ConsumerState<FisicaSolicitudPantalla> createState() => _FisicaEstado();
}

class _FisicaEstado extends EstadoBanco<FisicaSolicitudPantalla> {
  final direccion = TextEditingController(),
      ciudad = TextEditingController(),
      telefono = TextEditingController();
  final referencia = nuevaReferencia();
  late DateTime minimo, envio;
  bool acepta = false, cargando = true;
  @override
  void initState() {
    super.initState();
    minimo = primerEnvio(DateTime.now());
    envio = minimo;
    _precargar();
  }

  Future<void> _precargar() async {
    try {
      final uid = ref.read(identidadProvider).actual!.uid;
      final personal = await ref
          .read(datosProvider)
          .doc('usuarios/$uid/datosPersonales/identidad')
          .get(const GetOptions(source: Source.server));
      if (!mounted) return;
      final d = personal.data()?['domicilio'] as Map<String, dynamic>?;
      direccion.text = d?['direccion'] as String? ?? '';
      ciudad.text = d?['ciudad'] as String? ?? '';
      telefono.text = d?['telefono'] as String? ?? '';
    } catch (_) {
      /* El formulario permite completar el domicilio si no se pudo precargar. */
    }
    if (mounted) setState(() => cargando = false);
  }

  @override
  void dispose() {
    direccion.dispose();
    ciudad.dispose();
    telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarjeta = ref
        .watch(tarjetasBroProvider)
        .value
        ?.where((t) => t['id'] == widget.tarjeta)
        .firstOrNull;
    final solicitud = ref
        .watch(solicitudTarjetaProvider('fisica_${widget.tarjeta}'))
        .value;
    final pendiente =
        solicitud != null &&
        !['entregada', 'rechazada', 'cancelada'].contains(solicitud['estado']);
    return pagina('Tu tarjeta física', [
      if (tarjeta != null)
        TarjetaVisualBro(
          tarjeta,
          titular: ref.watch(sesionProvider).value?.nombre ?? 'FinanceBro',
        ),
      const SizedBox(height: 20),
      if (solicitud != null)
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                estadosTarjeta[solicitud['estado']] ?? 'Solicitud recibida',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('Envío solicitado: ${solicitud['fechaEnvio']}'),
              if (solicitud['nota'] != null) Text(solicitud['nota'] as String),
            ],
          ),
        ),
      if (cargando) const LinearProgressIndicator(),
      if (!pendiente && tarjeta != null) ...[
        const SizedBox(height: 16),
        Text(
          tarjeta['personalizada'] == true
              ? 'Revisaremos tu diseño en un plazo de 3 días. Una vez aprobado, prepararemos el envío a tu domicilio desde la fecha elegida.'
              : 'Reserva el envío de tu tarjeta. Necesitamos al menos 3 días para emitirla; la llegada depende de la entrega en tu domicilio.',
        ),
        campo(
          direccion,
          'Dirección de entrega',
          key: const Key('direccion-fisica'),
          maximo: 180,
        ),
        campo(ciudad, 'Ciudad', key: const Key('ciudad-fisica'), maximo: 60),
        campo(
          telefono,
          'Teléfono de contacto',
          key: const Key('telefono-fisica'),
          teclado: TextInputType.phone,
          maximo: 20,
        ),
        OutlinedButton.icon(
          onPressed: ocupado
              ? null
              : () async {
                  final actualMinimo = primerEnvio(DateTime.now());
                  final d = await showDatePicker(
                    context: context,
                    initialDate: envio.isBefore(actualMinimo)
                        ? actualMinimo
                        : envio,
                    firstDate: actualMinimo,
                    lastDate: actualMinimo.add(const Duration(days: 87)),
                    helpText: 'Envío desde 3 días después de hoy',
                  );
                  if (d != null && mounted) setState(() => envio = d);
                },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('Fecha de envío · ${fechaEnvio(envio)}'),
        ),
        CheckboxListTile(
          value: acepta,
          onChanged: ocupado ? null : (v) => setState(() => acepta = v!),
          title: const Text(
            'Confirmo el domicilio y autorizo usar estos datos para preparar mi tarjeta y gestionar su entrega.',
          ),
        ),
        FilledButton(
          onPressed: ocupado || !acepta || cargando
              ? null
              : () => trabajar(() async {
                  await llamar('solicitarFisica', {
                    'tarjeta': widget.tarjeta,
                    'referencia': referencia,
                    'direccion': direccion.text,
                    'ciudad': ciudad.text,
                    'telefono': telefono.text,
                    'fechaEnvio': fechaEnvio(envio),
                    'aceptaEnvio': true,
                  });
                }),
          child: const Text('Solicitar mi tarjeta física'),
        ),
      ],
    ]);
  }
}
