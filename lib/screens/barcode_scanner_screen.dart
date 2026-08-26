import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';

/// Tela em tela cheia para leitura de código de barras.
/// Retorna o texto do primeiro código válido detectado.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  String? _lockedCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lockedCode != null) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        _lockedCode = v.trim();
        if (mounted) Navigator.of(context).pop<String>(_lockedCode);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('Aponte para o código'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop<String?>(null),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.darkCardElevated.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cream.withValues(alpha: 0.2)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Mantenha o código dentro da área visível. A leitura é feita automaticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.cream, height: 1.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
