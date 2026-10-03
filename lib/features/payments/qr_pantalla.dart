import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/proveedores.dart';
import '../../app/tema.dart';
import '../../core/diseno_bro.dart';
import '../../core/componentes.dart';
import '../../core/errores.dart';
import 'pagos.dart';

class QrPantalla extends ConsumerStatefulWidget {
  const QrPantalla({super.key});
  @override
  ConsumerState<QrPantalla> createState() => _QrEstado();
}

class _QrEstado extends ConsumerState<QrPantalla> {
  SolicitudQr? _solicitud;
  ReciboPago? _recibo;
  String? _nombre, _cuenta, _error;
  bool _cargando = false;
  final _codigo = TextEditingController();
  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _leer(String codigo) async {
    setState(() {
      _error = null;
      _cargando = true;
      _solicitud = null;
      _recibo = null;
    });
    try {
      final solicitud = SolicitudQr.leer(codigo.trim());
      final nombre = await ref
          .read(pagosRepositorioProvider)
          .consultarComercio(solicitud.comercio);
      if (mounted) {
        setState(() {
          _solicitud = solicitud;
          _nombre = nombre;
          _cuenta = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const _EscanerBro()));
    if (codigo != null && mounted) await _leer(codigo);
  }

  Future<void> _pagar() async {
    if (_solicitud == null || _cuenta == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final uid = ref.read(identidadProvider).actual!.uid;
      final recibo = await ref
          .read(pagosRepositorioProvider)
          .pagar(uid, _cuenta!, _solicitud!);
      if (mounted) setState(() => _recibo = recibo);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagar con QR')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const EncabezadoBro(
          'Escanea. Confirma. Listo.',
          subtitulo: 'Un café, un plan, un pago sencillo.',
        ),
        EntradaBro(
          child: CristalBro(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: naranjaFinanceBro.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 72,
                    color: naranjaTextoBro,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pagos de demostración',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usa el QR del panel FinanceBro. Confirmar descontará fondos de prueba y guardará tu movimiento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _cargando ? null : _escanear,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Escanear QR'),
                ),
                TextButton(
                  onPressed: _cargando
                      ? null
                      : () => _leer(
                          SolicitudQr(
                            'cafe-bro',
                            450,
                            'demo-${DateTime.now().microsecondsSinceEpoch}',
                          ).contenido,
                        ),
                  child: const Text('Probar con Café Bro · USD 4,50'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ExpansionTile(
          title: const Text(
            'Tengo un código de pago',
            style: TextStyle(fontSize: 13),
          ),
          children: [
            TextField(
              key: const Key('codigo-qr'),
              controller: _codigo,
              maxLength: 512,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Código FinanceBro'),
            ),
            TextButton(
              onPressed: _cargando ? null : () => _leer(_codigo.text),
              child: const Text('Revisar código'),
            ),
          ],
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, key: const Key('error-qr')),
            ),
          ),
        if (_solicitud != null && _recibo == null) ...[
          const SizedBox(height: 18),
          CristalBro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _nombre!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dinero(_solicitud!.centavos),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),
                ref
                    .watch(cuentasProvider)
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) =>
                          PanelError(e, () => ref.invalidate(cuentasProvider)),
                      data: (datos) => Column(
                        children: [
                          if (datos.desdeCache) AvisoCache(datos.actualizado),
                          DropdownButtonFormField<String>(
                            key: const Key('cuenta-pago'),
                            initialValue: _cuenta,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Pagar desde',
                            ),
                            items: datos.valor
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.nombre,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _cargando
                                ? null
                                : (v) => setState(() => _cuenta = v),
                          ),
                          if (datos.valor.isEmpty)
                            const Text(
                              'Necesitas una cuenta asignada para pagar.',
                            ),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('confirmar-pago'),
                  onPressed: _cargando || _cuenta == null ? null : _pagar,
                  child: Text(
                    _cargando ? 'Confirmando…' : 'Confirmar pago de prueba',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El pago se confirma únicamente con conexión.',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        if (_recibo != null) ...[
          const SizedBox(height: 20),
          EntradaBro(
            child: CristalBro(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 58,
                    color: Color(0xFF356B53),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pago confirmado',
                    key: Key('recibo-pago'),
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${dinero(_recibo!.centavos)} · ${_recibo!.nombre}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    'Referencia: ${_recibo!.referencia}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ya puedes verlo en los movimientos de tu cuenta.',
                    style: TextStyle(fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _solicitud = null;
                      _recibo = null;
                    }),
                    child: const Text('Hacer otro pago'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _EscanerBro extends StatefulWidget {
  const _EscanerBro();
  @override
  State<_EscanerBro> createState() => _EscanerEstado();
}

class _EscanerEstado extends State<_EscanerBro> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _leido = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Enfoca el QR')),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (captura) {
            for (final codigo in captura.barcodes) {
              if (!_leido && codigo.rawValue != null) {
                _leido = true;
                Navigator.pop(context, codigo.rawValue);
                break;
              }
            }
          },
          errorBuilder: (context, error) => const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No podemos abrir la cámara. Revisa su permiso o vuelve para pegar el código de pago.',
                textAlign: TextAlign.center,
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
              'Solo QR de FinanceBro. Revisa el comercio y el importe antes de confirmar.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}
