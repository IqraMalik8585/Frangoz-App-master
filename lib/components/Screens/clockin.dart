import 'dart:async' show Completer, Future, Timer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nanoid/nanoid.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../Globals.dart';

import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';



//tarcker
final FirebaseAuth auth = FirebaseAuth.instance;
final User? user = auth.currentUser;
final myUid = userId;
final name = userNames;


bool showButton = false;


class MyIcons {
  static const IconData addShop = IconData(0xf52a, fontFamily: 'MaterialIcons');
  static const IconData store = Icons.store;
  static const IconData returnForm = IconData(0xee93, fontFamily: 'MaterialIcons');
  static const IconData person = Icons.person;
  static const IconData orderBookingStatus = IconData(0xf52a, fontFamily: 'MaterialIcons');
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>with WidgetsBindingObserver {

// Add this line
  List<String> shopList = [];
  String? selectedShop2;
  int? attendanceId;

  int? attendanceId1;
  double? globalLatitude1;
  double? globalLongitude1;

  bool isLoading = false; // Define isLoading variable
  bool isLoadingReturn= false;
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

        //startTimer();
        // _saveCurrentTime();
        // _saveClockStatus(true);
        // //_getLocation();
        // //getLocation();
        // _clockRefresh();
        // isClockedIn = true;



        if (kDebugMode) {
          print('HomePage:$currentPostId');
        }

      } else {
        // Generate a unique ID for the current post
        service.invoke("stopService");
        location.enableBackgroundMode(enable: false);
        await Future.delayed(const Duration(seconds: 10));

        await Future.delayed(const Duration(seconds: 4));

        isClockedIn = false;
        _saveClockStatus(false);



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

    if (kDebugMode) {
      print('data0');
    }

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

  @override
  Widget build(BuildContext context) {


    return WillPopScope(
      onWillPop: () async {
        // Return false to prevent going back
        return false;
      },
      child: Scaffold(
        appBar:AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.green,
          toolbarHeight: 80.0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Timer: ${_formatDuration(newsecondpassed.toString())}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Material(
                    elevation: 10.0,  // Set the elevation here
                    shape: const CircleBorder(),
                    color: Colors.deepOrangeAccent,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.deepOrangeAccent,
                          width: 0.1,
                        ),
                        //borderRadius: BorderRadius.circular(1),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        color: Colors.white,iconSize: 20,
                        onPressed: () async {
                          // Check internet connection before refresh
                          showLoadingIndicator(context);
                          bool isConnected = await isInternetAvailable();
                          Navigator.of(context, rootNavigator: true).pop();

                          if (isConnected) {
                            // Internet connection is available

                            await Future.wait([
                              //        Future.delayed(Duration(seconds: 10)),

                            ]);
                            // After 10 seconds, hide the loading indicator and perform the refresh logic
                            Navigator.of(context, rootNavigator: true).pop();
                          } else {
                            // No internet connection
                            Fluttertoast.showToast(
                              msg: "No internet connection.",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0,
                            );
                          }
                        },
                      ),
                    ),
                  )


                  // PopupMenuButton<int>(
                  //   icon: Icon(Icons.more_vert),
                  //   color: Colors.white,
                  //   onSelected: (value) async {
                  //     switch (value) {
                  //       case 1:
                  //       // Check internet connection before refresh
                  //         final bool isConnected = await InternetConnectionChecker().hasConnection;
                  //         if (!isConnected) {
                  //           // No internet connection
                  //           Fluttertoast.showToast(
                  //             msg: "No internet connection.",
                  //             toastLength: Toast.LENGTH_SHORT,
                  //             gravity: ToastGravity.BOTTOM,
                  //             backgroundColor: Colors.red,
                  //             textColor: Colors.white,
                  //             fontSize: 16.0,
                  //           );
                  //         } else {
                  //           // Internet connection is available
                  //           DatabaseOutputs outputs = DatabaseOutputs();
                  //           // Run both functions in parallel
                  //           showLoadingIndicator(context);
                  //           await Future.wait([
                  //             backgroundTask(),
                  //             postFile(),
                  //             outputs.checkFirstRun(),
                  //             Future.delayed(Duration(seconds: 10)),
                  //           ]);
                  //           // After 10 seconds, hide the loading indicator and perform the refresh logic
                  //           Navigator.of(context, rootNavigator: true).pop();
                  //         }
                  //         break;
                  //
                  //       case 2:
                  //       // Handle the action for the second menu item (Log Out)
                  //         if (isClockedIn) {
                  //           // Check if the user is clocked in
                  //           Fluttertoast.showToast(
                  //             msg: "Please clock out before logging out.",
                  //             toastLength: Toast.LENGTH_SHORT,
                  //             gravity: ToastGravity.BOTTOM,
                  //             backgroundColor: Colors.red,
                  //             textColor: Colors.white,
                  //             fontSize: 16.0,
                  //           );
                  //         } else {
                  //           await _logOut();
                  //           // If the user is not clocked in, proceed with logging out
                  //           Navigator.pushReplacement(
                  //             // Replace the current page with the login page
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (context) => LoginForm(),
                  //             ),
                  //           );
                  //         }
                  //         break;
                  //     }
                  //   },
                  //   itemBuilder: (BuildContext context) {
                  //     return [
                  //       PopupMenuItem<int>(
                  //         value: 1,
                  //         child: Text('Refresh'),
                  //       ),
                  //       PopupMenuItem<int>(
                  //         value: 2,
                  //         child: Text('Log Out'),
                  //       ),
                  //     ];
                  //   },
                  // ),
                ],
              ),
            ],
          ),
        ), body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 150,
                        // child: ElevatedButton(
                        //   onPressed: () {
                        //     if (isClockedIn) {
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (context) => const ShopPage(),
                        //         ),
                        //       );
                        //     } else {
                        //       showDialog(
                        //         context: context,
                        //         builder: (context) => AlertDialog(
                        //           title: const Text('Clock In Required'),
                        //           content: const Text('Please clock in before adding a shop.'),
                        //           actions: [
                        //             TextButton(
                        //               onPressed: () => Navigator.pop(context),
                        //               child: const Text('OK'),
                        //             ),
                        //           ],
                        //         ),
                        //       );
                        //     }
                        //   },
                        //   style: ElevatedButton.styleFrom(
                        //     foregroundColor: Colors.white, backgroundColor: Colors.green,
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        //   child: const Column(
                        //     mainAxisAlignment: MainAxisAlignment.center,
                        //     children: [
                        //       Icon(
                        //         MyIcons.addShop,
                        //         color: Colors.white,
                        //         size: 50,
                        //       ),
                        //       SizedBox(height: 10),
                        //       Text('Add Shop'),
                        //     ],
                        //   ),
                        // ),
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        ],
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 150,
                        width: 150,
                        // child: ElevatedButton(
                        //   onPressed: () {
                        //
                        //     if (isClockedIn) {
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (context) => ShopVisit(onBrandItemsSelected: (String) {}),
                        //         ),
                        //       );
                        //     } else {
                        //       showDialog(
                        //         context: context,
                        //         builder: (context) => AlertDialog(
                        //           title: const Text('Clock In Required'),
                        //           content: const Text('Please clock in before visiting a shop.'),
                        //           actions: [
                        //             TextButton(
                        //               onPressed: () => Navigator.pop(context),
                        //               child: const Text('OK'),
                        //             ),
                        //           ],
                        //         ),
                        //       );
                        //     }
                        //   },
                        //   style: ElevatedButton.styleFrom(
                        //     foregroundColor: Colors.white, backgroundColor: Colors.green,
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        //   child: const Column(
                        //     mainAxisAlignment: MainAxisAlignment.center,
                        //     children: [
                        //       Icon(
                        //         Icons.store,
                        //         color: Colors.white,
                        //         size: 50,
                        //       ),
                        //       SizedBox(height: 10),
                        //       Text('Shop Visit'),
                        //     ],
                        //   ),
                        // ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 150,
                        child: ElevatedButton(
                          onPressed: () async{
                            setState(() {
                              isLoading = true; // assuming isLoading is a boolean state variable
                            });
                            bool isConnected = await isInternetAvailable();
                            if (!isClockedIn) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Clock In Required'),
                                  content: const Text('Please clock in before accessing the Return Page.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } else if (!isConnected) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Internet Data Required'),
                                  content: const Text('Please check your internet connection before accessing the Return Page.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // DatabaseOutputs outputs = DatabaseOutputs();
                              // await  outputs.checkFirstRunAccounts();
                              //
                              // await Navigator.push(context, MaterialPageRoute(
                              //     builder: (context) => ReturnFormPage()));
                            }
                            setState(() {
                              isLoading = false; // set loading state to false after execution
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator() // Show a loading indicator
                              : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                MyIcons.returnForm,
                                color: Colors.white,
                                size: 50,
                              ),
                              SizedBox(height: 10),
                              Text('Return Form'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                          height: 150,
                          width: 150,
                          child:ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                isLoadingReturn = true; // assuming isLoading is a boolean state variable
                              });

                              // Delay for 5 seconds
                              // await Future.delayed(Duration(seconds: 5));

                              bool isConnected = await isInternetAvailable();

                              if (!isClockedIn) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Clock In Required'),
                                    content: const Text('Please clock in before accessing the Recovery.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (!isConnected) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Internet Data Required'),
                                    content: const Text('Please check your internet connection before accessing the Recovery.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // DatabaseOutputs outputs = DatabaseOutputs();
                                // await  outputs.checkFirstRunAccounts();
                                //
                                // await Navigator.push(context, MaterialPageRoute(
                                //     builder: (context) => RecoveryFromPage()));
                              }

                              setState(() {
                                isLoadingReturn = false; // set loading state to false after execution
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isLoadingReturn
                                ? const CircularProgressIndicator() // Show a loading indicator
                                : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 50,
                                ),
                                SizedBox(height: 10),
                                Text('Recovery'),
                              ],
                            ),
                          )

                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 150,
                        width: 150,
                        // child: ElevatedButton(
                        //   onPressed: () {
                        //     // if (isClockedIn) {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         // builder: (context) => OrderBookingStatus(),
                        //       ),
                        //     );
                        //     // } else {
                        //     //   showDialog(
                        //     //     context: context,
                        //     //     builder: (context) => AlertDialog(
                        //     //       title: Text('Clock In Required'),
                        //     //       content: Text('Please clock in before checking Order Booking Status.'),
                        //     //       actions: [
                        //     //         TextButton(
                        //     //           onPressed: () => Navigator.pop(context),
                        //     //           child: Text('OK'),
                        //     //         ),
                        //     //       ],
                        //     //     ),
                        //     //   );
                        //     // }
                        //   },
                        //   style: ElevatedButton.styleFrom(
                        //     foregroundColor: Colors.white, backgroundColor: Colors.green,
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        //   child: const Column(
                        //     mainAxisAlignment: MainAxisAlignment.center,
                        //     children: [
                        //       Icon(
                        //         MyIcons.orderBookingStatus,
                        //         color: Colors.white,
                        //         size: 50,
                        //       ),
                        //       SizedBox(height: 10),
                        //       Text('Order Booking Status'),
                        //     ],
                        //   ),
                        // ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ]
            ),
          ),
        ),
      ),
        //
        floatingActionButton: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),

            child:ElevatedButton.icon(
              onPressed:() async {
                // await MoveToBackground.moveTaskToBack();

                await _toggleClockInOut();
              },
              icon: Icon(
                isClockedIn ? Icons.timer_off : Icons.timer,
                color: isClockedIn ? Colors.red : Colors.green,
              ),
              label: Text(
                isClockedIn ? 'Clock Out' : 'Clock In',
                style: const TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: isClockedIn ? Colors.red : Colors.green, backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          ),
        ),
      ),
    );
  }


  Future<bool> requestPermissions(BuildContext context) async {
    final notificationStatus = await Permission.notification.status;
    final locationStatus = await Permission.location.status;

    if (!notificationStatus.isGranted) {
      PermissionStatus newNotificationStatus = await Permission.notification.request();

      if (newNotificationStatus.isDenied || newNotificationStatus.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Permission Denied'),
              content: const Text('Notification permission is required for this app to function properly. Please grant it in the app settings.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    openAppSettings();
                  },
                ),
              ],
            );
          },
        );
        return false;
      }
    }


    if (!locationStatus.isGranted) {
      PermissionStatus newLocationStatus = await Permission.location.request();

      if (newLocationStatus.isDenied || newLocationStatus.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Permission Denied'),
              content: const Text('Location permission is required for this app to function properly. Please grant it in the app settings.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    openAppSettings();
                  },
                ),
              ],
            );
          },
        );
        return false;
      }
    }

    return true;
  }



  void showLoadingIndicator(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Please Wait..."),
            ],
          ),
        );
      },
    );
  }

  Future<bool> isInternetConnected() async {
    bool isConnected = await InternetConnectionChecker().hasConnection;
    if (kDebugMode) {
      print('Internet Connected: $isConnected');
    }
    return isConnected;
  }


  _requestPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      if (kDebugMode) {
        print('done');
      }
    } else if (status.isDenied) {
      _requestPermission();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }


}