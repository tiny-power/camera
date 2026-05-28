import 'package:flutter/foundation.dart';

class SplashModel extends ChangeNotifier {
  bool _splashValue = false;

  bool get splashValue => _splashValue;

  void evaluate(bool value) {
    _splashValue = value;
    notifyListeners();
  }
}