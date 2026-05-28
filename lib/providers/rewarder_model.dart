import 'package:hand_camera/database_helper.dart';
import 'package:flutter/foundation.dart';

class RewarderModel extends ChangeNotifier {
  List<Map> _list = [];

  List<Map> get list => _list;

  void queryData() async {
    final db = await DatabaseHelper().database;
    try {
      var listData = await db.rawQuery(
        'SELECT * FROM Rewarder order by created_at desc',
      );
      _list = listData.toList();
    } catch (e) {
      e.toString();
    }
    notifyListeners();
  }

  void insert() async {
    final db = await DatabaseHelper().database;
    try {
      DateTime currentDate = DateTime.now();
      String recordTime =
          '${currentDate.year}-${currentDate.month}-${currentDate.day} ${currentDate.hour}:${currentDate.minute}:${currentDate.second}';
      await db.rawInsert(
        'INSERT INTO Rewarder(record_time) VALUES("$recordTime")',
      );
      var listData = await db.rawQuery(
        'SELECT * FROM Rewarder order by created_at desc',
      );
      _list = listData.toList();
    } catch (e) {
      e.toString();
    }
    notifyListeners();
  }
}
