import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'proveedores.dart';
import '../features/banking/historial.dart';
import '../features/banking/firebase_historial.dart';

final historialRepositorioProvider = Provider<RepositorioHistorial>(
  (ref) => FirebaseHistorial(ref.watch(datosProvider)),
);
final contactosRepositorioProvider = Provider<RepositorioContactos>(
  (ref) => FirebaseContactos(ref.watch(datosProvider)),
);
