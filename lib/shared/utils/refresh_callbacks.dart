/// Global refresh callbacks for app-wide state updates
/// Allows different screens to trigger refreshes in other screens

class RefreshCallback {
  Function? _callback;

  void setCallback(Function callback) {
    _callback = callback;
  }

  void clearCallback() {
    _callback = null;
  }

  void trigger() {
    _callback?.call();
  }
}

/// App-wide refresh callbacks for different screens
class AppRefreshCallbacks {
  static final RefreshCallback profile = RefreshCallback();
  static final RefreshCallback history = RefreshCallback();
  static final RefreshCallback home = RefreshCallback();
  static final RefreshCallback activeRentals = RefreshCallback();
  
  /// Trigger all refresh callbacks
  static void refreshAll() {
    profile.trigger();
    history.trigger();
    home.trigger();
    activeRentals.trigger();
  }
}
