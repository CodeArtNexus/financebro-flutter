import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/proveedores.dart';
import '../../core/diseno_bro.dart';
import '../../core/errores.dart';
import '../banking/banca.dart';
import '../banking/componentes_banca.dart';

class QrPantalla extends ConsumerStatefulWidget {
  const QrPantalla({
    super.key,
    this.numeroInicial,
    this.accesoRapido = false,
    this.recibirInicial = false,
  });
  final String? numeroInicial;
  final bool accesoRapido, recibirInicial;
  @override
  ConsumerState<QrPantalla> createState() => _QrEstado();
}

class _QrEstado extends EstadoBanco<QrPantalla> {
  final codigo = TextEditingController(),
      monto = TextEditingController(),
      nota = TextEditingController();
  String? cuenta, recibirCuenta;
  String referencia = nuevaReferencia();
  Map<String, dynamic>? receptor, recibo;
  bool recibir = false;
  @override
  void initState() {
    super.initState();
    recibir = widget.recibirInicial;
    if (widget.numeroInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => buscar(widget.numeroInicial!),
      );
    } else if (!widget.accesoRapido) {
      final p = ref.read(preferenciasLocalesProvider);
      final numero = p.getString('qr_pendiente');
      if (numero != null) {
        p.remove('qr_pendiente');
        WidgetsBinding.instance.addPostFrameCallback((_) => buscar(numero));
      }
    }
  }

  @override
  void didUpdateWidget(covariant QrPantalla anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.recibirInicial != widget.recibirInicial) {
      recibir = widget.recibirInicial;
    }
  }

  @override
  void dispose() {
    codigo.dispose();
    monto.dispose();
    nota.dispose();
    super.dispose();
  }

  Future<void> buscar(String numero) => trabajar(() async {
    final r = await llamar('destinatario', {'numero': numero});
    if (mounted) setState(() => receptor = r);
  });
  Future<void> leer(String valor) => trabajar(() async {
    final numero = leerQrCuenta(valor);
    if (widget.accesoRapido) {
      await ref
          .read(preferenciasLocalesProvider)
          .setString('qr_pendiente', numero);
      if (mounted) context.go('/ingresar');
      return;
    }
    final r = await llamar('destinatario', {'numero': numero});
    if (mounted) setState(() => receptor = r);
  });
  Future<void> escanear() async {
    final r = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const EscanerBro()));
    if (r != null && mounted) await leer(r);
  }

  Future<void> transferir() => trabajar(() async {
    final centavos = montoCentavos(monto.text);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revisa tu transferencia'),
        content: Text(
          'Enviar USD ${(centavos / 100).toStringAsFixed(2)} a ${receptor!['titular']}\nCuenta ${receptor!['numero']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final r = await llamar('transferir', {
      'cuenta': cuenta,
      'numero': receptor!['numero'],
      'centavos': centavos,
      'nota': nota.text.trim().isEmpty
          ? 'Transferencia FinanceBro'
          : nota.text.trim(),
      'referencia': referencia,
    });
    if (mounted) setState(() => recibo = r);
  });
  @override
  Widget build(
    BuildContext context,
  ) => pagina(widget.accesoRapido ? 'Pagar con QR' : 'Tu QR FinanceBro', [
    if (!widget.accesoRapido)
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Transferir'),
            icon: Icon(Icons.qr_code_scanner),
          ),
          ButtonSegment(
            value: true,
            label: Text('Mi QR'),
            icon: Icon(Icons.qr_code),
          ),
        ],
        selected: {recibir},
        onSelectionChanged: ocupado
            ? null
            : (v) => setState(() => recibir = v.first),
      ),
    const SizedBox(height: 20),
    if (recibo != null && !recibir)
      ReciboBro(
        recibo!,
        otra: () => setState(() {
          recibo = null;
          receptor = null;
          referencia = nuevaReferencia();
          monto.clear();
        }),
      )
    else if (recibir) ...[
      const EncabezadoBro(
        'Recibe con tu QR',
        subtitulo: 'La otra persona elige cuánto transferirte.',
      ),
      ref
          .watch(cuentasProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(mensajeError(e)),
            data: (d) {
              final cuentas = d.valor
                  .where((c) => c.numeroCuenta != null)
                  .toList();
              if (cuentas.isEmpty) {
                return CristalBro(
                  child: Column(
                    children: [
                      const Text('Necesitas una cuenta para recibir.'),
                      TextButton(
                        onPressed: () => context.push('/apertura/ahorros'),
                        child: const Text('Abrir cuenta'),
                      ),
                    ],
                  ),
                );
              }
              final elegida =
                  cuentas.where((c) => c.id == recibirCuenta).firstOrNull ??
                  cuentas.first;
              return CristalBro(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: elegida.id,
                      isExpanded: true,
                      items: cuentas
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => recibirCuenta = v),
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data:
                          'financebro://transferir?cuenta=${elegida.numeroCuenta}&v=1',
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ref.watch(sesionProvider).value?.nombre ?? 'FinanceBro',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SelectableText(
                      elegida.numeroCuenta!,
                      key: const Key('numero-mi-qr'),
                    ),
                    const Text(
                      'Comparte tu número o muestra este QR.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
    ] else ...[
      const EncabezadoBro(
        'De bro a bro',
        subtitulo: 'Transferencias de USD 0,10 a USD 100.',
      ),
      CristalBro(
        child: Column(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              widget.accesoRapido
                  ? 'Escanea primero. Ingresa para revisar y confirmar.'
                  : 'Escanea el QR de otra cuenta de FinanceBro.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: ocupado ? null : escanear,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Escanear QR'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        title: const Text('Tengo un código o número'),
        children: [
          campo(codigo, 'QR o número de cuenta', key: const Key('codigo-qr')),
          TextButton(
            onPressed: ocupado
                ? null
                : () {
                    final v = codigo.text.trim();
                    if (RegExp(r'^\d{14}$').hasMatch(v)) {
                      if (widget.accesoRapido) {
                        leer('financebro://transferir?cuenta=$v&v=1');
                      } else {
                        buscar(v);
                      }
                    } else {
                      leer(v);
                    }
                  },
            child: const Text('Revisar cuenta'),
          ),
        ],
      ),
      if (receptor != null)
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Titular verificado',
                style: TextStyle(fontSize: 11, color: Color(0xFF356B53)),
              ),
              Text(
                receptor!['titular'] as String,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(receptor!['numero'] as String),
              const SizedBox(height: 16),
              campo(
                monto,
                'Monto en USD',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                key: const Key('monto-transferencia'),
              ),
              campo(nota, 'Concepto (opcional)', maximo: 100),
              ElegirCuentaBro(
                valor: cuenta,
                cambiar: ocupado ? null : (v) => setState(() => cuenta = v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('confirmar-pago'),
                onPressed: ocupado || cuenta == null ? null : transferir,
                child: const Text('Revisar transferencia'),
              ),
            ],
          ),
        ),
    ],
  ]);
}

class EscanerBro extends StatefulWidget {
  const EscanerBro({super.key});
  @override
  State<EscanerBro> createState() => _EscanerEstado();
}

class _EscanerEstado extends State<EscanerBro> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool leido = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Enfoca el QR de tu bro')),
    body: Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (captura) {
            for (final codigo in captura.barcodes) {
              if (!leido && codigo.rawValue != null) {
                leido = true;
                Navigator.pop(context, codigo.rawValue);
                break;
              }
            }
          },
          errorBuilder: (_, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Revisa el permiso de cámara o vuelve para ingresar el código.',
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 36,
          left: 24,
          right: 24,
          child: CristalBro(
            child: Text(
              'Revisa el titular y el monto antes de transferir.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}
