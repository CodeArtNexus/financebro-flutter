import '../../core/errores.dart';
import '../accounts/cuentas.dart';

const destinosPermitidos = [
  '/inicio',
  '/cuentas',
  '/divisas',
  '/perfil',
  '/notificaciones',
];
const segmentosPermitidos = ['equilibrio', 'ahorro', 'viajes'];

class Perfil {
  const Perfil({
    required this.nombre,
    this.segmento = 'equilibrio',
    this.mostrarSaldo = true,
  });
  final String nombre;
  final String segmento;
  final bool mostrarSaldo;
}

class TarjetaRemota {
  const TarjetaRemota({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.destino,
    required this.segmento,
    required this.orden,
  });
  final String id, tipo, titulo, texto, destino, segmento;
  final int orden;
  Map<String, dynamic> aMapa() => {
    'id': id,
    'tipo': tipo,
    'titulo': titulo,
    'texto': texto,
    'destino': destino,
    'segmento': segmento,
    'orden': orden,
  };
}

class Experiencia {
  const Experiencia(this.tarjetas, this.revision, {this.respaldo = false});
  final List<TarjetaRemota> tarjetas;
  final int revision;
  final bool respaldo;
  List<TarjetaRemota> paraPerfil(String segmento) =>
      tarjetas
          .where((t) => t.segmento == 'todos' || t.segmento == segmento)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
  factory Experiencia.desdeMapa(Map<String, dynamic> m) {
    if (m['schemaVersion'] != 1 ||
        m['revision'] is! int ||
        m['tarjetas'] is! List ||
        (m['tarjetas'] as List).length > 20) {
      throw const FalloApp('La configuración recibida no es compatible.');
    }
    final resultado = <TarjetaRemota>[];
    final ids = <String>{};
    for (final entrada in m['tarjetas'] as List) {
      if (entrada is! Map) {
        throw const FalloApp('El contenido remoto no es válido.');
      }
      if (!['aviso', 'divisas', 'recomendacion'].contains(entrada['tipo'])) {
        continue;
      }
      for (final campo in [
        'id',
        'tipo',
        'titulo',
        'texto',
        'destino',
        'segmento',
      ]) {
        if (entrada[campo] is! String ||
            (entrada[campo] as String).isEmpty ||
            (entrada[campo] as String).length >
                (campo == 'texto' ? 300 : 100)) {
          throw const FalloApp('El contenido remoto no es válido.');
        }
      }
      if (!destinosPermitidos.contains(entrada['destino']) ||
          !['todos', ...segmentosPermitidos].contains(entrada['segmento']) ||
          entrada['orden'] is! int ||
          !ids.add(entrada['id'])) {
        throw const FalloApp(
          'El contenido remoto contiene un destino o identificador inválido.',
        );
      }
      resultado.add(
        TarjetaRemota(
          id: entrada['id'],
          tipo: entrada['tipo'],
          titulo: entrada['titulo'],
          texto: entrada['texto'],
          destino: entrada['destino'],
          segmento: entrada['segmento'],
          orden: entrada['orden'],
        ),
      );
    }
    return Experiencia(List.unmodifiable(resultado), m['revision']);
  }
  Map<String, dynamic> aMapa() => {
    'schemaVersion': 1,
    'revision': revision,
    'tarjetas': tarjetas.map((t) => t.aMapa()).toList(),
  };
}

const experienciaBase = Experiencia(
  [
    TarjetaRemota(
      id: 'base',
      tipo: 'aviso',
      titulo: 'Tu bienestar empieza con claridad',
      texto: 'Revisa tus cuentas y conoce cómo se mueve tu dinero.',
      destino: '/cuentas',
      segmento: 'todos',
      orden: 1,
    ),
  ],
  0,
  respaldo: true,
);

abstract interface class RepositorioExperiencia {
  Stream<Experiencia> observarContenido();
  Stream<DatosGuardados<Perfil>> observarPerfil(String uid);
  Future<void> guardarPerfil(String uid, Perfil perfil);
}
