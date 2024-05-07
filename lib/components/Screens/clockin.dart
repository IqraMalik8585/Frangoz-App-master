import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:login_signup/Tracker/trac.dart';
import 'package:login_signup/components/Screens/delivery_stops%20.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Globals.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage2(),
    );
  }
}

class HomePage2 extends StatefulWidget {
  @override
  _HomePage2State createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {

  final loc.Location location = loc.Location();

  // Future<void> _logOut() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   // Clear the user ID or any other relevant data from SharedPreferences
  //   prefs.remove('userId');
  //   prefs.remove('userCitys');
  //   prefs.remove('userNames');
  //   // Add any additional logout logic here
  // }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      // Handle the case when permission is denied
      Fluttertoast.showToast(
        msg: "Location permissions are required to clock in.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
  Future<bool> isInternetAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  _retrieveSavedValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId') ?? '';
      userNames = prefs.getString('userNames') ?? '';
      userCitys = prefs.getString('userCitys') ?? '';
      userDesignation = prefs.getString('userDesignation') ?? '';
    });
  }
  Future<void> _toggleClockInOut() async {
    final service = FlutterBackgroundService();
    Completer<void> completer = Completer<void>();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent users from dismissing the dialog
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    bool isLocationEnabled = await _isLocationEnabled();

    if (!isLocationEnabled) {
      Fluttertoast.showToast(
        msg: "Please enable GPS or location services before clocking in.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      completer.complete();
      return completer.future;
    }

    bool isLocationPermissionGranted = await _checkLocationPermission();
    if (!isLocationPermissionGranted) {
      await _requestLocationPermission();
      completer.complete();
      return completer.future;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await _getCurrentLocation();

    setState(() async {
      isClockedIn = !isClockedIn;

      if (isClockedIn) {
        await location.enableBackgroundMode(enable: true);
        await location.changeSettings(interval: 300, accuracy: loc.LocationAccuracy.high);
        locationbool = true;
        service.startService();

        var id = customAlphabet('1234567890', 10);
        await prefs.setString('clockInId', id);
        _saveCurrentTime();
        _saveClockStatus(true);
        //_getLocation();
        //getLocation();
        _clockRefresh();
        isClockedIn = true;
        await Future.delayed(const Duration(seconds: 5));
        await attendanceViewModel.addAttendance(AttendanceModel(
            id: prefs.getString('clockInId'),
            timeIn: _getFormattedtime(),
            date: _getFormattedDate(),
            userId: userId.toString(),
            latIn: globalLatitude1,
            lngIn: globalLongitude1,
            bookerName: userNames,
            city: userCitys,
            designation: userDesignation
        ));
        //startTimer();
        // _saveCurrentTime();
        // _saveClockStatus(true);
        // //_getLocation();
        // //getLocation();
        // _clockRefresh();
        // isClockedIn = true;
        DBHelper dbmaster = DBHelper();
        dbmaster.postAttendanceTable();

        if (kDebugMode) {
          print('HomePage:$currentPostId');
        }

      } else {
        // Generate a unique ID for the current post
        service.invoke("stopService");
        location.enableBackgroundMode(enable: false);
        await Future.delayed(const Duration(seconds: 10));
        postFile();
        await Future.delayed(const Duration(seconds: 4));
        attendanceViewModel.addAttendanceOut(AttendanceOutModel(
            id: prefs.getString('clockInId'),
            timeOut: _getFormattedtime(),
            totalTime: _formatDuration(newsecondpassed.toString()),
            date: _getFormattedDate(),
            userId: userId.toString(),
            latOut: globalLatitude1,
            lngOut: globalLongitude1,
            totalDistance: prefs.getDouble("TotalDistance").toString()
          // posted: postedController
        ));
        isClockedIn = false;
        _saveClockStatus(false);
        DBHelper dbmaster = DBHelper();
        dbmaster.postAttendanceOutTable();

        _stopTimer();
        setState(() async {
          _clockRefresh();
          //_stopListening();
          //stopListeningnew();
          //await saveGPXFile();
          await prefs.remove('clockInId');
        });

      }
    });
    await Future.delayed(const Duration(seconds: 10));
    Navigator.pop(context); // Close the loading indicator dialog
    completer.complete();
    return completer.future;
  }

  Future<bool> _isLocationEnabled() async {
    // Add your logic to check if location services are enabled
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    return isLocationEnabled;
  }


  String _getFormattedtime() {
    final now = DateTime.now();
    final formatter = DateFormat('HH:mm:ss a');
    return formatter.format(now);
  }

  _loadClockStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isClockedIn = prefs.getBool('isClockedIn') ?? false;
    if (isClockedIn == true) {
      //startTimerFromSavedTime();
      final service = FlutterBackgroundService();
      service.startService();
      //_clockRefresh();
    }else{
      prefs.setInt('secondsPassed', 0);
    }
  }

  _saveClockStatus(bool clockedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isClockedIn', clockedIn);
    isClockedIn = clockedIn;
  }
  data(){
    DBHelper dbHelper = DBHelper();
    if (kDebugMode) {
      print('data0');
    }
    dbHelper.getRecoveryHighestSerialNo();
    dbHelper.getHighestSerialNo();
  }

  @override
  void initState() {
    super.initState();

    // backgroundTask();
    WidgetsBinding.instance.addObserver(this);
    _loadClockStatus();
    fetchShopList();
    _retrieveSavedValues();
    _clockRefresh();
    if (kDebugMode) {
      print("B1000 ${name.toString()}");
    }
    _requestPermission();
    // location.changeSettings(interval: 300, accuracy: loc.LocationAccuracy.high);
    // location.enableBackgroundMode(enable: true);
    _getFormattedDate();
    data();
  }

  void _saveCurrentTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime currentTime = DateTime.now();
    String formattedTime = _formatDateTime(currentTime);
    prefs.setString('savedTime', formattedTime);
    if (kDebugMode) {
      print("Save Current Time");
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('HH:mm:ss');
    return formatter.format(dateTime);
  }
  int newsecondpassed = 0;
  void _clockRefresh() async {
    newsecondpassed = 0;
    timer = Timer.periodic(const Duration(seconds: 0), (timer) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        prefs.reload();
        newsecondpassed = prefs.getInt('secondsPassed')!;
      });
    });
  }

  Future<String> _stopTimer() async {
    String totalTime = _formatDuration(newsecondpassed.toString());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('secondsPassed', 0);
    setState(() {
      secondsPassed = 0;
    });
    return totalTime;
  }

  String _formatDuration(String secondsString) {
    int seconds = int.parse(secondsString);
    Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);

    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String secondsFormatted = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secondsFormatted';
  }

  @override
  void dispose() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await _determinePosition();
      // Save the location into the database (you need to implement this part)
      globalLatitude1 = position.latitude;
      globalLongitude1 = position.longitude;
      // Show a toast
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      throw Exception('Location services are disabled.');
    }

    // Check the location permission status.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Location permissions are denied
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Location permissions are permanently denied
      throw Exception('Location permissions are permanently denied.');
    }

    // Get the current position
    return await Geolocator.getCurrentPosition();
  }

  Future<void> fetchShopList() async {
    List<String> fetchShopList = await fetchData();
    if (fetchShopList.isNotEmpty) {
      setState(() {
        shopList = fetchShopList;
        selectedShop2 = shopList.first;
      });
    }
  }

  Future<List<String>> fetchData() async {
    return [];
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final formatter = DateFormat('dd-MMM-yyyy');
    return formatter.format(now);
  }

  void handleShopChange(String? newShop) {
    setState(() {
      selectedShop2 = newShop;
    });
  }
  //
  // String formatTimer(int seconds) {
  //   int hours = seconds ~/ 3600;
  //   int minutes = (seconds ~/ 60) % 60;
  //   int secs = seconds % 60;
  //   return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  // }
  // String _getFormattedtime() {
  //   final now = DateTime.now();
  //   final formatter = DateFormat('HH:mm:ss a');
  //   return formatter.format(now);
  // }
  //
  // _loadClockStatus() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   isClockedIn = prefs.getBool('isClockedIn') ?? false;
  //   print(isClockedIn.toString() + "RES B100");
  //   if (isClockedIn == true) {
  //     print("B100 CLOCKIN RUNN");
  //     //startTimerFromSavedTime();
  //     final service = FlutterBackgroundService();
  //     service.startService();
  //     //_clockRefresh();
  //   }else{
  //     prefs.setInt('secondsPassed', 0);
  //   }
  // }
  //
  // _saveClockStatus(bool clockedIn) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   prefs.setBool('isClockedIn', clockedIn);
  //   isClockedIn = clockedIn;
  // }
  //
  // void _saveCurrentTime() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   DateTime currentTime = DateTime.now();
  //   String formattedTime = _formatDateTime(currentTime);
  //   prefs.setString('savedTime', formattedTime);
  //   print("Save Current Time");
  // }
  //
  // String _formatDateTime(DateTime dateTime) {
  //   final formatter = DateFormat('HH:mm:ss');
  //   return formatter.format(dateTime);
  // }
  // int newsecondpassed = 0;
  // void _clockRefresh() async {
  //   newsecondpassed = 0;
  //   timer = Timer.periodic(Duration(seconds: 0), (timer) async {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     setState(() {
  //       prefs.reload();
  //       newsecondpassed = prefs.getInt('secondsPassed')!;
  //     });
  //   });
  // }
  //
  // Future<String> _stopTimer() async {
  //   String totalTime = _formatDuration(newsecondpassed.toString());
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   prefs.setInt('secondsPassed', 0);
  //   setState(() {
  //     secondsPassed = 0;
  //   });
  //   return totalTime;
  // }
  //
  // String _formatDuration(String secondsString) {
  //   int seconds = int.parse(secondsString);
  //   Duration duration = Duration(seconds: seconds);
  //   String twoDigits(int n) => n.toString().padLeft(2, '0');
  //   String hours = twoDigits(duration.inHours);
  //
  //   String minutes = twoDigits(duration.inMinutes.remainder(60));
  //   String secondsFormatted = twoDigits(duration.inSeconds.remainder(60));
  //   return '$hours:$minutes:$secondsFormatted';
  // }
  // String _getFormattedDate() {
  //   final now = DateTime.now();
  //   final formatter = DateFormat('dd-MMM-yyyy');
  //   return formatter.format(now);
  // }
  // @override
  // void dispose() {
  //
  //   super.dispose();
  //   WidgetsBinding.instance!.addObserver(this as WidgetsBindingObserver);
  //
  //   _loadClockStatus();
  //   _getFormattedDate();
  //
  //   _clockRefresh();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Timer: ${_formatDuration(newsecondpassed.toString())}',
              style: TextStyle(fontSize: 20, ),
            ),
            IconButton(
              onPressed: () {
                if (isClockedIn) {
                  startTimer();
                  _saveCurrentTime();
                  _saveClockStatus(true);
                  //_getLocation();
                  //getLocation();
                  _clockRefresh();
                  isClockedIn = true;
                } else {
                  isClockedIn = false;
                  _saveClockStatus(false);
                  _stopTimer();
                  setState(() async {
                    _clockRefresh();
                  });
                }
                setState(() {
                  isClockedIn = !isClockedIn;
                });
              },
              icon: Icon(
                isClockedIn ? Icons.timer_off : Icons.timer,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedLogo(),
                SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MapSample()),
                    );
                  },
                  style: ButtonStyle(
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        if (states.contains(MaterialState.hovered))
                          return Colors.transparent;
                        if (states.contains(MaterialState.focused) ||
                            states.contains(MaterialState.pressed))
                          return Colors.transparent;
                        return null;
                      },
                    ),
                  ),
                  child: Text(
                    'Tap to Add Stops',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSerif',
                      color: const Color(0xffae2012),
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isClockedIn) {
            startTimer();
            _saveCurrentTime();
            _saveClockStatus(true);
            //_getLocation();
            //getLocation();
            _clockRefresh();
            isClockedIn = true;
          } else {
            isClockedIn = false;
            _saveClockStatus(false);
            _stopTimer();
            setState(() async {
              _clockRefresh();
            });
          }
          setState(() {
            isClockedIn = !isClockedIn;
          });
        },
        child: Icon(
          isClockedIn ? Icons.timer_off : Icons.timer,
          color: Colors.white,
        ),
        backgroundColor: Color(0xffae2012),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class AnimatedLogo extends StatefulWidget {
  @override
  _AnimatedLogoState createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  // @override
  // void initState() {
  //   super.initState();
  //   controller = AnimationController(
  //     duration: Duration(seconds: 1),
  //     vsync: this,
  //   );
  //   animation = Tween<double>(begin: 0, end: 1).animate(controller)
  //     ..addListener(() {
  //       setState(() {});
  //     });
  //   controller.repeat(reverse: true);
  // }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: animation.value,
      child: Image.asset(
        'assets/images/stopicon.png',
        height: 249,
        width: 200,
      ),
    );
  }

  // @override
  // void dispose() {
  //   controller.dispose();
  //   super.dispose();
  // }
}
