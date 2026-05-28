import 'package:flutter/foundation.dart';

class UdiderModel extends ChangeNotifier {
  String _uuid = "";

  String get uuid => _uuid;

  void evaluate(String value) {
    _uuid = value;
    notifyListeners();
  }

}
