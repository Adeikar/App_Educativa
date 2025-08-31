import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class QLearningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final double alpha = 0.2;
  final double epsilon = 0.15;

  static const niveles = ['muy_basico', 'basico', 'medio', 'alto'];

  Future<Map<String, dynamic>> _getUserDoc(String uid) async {
    final snap = await _db.collection('usuarios').doc(uid).get();
    return snap.data() ?? {};
  }

  Future<void> _saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<String> selectNivel(String uid, String tema) async {
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});
    final temaTable = Map<String, dynamic>.from(qTable[tema] ?? {});

    final q = {
      for (final n in niveles) n: (temaTable[n] is num) ? (temaTable[n] as num).toDouble() : 0.0
    };

    if (Random().nextDouble() < epsilon) {
      return niveles[Random().nextInt(niveles.length)];
    }

    return q.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<void> updateQ(String uid, String tema, String nivel, double reward) async {
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});
    final temaTable = Map<String, dynamic>.from(qTable[tema] ?? {});

    double current = (temaTable[nivel] is num) ? (temaTable[nivel] as num).toDouble() : 0.0;
    final newQ = current + alpha * (reward - current);

    temaTable[nivel] = newQ;
    qTable[tema] = temaTable;

    await _saveUserDoc(uid, {
      'qTable': qTable,
      'ultimoAcceso': FieldValue.serverTimestamp(),
    });
  }
}
