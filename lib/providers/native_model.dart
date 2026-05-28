import 'package:flutter/foundation.dart';

class NativeModel extends ChangeNotifier {
  bool _nativeValue = false;

  bool get nativeValue => _nativeValue;

  void evaluate(bool value) {
    _nativeValue = value;
    notifyListeners();
  }
}