import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/audio_controller.dart';

/// WhatsApp-style voice message bubble with play/pause, seek bar,
/// duration display, and tap-to-reveal transcription.
class VoiceMessageBubble extends StatefulWidget {
  final Message message;

  const VoiceMessageBubble({super.key, required this.message});

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioController _audio = AudioController.instance;
  bool _showTranscription = false;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    super.dispose();
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  String get _messageId => widget.message.id;

  bool get _isPlaying => _audio.isPlaying(_messageId);
  bool get _isActive => _audio.isActive(_messageId);

  String? get _audioUrl => widget.message.voiceNoteUrl;

  String get _transcription => widget.message.content;
  bool get _hasTranscription => _transcription.trim().isNotEmpty;

  void _togglePlay() {
    if (_audioUrl == null || _audioUrl!.isEmpty) return;

    if (_isPlaying) {
      _audio.pause();
    } else {
      _audio.play(_messageId, _audioUrl!);
    }
  }

  void _onSeek(double value) {
    if (!_isActive) return;
    final position = Duration(
      milliseconds: (value * _audio.duration.inMilliseconds).round(),
    );
    _audio.seek(position);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = _audioUrl != null && _audioUrl!.isNotEmpty;
    final progress = _isActive ? _audio.progress : 0.0;
    final duration = _isActive ? _audio.duration : Duration.zero;
    final position = _isActive ? _audio.position : Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Player row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause button
            GestureDetector(
              onTap: hasUrl ? _togglePlay : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasUrl
                      ? VividColors.cyan.withOpacity(0.2)
                      : VividColors.textMuted.withOpacity(0.2),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: hasUrl ? VividColors.cyan : VividColors.textMuted,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Progress bar + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seek bar
                  SizedBox(
                    height: 20,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: VividColors.cyan,
                        inactiveTrackColor:
                            VividColors.textMuted.withOpacity(0.3),
                        thumbColor: VividColors.cyan,
                        overlayColor: VividColors.cyan.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: hasUrl && _isActive ? _onSeek : null,
                      ),
                    ),
                  ),

                  // Duration label
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _isActive
                          ? '${_formatDuration(position)} / ${_formatDuration(duration)}'
                          : hasUrl
                              ? 'Voice message'
                              : 'No audio',
                      style: TextStyle(
                        color: VividColors.textPrimary.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mic icon
            const SizedBox(width: 4),
            Icon(
              Icons.mic,
              size: 16,
              color: VividColors.cyan.withOpacity(0.5),
            ),
          ],
        ),

        // Transcription toggle
        if (_hasTranscription) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _showTranscription = !_showTranscription),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showTranscription
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 14,
                  color: VividColors.cyan.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  _showTranscription ? 'Hide transcription' : 'Show transcription',
                  style: TextStyle(
                    color: VividColors.cyan.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Transcription text
          if (_showTranscription) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VividColors.darkNavy.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _transcription,
                style: TextStyle(
                  color: VividColors.textPrimary.withOpacity(0.8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
