import 'package:cloud_firestore/cloud_firestore.dart';

class Tema {
  final String id;
  final String nombre;
  final String concepto;

  const Tema({required this.id, required this.nombre, required this.concepto});

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'concepto': concepto,
      };

  factory Tema.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Tema(
      id: doc.id,
      nombre: (data['nombre'] ?? '').toString(),
      concepto: (data['concepto'] ?? '').toString(),
    );
  }
}
