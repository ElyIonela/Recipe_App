import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        _isListening = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String) onResult,
    Function()? onDone,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) return;
    }

    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          onResult(result.recognizedWords);
          onDone?.call();
        }
      },
      listenFor: listenFor,
      cancelOnError: true,
      listenMode: stt.ListenMode.search,
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  void dispose() {
    _speech.cancel();
  }
}
