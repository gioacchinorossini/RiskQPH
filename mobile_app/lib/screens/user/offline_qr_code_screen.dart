import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class OfflineQRCodeScreen extends StatelessWidget {
  const OfflineQRCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final qrData = user == null
        ? ''
        : base64Encode(utf8.encode(jsonEncode({'studentId': user.id})));
    return Scaffold(
      appBar: AppBar(title: const Text('Offline QR Code')),
      body: Center(
        child: QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: 240,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

