import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Medicine {
  final int id;
  final String name;
  final String url;
  String info;
  int numOfDays;
  double numPerDay;
  DateTime firstDate;

  Medicine(
      {this.name,
      this.id,
      this.url,
      this.numOfDays,
      this.numPerDay = 0.0,
      this.firstDate,
      this.info});

  Map<String, dynamic> toMap() => {
        'name': name,
        'id': id,
        'url': url,
        'info': info,
        'numOfDays': numOfDays,
        'numPerDay': numPerDay.toInt(),
        'firstDate': firstDate.millisecondsSinceEpoch
      };

  Medicine.fromMap(Map<String, dynamic> map)
      : id = map['id'],
        numOfDays = map['numOfDays'],
        numPerDay = double.parse(map['numPerDay'].toString()),
        name = map['name'],
        url = map['url'],
        info = map['info'],
        firstDate = DateTime.fromMillisecondsSinceEpoch(map['firstDate']);
}

class Schedule {
  final int id;
  final String url;
  bool done;
  DateTime scheduledAt;

  Schedule({this.id, this.done = false, this.url, this.scheduledAt});

  Map<String, dynamic> toMap() => {
        'done': done == true ? 1 : 0,
        'id': id,
        'url': url.substring(22),
        'scheduledAt': scheduledAt.millisecondsSinceEpoch
      };

  Schedule.fromMap(Map<String, dynamic> map)
      : id = map['id'],
        done = map['done'] == 1,
        url = 'https://pda.rlsnet.ru/' + map['url'],
        scheduledAt = DateTime.fromMillisecondsSinceEpoch(map['scheduledAt']);
}

class DBHelper {
  static const DbFileName = 'sqflite_bh.db';
  static const DbMedicineTableName = 'medicine_tbl';
  static const DbScheduleTableName = 'schedule_tbl';
  Database db;

  Future<void> initDb() async {
    final dbFolder = await getDatabasesPath();
    if (!await Directory(dbFolder).exists()) {
      await Directory(dbFolder).create(recursive: true);
    }
    final dbPath = join(dbFolder, DbFileName);
    db = await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
      CREATE TABLE $DbMedicineTableName (
        id INTEGER PRIMARY KEY autoincrement,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        info TEXT,
        numOfDays INTEGER,
        numPerDay INTEGER,
        firstDate INTEGER)
      ''');
      await db.execute('''
      CREATE TABLE $DbScheduleTableName (
        id INTEGER PRIMARY KEY autoincrement,
        done INTEGER NOT NULL,
        url TEXT NOT NULL,
        scheduledAt INTEGER NOT NULL)
      ''');
    });
  }

  Future<void> insertMedicine(Medicine medicine) async {
    await db.insert(DbMedicineTableName, medicine.toMap());
  }

  Future<int> insertSchedule(Schedule schedule) async {
    return db.insert(DbScheduleTableName, schedule.toMap());
  }

  Future<List<Medicine>> getAllMedicine() async {
    List<Map> items = await db.query(DbMedicineTableName);
    return items.map((item) => Medicine.fromMap(item)).toList();
  }

  Future<List<Schedule>> getScheduleByMedicine(Medicine med) async {
    List<Map> items = await db.query(DbScheduleTableName,
        where: 'url = ?',
        orderBy: 'scheduledAt',
        whereArgs: [med.url.substring(22)]);
    if (items != null) {
      return items.map((item) => Schedule.fromMap(item)).toList();
    }
    return null;
  }

  Future<List<Schedule>> getScheduleByDay(DateTime date, Medicine med) async {
    int _firstDate = date.millisecondsSinceEpoch;
    int _lastDate = _firstDate + Duration(days: 1).inMilliseconds;
    List<Map> items = await db.query(DbScheduleTableName,
        where:
            'scheduledAt >= $_firstDate AND scheduledAt < $_lastDate AND url = ?',
        orderBy: 'scheduledAt',
        whereArgs: [med.url.substring(22)]);
    if (items.length > 0) {
      return items.map((item) => Schedule.fromMap(item)).toList();
    }
    return null;
  }

  Future<Medicine> getMedicineByName(String name) async {
    List<Map> items = await db
        .query(DbMedicineTableName, where: 'name = ?', whereArgs: [name]);
    if (items.length == 1) {
      return Medicine.fromMap(items[0]);
    }
    return null;
  }

  Future<void> deleteSchedulesByMedicine(Medicine medicine) async {
    await db.delete(DbScheduleTableName,
        where: 'url = ?', whereArgs: [medicine.url.substring(22)]);
  }

  Future<List<Schedule>> deleteMedicine(Medicine medicine) async {
    List<Schedule> schedules = await getScheduleByMedicine(medicine);
    if (schedules.length > 0) {
      await deleteSchedulesByMedicine(medicine);
    }
    await db.delete(DbMedicineTableName, where: 'id = ${medicine.id}');
    return schedules;
  }

  Future<void> updateMedicine(Medicine medicine) async {
    await db.update(DbMedicineTableName, medicine.toMap(),
        where: 'id = ${medicine.id}');
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await db.update(DbScheduleTableName, schedule.toMap(),
        where: 'id = ${schedule.id}');
  }

  Future close() async => db.close();
}
