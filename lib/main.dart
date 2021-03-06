import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cfm_feedback/ImageUtils.dart';
import 'package:cfm_feedback/MorePage.dart';
import 'package:cfm_feedback/PermissionUtils.dart';
import 'package:cfm_feedback/StatisticsPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:saf/saf.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:merge_images/merge_images.dart';

// import 'MyWebView.dart';

void main() async {
  // Avoid errors caused by flutter upgrade.
// Importing 'package:flutter/widgets.dart' is required.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // WidgetsFlutterBinding.ensureInitialized();
// Open the database and store the reference.
  final database = openDatabase(
    // Set the path to the database. Note: Using the `join` function from the
    // `path` package is best practice to ensure the path is correctly
    // constructed for each platform.
    join(await getDatabasesPath(), 'mission_database.db'),
    // When the database is first created, create a table to store dogs.
    onCreate: (db, version) {
      // Run the CREATE TABLE statement on the database.
      return db.execute(
        'CREATE TABLE missions(id INTEGER PRIMARY KEY, name TEXT, content TEXT, pay INTEGER, version TEXT, isFinished INTEGER, deadline TEXT, claim TEXT, url TEXT)',
      );
    },
    // Set the version. This executes the onCreate function and provides a
    // path to perform database upgrades and downgrades.
    version: 3,
  );
  Globals.database = database;
  runApp(MyApp());
}

class Globals {
  static late final database;
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CFM????????????',
      theme: ThemeData(
        //primarySwatch: Colors.orange,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'CFM??????????????????'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('zh', 'CN'),
      ],
    );
  }
}

enum netWorkState {
  Mobile4G,
  Unicom4G,
  Dianxin4G,
  Mobile5G,
  Unicom5G,
  Dianxin5G,
  Wifi
}

class Mission {
  int id;
  String name;
  String content;
  int pay;
  String version;
  bool isFinished;
  String claim;
  String deadline;
  String url;

  Mission({
    required this.id,
    required this.name,
    required this.content,
    required this.pay,
    required this.version,
    required this.isFinished,
    required this.claim,
    required this.deadline,
    required this.url,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'pay': pay,
      'version': version,
      'isFinished': isFinished ? 1 : 0,
      'claim': claim,
      'deadline': deadline,
      'url': url,
    };
  }

  static Mission fromJson(Map jsonstr) {
    return Mission(
        id: jsonstr["id"],
        name: jsonstr["name"],
        content: jsonstr["content"],
        pay: jsonstr["pay"],
        version: jsonstr["version"],
        isFinished: jsonstr["isFinished"],
        claim: jsonstr["claim"],
        deadline: jsonstr["deadline"],
        url: jsonstr["url"]);
  }

  @override
  String toString() {
    return 'Mission{id: $id, name: $name, content: $content, pay: $pay}';
  }

  // Map toJson() {
  //   Map map = new Map();
  //   map["id"] = this.id;
  //   map["name"] = this.name;
  //   map["content"] = this.content;
  //   map["pay"] = this.pay;
  //   map["version"] = this.version;
  //   map["isFinished"] = this.isFinished;
  //   map["claim"] = this.claim;
  //   map["deadline"] = this.deadline;
  //   map["url"] = this.url;
  //   return map;
  // }

  String toJson() {
    return "{\"id\": $id, \"name\": \"$name\", \"content\": \"$content\", \"pay\": $pay, \"version\": \"$version\", \"isFinished\": $isFinished, \"claim\": \"$claim\", \"deadline\": \"$deadline\", \"url\": \"$url\"}";
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _serverValue = "?????????";
  var _nameValueController = TextEditingController();
  String? _nameError;
  var _qqValueController = TextEditingController();
  String? _qqError;
  var _netWorkValueController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  var _dateValueController = TextEditingController();
  var _phoneValueController = TextEditingController();
  String? _phoneError;
  String _bugValue = "??????BUG";
  String _modeValue = "PVP";
  String _degreeValue = "??????";
  var _descriptionController = TextEditingController();
  String? _descriptionError;
  String _appearValue = "??????";
  var _stepController = TextEditingController();
  String? _stepError;
  var _positionController = TextEditingController();
  String? _positionError;
  var _videoValueController = TextEditingController();
  var _logValueController = TextEditingController();

  int currentIndex = 0;
  List<Mission> missions = [];
  String version = "";
  List<String> versions = [];

  bool isSubscribed = false;
  late DateTime subscribeTime;
  String subscribeURL = "";

  Future<Null> _selectDate(
      BuildContext context, TextEditingController textEditingController,
      {bool format = false}) async {
    DateTime? _datePicker = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2030),
    );
    TimeOfDay? _timePicker = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (_datePicker != null && _timePicker != null) {
      setState(() {
        _date = _datePicker;
        _time = _timePicker;
        if (format) {
          String str = DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          ).toString();
          textEditingController.text = str.substring(0, str.length - 7);
        } else {
          textEditingController.text =
              "${_date.year}???${_date.month}???${_date.day}??? ${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}";
        }
      });
    }
  }

  var _missionNameController = TextEditingController();
  var _missionContentController = TextEditingController();
  var _missionPayController = TextEditingController();
  var _missionClaimController = TextEditingController();
  var _missionDeadlineController = TextEditingController();
  var _missionUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    FlutterNativeSplash.remove();
    PermissionUtils.requestStoragePermission();
    createCFM();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: IndexedStack(
          index: currentIndex,
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(widget.title),
                centerTitle: true,
                actions: [
                  IconButton(
                    onPressed: () {
                      showAboutDialog(
                        context: context,
                        applicationName: "M????????????",
                        applicationVersion: "2.0.1",
                        applicationLegalese: "@Rlin",
                        applicationIcon: Image.asset(
                          "assets/cf_icon.png",
                          height: 80,
                          width: 80,
                        ),
                      );
                    },
                    icon: Icon(Icons.info_outline),
                  )
                ],
              ),
              body: Center(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "?????????M???????????????????????????",
                            style: GoogleFonts.maShanZheng(
                              textStyle: TextStyle(
                                color: Colors.red,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "?????????/?????????",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Radio(
                          value: "?????????",
                          groupValue: _serverValue,
                          onChanged: (value) {
                            setState(() {
                              _serverValue = value.toString();
                            });
                          },
                        ),
                        Text("?????????"),
                        Radio(
                          value: "?????????",
                          groupValue: _serverValue,
                          onChanged: (value) {
                            setState(() {
                              _serverValue = value.toString();
                            });
                          },
                        ),
                        Text("?????????"),
                        Radio(
                          value: "?????????",
                          groupValue: _serverValue,
                          onChanged: (value) {
                            setState(() {
                              _serverValue = value.toString();
                            });
                          },
                        ),
                        Text("?????????"),
                      ],
                    ),
                    Divider(),
                    //?????????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _nameValueController,
                        onChanged: (v) {
                          if (_nameError != checkEmpty(v)) {
                            setState(() {
                              _nameError = checkEmpty(v);
                            });
                          }
                          _saveName();
                        },
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "M??????????????????",
                          labelText: "?????????",
                          border: OutlineInputBorder(),
                          errorText: _nameError,
                        ),
                      ),
                    ),
                    Divider(),
                    //QQ???
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _qqValueController,
                        onChanged: (v) {
                          if (_qqError != checkEmpty(v)) {
                            setState(() {
                              _qqError = checkEmpty(v);
                            });
                          }
                        },
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: "??????QQ???",
                          labelText: "QQ",
                          border: OutlineInputBorder(),
                          errorText: _qqError,
                        ),
                      ),
                    ),
                    Divider(),
                    //????????????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _netWorkValueController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "??????????????????",
                          labelText: "????????????",
                          border: OutlineInputBorder(),
                          suffixIcon: PopupMenuButton<netWorkState>(
                            onSelected: (v) {
                              switch (v) {
                                case netWorkState.Mobile4G:
                                  _netWorkValueController.text = "??????4G";
                                  break;
                                case netWorkState.Unicom4G:
                                  _netWorkValueController.text = "??????4G";
                                  break;
                                case netWorkState.Dianxin4G:
                                  _netWorkValueController.text = "??????4G";
                                  break;
                                case netWorkState.Mobile5G:
                                  _netWorkValueController.text = "??????5G";
                                  break;
                                case netWorkState.Unicom5G:
                                  _netWorkValueController.text = "??????5G";
                                  break;
                                case netWorkState.Dianxin5G:
                                  _netWorkValueController.text = "??????5G";
                                  break;
                                case netWorkState.Wifi:
                                  _netWorkValueController.text = "WiFi";
                                  break;
                                default:
                              }
                            },
                            icon: Icon(Icons.arrow_drop_down),
                            itemBuilder: (BuildContext context) {
                              return <PopupMenuEntry<netWorkState>>[
                                PopupMenuItem(
                                  child: Text("??????4G"),
                                  value: netWorkState.Mobile4G,
                                ),
                                PopupMenuItem(
                                  child: Text("??????4G"),
                                  value: netWorkState.Unicom4G,
                                ),
                                PopupMenuItem(
                                  child: Text("??????4G"),
                                  value: netWorkState.Dianxin4G,
                                ),
                                PopupMenuItem(
                                  child: Text("??????5G"),
                                  value: netWorkState.Mobile5G,
                                ),
                                PopupMenuItem(
                                  child: Text("??????5G"),
                                  value: netWorkState.Unicom5G,
                                ),
                                PopupMenuItem(
                                  child: Text("??????5G"),
                                  value: netWorkState.Dianxin5G,
                                ),
                                PopupMenuItem(
                                  child: Text("WiFi"),
                                  value: netWorkState.Wifi,
                                ),
                              ];
                            },
                          ),
                        ),
                      ),
                    ),
                    Divider(),
                    //??????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _dateValueController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "??????????????????",
                          labelText: "????????????",
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _selectDate(context, _dateValueController);
                              });
                            },
                            icon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                    Divider(),
                    //????????????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _phoneValueController,
                        onChanged: (v) {
                          if (_phoneError != checkEmpty(v)) {
                            setState(() {
                              _phoneError = checkEmpty(v);
                            });
                          }
                        },
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "????????????11",
                          labelText: "????????????",
                          errorText: _phoneError,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Divider(),
                    //BUG??????
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Bug??????",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Radio(
                          value: "??????BUG",
                          groupValue: _bugValue,
                          onChanged: (value) {
                            setState(() {
                              _bugValue = value.toString();
                            });
                          },
                        ),
                        Text("??????BUG"),
                        Radio(
                          value: "??????BUG",
                          groupValue: _bugValue,
                          onChanged: (value) {
                            setState(() {
                              _bugValue = value.toString();
                            });
                          },
                        ),
                        Text("??????BUG"),
                        Radio(
                          value: "??????BUG",
                          groupValue: _bugValue,
                          onChanged: (value) {
                            setState(() {
                              _bugValue = value.toString();
                            });
                          },
                        ),
                        Text("??????BUG"),
                      ],
                    ),
                    Divider(),
                    //BUG??????
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Bug??????",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Radio(
                          value: "PVP",
                          groupValue: _modeValue,
                          onChanged: (value) {
                            setState(() {
                              _modeValue = value.toString();
                            });
                          },
                        ),
                        Text("PVP"),
                        Radio(
                          value: "PVE",
                          groupValue: _modeValue,
                          onChanged: (value) {
                            setState(() {
                              _modeValue = value.toString();
                            });
                          },
                        ),
                        Text("PVE"),
                        Radio(
                          value: "??????",
                          groupValue: _modeValue,
                          onChanged: (value) {
                            setState(() {
                              _modeValue = value.toString();
                            });
                          },
                        ),
                        Text("??????"),
                      ],
                    ),
                    Divider(),
                    //BUG????????????
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Bug????????????",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Radio(
                        //   value: "?????????",
                        //   groupValue: _degreeValue,
                        //   onChanged: (value) {
                        //     setState(() {
                        //       _degreeValue = value.toString();
                        //     });
                        //   },
                        // ),
                        // Text("?????????"),
                        Radio(
                          value: "??????",
                          groupValue: _degreeValue,
                          onChanged: (value) {
                            setState(() {
                              _degreeValue = value.toString();
                            });
                          },
                        ),
                        Text("??????"),
                        Radio(
                          value: "??????",
                          groupValue: _degreeValue,
                          onChanged: (value) {
                            setState(() {
                              _degreeValue = value.toString();
                            });
                          },
                        ),
                        Text("??????"),
                        Radio(
                          value: "??????",
                          groupValue: _degreeValue,
                          onChanged: (value) {
                            setState(() {
                              _degreeValue = value.toString();
                            });
                          },
                        ),
                        Text("??????"),
                      ],
                    ),
                    Divider(),
                    //BUG????????????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _descriptionController,
                        onChanged: (v) {
                          if (_descriptionError != checkEmpty(v)) {
                            setState(() {
                              _descriptionError = checkEmpty(v);
                            });
                          }
                        },
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "?????????bug?????????????????????",
                          labelText: "BUG????????????",
                          errorText: _descriptionError,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Divider(),
                    //BUG????????????
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "BUG????????????",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Radio(
                          value: "??????",
                          groupValue: _appearValue,
                          onChanged: (value) {
                            setState(() {
                              _appearValue = value.toString();
                            });
                          },
                        ),
                        Text("??????"),
                        Radio(
                          value: "??????",
                          groupValue: _appearValue,
                          onChanged: (value) {
                            setState(() {
                              _appearValue = value.toString();
                            });
                          },
                        ),
                        Text("??????"),
                      ],
                    ),
                    Divider(),
                    //BUG????????????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _stepController,
                        onChanged: (v) {
                          if (_stepError != checkEmpty(v)) {
                            setState(() {
                              _stepError = checkEmpty(v);
                            });
                          }
                        },
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: _appearValue == "??????"
                              ? "????????????????????????"
                              : "?????????????????????????????????????????????",
                          labelText: "BUG????????????",
                          errorText: _stepError,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Divider(),
                    //BUG????????????
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _positionController,
                        onChanged: (v) {
                          if (_positionError != checkEmpty(v)) {
                            setState(() {
                              _positionError = checkEmpty(v);
                            });
                          }
                        },
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "BUG???????????????????????????,?????????bug?????????",
                          labelText: "BUG????????????",
                          errorText: _positionError,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Divider(),
                    //??????ID
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _videoValueController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "????????????BUG?????????????????????????????????",
                          labelText: "??????id",
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.input),
                            onPressed: () {
                              _videoValueController.text =
                                  "${_nameValueController.text} ${_time.hour.toString().padLeft(2, '0')}${_time.minute.toString().padLeft(2, '0')}.mp4";
                              _getVideo(_videoValueController.text, context);
                            },
                          ),
                        ),
                      ),
                    ),
                    Divider(),
                    //LogID
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        minLines: 1,
                        maxLines: 3,
                        controller: _logValueController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: "??????Log????????????????????????",
                          labelText: "Log id",
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.input),
                            onPressed: () {
                              _getLog(!_serverValue.contains("?????????"), context);
                            },
                          ),
                        ),
                      ),
                    ),
                    Divider(),
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: OutlinedButton(
                        onPressed: () {
                          _mergeImage("${_nameValueController.text} ${_time.hour.toString().padLeft(2, '0')}${_time.minute.toString().padLeft(2, '0')}",context);
                        },
                        child: Text("????????????"),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        elevation: 0,
                        child: Container(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "????????????????????????????????????????????????\n?????????????????????/Sdcard/DCIM/CFM\nLog????????????/Sdcard/CFM/log\n\tBy M?????????",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () async {
                  if (checkAllEmpty()) {
                    Fluttertoast.showToast(msg: "?????????????????????");
                    return;
                  }
                  if (_videoValueController.text == "")
                    _videoValueController.text = "???";
                  if (_logValueController.text == "")
                    _logValueController.text = "???";
                  _saveData();
                  String feedback = """$_serverValue
${_nameValueController.text}
${_qqValueController.text}
${_netWorkValueController.text}
${_dateValueController.text}
${_phoneValueController.text}
$_bugValue
$_modeValue
$_degreeValue
${_descriptionController.text}
$_appearValue
${_stepController.text}
${_positionController.text}
${_videoValueController.text}
${_logValueController.text}""";
                  Clipboard.setData(ClipboardData(text: feedback));
                  showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('?????????????????????'),
                      content: Text(feedback),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, '??????'),
                          child: const Text('??????'),
                        ),
                        TextButton(
                          onPressed: () async {
                            /*const url = 'tel';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        throw 'Could not launch $url';
                      }*/
                            Navigator.pop(context, '??????');
                          },
                          child: const Text('??????'),
                        ),
                      ],
                    ),
                  );
                },
                child: Icon(Icons.file_copy),
              ), // This trailing comma makes auto-formatting nicer for build methods.
            ),
            Scaffold(
              appBar: AppBar(
                title: GestureDetector(
                  child: Row(
                    children: [
                      Text(version + "????????????"),
                      Expanded(child: Icon(Icons.keyboard_arrow_down)),
                    ],
                  ),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return SimpleDialog(
                            children: versions
                                .map((e) => InkWell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 20),
                                        ),
                                      ),
                                      onTap: () async {
                                        version = e;
                                        missions = await getMissions(version);
                                        _saveData();
                                        setState(() {});
                                        Navigator.pop(context);
                                      },
                                    ))
                                .toList(),
                          );
                        });
                  },
                  onLongPress: () async {
                    HapticFeedback.vibrate();
                    var verDate = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2050),
                    );
                    if (verDate != null) {
                      String tempDate = "${verDate.year}???${verDate.month}???";
                      if (!versions.contains(tempDate)) {
                        setState(() {
                          versions.add(tempDate);
                        });
                        Fluttertoast.showToast(msg: "$tempDate?????????");
                        await _saveData();
                      } else {
                        Fluttertoast.showToast(msg: "$tempDate?????????");
                      }
                    }
                  },
                ),
                actions: [
                  Visibility(
                    child: IconButton(
                      tooltip: "????????????",
                      onPressed: () async {
                        Fluttertoast.showToast(msg: "???????????????...");
                        _printAllMission();
                        try {
                          int count = await _subscribe();
                          Fluttertoast.showToast(msg: "?????????$count?????????");
                          missions = await getMissions(version);
                          setState(() {});
                        } catch (e) {
                          Fluttertoast.showToast(msg: "????????????");
                        }
                      },
                      icon: Icon(Icons.cloud_download),
                    ),
                    visible: isSubscribed,
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return StatisticsPage(
                            missions, version, _nameValueController.text);
                      }));
                    },
                    icon: Icon(Icons.insert_chart),
                    tooltip: "????????????",
                  ),
                  IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            //_getClip();
                            return SimpleDialog(title: Text("????????????"), children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "1. ????????????\n\t\t??????????????????????????????????????????????????????????????????\n"),
                                        Text(
                                            "2. ????????????\n\t\t????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????\n"),
                                        Text("3. ????????????\n\t\t????????????????????????????????????????????????\n"),
                                      ],
                                    ),
                                    Text(
                                      "??????????????????????????????????????????????????????\n",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    Text(
                                      "By M??????",
                                      style: GoogleFonts.zhiMangXing(
                                        textStyle: TextStyle(
                                            color: Colors.grey, fontSize: 28),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          });
                    },
                    icon: Icon(Icons.help),
                    tooltip: "??????",
                  ),
                ],
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  missions = await getMissions(version);
                  setState(() {});
                },
                child: Scrollbar(
                  child: ListView.separated(
                    itemBuilder: (BuildContext context, int index) {
                      return Dismissible(
                        key: Key(index.toString()),
                        background: Container(
                          padding: EdgeInsets.only(right: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          color: Colors.orange[300],
                        ),
                        direction: DismissDirection.endToStart,
                        dismissThresholds: {DismissDirection.endToStart: 0.2},
                        confirmDismiss: (d) async {
                          return await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("????????????"),
                                  content: Text("???????????????????????????"),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text("??????")),
                                    TextButton(
                                        onPressed: () async {
                                          setState(() {
                                            deleteMission(missions[index].id);
                                            missions.removeAt(index);
                                          });
                                          Navigator.of(context).pop(true);
                                        },
                                        child: Text("??????")),
                                  ],
                                );
                              });
                          //return false;
                        },
                        onDismissed: (d) {
                          // setState(() {
                          //   missions[index].isFinished = !missions[index].isFinished;
                          // });
                          // ScaffoldMessenger.of(context)
                          //     .showSnackBar(SnackBar(content: Text('${missions[index].name} dismissed')));
                        },
                        child: ListTile(
                          leading: IconButton(
                            icon: missions[index].isFinished
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : Icon(Icons.radio_button_unchecked),
                            onPressed: () async {
                              setState(() {
                                missions[index].isFinished =
                                    !missions[index].isFinished;
                              });
                              await updateMission(missions[index]);
                            },
                          ),
                          title: Text(missions[index].name),
                          subtitle: Text(missions[index].deadline +
                              "\n" +
                              missions[index].content),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(missions[index].pay.toString()),
                            ],
                          ),
                          onTap: () {
                            showModalBottomSheet(
                              isScrollControlled: true,
                              context: context,
                              builder: (context) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: Text("????????????"),
                                      subtitle: Text(missions[index].name),
                                    ),
                                    ListTile(
                                      title: Text("????????????"),
                                      subtitle: Text(missions[index].content),
                                    ),
                                    ListTile(
                                      title: Text("????????????"),
                                      subtitle: Text(missions[index].claim),
                                    ),
                                    ListTile(
                                      title: Text("????????????"),
                                      subtitle:
                                          Text(missions[index].pay.toString()),
                                    ),
                                    ListTile(
                                      title: Text("????????????"),
                                      subtitle: Text(missions[index].deadline),
                                    ),
                                    ListTile(
                                      title: Text("????????????"),
                                      subtitle: Text(
                                        missions[index].url,
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                      onTap: () {
                                        launch(missions[index].url);
                                        // Navigator.push(context,
                                        //     MaterialPageRoute(builder: (context) {
                                        //   return MyWebView(
                                        //     selectedUrl: missions[index].url,
                                        //     title: missions[index].name,
                                        //   );
                                        // }));
                                      },
                                    ),
                                  ],
                                );
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                            );
                          },
                          onLongPress: () async {
                            setState(() {
                              missions[index].isFinished =
                                  !missions[index].isFinished;
                            });
                            await updateMission(missions[index]);
                            // showDialog(
                            //     context: context,
                            //     builder: (BuildContext context) {
                            //       return AlertDialog(
                            //         title: Text("????????????"),
                            //         content: Text("???????????????????????????"),
                            //         actions: [
                            //           TextButton(
                            //               onPressed: () => Navigator.pop(context),
                            //               child: Text("??????")),
                            //           TextButton(
                            //               onPressed: () async {
                            //                 setState(() {
                            //                   deleteMission(missions[index].id);
                            //                   missions.removeAt(index);
                            //                 });
                            //                 Navigator.pop(context);
                            //               },
                            //               child: Text("??????")),
                            //         ],
                            //       );
                            //     });
                          },
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(
                      height: 1,
                    ),
                    itemCount: missions.length,
                  ),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                child: Icon(Icons.add),
                onPressed: () async {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        _getClip();
                        return SimpleDialog(
                          title: Text("????????????"),
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 16.0, right: 16.0),
                              child: Container(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      size: 18,
                                    ),
                                    Text("  ???????????????????????????"),
                                  ],
                                ),
                                decoration: BoxDecoration(
                                  color: (Theme.of(context)
                                              .colorScheme
                                              .brightness !=
                                          Brightness.dark)
                                      ? Colors.orange[100]
                                      : Colors.black26,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8.0)),
                                ),
                                padding: EdgeInsets.all(8.0),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "??????????????????",
                                  labelText: "????????????/????????????",
                                ),
                                textInputAction: TextInputAction.next,
                                controller: _missionNameController,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "??????????????????",
                                  labelText: "????????????",
                                ),
                                textInputAction: TextInputAction.next,
                                controller: _missionContentController,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "??????????????????",
                                  labelText: "????????????",
                                ),
                                textInputAction: TextInputAction.next,
                                controller: _missionClaimController,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                decoration: InputDecoration(
                                    hintText: "????????????????????????",
                                    labelText: "??????????????????",
                                    suffix: IconButton(
                                      onPressed: () {
                                        _selectDate(
                                            context, _missionDeadlineController,
                                            format: true);
                                      },
                                      icon: Icon(Icons.calendar_today),
                                    )),
                                textInputAction: TextInputAction.next,
                                controller: _missionDeadlineController,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: "??????????????????",
                                  labelText: "????????????",
                                ),
                                textInputAction: TextInputAction.next,
                                controller: _missionPayController,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: "??????????????????",
                                  labelText: "????????????",
                                ),
                                textInputAction: TextInputAction.done,
                                controller: _missionUrlController,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                      onPressed: () async {
                                        if (_missionNameController
                                            .text.isEmpty) {
                                          Fluttertoast.showToast(msg: "??????????????????");
                                        } else {
                                          Response response;
                                          try {
                                            response = await Dio().get(
                                                'https://gitee.com/rlin1538/cfm_feedback_subscribe/raw/main/subscribe');
                                            //print(response);
                                            List<String> subscribe =
                                                response.toString().split('\n');
                                            for (int i = 0;
                                                i < subscribe.length;
                                                i++) {
                                              if (_missionNameController.text ==
                                                  subscribe[i]) {
                                                setState(() {
                                                  subscribeURL =
                                                      subscribe[i + 1];
                                                  isSubscribed = true;
                                                  subscribeTime =
                                                      DateTime.now();
                                                });
                                                await _saveData();
                                                await _subscribe();
                                                Fluttertoast.showToast(
                                                    msg:
                                                        "?????????${_missionNameController.text}?????????");
                                                print(subscribeURL);
                                                break;
                                              }
                                              if (i == subscribe.length - 1) {
                                                Fluttertoast.showToast(
                                                    msg: "??????????????????");
                                              }
                                            }
                                          } catch (e) {
                                            print(e);
                                            Fluttertoast.showToast(
                                                msg: "???????????????");
                                          }

                                          Navigator.pop(context);
                                        }
                                      },
                                      child: Text("??????")),
                                  TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text("??????")),
                                  TextButton(
                                      onPressed: () async {
                                        if (checkTextController()) {
                                          Fluttertoast.showToast(
                                              msg: "?????????????????????");
                                        } else {
                                          Mission m = Mission(
                                            id: _missionNameController
                                                .text.hashCode,
                                            name: _missionNameController.text,
                                            content:
                                                _missionContentController.text,
                                            pay: int.parse(
                                                _missionPayController.text),
                                            version: version,
                                            isFinished: false,
                                            url: _missionUrlController.text,
                                            deadline:
                                                _missionDeadlineController.text,
                                            claim: _missionClaimController.text,
                                          );
                                          if (!checkContainMission(m)) {
                                            missions.add(m);
                                            insertMission(m);
                                            Fluttertoast.showToast(
                                              msg: "????????????",
                                              toastLength: Toast.LENGTH_SHORT,
                                              gravity: ToastGravity.CENTER,
                                              timeInSecForIosWeb: 1,
                                              backgroundColor: Colors.red,
                                              textColor: Colors.white,
                                              fontSize: 16.0,
                                            );
                                            setState(() {});
                                          } else {
                                            Fluttertoast.showToast(
                                                msg: "${m.name}????????????");
                                          }

                                          Navigator.pop(context);
                                        }
                                      },
                                      child: Text("??????")),
                                ],
                              ),
                            )
                          ],
                        );
                      }).then((value) => setState(() {}));
                },
                heroTag: "other",
              ),
            ),
            MorePage(_nameValueController.text),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.feedback),
            label: "????????????",
          ),
          NavigationDestination(
            icon: Icon(Icons.table_rows),
            label: "????????????",
          ),
          NavigationDestination(
            icon: Icon(Icons.more),
            label: "????????????",
          ),
        ],
        height: 70,
      ),
    );
  }

  _getVideo(String videoName, BuildContext context) async {
    //createCFM();
    final List<AssetEntity>? result = await AssetPicker.pickAssets(context,
        pickerConfig: const AssetPickerConfig(
            maxAssets: 1, requestType: RequestType.video));
    (await result?.first.file)?.copy("/storage/emulated/0/DCIM/CFM/$videoName");
  }

  _getLog(bool isAlpha, BuildContext context) async {
    //createCFM();
    String logPath;
    if (isAlpha) {
      logPath = "Android/data/com.tencent.tmgp.cfalpha/cache/Cache/Log";
    } else {
      logPath = "Android/data/com.tencent.tmgp.cf/cache/Cache/Log";
    }
    Saf saf = Saf(logPath);

    bool? isGranted = await saf.getDirectoryPermission(isDynamic: false);
    if (isGranted != null && isGranted) {
      var cachedFilesPath = await saf.cache();
      if (cachedFilesPath != null) {
        await showDialog(
            context: context,
            builder: (context) {
              return SimpleDialog(
                title: Text("????????????log??????"),
                children: [
                  Container(
                    height: 400,
                    width: 300,
                    child: ListView.separated(
                        itemBuilder: (BuildContext context, int index) {
                          String title = cachedFilesPath[index].substring(
                              cachedFilesPath[index].lastIndexOf('/') + 1);
                          return ListTile(
                            title: Text(title),
                            onTap: () {
                              File file = File(cachedFilesPath[index]);
                              String logName =
                                  "${_nameValueController.text} ${_qqValueController.text} ${_descriptionController.text} $title";
                              file.copy("/storage/emulated/0/CFM/log/$logName");
                              _logValueController.text = logName;
                              Navigator.pop(context);
                            },
                          );
                        },
                        separatorBuilder: (BuildContext context, int i) =>
                            Divider(),
                        itemCount: cachedFilesPath.length),
                  )
                ],
              );
            });
      }
    } else {
      // failed to get the permission
      Fluttertoast.showToast(msg: "??????????????????");
    }
    saf.clearCache();
  }

  Future<void> createCFM() async {
    Directory cfm = Directory("/storage/emulated/0/CFM");
    if (!(await cfm.exists())) {
      cfm.create();
      Directory cfmLog = Directory("/storage/emulated/0/CFM/log");
      Directory cfmPicture = Directory("/storage/emulated/0/CFM/picture");
      cfmLog.create();
      cfmPicture.create();
    }
    Directory cfmVideo = Directory("/storage/emulated/0/DCIM/CFM");
    if (!(await cfmVideo.exists())) {
      cfmVideo.create();
    }
  }

  Future<int> _subscribe() async {
    int count = 0;
    Response response;
    print("??????????????????$subscribeURL");
    response = await Dio().get(
      subscribeURL,
    );
    //print("???????????????"+response.toString());
    List<dynamic> maps = json.decode(response.toString());

    List<Mission> lists = List.generate(maps.length, (i) {
      //print("???????????????${maps[i]["id"]}");
      return Mission(
        id: maps[i]['id'],
        name: maps[i]['name'],
        content: maps[i]['content'],
        pay: maps[i]['pay'],
        version: maps[i]['version'],
        isFinished: maps[i]['isFinished'],
        claim: maps[i]['claim'],
        url: maps[i]['url'],
        deadline: maps[i]['deadline'],
      );
    });
    for (Mission m in lists) {
      //print("??????????????????$m");
      if (await containMissions(m.id)) {
        continue;
      } else {
        missions.add(m);
        await insertMission(m);
        count++;
      }
    }

    return count;
  }

  _printAllMission() {
    String json = "";
    if (kDebugMode && missions.isNotEmpty) {
      for (Mission s in missions) {
        json = json + s.toJson() + ',';
        //print(s.toJson()+',');
      }
      json = json.substring(0, json.length - 1);
      json = '[' + json + ']';
      Clipboard.setData(ClipboardData(text: json));
      log(json);
    }
  }

  void _getClip() async {
    var s = await Clipboard.getData(Clipboard.kTextPlain);
    if (s != null) {
      if (s.text!.startsWith("????????????")) {
        _getFormat(s.text!);
      }
    }
  }

  _getFormat(String s) {
    List<String> strlist = s.split('\n');
    for (String str in strlist) {
      if (str.startsWith("????????????")) {
        _missionNameController.text = str.substring(str.indexOf('???') + 1);
      } else if (str.startsWith("????????????")) {
        _missionContentController.text = str.substring(str.indexOf('???') + 1);
      } else if (str.startsWith("??????????????????")) {
        _missionPayController.text = str.substring(str.indexOf('???') + 1);
      } else if (str.startsWith("????????????")) {
        _missionClaimController.text = str.substring(str.indexOf('???') + 1);
      } else if (str.startsWith("??????????????????")) {
        try {
          int YY, MM, DD, HH, Mi;
          List<String> strTime =
              str.substring(str.indexOf('???') + 1).split(RegExp(' |??'));
          //print(strTime);
          List<String> strDate = strTime[0].split('.');
          //print(strDate);
          YY = int.parse(strDate[0]);
          MM = int.parse(strDate[1]);
          DD = int.parse(strDate[2]);
          List<String> strT = strTime[strTime.length - 1].split(':');
          if (strT.length == 1) {
            strT = strTime[strTime.length - 1].split('???');
          }
          HH = int.parse(strT[0]);
          Mi = int.parse(strT[1]);
          var deadtime = DateTime(YY, MM, DD, HH, Mi);
          _missionDeadlineController.text =
              deadtime.toString().substring(0, deadtime.toString().length - 7);
        } catch (e) {
          Fluttertoast.showToast(msg: "????????????????????????????????????");
          print(e);
        }
      } else if (str.startsWith("????????????")) {
        _missionUrlController.text = str.substring(str.indexOf('???') + 1);
      }
    }
  }

  void _loadData() async {
    var prefs = await SharedPreferences.getInstance();
    if (prefs.getString("Name") != null) {
      _nameValueController.text = prefs.getString("Name").toString();
    } else {
      _nameValueController.text = "M????????????";
    }
    if (prefs.getString("QQ") != null) {
      _qqValueController.text = prefs.getString("QQ").toString();
      print(prefs.getString("QQ").toString());
    }
    if (prefs.getString("Phone") != null) {
      _phoneValueController.text = prefs.getString("Phone").toString();
    }
    _dateValueController.text =
        "${_date.year}???${_date.month}???${_date.day}??? ${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}";

    if (prefs.getString("Version") != null) {
      version = prefs.getString("Version").toString();
    }
    if (prefs.getStringList("Versions") != null) {
      versions = prefs.getStringList("Versions")!;
    } else {
      versions.add("${_date.year}???${_date.month}???");
      version = "${_date.year}???${_date.month}???";
    }

    missions = await getMissions(version);
    // if (mList.length >= 0) {
    //   missions = mList;
    // }
    if (prefs.getBool("isSubscribed") != null) {
      isSubscribed = prefs.getBool("isSubscribed")!;
    }
    if (prefs.getString("subscribeURL") != null) {
      subscribeURL = prefs.getString("subscribeURL")!;
    }
    if (isSubscribed) {
      try {
        print("??????????????????");
        int count = await _subscribe();
        Fluttertoast.showToast(msg: "?????????$count?????????");
        missions = await getMissions(version);
      } catch (e) {
        Fluttertoast.showToast(msg: "????????????");
      }
    }
  }

  _saveData() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setString("Name", _nameValueController.text);
    prefs.setString("QQ", _qqValueController.text);
    prefs.setString("Phone", _phoneValueController.text);
    prefs.setString("Version", version);
    prefs.setStringList("Versions", versions);
    prefs.setBool("isSubscribed", isSubscribed);
    prefs.setString("subscribeURL", subscribeURL);
  }

  _saveName() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setString("Name", _nameValueController.text);
  }

  bool checkContainMission(Mission m) {
    for (int i = 0; i < missions.length; i++) {
      if (m.id == missions[i].id) {
        return true;
      }
    }
    return false;
  }

  bool checkAllEmpty() {
    if (checkEmpty(_nameValueController.text) != null) {
      setState(() {
        _nameError = "?????????";
      });
      return true;
    }
    if (checkEmpty(_qqValueController.text) != null) {
      setState(() {
        _qqError = "?????????";
      });
      return true;
    }
    if (checkEmpty(_phoneValueController.text) != null) {
      setState(() {
        _phoneError = "?????????";
      });
      return true;
    }
    if (checkEmpty(_descriptionController.text) != null) {
      setState(() {
        _descriptionError = "?????????";
      });
      return true;
    }
    if (checkEmpty(_stepController.text) != null) {
      setState(() {
        _stepError = "?????????";
      });
      return true;
    }
    if (checkEmpty(_positionController.text) != null) {
      setState(() {
        _positionError = "?????????";
      });
      return true;
    }
    return false;
  }

  String? checkEmpty(String? text) {
    String? err;
    if (text == "")
      err = "?????????";
    else
      err = null;

    return err;
  }

  bool checkTextController() {
    bool err = false;
    if (_missionContentController.text.isEmpty) {
      err = true;
    }
    if (_missionNameController.text.isEmpty) {
      err = true;
    }
    if (_missionPayController.text.isEmpty) {
      err = true;
    }
    return err;
  }
  //????????????
  void _mergeImage(String imageName, BuildContext context) async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(context,
          pickerConfig: const AssetPickerConfig(
              maxAssets: 9, requestType: RequestType.image));
      if (result!=null) {
        await ImageUtils.mergeImage(result, imageName);
        Fluttertoast.showToast(msg: "????????????$imageName.png");
      }
    } catch (e) {
      print(e);
    }
  }
}

Future<void> insertMission(Mission m) async {
  // Get a reference to the database.
  final db = await Globals.database;

  // Insert the Dog into the correct table. You might also specify the
  // `conflictAlgorithm` to use in case the same dog is inserted twice.
  //
  // In this case, replace any previous data.
  await db.insert(
    'missions',
    m.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> updateMission(Mission m) async {
  // Get a reference to the database.
  final db = await Globals.database;

  // Insert the Dog into the correct table. You might also specify the
  // `conflictAlgorithm` to use in case the same dog is inserted twice.
  //
  // In this case, replace any previous data.
  await db.update(
    'missions',
    m.toMap(),
    where: 'id=?',
    whereArgs: [m.id],
  );
}

Future<void> deleteMission(int id) async {
  // Get a reference to the database (?????????????????????)
  final db = await Globals.database;

  // Remove the Dog from the database.
  await db.delete(
    'missions',
    // Use a `where` clause to delete a specific dog.
    where: 'id = ?',
    // Pass the Dog's id as a whereArg to prevent SQL injection.
    whereArgs: [id],
  );
}

Future<List<Mission>> getMissions(String version) async {
  // Get a reference to the database.
  final db = await Globals.database;

  // Query the table for all The Dogs.
  final List<Map<String, dynamic>> maps = await db.query('missions',
      where: "version=?",
      whereArgs: [version],
      orderBy: 'isFinished asc, deadline asc');
  // Convert the List<Map<String, dynamic> into a List<Dog>.
  return List.generate(maps.length, (i) {
    return Mission(
      id: maps[i]['id'],
      name: maps[i]['name'],
      content: maps[i]['content'],
      pay: maps[i]['pay'],
      version: maps[i]['version'],
      isFinished: maps[i]['isFinished'] == 1 ? true : false,
      claim: maps[i]['claim'],
      url: maps[i]['url'],
      deadline: maps[i]['deadline'],
    );
  });
}

Future<bool> containMissions(int id) async {
  final db = await Globals.database;

  // Query the table for all The Dogs.
  final List<Map<String, dynamic>> maps = await db.query(
    'missions',
    where: "id = ?",
    whereArgs: [id],
  );
  if (maps.length == 0) {
    return false;
  } else {
    return true;
  }
}
