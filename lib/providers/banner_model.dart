import 'package:flutter/foundation.dart';

class BannerModel extends ChangeNotifier {
  bool _bannerValue = false;

  bool get bannerValue => _bannerValue;

  void evaluate(bool value) {
    _bannerValue = value;
    notifyListeners();
  }
}