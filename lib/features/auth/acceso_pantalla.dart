import '../../core/red_banco.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/proveedores.dart';
import '../../core/errores.dart';
import '../../core/diseno_bro.dart';
import 'identidad.dart';
import 'registro.dart';

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
  final _apellidos = TextEditingController(),
      _cedula = TextEditingController(),
      _direccion = TextEditingController(),
      _ciudad = TextEditingController(),
      _telefono = TextEditingController();
  int _paso = 0;
  bool _acepta = false;
  String? _error;
  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _nombre.dispose();
    for (final c in [_apellidos, _cedula, _direccion, _ciudad, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando || !_formulario.currentState!.validate()) return;
    if (widget.registro && _paso == 1 && !_acepta) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (ref.read(conexionBancoProvider).value != EstadoConexion.conectado) {
        final red = ref.read(redBancoProvider);
        // Una revisión pendiente no equivale a una desconexión.
        await red.revisar();
        if (!mounted) return;
        if (!red.conectado) {
          context.push('/conexion');
          return;
        }
      }
      if (widget.registro && _paso == 0) {
        setState(() => _paso = 1);
        return;
      }
      final repositorio = ref.read(identidadProvider);
      if (widget.registro) {
        await repositorio.registrar(
          DatosRegistro(
            nombres: _nombre.text,
            apellidos: _apellidos.text,
            correo: _correo.text,
            cedula: _cedula.text,
            clave: _clave.text,
            direccion: _direccion.text,
            ciudad: _ciudad.text,
            telefono: _telefono.text,
          ),
        );
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

  Future<void> _biometria() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(identidadProvider).reanudarConBiometria();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _dato(
    TextEditingController controlador,
    String etiqueta,
    Key key, {
    TextInputType? teclado,
    int minimo = 2,
    int maximo = 120,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: key,
      controller: controlador,
      keyboardType: teclado,
      decoration: InputDecoration(labelText: etiqueta),
      validator: (v) =>
          (v?.trim().length ?? 0) < minimo || (v?.trim().length ?? 0) > maximo
          ? 'Revisa $etiqueta.'
          : null,
    ),
  );
  Future<void> _contrato() => showDialog<void>(
    context: context,
    builder: (c) => AlertaBro(
      title: const Text('Contrato, términos y condiciones'),
      content: const SingleChildScrollView(child: Text(contratoRegistro)),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(c),
          icon: const Icon(Icons.arrow_forward_rounded, size: 19),

          label: const Text('Entendido'),
        ),
      ],
    ),
  );

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
                      if (ref.watch(conexionBancoProvider).value !=
                          EstadoConexion.conectado)
                        OutlinedButton.icon(
                          onPressed: () => context.push("/conexion"),
                          icon: const Icon(Icons.wifi_off),
                          label: const Text("Revisar conexión"),
                        ),
                      Text(
                        widget.registro
                            ? (_paso == 0
                                  ? 'Tu cuenta empieza contigo'
                                  : 'Tus datos, tu tranquilidad')
                            : (ref.watch(recuerdoAccesoProvider)?.saludo == null
                                  ? 'Qué bueno verte de nuevo'
                                  : 'Hola, ${ref.watch(recuerdoAccesoProvider)!.saludo} 👋'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.registro
                            ? (_paso == 0
                                  ? 'Crea tu cuenta de ahorros y recibe tu tarjeta de débito digital.'
                                  : 'Confirma tu domicilio y revisa el contrato antes de abrir tu cuenta.')
                            : (ref.watch(conexionBancoProvider).value ==
                                      EstadoConexion.sinConexion
                                  ? 'Tus datos guardados siguen contigo. Conéctate para ingresar o desbloquea tu sesión anterior.'
                                  : 'Aquí tienes a tu financebro de confianza. Vamos a tus planes.'),
                      ),
                      const SizedBox(height: 28),
                      if (!widget.registro || _paso == 0) ...[
                        if (widget.registro) ...[
                          TextFormField(
                            key: const Key('nombre'),
                            controller: _nombre,
                            decoration: const InputDecoration(
                              labelText: 'Nombres',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v?.trim().length ?? 0) < 2 ||
                                    (v?.length ?? 0) > 28
                                ? 'Escribe un nombre entre 2 y 28 caracteres.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.registro) ...[
                          _dato(
                            _apellidos,
                            'Apellidos',
                            const Key('apellidos'),
                            maximo: 28,
                          ),
                          TextFormField(
                            key: const Key('cedula'),
                            controller: _cedula,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cédula',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                                ? null
                                : 'Escribe tu cédula de 10 dígitos.',
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
                            prefixIcon: Icon(Icons.alternate_email),
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
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                      ],
                      if (widget.registro && _paso == 1) ...[
                        _dato(
                          _direccion,
                          'Dirección de domicilio',
                          const Key('direccion'),
                          minimo: 8,
                          maximo: 180,
                          teclado: TextInputType.streetAddress,
                        ),
                        _dato(
                          _ciudad,
                          'Ciudad',
                          const Key('ciudad'),
                          maximo: 60,
                        ),
                        _dato(
                          _telefono,
                          'Teléfono',
                          const Key('telefono'),
                          minimo: 7,
                          maximo: 20,
                          teclado: TextInputType.phone,
                        ),
                        const CristalBro(
                          child: Text(
                            'Tu cuenta se abrirá con USD 0 y tu tarjeta de débito digital quedará lista. Los pagos y transferencias se confirman antes de ejecutarse.',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cargando ? null : _contrato,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                          ),

                          label: const Text(
                            'Leer contrato, términos y condiciones',
                          ),
                        ),
                        CheckboxListTile(
                          key: const Key('aceptar-contrato'),
                          contentPadding: EdgeInsets.zero,
                          value: _acepta,
                          onChanged: _cargando
                              ? null
                              : (v) => setState(() => _acepta = v ?? false),
                          title: const Text(
                            'Soy mayor de edad y acepto el contrato y los términos para abrir mi cuenta y emitir mi tarjeta.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cargando
                              ? null
                              : () => setState(() => _paso = 0),
                          icon: const Icon(Icons.search_rounded, size: 19),

                          label: const Text('Revisar mis datos'),
                        ),
                      ],
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
                      FilledButton.icon(
                        key: const Key('enviar-acceso'),
                        onPressed:
                            _cargando ||
                                widget.registro && _paso == 1 && !_acepta
                            ? null
                            : _enviar,
                        icon: _cargando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                widget.registro
                                    ? Icons.person_add_outlined
                                    : Icons.login_rounded,
                              ),
                        label: Text(
                          _cargando
                              ? 'Conectando…'
                              : widget.registro
                              ? (_paso == 0
                                    ? 'Continuar'
                                    : 'Crear mi cuenta y tarjeta')
                              : 'Ingresar',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _cargando
                            ? null
                            : () => context.go(
                                widget.registro ? '/ingresar' : '/registrar',
                              ),
                        icon: const Icon(Icons.login_rounded, size: 19),

                        label: Text(
                          widget.registro
                              ? 'Ya tengo una cuenta'
                              : 'Quiero crear una cuenta',
                        ),
                      ),
                      if (!widget.registro)
                        TextButton.icon(
                          onPressed: _cargando ? null : _recuperar,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                          ),

                          label: const Text('Olvidé mi contraseña'),
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
                              : _biometria,
                          icon: const Icon(
                            Icons.face_retouching_natural_rounded,
                          ),
                          label: const Text('Desbloquear mi sesión'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Usa la seguridad de tu dispositivo después de tu primer ingreso.',
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
