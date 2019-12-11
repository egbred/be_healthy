import 'package:be_healthy/src/provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:date_range_picker/date_range_picker.dart' as DateRangePicker;

class SettingsScreen extends StatefulWidget {
  SettingsScreen({Key key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController _controller = TextEditingController();

  int _currentStep = 0;

  void _onStepCancel() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  void _onStepContinue() {
    if (_currentStep <= 3) {
      setState(() {
        _currentStep += 1;
      });
    } else {
      Provider.of<DataModel>(context)
          .insertCur(_controller.text)
          .then((_) => Navigator.popUntil(context, ModalRoute.withName('/')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dm = Provider.of<DataModel>(context);
    return Material(
      child: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          steps: <Step>[
            Step(
              isActive: _currentStep >= 0,
              state: _currentStep == 0
                  ? StepState.editing
                  : (_currentStep > 0 ? StepState.complete : StepState.disabled),
              title: Text('Подтвердить'),
              content: Builder(
                  builder: (context) => Center(
                          child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'Вы выбрали ${dm.curMed.name}, так?',
                          style: TextStyle(fontFamily: 'Lora'),
                        ),
                      ))),
            ),
            Step(
              isActive: _currentStep >= 1,
              title: Text('Заданный период'),
              content: Builder(builder: (BuildContext context) {
                if (dm.curMed.firstDate == null) {
                  return Center(
                      child: RaisedButton(
                          child: Text('Выбрать дату'),
                          onPressed: () async {
                            DateRangePicker.showDatePicker(
                                    context: context,
                                    initialFirstDate: DateTime.now(),
                                    initialLastDate:
                                        DateTime.now().add(Duration(days: 3)),
                                    firstDate: DateTime(2018),
                                    lastDate:
                                        DateTime.now().add(Duration(days: 90)))
                                .then((dates) => dm.onDatePicked(dates));
                          }));
                } else {
                  final _firstDate =
                      '${dm.curMed.firstDate.day} ${dm.rusMonths[dm.curMed.firstDate.month - 1]}';
                  final _lastDate =
                      '${dm.curMed.firstDate.add(Duration(days: dm.curMed.numOfDays - 1)).day} ${dm.rusMonths[dm.curMed.firstDate.add(Duration(days: dm.curMed.numOfDays)).month - 1]}';
                  return Column(
                    children: <Widget>[
                      Text('Запланированный прием лекарства:\n'
                          ' c $_firstDate по $_lastDate'),
                      SizedBox(height: 50.0),
                      RaisedButton(
                          child: Text('Изменить'),
                          onPressed: () async {
                            DateRangePicker.showDatePicker(
                                    context: context,
                                    initialFirstDate: DateTime.now(),
                                    initialLastDate:
                                        DateTime.now().add(Duration(days: 3)),
                                    firstDate: DateTime(2018),
                                    lastDate:
                                        DateTime.now().add(Duration(days: 90)))
                                .then((dates) => dm.onDatePicked(dates));
                          }),
                      SizedBox(height: 50.0),
                    ],
                  );
                }
              }),
              state: _currentStep == 1
                  ? StepState.editing
                  : (_currentStep > 1 ? StepState.complete : StepState.disabled),
            ),
            Step(
              isActive: _currentStep >= 2,
              title: Text('Количество приемов в день'),
              content: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: Slider(
                    value: dm.curMed.numPerDay,
                    divisions: 5,
                    min: 0.0,
                    max: 5.0,
                    onChanged: (val) {
                      if (val != dm.curMed.numPerDay) {
                        dm.onSliderChanged(val);
                      }
                    },
                    label: '${dm.curMed.numPerDay.round()}',
                  ),
                ),
              ),
              state: _currentStep == 2
                  ? StepState.editing
                  : (_currentStep > 2 ? StepState.complete : StepState.disabled),
            ),
            Step(
              isActive: _currentStep >= 3,
              title: Text('Время напоминаний'),
              content: Builder(
                builder: (BuildContext context) {
                  if (dm.scheduleList.length > 0) {
                    return _timeWidget(context);
                  } else {
                    return Center(child: Text('Прием лекарства не запланирован'));
                  }
                },
              ),
              state: _currentStep == 3
                  ? StepState.editing
                  : (_currentStep > 3 ? StepState.complete : StepState.disabled),
            ),
            Step(
              isActive: _currentStep >= 4,
              title: Text('Заметки'),
              subtitle: Text('(не обязательно)'),
              content: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                      border: OutlineInputBorder()),
                  textCapitalization:
                  TextCapitalization.sentences,
                  maxLength: 255,
                  maxLines: null),
              state: _currentStep == 4
                  ? StepState.editing
                  : (_currentStep > 4 ? StepState.complete : StepState.disabled),
            ),
          ],
          controlsBuilder: (BuildContext context,
              {VoidCallback onStepContinue, VoidCallback onStepCancel}) {
            if (_currentStep == 4) {
              return ButtonBar(
                alignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  RaisedButton(
                    color: Colors.green[400],
                    textColor: Colors.white,
                    onPressed: _onStepContinue,
                    child: Text('ДОБАВИТЬ'),
                  ),
                  FlatButton(
                    onPressed: _onStepCancel,
                    child: Text('ОТМЕНА'),
                  ),
                ],
              );
            } else if (_currentStep == 1) {
              return ButtonBar(
                alignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  RaisedButton(
                    color: dm.curMed.firstDate == null ? null : Colors.lightBlue,
                    textColor: dm.curMed.firstDate == null ? null : Colors.white,
                    onPressed:
                        dm.curMed.firstDate == null ? null : _onStepContinue,
                    child: const Text('ПРОДОЛЖИТЬ'),
                  ),
                  FlatButton(
                    onPressed: _onStepCancel,
                    child: const Text('ОТМЕНА'),
                  ),
                ],
              );
            } else {
              return ButtonBar(
                alignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  RaisedButton(
                    color: Colors.lightBlue,
                    textColor: Colors.white,
                    onPressed: _onStepContinue,
                    child: const Text('ПРОДОЛЖИТЬ'),
                  ),
                  FlatButton(
                    onPressed: _onStepCancel,
                    child: const Text('ОТМЕНА'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _timeWidget(BuildContext context) {
    final dm = Provider.of<DataModel>(context);
    return Wrap(
        runSpacing: 16.0,
        spacing: 16.0,
        children: dm.scheduleList
            .map((schedule) => ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  child: Container(
                    padding: EdgeInsets.only(left: 10.0),
                    color: Colors.lightBlue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${schedule.scheduledAt.hour < 10 ? '0' + schedule.scheduledAt.hour.toString() : schedule.scheduledAt.hour}:${schedule.scheduledAt.minute < 10 ? '0' + schedule.scheduledAt.minute.toString() : schedule.scheduledAt.minute}',
                          style: TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          color: Colors.white,
                          icon: Icon(Icons.schedule),
                          onPressed: () async {
                            showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                        schedule.scheduledAt))
                                .then((time) =>
                                    {dm.onTimePicked(schedule, time)});
                          },
                        )
                      ],
                    ),
                  ),
                ))
            .toList());
  }
}
