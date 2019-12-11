import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database.dart';
import 'dart:async';

class DataModel with ChangeNotifier {
  static const List<String> _rusMonths = [
    'Января',
    'Февраля',
    'Марта',
    'Апреля',
    'Мая',
    'Июня',
    'Июля',
    'Августа',
    'Сентября',
    'Октября',
    'Ноября',
    'Декабря'
  ];

  List<String> get rusMonths => _rusMonths;

  var _db = DBHelper();

  List<Schedule> _scheduleList = [];

  List<Schedule> get scheduleList => _scheduleList;

  List<Medicine> _medicineList = [];

  List<Medicine> get medicineList => _medicineList;

  Medicine _curMed;

  Medicine get curMed => _curMed;

  bool _available = false;

  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  bool get available => _available;

  Future<void> setCureMed(Medicine med) async {
    _curMed = med;
    _scheduleList = await _db.getScheduleByMedicine(med);
  }

  DataModel(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) {
    _flutterLocalNotificationsPlugin = flutterLocalNotificationsPlugin;
    _init();
  }

  Future<void> _init() async {
    _medicineList = await _db.initDb().then((_) => _db.getAllMedicine());
    notifyListeners();
  }

  void checkURL(String url) {
    bool prev = _available;
    _available = url.contains('tn_index_id');
    if (prev != _available) notifyListeners();
  }

  Future<void> insertCur(String info) async {
    if (_curMed.numOfDays > 0 && _scheduleList.length > 0) {
      for (int i = 0; i < _curMed.numOfDays; i++) {
        for (Schedule schedule in _scheduleList) {
          Schedule newSchedule = Schedule(
              url: _curMed.url,
              scheduledAt: _curMed.firstDate.add(Duration(
                  hours: schedule.scheduledAt.hour,
                  minutes: schedule.scheduledAt.minute,
                  days: i)));
          await _db.insertSchedule(newSchedule).then((int i) async {
            await scheduleNotification(newSchedule, _curMed.name, i);
          });
        }
      }
      _scheduleList.clear();
    }
    if (info != null) {
      _curMed.info = info;
    }
    _medicineList =
        await _db.insertMedicine(_curMed).then((_) => _db.getAllMedicine());
    notifyListeners();
  }

  Future<void> deleteMed(Medicine med) async {
    final schedules = await _db.deleteMedicine(med);
    if (schedules.length > 0) {
      await cancelNotification(schedules);
    }
    _medicineList =
        await _db.deleteMedicine(med).then((_) => _db.getAllMedicine());
    notifyListeners();
  }

  void onDatePicked(List<DateTime> dates) {
    if (dates != null) {
      if (dates[0].hour != 0 || dates[0].minute != 0) {
        _curMed.firstDate = DateTime.fromMillisecondsSinceEpoch(dates[0]
                .millisecondsSinceEpoch -
            dates[0].millisecondsSinceEpoch % Duration(days: 1).inMilliseconds -
            Duration(hours: 3).inMilliseconds);
      } else {
        _curMed.firstDate = dates[0];
      }
      _curMed.numOfDays = dates[1].difference(_curMed.firstDate).inDays + 1;
      notifyListeners();
    }
  }

  void onSliderChanged(double newVal) {
    _curMed.numPerDay = newVal;
    List<Schedule> newList = [];
    for (int i = 0; i < newVal; i++) {
      newList.add(Schedule(url: _curMed.url, scheduledAt: DateTime.utc(2019)));
    }
    if (_scheduleList != newList) {
      _scheduleList.clear();
      _scheduleList = newList;
      notifyListeners();
    }
  }

  void onTimePicked(Schedule schedule, TimeOfDay newTime) {
    int index = _scheduleList.indexOf(schedule);
    _scheduleList[index].scheduledAt =
        DateTime.utc(2019, 1, 1, newTime.hour, newTime.minute);
    notifyListeners();
  }

  Future<List<Schedule>> getSchedules(Medicine med, int index) async {
    final date = med.firstDate.add(Duration(days: index));
    List<Schedule> list = await _db.getScheduleByDay(date, med);
    return list;
  }

  Future<void> scheduleDone(Schedule schedule) async {
    schedule.done = true;
    await _db.updateSchedule(schedule);
  }

  Future<List<Schedule>> getScheduleList(medicine) async {
    return _db.getScheduleByMedicine(medicine);
  }

  Future<void> updateInfo(String str) async {
    _curMed.info = str;
    await _db.updateMedicine(_curMed);
    notifyListeners();
  }

  Future<void> answerThePayback(String name) async {
    await _db.getMedicineByName(name).then((med) => setCureMed(med));
  }

  Future<void> scheduleNotification(
      Schedule schedule, String name, int id) async {
    var scheduledNotificationDateTime = schedule.scheduledAt;
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'channel id', 'channel name', 'channel description',
        importance: Importance.Max, priority: Priority.High);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    NotificationDetails platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.schedule(
        id,
        '$name',
        '${timeFormat(schedule)} - Время для приема лекарства',
        scheduledNotificationDateTime,
        platformChannelSpecifics,
        payload: name,
        androidAllowWhileIdle: true);
  }

  Future<void> cancelNotification(List<Schedule> schedules) async {
    schedules.forEach((Schedule schedule) async {
      await _flutterLocalNotificationsPlugin.cancel(schedule.id);
    });
  }
}

String timeFormat(Schedule schedule) {
  String hour =
      '${schedule.scheduledAt.hour < 10 ? '0' + schedule.scheduledAt.hour.toString() : schedule.scheduledAt.hour}';
  String minute =
      '${schedule.scheduledAt.minute < 10 ? '0' + schedule.scheduledAt.minute.toString() : schedule.scheduledAt.minute}';
  return '$hour:$minute';
}
