import 'package:be_healthy/src/database.dart';
import 'package:be_healthy/src/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

class MedPage extends StatefulWidget {
  final String name;

  MedPage({this.name});

  @override
  _MedPageState createState() => _MedPageState();
}

class _MedPageState extends State<MedPage> {
  @override
  Widget build(BuildContext context) {
    final _dm = Provider.of<DataModel>(context);
    if (widget.name != 'not a notification') {
      return FutureBuilder(
          future: _dm.answerThePayback(widget.name),
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                _dm.curMed != null) {
              return _body(context);
            } else {
              return Scaffold(
                  body: Center(
                child: CircularProgressIndicator(),
              ));
            }
          });
    } else {
      return _body(context);
    }
  }

  Widget _body(BuildContext context) {
    final _dm = Provider.of<DataModel>(context);
    return Scaffold(
        body: SingleChildScrollView(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Container(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverAppBar(
                      title: Text(_dm.curMed.name),
                      floating: true,
                      expandedHeight: 50.0,
                    ),
                    SliverList(
                        delegate: SliverChildListDelegate([
                      Column(
                        children: <Widget>[
                          SizedBox(height: 25.0),
                          Text('Прогресс:'),
                          SizedBox(height: 15.0),
                          LinearPercentIndicator(
                            alignment: MainAxisAlignment.center,
                            width: MediaQuery.of(context).size.width - 50,
                            animation: true,
                            lineHeight: 20.0,
                            animationDuration: 1500,
                            percent: _dm.scheduleList
                                    .where((e) => e.done == true)
                                    .length /
                                _dm.scheduleList.length,
                            center: Text(
                                '${(_dm.scheduleList.where((e) => e.done == true).length / _dm.scheduleList.length * 100).toStringAsFixed(2)}%'),
                            linearStrokeCap: LinearStrokeCap.roundAll,
                            progressColor: Colors.green,
                          ),
                          SizedBox(height: 30.0),
                          Text(
                              'Осталось ещё приемов: ${_dm.scheduleList.where((e) => e.done != true).length}'),
                          SizedBox(height: 30.0),
                          Text('Заметки:'),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                                controller: TextEditingController(
                                    text: _dm.curMed.info == null
                                        ? ''
                                        : _dm.curMed.info),
                                textInputAction: TextInputAction.done,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                    border: OutlineInputBorder()),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                maxLength: 255,
                                maxLines: null,
                                onSubmitted: (str) => _dm.updateInfo(str)),
                          )
                        ],
                      )
                    ])),
                  ],
                ),
                height: (MediaQuery.of(context).size.height) / 2),
            Container(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverList(
                        delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _tile(context, _dm.scheduleList[index]),
                            childCount: _dm.scheduleList.length))
                  ],
                ),
                height: (MediaQuery.of(context).size.height) / 2)
          ]),
    ));
  }

  Widget _tile(BuildContext context, Schedule schedule) {
    final _dm = Provider.of<DataModel>(context);
    return ListTile(
      title: Text(
        '${schedule.scheduledAt.day} ${_dm.rusMonths[schedule.scheduledAt.month - 1]} ${timeFormat(schedule)}',
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
                  await _dm.scheduleDone(schedule);
                  setState(() {});
                }),
    );
  }
}
