import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bidzii/global.dart';
import 'package:bidzii/models/Me.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_count_down/date_count_down.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/leaderboard.dart';

class CompetitionPage extends StatefulWidget {
  const CompetitionPage({super.key, required this.me});
  final Me me;
  @override
  State<CompetitionPage> createState() => _CompetitionPageState();
}

class _CompetitionPageState extends State<CompetitionPage>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  int highestTime = 0;
  double timeFraction = 0;

  Location? location;
  int vibrationCount = 10;
  late DateTime competitionTime = DateTime.now();
  bool _showMessage = false, _passed = false;

  late final PageController _pageController;
  bool isRunning = true;

  bool playing = false;

  late AnimationController _startController;
  late Animation<double> _playAnimation;

  bool _move = false;
  bool _competitionActive = false;

  late DateTime _activationTime = DateTime.now();
  bool _loading = true;
  bool _notify = false;
  Future<void> checkTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey("notify")) {
      _notify = prefs.getBool("notify") ?? false;
    }

    // await firestore.collection("system").doc("main").update({
    //   "competitionTime":
    //       DateTime.now().add(Duration(days: 43)).millisecondsSinceEpoch
    // });
    final snap = await firestore.collection("system").doc("main").get();

    if (snap.exists) {
      if (snap.data()!.containsKey("ended") || snap.data()!['ended'] == true) {
        competitionTime = DateTime.now().subtract(const Duration(days: 10));
        isRunning = false;
        ended = isRunning;
        return;
      } else {
        debugPrint("continuing");
      }
      DateTime now = await NTP.now();

      competitionTime =
          DateTime.fromMillisecondsSinceEpoch(snap.data()!["competitionTime"]);
      _activationTime = snap.data()!.containsKey("activationTime")
          ? DateTime.fromMillisecondsSinceEpoch(snap.data()!['activationTime'])
          : DateTime.now().add(const Duration(days: 55));
      _competitionActive = _activationTime.isBefore(now);

      DateTime nowTime = await NTP.now();

      setState(() {
        if (nowTime.isAfter(competitionTime)) {
          isRunning = false;
          debugPrint("Competition Ended");
        } else {
          isRunning = true;
          ended = isRunning;
          debugPrint(
              "Competition ${DateFormat.yMEd().format(competitionTime)}");
          debugPrint("Activation ${DateFormat.yMEd().format(_activationTime)}");
        }
      });
    }
    final secureStorage = await SharedPreferences.getInstance();

    final snap2 =
        await firestore.collection("users").doc(auth.currentUser!.uid).get();
    if (snap2.exists) {
      final info = snap2.data()!;
      _seconds = !info.containsKey("highestTime") ? 0 : info['highestTime'];
      debugPrint("$_seconds");
      _milliseconds =
          ((!info.containsKey("timeFraction") ? 0 : info['timeFraction']) / 100)
              .toInt();
      highestTime = _seconds;
      timeFraction = (_milliseconds * 100).toDouble();
    } else {
      if (secureStorage.containsKey("seconds")) {
        _seconds = (secureStorage.getInt("seconds")) ?? 0;

        _milliseconds = (secureStorage.getInt("milliseconds")) ?? 0;
        setState(() {});
      }
    }

    setState(() {
      if (!Globals.globalTime.difference(competitionTime).isNegative) {
        ended = true;
        debugPrint("ended");
        _pageController.animateToPage(1,
            duration: mainDuration, curve: Curves.fastLinearToSlowEaseIn);
      }
      _loading = false;
    });
  }

  bool ended = false;

  late final startTime;

  @override
  void initState() {
    _pageController = PageController(viewportFraction: 1.0, initialPage: 0);

    checkTime();
    _animationController =
        AnimationController(vsync: this, duration: mainDurationLonger);
    _startController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _playAnimation = CurvedAnimation(
        parent: _startController,
        curve: Curves.fastLinearToSlowEaseIn,
        reverseCurve: Curves.fastEaseInToSlowEaseOut);
    super.initState();
  }

  Timer? _timer, _timer2, _locationShuffler, _timeReaper;
  int _seconds = 0, _milliseconds = 0;

  void _startTimer() {
    location = null;

    _seconds = 0;
    _milliseconds = 0;
    if (Globals.globalTime.difference(competitionTime).isNegative) {
      firestore.collection("users").doc(auth.currentUser!.uid).set({
        "isPlaying": true,
      }, SetOptions(merge: true));
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });

    int max = 23;
    _locationShuffler = Timer.periodic(Duration(seconds: max), (timer) {
      setState(() {
        location = Random().nextBool()
            ? Location.top
            : Random().nextBool()
                ? Location.bottom
                : Random().nextBool()
                    ? Location.left
                    : Location.right;
        _showMessage = true;

        Future.delayed(const Duration(seconds: 14), () {
          if (mounted) {
            setState(() {
              _showMessage = false;
            });
          }
        });

        //Warning
        Future.delayed(const Duration(seconds: 15), () {
          if (location == null) {
            Fluttertoast.showToast(
              gravity: ToastGravity.CENTER,
              backgroundColor: Globals.primaryColor,
              textColor: Colors.white,
              msg: "Good🫡 You're still with us",
            );
            setState(() {
              _passed = false;
            });
          } else {
            toast(
                toastPosition: ToastGravity.TOP,
                backgroundColor: Globals.primaryColor,
                textColor: Colors.white,
                message: "You're Out of Time 💀");

            setState(() {
              playing = false;
              _startController.reverse();
              debugPrint("Failed to touch the button");
              _showMessage = false;
              if (!_passed && location != null) {
                _timer!.cancel();
                _timer2!.cancel();
                _locationShuffler!.cancel();
              }
            });
          }
        });
      });
    });
    // _timeReaper = Timer.periodic(Duration(seconds: max + 10), (timer) {
    // });
    _timer2 = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _milliseconds = _milliseconds == 900 ? 0 : _milliseconds + 100;
      });
    });
  }

  final Stream _streamer = firestore
      .collection("users")
      .where("isPlaying", isEqualTo: true)
      .snapshots();

  void _stopTimer() {
    if (_seconds > highestTime) {
      highestTime = _seconds;
      timeFraction = _milliseconds / 100;
    }
    debugPrint("Highest time $highestTime");
    _timer?.cancel();
    _timer2?.cancel();
    _locationShuffler?.cancel();
    _timeReaper?.cancel();

    if (isRunning) {
      firestore.collection("users").doc(auth.currentUser!.uid).set({
        "highestTime": highestTime,
        "timeFraction": timeFraction,
        "isPlaying": false,
      }, SetOptions(merge: true)).then((value) async {
        const pref = FlutterSecureStorage();
        pref.write(key: "seconds", value: "$highestTime");
        pref.write(key: "milliseconds", value: "${timeFraction * 100}");
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer2?.cancel();
    _locationShuffler?.cancel();
    _timeReaper?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = getSize(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1500),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor:
              CurvedAnimation(parent: animation, curve: Curves.elasticInOut),
          child: Align(alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: _loading
          ? Container(
              color: Globals.white,
              child: Center(
                child: Lottie.asset(
                  "$dir/load1.json",
                  fit: BoxFit.contain,
                  width: size.width,
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _startController,
              builder: (context, child) {
                return Scaffold(
                  backgroundColor: const Color(0xffffffff),
                  body: Stack(
                    children: [
                      Lottie.asset("$dir/round6.json", fit: BoxFit.contain),
                      AnimatedPositioned(
                          duration: mainDurationLonger,
                          curve: Curves.fastEaseInToSlowEaseOut,
                          left: _move ? 0 : size.width * .38,
                          top: size.width * .38,
                          child: Lottie.asset("$dir/ripple5.json",
                              fit: BoxFit.contain)),
                      AnimatedPositioned(
                          duration: mainDurationLonger,
                          curve: Curves.decelerate,
                          left: _move ? 0 : size.width * .18,
                          top: _move ? size.width * 1.12 : size.width * .38,
                          child: Lottie.asset("$dir/wave3.json",
                              fit: BoxFit.contain)),
                      AnimatedPositioned(
                          duration: mainDurationLonger,
                          curve: Curves.decelerate,
                          left: _move ? 0 : size.width * .18,
                          top: _move ? size.width * .12 : size.width * .18,
                          child: Lottie.asset("$dir/scroll4.json",
                              fit: BoxFit.contain)),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                        child: const Center(child: Text("")),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: PageView(
                          physics: const NeverScrollableScrollPhysics(),
                          controller: _pageController,
                          children: [
                            auth.currentUser == null
                                ? const Center(
                                    child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                        "You have to be connected to play"),
                                  ))
                                : !isRunning
                                    ? Center(
                                        child: SizedBox(
                                            width: size.width,
                                            height: 100,
                                            child: Material(
                                              elevation: 110,
                                              shadowColor:
                                                  Colors.black.withOpacity(.09),
                                              color: Globals.white,
                                              child: const Padding(
                                                padding: EdgeInsets.all(18.0),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "Competition Ended already",
                                                      style: Globals.title,
                                                    ),
                                                    Text(
                                                      "You can visit the leaderboard to find out winners\nOur finger game will come back when it's time",
                                                      style: Globals.subtitle,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )),
                                      )
                                    : Stack(
                                        children: [
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            width: size.width,
                                            height: size.height,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                    height: size.width * .85,
                                                    width: size.width * .85,
                                                    child: Center(
                                                        child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const SizedBox(
                                                            height: 100),
                                                        const Text(
                                                            "Your highest Score"),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      18.0),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceEvenly,
                                                            children: [
                                                              Column(
                                                                children: [
                                                                  Text(
                                                                    prettyNumber((_seconds /
                                                                            (60 *
                                                                                60))
                                                                        .floor()),
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            35,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                  Text(
                                                                    "Hours",
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            16,
                                                                        color: ColorTween(begin: Colors.grey, end: Globals.blue)
                                                                            .animate(
                                                                                _playAnimation)
                                                                            .value,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                ],
                                                              ),
                                                              Column(
                                                                children: [
                                                                  Text(
                                                                    prettyNumber(
                                                                        (_seconds /
                                                                                60)
                                                                            .floor()),
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            35,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                  Text(
                                                                    "Minutes",
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            16,
                                                                        color: ColorTween(begin: Colors.grey, end: Globals.blue)
                                                                            .animate(
                                                                                _playAnimation)
                                                                            .value,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                ],
                                                              ),
                                                              Column(
                                                                children: [
                                                                  Text(
                                                                    prettyNumber(_seconds -
                                                                        ((_seconds / 60).floor() *
                                                                            60)),
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            35,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                  Text(
                                                                    "Seconds",
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            16,
                                                                        color: ColorTween(begin: Colors.grey, end: const Color(0xFF42C993))
                                                                            .animate(
                                                                                _playAnimation)
                                                                            .value,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                ],
                                                              ),
                                                              Column(
                                                                children: [
                                                                  Text(
                                                                    prettyNumber(
                                                                        _milliseconds /
                                                                            100),
                                                                    style: GoogleFonts.cousine(
                                                                        color: ColorTween(begin: Colors.grey, end: Globals.orange)
                                                                            .animate(
                                                                                _playAnimation)
                                                                            .value,
                                                                        fontSize:
                                                                            35,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                  Text(
                                                                    "ms",
                                                                    style: GoogleFonts.cousine(
                                                                        fontSize:
                                                                            16,
                                                                        color: ColorTween(begin: Colors.grey, end: const Color(0xFF42C993))
                                                                            .animate(
                                                                                _playAnimation)
                                                                            .value,
                                                                        fontWeight:
                                                                            FontWeight.w300),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 20),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            StreamBuilder(
                                                                stream:
                                                                    _streamer,
                                                                initialData:
                                                                    null,
                                                                builder: (context,
                                                                    snapshot) {
                                                                  if (snapshot
                                                                      .hasData) {
                                                                    final data =
                                                                        snapshot
                                                                            .data!;
                                                                    return Text(
                                                                      prettyNumber(data
                                                                          .docs
                                                                          .length),
                                                                      style: GoogleFonts.poppins(
                                                                          fontSize:
                                                                              18,
                                                                          fontWeight:
                                                                              FontWeight.w400),
                                                                    );
                                                                  }

                                                                  return Text(
                                                                    "N/A",
                                                                    style: GoogleFonts.poppins(
                                                                        fontSize:
                                                                            18,
                                                                        fontWeight:
                                                                            FontWeight.w800),
                                                                  );
                                                                }),
                                                            const SizedBox(
                                                                height: 50),
                                                            Text(
                                                              " Users Playing Now",
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                      fontSize:
                                                                          18,
                                                                      color: Colors
                                                                          .black),
                                                            ),
                                                          ],
                                                        )
                                                      ],
                                                    ))),
                                                Card(
                                                  shape: const CircleBorder(),
                                                  color: ColorTween(
                                                          begin: Globals
                                                              .primaryColor,
                                                          end: Globals.white)
                                                      .animate(_playAnimation)
                                                      .value,
                                                  elevation: 40,
                                                  shadowColor: Globals.black
                                                      .withOpacity(.3),
                                                  surfaceTintColor:
                                                      Colors.white,
                                                  child: InkWell(
                                                    customBorder:
                                                        const CircleBorder(),
                                                    onTap: () {},
                                                    child: isRunning
                                                        ? GestureDetector(
                                                            onLongPress: () {
                                                              analytics
                                                                  .logEvent(
                                                                name:
                                                                    "Competition Game",
                                                              );
                                                              vibrateLonger();
                                                              _startTimer();
                                                              debugPrint(
                                                                  "Recording started");
                                                              playing = true;
                                                              _startController
                                                                  .forward();
                                                            },
                                                            onLongPressUp: () {
                                                              _stopTimer();
                                                              vibrateLonger();
                                                              playing = false;
                                                              _startController
                                                                  .reverse();
                                                              debugPrint(
                                                                  "Recording stopped");
                                                            },
                                                            onLongPressMoveUpdate:
                                                                (details) async {
                                                              int count = 0;

                                                              if (_passed &&
                                                                  location !=
                                                                      null) {
                                                                setState(() {
                                                                  HapticFeedback
                                                                      .heavyImpact();
                                                                  location =
                                                                      null;
                                                                });
                                                                return;
                                                              }
                                                              _passed = false;

                                                              switch (
                                                                  location) {
                                                                case Location
                                                                      .top:
                                                                  if (details
                                                                          .localPosition
                                                                          .dy <
                                                                      30) {
                                                                    count = 1;
                                                                  } else {
                                                                    count = -1;
                                                                  }
                                                                  break;
                                                                case Location
                                                                      .bottom:
                                                                  if (details
                                                                          .localPosition
                                                                          .dy >
                                                                      300) {
                                                                    count = 3;
                                                                  } else {
                                                                    count = -1;
                                                                  }
                                                                  break;

                                                                case Location
                                                                      .left:
                                                                  if (details
                                                                          .localPosition
                                                                          .dx <
                                                                      30) {
                                                                    count = 2;
                                                                  } else {
                                                                    count = -1;
                                                                  }
                                                                  break;

                                                                case Location
                                                                      .right:
                                                                  if (details
                                                                          .localPosition
                                                                          .dx >
                                                                      300) {
                                                                    count = 4;
                                                                  } else {
                                                                    count = -1;
                                                                  }
                                                                  break;

                                                                default:
                                                                  count = 5;
                                                              }

                                                              if (count > 0 &&
                                                                  count < 5) {
                                                                _passed = true;
                                                                for (int i = 0;
                                                                    i < 15;
                                                                    i++) {
                                                                  HapticFeedback
                                                                      .heavyImpact();
                                                                }

                                                                setState(() {
                                                                  location =
                                                                      null;
                                                                });
                                                              }
                                                            },
                                                            child: ClipOval(
                                                              child: SizedBox(
                                                                height:
                                                                    size.width *
                                                                        .85,
                                                                width:
                                                                    size.width *
                                                                        .85,
                                                                child: Stack(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  children: [
                                                                    AnimatedSwitcher(
                                                                      duration:
                                                                          mainDuration,
                                                                      switchInCurve:
                                                                          Curves
                                                                              .fastLinearToSlowEaseIn,
                                                                      transitionBuilder: (child, animation) => SizeTransition(
                                                                          sizeFactor:
                                                                              animation,
                                                                          child:
                                                                              Center(child: child)),
                                                                      child: _playAnimation.value <
                                                                              .9
                                                                          ? null
                                                                          : Lottie
                                                                              .asset(
                                                                              "$dir/round44.json",
                                                                              repeat: true,
                                                                              animate: true,
                                                                              filterQuality: FilterQuality.high,
                                                                              fit: BoxFit.contain,
                                                                              alignment: Alignment.center,
                                                                              options: LottieOptions(
                                                                                enableApplyingOpacityToLayers: true,
                                                                                enableMergePaths: true,
                                                                              ),
                                                                            ),
                                                                    ),
                                                                    Center(
                                                                      child: AnimatedBuilder(
                                                                          animation: _playAnimation,
                                                                          builder: (context, child) {
                                                                            return ClipOval(
                                                                              child: SizedBox(
                                                                                height: size.width * .68 + (size.width * .07 * _playAnimation.value),
                                                                                width: size.width * .68 + (size.width * .07 * _playAnimation.value),
                                                                                child: Card(
                                                                                  color: Globals.transparent,
                                                                                  elevation: 0,
                                                                                  clipBehavior: Clip.antiAlias,
                                                                                  child: ClipOval(
                                                                                    child: BackdropFilter(
                                                                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                                                                      child: SizedBox(height: size.width * .68 + (size.width * .07 * _playAnimation.value), width: size.width * .68 + (size.width * .07 * _playAnimation.value), child: const Text("")),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            );
                                                                          }),
                                                                    ),
                                                                    AnimatedSwitcher(
                                                                      duration:
                                                                          mainDuration,
                                                                      switchInCurve:
                                                                          Curves
                                                                              .fastLinearToSlowEaseIn,
                                                                      transitionBuilder: (child, animation) => SizeTransition(
                                                                          sizeFactor:
                                                                              animation,
                                                                          child:
                                                                              child),
                                                                      child: location !=
                                                                              Location.top
                                                                          ? null
                                                                          : Align(
                                                                              alignment: Alignment.topCenter,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.only(top: 8.0),
                                                                                child: ClipOval(
                                                                                  child: AnimatedContainer(
                                                                                    duration: mainDurationLonger,
                                                                                    alignment: Alignment.center,
                                                                                    width: _seconds % 5 == 0 ? 20 : 30,
                                                                                    height: _seconds % 5 == 0 ? 20 : 30,
                                                                                    curve: Curves.elasticInOut,
                                                                                    color: Globals.blue,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ),
                                                                    AnimatedSwitcher(
                                                                      duration:
                                                                          mainDuration,
                                                                      switchInCurve:
                                                                          Curves
                                                                              .fastLinearToSlowEaseIn,
                                                                      transitionBuilder: (child, animation) => SizeTransition(
                                                                          sizeFactor:
                                                                              animation,
                                                                          child:
                                                                              child),
                                                                      child: location !=
                                                                              Location.left
                                                                          ? null
                                                                          : Align(
                                                                              alignment: Alignment.centerLeft,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.only(left: 8.0),
                                                                                child: ClipOval(
                                                                                  child: AnimatedContainer(
                                                                                    duration: mainDurationLonger,
                                                                                    alignment: Alignment.center,
                                                                                    width: _seconds % 5 == 0 ? 20 : 30,
                                                                                    height: _seconds % 5 == 0 ? 20 : 30,
                                                                                    curve: Curves.elasticInOut,
                                                                                    color: Globals.orange,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ),
                                                                    AnimatedSwitcher(
                                                                      duration:
                                                                          mainDuration,
                                                                      switchInCurve:
                                                                          Curves
                                                                              .fastLinearToSlowEaseIn,
                                                                      transitionBuilder: (child, animation) => SizeTransition(
                                                                          sizeFactor:
                                                                              animation,
                                                                          child:
                                                                              child),
                                                                      child: location !=
                                                                              Location.right
                                                                          ? null
                                                                          : Align(
                                                                              alignment: Alignment.centerRight,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.only(right: 8.0),
                                                                                child: ClipOval(
                                                                                  child: AnimatedContainer(
                                                                                    duration: mainDurationLonger,
                                                                                    alignment: Alignment.center,
                                                                                    width: _seconds % 5 == 0 ? 20 : 30,
                                                                                    height: _seconds % 5 == 0 ? 20 : 30,
                                                                                    curve: Curves.elasticInOut,
                                                                                    color: Globals.pink,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ),
                                                                    AnimatedSwitcher(
                                                                      duration:
                                                                          mainDuration,
                                                                      switchInCurve:
                                                                          Curves
                                                                              .fastLinearToSlowEaseIn,
                                                                      transitionBuilder: (child, animation) => SizeTransition(
                                                                          sizeFactor:
                                                                              animation,
                                                                          child:
                                                                              child),
                                                                      child: location !=
                                                                              Location.bottom
                                                                          ? null
                                                                          : Align(
                                                                              alignment: Alignment.bottomCenter,
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.only(top: 8.0),
                                                                                child: ClipOval(
                                                                                  child: AnimatedContainer(
                                                                                    duration: mainDurationLonger,
                                                                                    alignment: Alignment.center,
                                                                                    width: _seconds % 5 == 0 ? 20 : 30,
                                                                                    height: _seconds % 5 == 0 ? 20 : 30,
                                                                                    curve: Curves.elasticInOut,
                                                                                    color: Globals.primaryColor,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ),
                                                                    Center(
                                                                      child:
                                                                          Column(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          CountDownText(
                                                                            due:
                                                                                competitionTime,
                                                                            finishedText:
                                                                                "Competition Finished",
                                                                            style: GoogleFonts.jost(
                                                                                fontSize: 25,
                                                                                fontWeight: FontWeight.w700,
                                                                                color: ColorTween(begin: Globals.white, end: Globals.primaryColor).animate(_playAnimation).value),
                                                                          ),
                                                                          const SizedBox(
                                                                            height:
                                                                                10,
                                                                          ),
                                                                          Text(
                                                                            "Hold & Win!",
                                                                            style: GoogleFonts.cousine(
                                                                                fontSize: 22,
                                                                                color: ColorTween(begin: Globals.white, end: Globals.primaryColor).animate(_playAnimation).value,
                                                                                fontWeight: FontWeight.w300),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                        : Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(58.0),
                                                            child: Center(
                                                              child: Text(
                                                                "Competition Ended",
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            top: 0,
                                            height: 190,
                                            width: size.width,
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: SizedBox(
                                                width: size.width * .98,
                                                height: 40.0,
                                                child: Material(
                                                  elevation:
                                                      location == null ? 0 : 10,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              60)),
                                                  color: location ==
                                                          Location.top
                                                      ? Globals.blue
                                                      : location ==
                                                              Location.left
                                                          ? Globals.orange
                                                          : location ==
                                                                  Location.right
                                                              ? Globals.pink
                                                              : location ==
                                                                      Location
                                                                          .bottom
                                                                  ? Globals
                                                                      .primaryColor
                                                                  : Colors
                                                                      .white,
                                                  shadowColor: (location ==
                                                              Location.top
                                                          ? Globals.blue
                                                          : location ==
                                                                  Location.left
                                                              ? Globals.orange
                                                              : location ==
                                                                      Location
                                                                          .right
                                                                  ? Globals.pink
                                                                  : Colors
                                                                      .black)
                                                      .withOpacity(.25),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Center(
                                                        child: Text(
                                                      _passed
                                                          ? "Good you're still with us😊"
                                                          : "Swipe your hand to the Dot to avoid Knockout",
                                                      style:
                                                          GoogleFonts.poppins(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12),
                                                    )),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ).animate(
                                              target: _showMessage ? 1 : 0,
                                              effects: [
                                                const ScaleEffect(
                                                    duration: mainDuration,
                                                    curve: Curves
                                                        .fastLinearToSlowEaseIn,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    begin: Offset(0, 0),
                                                    end: Offset(1, 1)),
                                                const FadeEffect(
                                                  duration: mainDuration,
                                                  curve: Curves
                                                      .fastLinearToSlowEaseIn,
                                                  begin: 0,
                                                  end: 1,
                                                )
                                              ])
                                        ],
                                      ),
                            Leaderboard(
                              isRunning: isRunning,
                              competitionTime: competitionTime,
                            )
                          ],
                        ),
                      ),
                      Positioned(
                          width: size.width,
                          height: kToolbarHeight,
                          top: 50,
                          left: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Material(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 10,
                                color: Colors.white,
                                shadowColor: Colors.black.withOpacity(.075),
                                child: InkWell(
                                  customBorder: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  onTap: () {
                                    setState(() {
                                      _move = true;
                                    });
                                    _pageController.animateToPage(0,
                                        duration: mainDuration,
                                        curve: Curves.elasticOut);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          !isRunning ? "Ended" : "Play & Win",
                                          style: GoogleFonts.poppins(
                                              color: Globals.black),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          !isRunning ? "🛑" : "😊",
                                          style: GoogleFonts.poppins(
                                              color: Globals.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Material(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 10,
                                  shadowColor: Colors.black.withOpacity(.075),
                                  color: Colors.white,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _move = false;
                                      });

                                      _pageController.animateToPage(1,
                                          duration: mainDurationLonger,
                                          curve: Curves.fastLinearToSlowEaseIn);
                                    },
                                    customBorder: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            "Leaderboard",
                                            style: GoogleFonts.poppins(
                                                color: Globals.black),
                                          ),
                                          const SizedBox(width: 16),
                                          const Icon(FontAwesomeIcons.trophy,
                                              color: Globals.black, size: 16),
                                        ],
                                      ),
                                    ),
                                  )),
                              SizedBox(
                                width: 30,
                                height: 30,
                                child: MaterialButton(
                                  onPressed: () async {
                                    await showCupertinoModalPopup(
                                        context: context,
                                        builder: (_) {
                                          return CupertinoAlertDialog(
                                            insetAnimationDuration:
                                                mainDurationLonger,
                                            insetAnimationCurve:
                                                Curves.fastLinearToSlowEaseIn,
                                            title: const Text('How To Play',
                                                style: Globals.heading),
                                            content: const Text(
                                                'The rules of the game are simple:\n1. Anyone can play, whether you\'re a seller, Buyer, or it\'s your first time opening our app.\n'
                                                "\n2.You Play by simply pressing on the big button for as long as possible. Your time is measured as long as you're pressing the button"
                                                "\n\n3.You stop playing by either removing your finger from the button, or Failing to swipe your pressing finger over the Dot that appears within 20 seconds after it appears without raising your finger."
                                                "\n\n4. Everyone has a chance of winning the cash prize since at the end of the game, the cash prize will be available to the first 40 winners"
                                                "\n\n5. You can also make money by referring winners, so when a person you referred wins, you win too🥈✅"
                                                "\n\nSo Play with confidence and track your score on the Leaderboard🫡"),
                                            actions: <Widget>[
                                              CupertinoDialogAction(
                                                child: Text(
                                                  'Got It',
                                                  style: GoogleFonts.poppins(
                                                      color:
                                                          Globals.primaryColor),
                                                ),
                                                onPressed: () {
                                                  HapticFeedback.heavyImpact();

                                                  Navigator.of(context)
                                                      .pop(true);
                                                },
                                              ),
                                            ],
                                          );
                                        });
                                  },
                                  elevation: 0,
                                  textColor: Globals.pink,
                                  color: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                  child: const Icon(FontAwesomeIcons.info,
                                      size: 16),
                                ),
                              )
                            ],
                          )),
                      if (_activationTime.isAfter(Globals.globalTime))
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                          child: Stack(
                            children: [
                              Positioned(
                                  child: Container(
                                width: size.width,
                                height: size.height,
                                color: Globals.black.withOpacity(.85),
                                child: Align(
                                    child: Lottie.asset("$dir/misc11.json",
                                        fit: BoxFit.contain)),
                              )),
                              SizedBox(
                                width: size.width,
                                height: size.height,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 108.0),
                                      child: Lottie.asset(
                                        "$dir/competition1.json",
                                        fit: BoxFit.contain,
                                        height: 100,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 58.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            "Coming Soon",
                                            style: Globals.whiteBoldText,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Card(
                                      color: Globals.white,
                                      margin: EdgeInsets.zero,
                                      surfaceTintColor: Colors.white,
                                      elevation: 30,
                                      shadowColor: Colors.black.withOpacity(.4),
                                      shape: Globals.radius(0),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            top: 25.0, bottom: 58.0),
                                        child: SwitchListTile(
                                          value: _notify,
                                          onChanged: (v0) async {
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            prefs.setBool("notify", v0);
                                            setState(() {
                                              _notify = v0;
                                            });

                                            if (v0) {
                                              messaging
                                                  .subscribeToTopic(
                                                      "competition")
                                                  .then((value) => toast(
                                                      message:
                                                          "You will recieve a notification to play"));
                                            }
                                          },
                                          shape: Globals.radius(8),
                                          tileColor: Globals.white,
                                          activeTrackColor:
                                              Globals.primaryColor,
                                          dense: true,
                                          isThreeLine: true,
                                          inactiveTrackColor:
                                              const Color(0xfff6f6f6),
                                          subtitle: const Text(
                                            "We'll notify you immediately",
                                            style: Globals.subtitle,
                                          ),
                                          title: const Text(
                                            "Tell me when It's live",
                                            style: Globals.title,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                    ],
                  ),
                );
              }),
    );
  }
}

enum Location { top, bottom, left, right }
