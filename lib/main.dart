import 'package:flutter_timer_location_service/background_location/location_callback_handler.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:background_locator/background_locator.dart';
import 'package:background_locator/location_dto.dart';
import 'package:background_locator/settings/android_settings.dart';
import 'package:background_locator/settings/ios_settings.dart';
import 'package:background_locator/settings/locator_settings.dart';
import 'package:custom_timer/custom_timer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timer_location_service/common/shared_pref_manager.dart';
import 'package:location_permissions/location_permissions.dart';
import 'background_location/location_callback_handler.dart';
import 'background_location/location_service_repository.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ReceivePort port = ReceivePort();
  bool flag = true;
  Stream<int> timerStream;
  StreamSubscription<int> timerSubscription;

  // CustomTimerController _controller;
  String hoursStr = '00';
  String minutesStr = '00';
  String secondsStr = '00';
  bool isRunning = false;
  LocationDto lastLocation;
  DateTime lastTimeLocation;

  Stream<int> stopWatchStream() {
    StreamController<int> streamController;
    Timer timer;
    Duration timerInterval = Duration(seconds: 1);
    int counter = 0;

    void stopTimer() {
      if (timer != null) {
        timer.cancel();
        timer = null;
        counter = 0;
        streamController.close();
      }
    }

    void tick(_) {
      counter++;
      streamController.add(counter);
      if (!flag) {
        stopTimer();
      }
    }

    void startTimer() {
      timer = Timer.periodic(timerInterval, tick);
    }

    streamController = StreamController<int>(
      onListen: startTimer,
      onCancel: stopTimer,
      onResume: startTimer,
      onPause: stopTimer,
    );

    return streamController.stream;
  }

  @override
  void initState() {
    super.initState();
    // _controller = new CustomTimerController();
    if (IsolateNameServer.lookupPortByName(
            LocationServiceRepository.isolateName) !=
        null) {
      IsolateNameServer.removePortNameMapping(
          LocationServiceRepository.isolateName);
    }

    IsolateNameServer.registerPortWithName(
        port.sendPort, LocationServiceRepository.isolateName);

    port.listen(
      (dynamic data) async {
        await updateUI(data);
      },
    );
    initPlatformState();
    WidgetsBinding.instance.addPostFrameCallback((_) => setTimer());
  }

  Future<void> initPlatformState() async {
    print('Initializing...');
    await BackgroundLocator.initialize();
    print('Initialization done');
    final _isRunning = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = _isRunning;
    });
    print('Running ${isRunning.toString()}');
  }

  Future<void> updateUI(LocationDto data) async {
    await _updateNotificationText(data);

    setState(() {
      if (data != null) {
        lastLocation = data;
        lastTimeLocation = DateTime.now();
      }
    });
  }

  Future<void> _updateNotificationText(LocationDto data) async {
    if (data == null) {
      return;
    }

    await BackgroundLocator.updateNotificationText(
        title: "new location received",
        msg: "${DateTime.now()}",
        bigMsg: "${data.latitude}, ${data.longitude}");
  }

  @override
  Widget build(BuildContext context) {
    final start = ElevatedButton(
      style: ButtonStyle(
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        )),
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) return null;
            if (states.contains(MaterialState.disabled))
              return Colors.grey.withOpacity(0.3);
            return Colors.blueAccent; // Use the component's default.
          },
        ),
      ),
      child: Text(
        'start service',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
      ),
      onPressed: !isRunning
          ? () {
              playTimer();
              startTracking();
            }
          : null,
    );
    final stop = ElevatedButton(
      style: ButtonStyle(
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        )),
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) return null;
            if (states.contains(MaterialState.disabled))
              return Colors.grey.withOpacity(0.3);
            return Colors.blueAccent; // Use the component's default.
          },
        ),
      ),
      child: Text('end service',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
      onPressed: isRunning
          ? () async {
              stopTracking();
              timerSubscription.cancel();
              timerStream = null;
            }
          : null,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "$hoursStr:$minutesStr:$secondsStr",
              style: TextStyle(
                fontSize: 90.0,
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [start, stop],
            )
          ],
        ),
      ),
    );
  }

  playTimer() {
    timerStream = stopWatchStream();
    timerSubscription = timerStream.listen((int newTick) {
      setState(() {
        hoursStr =
            ((newTick / (60 * 60)) % 60).floor().toString().padLeft(2, '0');
        minutesStr = ((newTick / 60) % 60).floor().toString().padLeft(2, '0');
        secondsStr = (newTick % 60).floor().toString().padLeft(2, '0');
      });
    });
  }

  startTracking() async {
    await _onStart();
    await SharedPrefManager()
        .writeDate(DateTime.now().millisecondsSinceEpoch.toString());
    // _controller.start();
  }

  Future<void> _onStart() async {
    if (await _checkLocationPermission()) {
      _startLocator();
      final _isRunning = await BackgroundLocator.isServiceRunning();

      setState(() {
        isRunning = _isRunning;
        lastTimeLocation = null;
        lastLocation = null;
      });
    } else {
      // show error
    }
  }

  Future<bool> _checkLocationPermission() async {
    final access = await LocationPermissions().checkPermissionStatus();
    switch (access) {
      case PermissionStatus.unknown:
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        final permission = await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationWhenInUse,
        );
        if (permission == PermissionStatus.granted) {
          return true;
        } else {
          return false;
        }
        break;
      case PermissionStatus.granted:
        print("granted");
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  stopTracking() async {
    onStop();
    // _controller.reset();
  }

  void onStop() async {
    BackgroundLocator.unRegisterLocationUpdate();
    final _isRunning = await BackgroundLocator.isServiceRunning();
    await SharedPrefManager().writeDate("");
    setState(() {
      isRunning = _isRunning;
      hoursStr = "00";
      minutesStr = "00";
      secondsStr = "00";
    });
  }

  void _startLocator() {
    BackgroundLocator.registerLocationUpdate(LocationCallbackHandler.callback,
        // initCallback: LocationCallbackHandler.initCallback,
        // initDataCallback: data,
        // disposeCallback: LocationCallbackHandler.disposeCallback,
        iosSettings: IOSSettings(
            accuracy: LocationAccuracy.NAVIGATION, distanceFilter: 0),
        autoStop: false,
        androidSettings: AndroidSettings(
            accuracy: LocationAccuracy.NAVIGATION,
            interval: 5,
            distanceFilter: 0,
            client: LocationClient.google,
            androidNotificationSettings: AndroidNotificationSettings(
                notificationChannelName: 'Location tracking',
                notificationTitle: 'Start Location Tracking',
                notificationMsg: 'Track location in background',
                notificationBigMsg:
                    'Background location is on to keep the app up-tp-date with your location. This is required for main features to work properly when the app is not running.',
                notificationIcon: '',
                notificationIconColor: Colors.grey,
                notificationTapCallback:
                    LocationCallbackHandler.notificationCallback)));
  }
}
