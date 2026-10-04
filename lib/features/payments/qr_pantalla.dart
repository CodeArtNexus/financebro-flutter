import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/red_banco.dart';
import '../banking/pendientes_pantalla.dart';

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
  bool recibir = false, pendiente = false;
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
    if (!ref.read(redBancoProvider).conectado) {
      final uid = ref.read(identidadProvider).actual?.uid;
      if (uid == null) {
        throw const FalloApp(
          'Desbloquea tu sesión guardada para preparar una transferencia.',
        );
      }
      final contactos = await ref
          .read(datosProvider)
          .collection('usuarios/$uid/contactos')
          .get(const GetOptions(source: Source.cache));
      final c = contactos.docs
          .where(
            (c) =>
                c.data()['tipo'] == 'interno' && c.data()['numero'] == numero,
          )
          .firstOrNull;
      if (c == null) {
        throw const FalloApp(
          'Sin conexión puedes preparar envíos a contactos FinanceBro que ya verificaste. Conéctate para validar una cuenta nueva.',
        );
      }
      setState(
        () => receptor = {
          'numero': numero,
          'titular': c.data()['nombre'],
          'guardado': true,
        },
      );
      return;
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => buscar(numero));
  });
  Future<void> escanear() async {
    final r = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const EscanerBro()));
    if (r != null && mounted) await leer(r);
  }

  Future<void> transferir() => trabajar(() async {
    final centavos = montoCentavos(monto.text);
    final sinConexion = !ref.read(redBancoProvider).conectado;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertaBro(
        title: Text(
          sinConexion
              ? 'Autoriza el envío pendiente'
              : 'Revisa tu transferencia',
        ),
        content: Text(
          'Enviar USD ${(centavos / 100).toStringAsFixed(2)} a ${receptor!['titular']}\nCuenta ${receptor!['numero']}${sinConexion ? '\nSe validará al reconectar y caduca en 24 horas. El dinero aún no se descontará.' : ''}',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(c, false),
            icon: const Icon(Icons.close_rounded, size: 19),

            label: const Text('Volver'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.check_rounded, size: 19),

            label: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final datos = <String, dynamic>{
      'cuenta': cuenta,
      'numero': receptor!['numero'],
      'centavos': centavos,
      'nota': nota.text.trim().isEmpty
          ? 'Transferencia FinanceBro'
          : nota.text.trim(),
      'referencia': referencia,
    };
    if (sinConexion) {
      await ref
          .read(colaTransferenciasProvider)
          .agregar(datos, receptor!['titular'] as String);
      if (mounted) setState(() => pendiente = true);
      return;
    }
    final r = await llamar('transferir', datos);
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
    if (!widget.accesoRapido)
      OutlinedButton.icon(
        onPressed: () => context.push('/pendientes'),
        icon: const Icon(Icons.schedule_send_outlined),
        label: const Text('Mis transferencias pendientes'),
      ),
    if (pendiente && !recibir)
      CristalBro(
        child: Column(
          children: [
            const Icon(Icons.schedule_send, size: 56),
            const Text(
              'Transferencia preparada',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const Text(
              'Aún no descontamos dinero. Al reconectar validaremos la cuenta, los fondos y el monto.',
            ),
            FilledButton.icon(
              onPressed: () => context.push('/pendientes'),
              icon: const Icon(Icons.list_alt),
              label: const Text('Ver estado del envío'),
            ),
          ],
        ),
      )
    else if (recibo != null && !recibir)
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
                      const Text(
                        'Conéctate para consultar tu cuenta y recibir.',
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
          TextButton.icon(
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
            icon: const Icon(Icons.login_rounded, size: 19),

            label: const Text('Revisar cuenta'),
          ),
        ],
      ),
      if (receptor != null)
        CristalBro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                receptor!['guardado'] == true
                    ? 'Contacto guardado · pendiente de validar'
                    : 'Titular verificado',
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
              FilledButton.icon(
                key: const Key('confirmar-pago'),
                onPressed: ocupado || cuenta == null ? null : transferir,
                icon: const Icon(Icons.send_rounded, size: 19),

                label: Text(
                  ref.watch(conexionBancoProvider).value ==
                          EstadoConexion.conectado
                      ? 'Revisar transferencia'
                      : 'Preparar para enviar al reconectar',
                ),
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
