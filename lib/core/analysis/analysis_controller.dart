import 'dart:async';

class AnalysisController {
  bool _paused = false;

  bool _cancelled = false;

  bool get isPaused => _paused;

  bool get isCancelled => _cancelled;

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
  }

  void cancel() {
    _cancelled = true;
  }

  void reset() {
    _paused = false;
    _cancelled = false;
  }

  Future<bool> checkpoint() async {
    if (_cancelled) {
      return false;
    }

    while (_paused) {
      if (_cancelled) {
        return false;
      }

      await Future.delayed(
        const Duration(milliseconds: 100),
      );
    }

    return !_cancelled;
  }
}