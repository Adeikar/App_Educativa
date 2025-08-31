import 'package:flutter/material.dart';
import '../repaso_screen.dart';

class InicioTab extends StatelessWidget {
  const InicioTab({super.key});

  void _goTema(BuildContext context, String tema) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RepasoScreen(tema: tema)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TemaButton(color: Colors.green, icon: Icons.add, text: 'Suma', onTap: () => _goTema(context, 'suma')),
        const SizedBox(height: 12),
        _TemaButton(color: Colors.red, icon: Icons.remove, text: 'Resta', onTap: () => _goTema(context, 'resta')),
        const SizedBox(height: 12),
        _TemaButton(color: Colors.blue, icon: Icons.clear, text: 'Multiplicación', onTap: () => _goTema(context, 'multiplicacion')),
        const SizedBox(height: 12),
        _TemaButton(color: Colors.orange, icon: Icons.numbers, text: 'Conteo', onTap: () => _goTema(context, 'conteo')),
      ],
    );
  }
}

class _TemaButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TemaButton({required this.color, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
