// AuthService: registro, login con verificación de correo y bloqueo de docente pendiente.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _fs = FirestoreService();

  // Stream del estado de auth.
  Stream<User?> get userStream => _auth.authStateChanges();

  // Registro genérico (usa FirestoreService para perfilar).
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    String? nivelEducativo,
    String? discapacidad,
    String? relacionFamiliar,
    String? pais,
    String? ciudad,
    String? area,
    String? institucion,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await sendEmailVerification(user);
    await _fs.guardarUsuario(
      uid: user.uid,
      nombre: nombre,
      correo: email,
      rol: rol,
      nivelEducativo: nivelEducativo,
      discapacidad: discapacidad,
      relacionFamiliar: relacionFamiliar,
      pais: pais,
      ciudad: ciudad,
      area: area,
      institucion: institucion,
    );
    return cred;
  }

  // Login: exige email verificado y bloquea 'docente_solicitado'.
  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;

    // (1) Exigir verificación de correo
    if (!user.emailVerified) {
      await user.sendEmailVerification();
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Debes verificar tu correo. Te reenvié el enlace.',
      );
    }

    // (2) Leer rol desde Firestore y bloquear si está pendiente
    final doc = await _db.collection('usuarios').doc(user.uid).get();
    final rol = (doc.data()?['rol'] ?? '').toString();

    if (rol == 'docente_solicitado') {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'teacher-pending',
        message: 'Tu solicitud para Docente está en revisión por el administrador.',
      );
    }

    // (3) Metadatos de acceso
    await _db.collection('usuarios').doc(user.uid).set({
      'ultimoAcceso': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return cred;
  }

  // Reset password.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Enviar verificación.
  Future<void> sendEmailVerification(User user) async {
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Logout.
  Future<void> signOut() => _auth.signOut();
}
