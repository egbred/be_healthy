import 'dart:async';
import 'package:be_healthy/src/database.dart';
import 'package:be_healthy/src/medicine_page.dart';
import 'package:be_healthy/src/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:be_healthy/src/settings.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_notification');
  var initializationSettingsIOS = IOSInitializationSettings();
  var initializationSettings = InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    selectNotificationSubject.add(payload);
  });
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(
        create: (_) => DataModel(flutterLocalNotificationsPlugin))
  ], child: MaterialApp(home: MyApp())));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Не забудь про лекарство',
      routes: {
        '/': (context) => MyHomePage(),
        '/settings': (context) => SettingsScreen(),
        '/medicine': (context) => MedPage(name: 'not a notification'),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    selectNotificationSubject.stream.listen((String payload) async {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => MedPage(name: payload)));
    });
  }

  @override
  void dispose() {
    selectNotificationSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dm = Provider.of<DataModel>(context);
    return Scaffold(
        appBar: AppBar(
          title: Text('Список лекарств'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewChooser(),
                    ));
              },
            )
          ],
        ),
        body: Builder(builder: (BuildContext context) {
          if (dm.medicineList.length > 0) {
            return ListView(children: _body(dm.medicineList));
          } else {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Добавь свое первое лекарство, нажав на иконку (+)',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Lora', fontSize: 18.0),
              ),
            ));
          }
        }));
  }

  List<ExpansionTile> _body(List<Medicine> meds) {
    final dm = Provider.of<DataModel>(context);
    return meds
        .map((med) => ExpansionTile(
              key: Key(med.name),
              title: Text(
                med.name,
                style: TextStyle(fontFamily: 'Lora', fontSize: 18.0),
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          dm.deleteMed(med);
                        },
                      ),
                      SizedBox(
                        width: 10.0,
                      ),
                      IconButton(
                          icon: Icon(Icons.info_outline),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      MedicineWebPage(med.url, med.name)))),
                      SizedBox(
                        width: 10.0,
                      ),
                      IconButton(
                          icon: Icon(Icons.storage),
                          onPressed: () async {
                            dm.setCureMed(med).then((_) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        MedPage(name: 'not a notification'))));
                          })
                    ],
                  ),
                ),
                SizedBox(
                  height: 250.0,
                  child: PageView.builder(
                      itemBuilder: (BuildContext context, int index) =>
                          FutureBuilder(
                            future: dm.getSchedules(med, index),
                            builder:
                                (BuildContext context, AsyncSnapshot snapshot) {
                              if (snapshot.hasData) {
                                List<Schedule> scheduleList = snapshot.data;
                                return Column(
                                  children: <Widget>[
                                    Text(
                                        '${scheduleList[0].scheduledAt.day} ${dm.rusMonths[scheduleList[0].scheduledAt.month - 1]}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16.0)),
//                                    SizedBox(height: 15.0),
                                    SizedBox(
                                        height: 200.0,
                                        child: ListView(
                                            children: scheduleList
                                                .map((schedule) =>
                                                    _schedule(schedule))
                                                .toList())),
                                  ],
                                );
                              } else {
                                return Center(
                                    child: CircularProgressIndicator());
                              }
                            },
                          ),
                      itemCount: med.numOfDays,
                      controller: _pageController),
                ),
              ],
            ))
        .toList();
  }

  Widget _schedule(Schedule schedule) {
    final dm = Provider.of<DataModel>(context);
    return ListTile(
      title: Text(
        timeFormat(schedule),
        style: TextStyle(
            fontStyle: schedule.done ? FontStyle.italic : null,
            color: schedule.done ? Colors.grey : null,
            decoration: schedule.done ? TextDecoration.lineThrough : null),
      ),
      trailing: Checkbox(
          value: schedule.done,
          onChanged: schedule.done == true
              ? null
              : (_) async {
                  await dm.scheduleDone(schedule);
                  setState(() {});
                }),
    );
  }
}

class WebViewChooser extends StatefulWidget {
  @override
  _WebViewChooserState createState() => _WebViewChooserState();
}

class _WebViewChooserState extends State<WebViewChooser> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбери лекарство'),
      ),
      body: Builder(builder: (BuildContext context) {
        return WebView(
            initialUrl: 'https://pda.rlsnet.ru/',
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (WebViewController webViewController) {
              _controller.complete(webViewController);
            },
            onPageFinished: (url) {
              Provider.of<DataModel>(context).checkURL(url);
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            });
      }),
      floatingActionButton: favoriteButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget favoriteButton() {
    final dm = Provider.of<DataModel>(context);
    return FutureBuilder<WebViewController>(
        future: _controller.future,
        builder: (BuildContext context,
            AsyncSnapshot<WebViewController> controller) {
          if (controller.hasData) {
            return RaisedButton(
              disabledColor: Colors.white54,
              color: Colors.green,
              elevation: 10.0,
              textColor: Colors.white,
              onPressed: (!dm.available)
                  ? null
                  : () async {
                      final url = await controller.data.currentUrl();
                      final name = await controller.data.getTitle().then(
                          (val) => val.substring(
                              0,
                              val.contains('- инструкция')
                                  ? val.indexOf(' - инструкция')
                                  : val.indexOf(' инструкция') - 2));
                      dm.setCureMed(Medicine(url: url, name: name)).then((_) =>
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SettingsScreen())));
                    },
              child: Text('ВЫБРАТЬ'),
            );
          } else {
            return Container();
          }
        });
  }
}

class MedicineWebPage extends StatelessWidget {
  MedicineWebPage(this.url, this.name);

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: WebView(
        initialUrl: url,
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}
