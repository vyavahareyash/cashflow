import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/audio_capture_service.dart';
import '../services/database_helper.dart';
import '../services/speech_to_text_service.dart';
import '../services/voice_pipeline_coordinator.dart';
import '../theme/theme_constants.dart';
import 'voice_transaction_staging_sheet.dart';

/// Modal state representing the active recording and processing lifecycle.
enum VoiceModalState {
  initiating,
  recording,
  processing,
  error,
}

/// Interactive modal bottom sheet for voice recording and AI pipeline orchestration (US 1, 3, 13, 16).
///
/// Features animated pulsating microphone wave, live duration timer, WCAG AA accessibility
/// live region announcements, graceful microphone permission error handling, and seamless
/// transition to [VoiceTransactionStagingSheet].
class VoiceRecordingModal extends StatefulWidget {
  final VoicePipelineCoordinator? coordinator;
  final DateTime? anchorDate;

  const VoiceRecordingModal({
    super.key,
    this.coordinator,
    this.anchorDate,
  });

  /// Displays the voice recording modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    VoicePipelineCoordinator? coordinator,
    DateTime? anchorDate,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => VoiceRecordingModal(
        coordinator: coordinator,
        anchorDate: anchorDate,
      ),
    );
  }

  @override
  State<VoiceRecordingModal> createState() => _VoiceRecordingModalState();
}

class _VoiceRecordingModalState extends State<VoiceRecordingModal> {
  late final VoicePipelineCoordinator _coordinator;
  StreamSubscription<double>? _amplitudeSubscription;
  double _currentAmplitude = 0.0;
  bool _isMicActive = true;

  VoiceModalState _state = VoiceModalState.initiating;
  String _statusMessage = 'Preparing offline voice models...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _coordinator = widget.coordinator ?? VoicePipelineCoordinator();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    if (_coordinator.isRecording) {
      _coordinator.cancelRecording();
    }
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      setState(() {
        _statusMessage = 'Preparing offline voice models...';
      });
      await _coordinator.prepareSession();
      await _coordinator.startRecording();

      if (!mounted) return;
      setState(() {
        _isMicActive = true;
        _state = VoiceModalState.recording;
        _statusMessage = 'Listening... Speak your transactions in rupees';
      });

      _amplitudeSubscription = _coordinator.amplitudeStream.listen((amp) {
        if (mounted) {
          setState(() {
            _currentAmplitude = amp;
          });
        }
      });
    } on AudioCapturePermissionException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceModalState.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceModalState.error;
        _errorMessage = 'Could not start recording: $e';
      });
    }
  }

  Future<void> _toggleMic() async {
    if (_state != VoiceModalState.recording) return;

    if (_isMicActive) {
      await _coordinator.pauseListening();
      if (!mounted) return;
      setState(() {
        _isMicActive = false;
        _currentAmplitude = 0.0;
        _statusMessage = 'Microphone paused. Tap mic to resume';
      });
    } else {
      await _coordinator.resumeListening();
      if (!mounted) return;
      setState(() {
        _isMicActive = true;
        _statusMessage = 'Listening... Speak your transactions in rupees';
      });
    }
  }

  Future<void> _stopAndProcess() async {
    _amplitudeSubscription?.cancel();
    setState(() {
      _isMicActive = false;
      _state = VoiceModalState.processing;
      _statusMessage = 'Transcribing speech & extracting transactions...';
    });

    try {
      final drafts = await _coordinator.stopAndProcess(
        anchorDate: widget.anchorDate,
      );

      if (!mounted) return;

      // Close recording modal
      Navigator.of(context).pop();

      if (drafts.isEmpty) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? AppColors.darkText : AppColors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No transactions recognized. Please speak clearly with amounts in rupees and items.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.gray900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : Colors.transparent,
                width: 1,
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        await _coordinator.endSession();
        return;
      }

      // Transition smoothly to Staging Sheet
      await VoiceTransactionStagingSheet.show(
        context,
        drafts: drafts,
        onCommit: (approved) async {
          await DatabaseHelper.instance.commitDraftTransactions(approved);
        },
        onDismiss: () async {
          await _coordinator.endSession();
        },
      );
    } on SttSilentAudioException catch (_) {
      if (!mounted) return;
      setState(() {
        _state = VoiceModalState.error;
        _errorMessage =
            'No decipherable speech detected. Please speak clearly into the microphone.';
      });
    } on AudioCapturePermissionException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceModalState.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceModalState.error;
        _errorMessage = 'Voice extraction failed: $e';
      });
    }
  }

  Future<void> _cancel() async {
    _amplitudeSubscription?.cancel();
    try {
      await _coordinator.cancelRecording();
      await _coordinator.endSession();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        key: const Key('voice_recording_modal'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.gray700 : AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Title
              Semantics(
                header: true,
                child: Text(
                  'Voice Transaction Journaling',
                  style: AppTypography.titleMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.gray900,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Status Announcement with liveRegion for screen readers
              Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  _state == VoiceModalState.error
                      ? 'Error'
                      : _statusMessage,
                  key: const Key('voice_recording_status_text'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: _state == VoiceModalState.error
                        ? AppColors.danger
                        : isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.gray600,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Central Visual Content
              if (_state == VoiceModalState.error)
                _buildErrorView(isDark)
              else if (_state == VoiceModalState.processing)
                _buildProcessingView(isDark)
              else
                _buildRecordingView(isDark),

              const SizedBox(height: AppSpacing.xxl),

              // Bottom Actions
              if (_state == VoiceModalState.recording)
                _buildRecordingControls(isDark)
              else if (_state == VoiceModalState.error)
                _buildErrorControls(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingView(bool isDark) {
    return Column(
      children: [
        // 1. Live Streaming Transcript Card
        _buildLiveTranscriptCard(isDark),
        const SizedBox(height: AppSpacing.lg),

        // 2. Voice-Driven Reactive AI Waveform & Centered Mic Button
        _buildWaveformView(isDark),
        const SizedBox(height: AppSpacing.lg),

        // 3. Spoken Example Helper (Indian Context)
        Text(
          'e.g., "Lunch 250 rupees on HDFC, 1200 rupees groceries yesterday"',
          style: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.gray500,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLiveTranscriptCard(bool isDark) {
    return ValueListenableBuilder<String>(
      valueListenable: _coordinator.liveTranscriptListenable,
      builder: (context, transcript, _) {
        final hasText = transcript.trim().isNotEmpty;
        final isHearingVoice = _isMicActive && _currentAmplitude > 0.06;

        return Container(
          key: const Key('voice_recording_live_transcript_card'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88, maxHeight: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5)
                : AppColors.emerald500.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !_isMicActive
                  ? (isDark ? AppColors.darkBorder : AppColors.gray200)
                  : isHearingVoice
                      ? AppColors.emerald500.withValues(alpha: 0.5)
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.gray200,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: AI Badge & Hearing Voice / Listening / Mic Off indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: _isMicActive
                            ? AppColors.emerald500
                            : (isDark ? AppColors.gray500 : AppColors.gray400),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Offline AI Voice Engine',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : (_isMicActive
                                  ? AppColors.emerald700
                                  : AppColors.gray600),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: !_isMicActive
                              ? (isDark ? AppColors.gray600 : AppColors.gray400)
                              : isHearingVoice
                                  ? AppColors.emerald500
                                  : (isDark ? AppColors.gray600 : AppColors.gray400),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        !_isMicActive
                            ? 'Mic Off'
                            : (isHearingVoice ? 'Hearing Voice' : 'Listening'),
                        key: const Key('voice_recording_header_status_badge'),
                        style: AppTypography.labelSmall.copyWith(
                          color: !_isMicActive
                              ? (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.gray500)
                              : isHearingVoice
                                  ? AppColors.emerald500
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.gray500),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Transcript Body with Semantics liveRegion
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Semantics(
                    liveRegion: true,
                    label: hasText
                        ? 'Live transcript: $transcript'
                        : 'Listening for speech in rupees',
                    child: Text(
                      hasText
                          ? transcript
                          : 'e.g., "Chai 20 rupees on UPI, 450 rupees groceries yesterday"',
                      key: const Key('voice_recording_live_transcript_text'),
                      style: AppTypography.bodyMedium.copyWith(
                        color: hasText
                            ? (isDark ? AppColors.darkText : AppColors.gray900)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.gray500),
                        fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                        fontWeight: hasText ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveformView(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _isMicActive ? _currentAmplitude : 0.0),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutQuad,
      builder: (context, animatedAmp, child) {
        return SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Waveform Canvas (Decorative, ExcludeSemantics)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _VoiceReactiveWavePainter(
                      amplitude: _isMicActive ? animatedAmp : 0.0,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),

              // Dynamic Voice-Reactive Glowing Aura Ring
              if (_isMicActive)
                ExcludeSemantics(
                  child: Container(
                    width: 86 * (1.0 + animatedAmp * 0.45),
                    height: 86 * (1.0 + animatedAmp * 0.45),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withValues(
                            alpha: (0.15 + animatedAmp * 0.35).clamp(0.0, 1.0),
                          ),
                          AppColors.emerald500.withValues(
                            alpha: (0.1 + animatedAmp * 0.3).clamp(0.0, 1.0),
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

              // Centered AI Microphone Toggle Button
              Semantics(
                button: true,
                label: _isMicActive ? 'Mute microphone' : 'Turn on microphone',
                child: Material(
                  color: _isMicActive
                      ? AppColors.emerald600
                      : (isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.gray300),
                  shape: const CircleBorder(),
                  elevation: _isMicActive ? 6 : 2,
                  shadowColor: _isMicActive
                      ? AppColors.emerald600.withValues(
                          alpha: (0.35 + animatedAmp * 0.4).clamp(0.0, 1.0),
                        )
                      : Colors.transparent,
                  child: InkWell(
                    key: const Key('voice_recording_mic_button'),
                    customBorder: const CircleBorder(),
                    onTap: _toggleMic,
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Icon(
                        _isMicActive
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        size: 38,
                        color: _isMicActive
                            ? AppColors.white
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.gray700),
                      ),
                    ),
                  ),
                ),
              ),

              // Mic ON / OFF status pill badge
              Positioned(
                bottom: 4,
                child: Container(
                  key: const Key('voice_recording_mic_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isMicActive
                        ? AppColors.emerald600
                        : (isDark ? AppColors.darkSurfaceElevated : AppColors.gray600),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isMicActive
                          ? AppColors.emerald500
                          : (isDark ? AppColors.darkBorder : AppColors.gray500),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isMicActive
                              ? AppColors.emerald50
                              : AppColors.gray400,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isMicActive ? 'MIC ON' : 'MIC OFF',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcessingView(bool isDark) {
    return Column(
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            strokeWidth: 3.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald500),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Extracting financial entities locally...',
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.gray600,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _errorMessage ?? 'An unexpected error occurred.',
          key: const Key('voice_recording_error_text'),
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.darkText : AppColors.gray800,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecordingControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel Button (>= 48x48)
        Semantics(
          button: true,
          label: 'Cancel voice recording',
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('voice_recording_cancel_button'),
              onPressed: _cancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? AppColors.darkTextSecondary : AppColors.gray700,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.gray300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
              ),
            ),
          ),
        ),

        // Done / Stop Button (>= 48x48)
        Semantics(
          button: true,
          label: 'Finish recording and transcribe',
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('voice_recording_done_button'),
              onPressed: _stopAndProcess,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald600,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorControls(bool isDark) {
    return Semantics(
      button: true,
      label: 'Close voice recording modal',
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          key: const Key('voice_recording_error_close_button'),
          onPressed: _cancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.gray800 : AppColors.gray200,
            foregroundColor: isDark ? AppColors.darkText : AppColors.gray900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text('Close'),
        ),
      ),
    );
  }
}

/// Custom painter rendering voice-reactive harmonic waveforms that swell with user audio.
class _VoiceReactiveWavePainter extends CustomPainter {
  final double amplitude;
  final bool isDark;

  _VoiceReactiveWavePainter({
    required this.amplitude,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;
    final width = size.width;

    // Baseline height so there is an elegant wave presence even when quiet
    final activeAmp = amplitude.clamp(0.0, 1.0);
    final waveHeight = 4.0 + (activeAmp * (size.height * 0.38));

    // 1. Primary Wave: Cyan 400
    final path1 = Path()..moveTo(0, centerY);
    for (double x = 0; x <= width; x += 3) {
      final normX = (x / width) * 2 - 1;
      final envelope = (1 - normX * normX).clamp(0.0, 1.0);
      final y = centerY +
          math.sin((x / width) * 3 * math.pi * 2) * waveHeight * envelope;
      path1.lineTo(x, y);
    }
    final paint1 = Paint()
      ..color = AppColors.accent.withValues(
        alpha: (0.3 + activeAmp * 0.5).clamp(0.0, 1.0),
      )
      ..strokeWidth = 2.0 + activeAmp * 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path1, paint1);

    // 2. Secondary Wave: Emerald 500
    final path2 = Path()..moveTo(0, centerY);
    for (double x = 0; x <= width; x += 3) {
      final normX = (x / width) * 2 - 1;
      final envelope = (1 - normX * normX).clamp(0.0, 1.0);
      final y = centerY +
          math.sin((x / width) * 4 * math.pi * 2 + math.pi / 3) *
              (waveHeight * 0.8) *
              envelope;
      path2.lineTo(x, y);
    }
    final paint2 = Paint()
      ..color = AppColors.emerald500.withValues(
        alpha: (0.4 + activeAmp * 0.5).clamp(0.0, 1.0),
      )
      ..strokeWidth = 2.5 + activeAmp * 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path2, paint2);

    // 3. Tertiary Wave (Counter-phase harmonic): Emerald 400/600
    final path3 = Path()..moveTo(0, centerY);
    for (double x = 0; x <= width; x += 3) {
      final normX = (x / width) * 2 - 1;
      final envelope = (1 - normX * normX).clamp(0.0, 1.0);
      final y = centerY -
          math.sin((x / width) * 2.5 * math.pi * 2 + math.pi / 4) *
              (waveHeight * 0.6) *
              envelope;
      path3.lineTo(x, y);
    }
    final paint3 = Paint()
      ..color = (isDark ? AppColors.emerald400 : AppColors.emerald600)
          .withValues(
            alpha: (0.25 + activeAmp * 0.4).clamp(0.0, 1.0),
          )
      ..strokeWidth = 1.8 + activeAmp * 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant _VoiceReactiveWavePainter oldDelegate) {
    return (oldDelegate.amplitude - amplitude).abs() > 0.01 ||
        oldDelegate.isDark != isDark;
  }
}
