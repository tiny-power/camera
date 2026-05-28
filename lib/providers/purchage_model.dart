import 'package:flutter/foundation.dart';

class PurchageModel extends ChangeNotifier {
  bool _value = false;

  bool get value => _value;

  void evaluate(bool value) {
    _value = value;
    notifyListeners();
  }
}