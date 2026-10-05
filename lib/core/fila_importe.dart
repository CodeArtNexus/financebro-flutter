import 'package:flutter/material.dart';

// La información monetaria conserva su tamaño cuando el texto necesita más espacio.
class FilaImporteBro extends StatelessWidget {
  const FilaImporteBro({
    super.key,
    required this.titulo,
    required this.importe,
  });
  final Widget titulo, importe;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
          limites.maxWidth < 280) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [titulo, const SizedBox(height: 8), importe],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titulo),
          const SizedBox(width: 12),
          importe,
        ],
      );
    },
  );
}
