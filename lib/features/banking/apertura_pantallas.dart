import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import 'banca.dart';
import 'componentes_banca.dart';

const documentosBro = {
  'constitucion': 'Escritura de constitución',
  'estatutos': 'Estatutos y reformas',
  'nombramiento': 'Nombramiento del representante inscrito',
  'ruc': 'RUC actualizado',
  'balances': 'Impuesto a la renta y estados financieros',
};

class AperturaCorrientePantalla extends ConsumerStatefulWidget {
  const AperturaCorrientePantalla({super.key});
  @override
  ConsumerState<AperturaCorrientePantalla> createState() => _CorrienteEstado();
}

class _CorrienteEstado extends EstadoBanco<AperturaCorrientePantalla> {
  final empresa = TextEditingController(),
      ruc = TextEditingController(),
      representante = TextEditingController();
  String escala = 'pyme';
  bool inicializado = false;
  bool acepta = false;
  @override
  void dispose() {
    empresa.dispose();
    ruc.dispose();
    representante.dispose();
    super.dispose();
  }

  Future<void> guardar() => trabajar(() async {
    await llamar('guardarSolicitud', {
      'empresa': empresa.text,
      'ruc': ruc.text,
      'representante': representante.text,
      'escala': escala,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progreso guardado. Puedes continuar más tarde.'),
        ),
      );
    }
  });
  Future<void> subir(String categoria) => trabajar(() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (resultado.isEmpty) return;
    final archivo = resultado.single;
    final longitud = await archivo.length();
    if (longitud != null && longitud > 5 * 1024 * 1024) {
      throw const FalloApp('Usa un documento de hasta 5 MB.');
    }
    final bytes = await archivo.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FalloApp('Usa un documento de hasta 5 MB.');
    }
    final uid = ref.read(identidadProvider).actual!.uid,
        extension = archivo.extension?.toLowerCase() == 'jpeg'
            ? 'jpg'
            : archivo.extension?.toLowerCase();
    final ruta =
            'expedientes/$uid/corriente/$categoria/${nuevaReferencia()}.$extension',
        tipo = extension == 'pdf'
            ? 'application/pdf'
            : extension == 'png'
            ? 'image/png'
            : 'image/jpeg';
    await ref
        .read(bancaProvider)
        .storage
        .ref(ruta)
        .putData(bytes, SettableMetadata(contentType: tipo));
    await llamar('registrarDocumento', {
      'categoria': categoria,
      'ruta': ruta,
      'nombre': archivo.name,
    });
  });
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(solicitudBroProvider);
    return pagina('Cuenta corriente', [
      const EncabezadoBro(
        'Tu empresa también tiene planes',
        subtitulo: 'Guarda cada paso. Un asesor revisará tu solicitud.',
      ),
      async.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(mensajeError(e)),
        data: (solicitud) {
          if (solicitud != null && !inicializado) {
            empresa.text = solicitud['empresa'] as String? ?? '';
            ruc.text = solicitud['ruc'] as String? ?? '';
            representante.text = solicitud['representante'] as String? ?? '';
            escala = solicitud['escala'] as String? ?? 'pyme';
            inicializado = true;
          }
          final estadoSolicitud = solicitud?['estado'] as String? ?? 'borrador',
              editable = ['borrador', 'correcciones'].contains(estadoSolicitud);
          final docs = Map<String, dynamic>.from(
            solicitud?['documentos'] as Map? ?? {},
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CristalBro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(switch (estadoSolicitud) {
                      'revision' => 'En revisión por tu asesor',
                      'deposito' => 'Cuenta temporal · espera tu depósito',
                      'activa' => 'Tu cuenta corriente está activa',
                      'correcciones' => 'Completa las observaciones del asesor',
                      _ => 'Borrador guardado · ${docs.length}/5 documentos',
                    }, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (solicitud?['nota'] != null)
                      Text(solicitud!['nota'] as String),
                    if (estadoSolicitud == 'deposito') ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        'Cuenta temporal: ${solicitud!['numeroCuenta']}',
                      ),
                      Text(
                        'Depósito inicial: USD ${((solicitud['depositoCentavos'] as num) / 100).toStringAsFixed(2)}',
                      ),
                      const Text(
                        'Puede recibir fondos. El asesor validará el depósito para habilitar transferencias y pagos.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (editable) ...[
                const SizedBox(height: 16),
                CristalBro(
                  child: Column(
                    children: [
                      campo(empresa, 'Razón social'),
                      campo(
                        ruc,
                        'RUC · 13 dígitos',
                        teclado: TextInputType.number,
                      ),
                      campo(representante, 'Representante legal'),
                      DropdownButtonFormField<String>(
                        initialValue: escala,
                        items: const [
                          DropdownMenuItem(
                            value: 'pyme',
                            child: Text('Pyme · depósito USD 1.000'),
                          ),
                          DropdownMenuItem(
                            value: 'empresa',
                            child: Text('Empresa · depósito USD 2.000'),
                          ),
                        ],
                        onChanged: ocupado
                            ? null
                            : (v) => setState(() => escala = v!),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: ocupado ? null : guardar,
                        icon: const Icon(Icons.check_circle_outline, size: 19),

                        label: const Text('Guardar datos y continuar'),
                      ),
                    ],
                  ),
                ),
                if (solicitud != null) ...[
                  const EncabezadoBro(
                    'Documentos de tu empresa',
                    subtitulo: 'PDF, PNG o JPG · hasta 5 MB por documento.',
                  ),
                  for (final entrada in documentosBro.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CristalBro(
                        padding: const EdgeInsets.all(14),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            docs.containsKey(entrada.key)
                                ? Icons.check_circle_outline
                                : Icons.description_outlined,
                          ),
                          title: Text(
                            entrada.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: docs[entrada.key] != null
                              ? Text(
                                  docs[entrada.key]['nombre'] as String,
                                  style: const TextStyle(fontSize: 10),
                                )
                              : const Text(
                                  'Pendiente',
                                  style: TextStyle(fontSize: 11),
                                ),
                          trailing: IconButton(
                            tooltip: 'Subir ${entrada.value}',
                            onPressed: ocupado
                                ? null
                                : () => subir(entrada.key),
                            icon: const Icon(Icons.upload_file),
                          ),
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    value: acepta,
                    onChanged: ocupado
                        ? null
                        : (v) => setState(() => acepta = v ?? false),
                    title: const Text(
                      'Autorizo la revisión de estos documentos y la apertura de la cuenta temporal.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: ocupado || docs.length != 5 || !acepta
                        ? null
                        : () => trabajar(() async {
                            await llamar('enviarSolicitud', {'acepta': true});
                          }),
                    icon: const Icon(Icons.send_rounded, size: 19),

                    label: const Text('Enviar al asesor'),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              const Text(
                'Tu proceso: revisión → cuenta temporal → depósito inicial → validación del asesor → cuenta activa.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          );
        },
      ),
    ]);
  }
}
