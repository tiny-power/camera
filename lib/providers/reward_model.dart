import 'package:flutter/foundation.dart';

class RewardModel extends ChangeNotifier {
  bool _rewardValue = false;

  bool get rewardValue => _rewardValue;

  void evaluate(bool value) {
    _rewardValue = value;
    notifyListeners();
  }
}