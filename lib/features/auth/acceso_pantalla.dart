import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/errores.dart';
import '../../core/diseno_bro.dart';
import 'identidad.dart';

class AccesoPantalla extends ConsumerStatefulWidget {
  const AccesoPantalla({super.key, this.registro = false});
  final bool registro;
  @override
  ConsumerState<AccesoPantalla> createState() => _AccesoEstado();
}

class _AccesoEstado extends ConsumerState<AccesoPantalla> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _nombre = TextEditingController();
  bool _cargando = false;
  bool _ocultar = true;
  bool _abrirAhorros = false;
  String? _error;
  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repositorio = ref.read(identidadProvider);
      if (widget.registro) {
        await ref
            .read(preferenciasLocalesProvider)
            .setBool('abrir_ahorros_pendiente', _abrirAhorros);
        await repositorio.registrar(_nombre.text, _correo.text, _clave.text);
      } else {
        await repositorio.ingresar(_correo.text, _clave.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _recuperar() async {
    if (validarCorreo(_correo.text) != null) {
      setState(() => _error = 'Escribe tu correo para recuperar el acceso.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(identidadProvider).recuperar(_correo.text);
      if (mounted) {
        setState(
          () => _error = 'Si el correo tiene una cuenta, recibirás instrucciones para recuperar el acceso.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _biometriaDemo() async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.face_retouching_natural_rounded, size: 54),
        title: const Text('Tu acceso, más fácil'),
        content: const Text(
          'Esta es una demostración de Face ID. Reanuda tu sesión de Firebase; no reconoce tu rostro ni usa el sensor del teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar demo'),
          ),
        ],
      ),
    );
    if (continuar != true || !mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(identidadProvider).reanudarDemostracion();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const MarcaBro(compacta: true)),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EntradaBro(
              child: CristalBro(
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.registro
                            ? 'Tu próximo paso empieza aquí'
                            : (ref.watch(recuerdoAccesoProvider)?.saludo == null
                                  ? 'Qué bueno verte de nuevo'
                                  : 'Hola, ${ref.watch(recuerdoAccesoProvider)!.saludo} 👋'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.registro
                            ? 'Crea tu espacio financiero en unos minutos.'
                            : 'Aquí tienes a tu financebro de confianza. Vamos a tus planes.',
                      ),
                      const SizedBox(height: 28),
                      if (widget.registro) ...[
                        TextFormField(
                          key: const Key('nombre'),
                          controller: _nombre,
                          decoration: const InputDecoration(
                            labelText: 'Tu nombre',
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              (v?.trim().length ?? 0) < 2 ||
                                  (v?.length ?? 0) > 60
                              ? 'Escribe un nombre entre 2 y 60 caracteres.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const Key('correo'),
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        validator: validarCorreo,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('clave'),
                        controller: _clave,
                        obscureText: _ocultar,
                        autofillHints: [
                          widget.registro
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          suffixIcon: IconButton(
                            tooltip: _ocultar
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                            icon: Icon(
                              _ocultar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: validarClave,
                        onFieldSubmitted: (_) {
                          if (!_cargando) _enviar();
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              key: const Key('error-acceso'),
                            ),
                          ),
                        ),
                      if (widget.registro)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _abrirAhorros,
                          onChanged: _cargando
                              ? null
                              : (v) => setState(() => _abrirAhorros = v),
                          title: const Text(
                            'Quiero abrir mi cuenta de ahorros',
                            style: TextStyle(fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Opcional. Completarás tus datos y aceptarás los términos en el siguiente paso.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      FilledButton(
                        key: const Key('enviar-acceso'),
                        onPressed: _cargando ? null : _enviar,
                        child: _cargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.registro
                                    ? 'Crear mi cuenta'
                                    : 'Ingresar',
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _cargando
                            ? null
                            : () => context.go(
                                widget.registro ? '/ingresar' : '/registrar',
                              ),
                        child: Text(
                          widget.registro
                              ? 'Ya tengo una cuenta'
                              : 'Quiero crear una cuenta',
                        ),
                      ),
                      if (!widget.registro)
                        TextButton(
                          onPressed: _cargando ? null : _recuperar,
                          child: const Text('Olvidé mi contraseña'),
                        ),
                      if (!widget.registro &&
                          ref.watch(recuerdoAccesoProvider) != null)
                        OutlinedButton.icon(
                          onPressed: _cargando
                              ? null
                              : () => context.push('/qr-acceso'),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Pagar con QR'),
                        ),
                      if (!widget.registro) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed:
                              _cargando ||
                                  !ref.watch(identidadProvider).sesionGuardada
                              ? null
                              : _biometriaDemo,
                          icon: const Icon(
                            Icons.face_retouching_natural_rounded,
                          ),
                          label: const Text('Face ID · demo'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Acceso simulado con una sesión previa. Ingresa una vez para probarlo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
