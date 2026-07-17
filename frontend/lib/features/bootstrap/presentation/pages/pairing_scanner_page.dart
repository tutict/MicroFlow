import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/pairing_qr_payload.dart';

class PairingScannerPage extends StatefulWidget {
  const PairingScannerPage({super.key});

  @override
  State<PairingScannerPage> createState() => _PairingScannerPageState();
}

class _PairingScannerPageState extends State<PairingScannerPage> {
  late final MobileScannerController _controller;
  bool _handlingResult = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handlingResult) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) continue;
      try {
        final payload = PairingQrPayload.parse(rawValue);
        _handlingResult = true;
        await _controller.stop();
        if (!mounted) return;
        Navigator.of(context).pop(payload);
        return;
      } on FormatException {
        if (mounted) {
          setState(() => _errorText = _ScannerCopy.of(context).invalidCode);
        }
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on MobileScannerException {
      if (mounted) {
        setState(() => _errorText = _ScannerCopy.of(context).cameraUnavailable);
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } on MobileScannerException {
      if (mounted) {
        setState(() => _errorText = _ScannerCopy.of(context).cameraUnavailable);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _ScannerCopy.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(copy.title),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchEnabled = state.torchState == TorchState.on;
              return IconButton(
                tooltip: copy.torch,
                onPressed: state.isInitialized ? _toggleTorch : null,
                icon: Icon(
                  torchEnabled
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                ),
              );
            },
          ),
          IconButton(
            tooltip: copy.switchCamera,
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
            errorBuilder: (context, error) => _CameraError(
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? copy.permissionDenied
                  : copy.cameraUnavailable,
              retryLabel: copy.retry,
              onRetry: _controller.start,
            ),
            placeholderBuilder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.max(
                  0.0,
                  math.min(
                    constraints.maxWidth - 48,
                    math.min(constraints.maxHeight * 0.55, 300.0),
                  ),
                );
                return Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.lg,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppMotion.fast,
                child: Semantics(
                  key: ValueKey(_errorText),
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _errorText == null
                              ? Icons.qr_code_scanner_rounded
                              : Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            _errorText ?? copy.scanning,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 36,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerCopy {
  const _ScannerCopy({
    required this.title,
    required this.scanning,
    required this.invalidCode,
    required this.permissionDenied,
    required this.cameraUnavailable,
    required this.retry,
    required this.torch,
    required this.switchCamera,
  });

  final String title;
  final String scanning;
  final String invalidCode;
  final String permissionDenied;
  final String cameraUnavailable;
  final String retry;
  final String torch;
  final String switchCamera;

  static _ScannerCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'zh') {
      return const _ScannerCopy(
        title: '扫描设备二维码',
        scanning: '正在扫描',
        invalidCode: '二维码无效或已过期',
        permissionDenied: '请允许访问相机后重试',
        cameraUnavailable: '相机暂不可用',
        retry: '重试',
        torch: '闪光灯',
        switchCamera: '切换相机',
      );
    }
    return const _ScannerCopy(
      title: 'Scan device QR code',
      scanning: 'Scanning',
      invalidCode: 'This QR code is invalid or expired',
      permissionDenied: 'Allow camera access and try again',
      cameraUnavailable: 'Camera unavailable',
      retry: 'Retry',
      torch: 'Flash',
      switchCamera: 'Switch camera',
    );
  }
}
