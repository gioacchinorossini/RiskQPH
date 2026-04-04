import 'package:flutter/material.dart';
import '../../models/event.dart';

class QRCodeScreen extends StatelessWidget {
  final Event event;
  const QRCodeScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: const Center(child: Text('QR code generation placeholder')),
    );
  }
}

