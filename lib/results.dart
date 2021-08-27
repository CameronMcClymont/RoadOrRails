import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:timeline_tile/timeline_tile.dart';

class Results extends StatelessWidget {
  final double costToDrive;
  final int timeToDrive; // Total trip driving time in seconds
  final String originPostcode;
  final String destPostcode;
  final double drivingDistance;

  final double costToTrain;
  final int timeToOriginStation; // Time to walk to origin station in seconds
  final int timeOnTrain; // Time spent on train in seconds
  final int timeToDestStation; // Time to walk from destination station in seconds
  final String originStation;
  final String destStation;
  final double distToOriginStation; // Miles
  final double distToDestStation; // Miles
  final int numChanges;

  const Results(
      {Key? key,
      required this.costToDrive,
      required this.timeToDrive,
      required this.originPostcode,
      required this.destPostcode,
      required this.drivingDistance,
      required this.costToTrain,
      required this.timeToOriginStation,
      required this.timeOnTrain,
      required this.timeToDestStation,
      required this.originStation,
      required this.destStation,
      required this.distToOriginStation,
      required this.distToDestStation,
      required this.numChanges})
      : super(key: key);

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget timelineLabel(Alignment alignment, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: alignment,
        child: Text(text),
      ),
    );
  }

  TimelineTile timelineTile(BuildContext context, bool isLeft, String nodeText,
      {String? cardTopText, String? cardBottomText, Icon? icon, visibleDot = true, bool isFirst = false, bool isLast = false}) {
    Widget labelChild = Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 130,
          child: timelineLabel(isLeft ? Alignment.centerLeft : Alignment.centerRight, nodeText),
        ),
        if (cardTopText != null && cardBottomText != null)
          Positioned(
            bottom: -31,
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(cardTopText),
                    Text(cardBottomText),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    Widget iconChild = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: -10,
          child: Align(
            alignment: isLeft ? Alignment.bottomRight : Alignment.bottomLeft,
            child: icon,
          ),
        ),
      ],
    );

    return TimelineTile(
      alignment: TimelineAlign.manual,
      lineXY: isLeft ? 0.2 : 0.8,
      indicatorStyle: IndicatorStyle(width: 20, color: visibleDot ? Theme.of(context).primaryColor : Colors.transparent),
      beforeLineStyle: const LineStyle(color: Colors.black54, thickness: 3),
      afterLineStyle: const LineStyle(color: Colors.black54, thickness: 3),
      isFirst: isFirst,
      isLast: isLast,
      startChild: isLeft ? iconChild : labelChild,
      endChild: isLeft ? labelChild : iconChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalTimeToTrain = timeToOriginStation + timeOnTrain + timeToDestStation;

    double costDifference = 100 * costToTrain / costToDrive;
    double timeDifference = 100 * totalTimeToTrain.roundToDouble() / timeToDrive.roundToDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.drive_eta),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('£${costToDrive.toStringAsFixed(2)}'),
                          Text(formatDuration(Duration(seconds: timeToDrive))),
                        ],
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      Column(
                        children: [
                          Text(
                            (costDifference > 0 ? '+' : (costDifference < 0 ? '-' : '=')) + '${costDifference.round()}%',
                            style: TextStyle(color: costDifference > 0 ? Colors.red : (costDifference < 0 ? Colors.green : Colors.black), fontWeight: FontWeight.bold),
                          ),
                          Text(
                            (timeDifference > 0 ? '+' : (timeDifference < 0 ? '-' : '=')) + '${timeDifference.round()}%',
                            style: TextStyle(color: timeDifference > 0 ? Colors.red : (timeDifference < 0 ? Colors.green : Colors.black), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('£${costToTrain.toStringAsFixed(2)}'),
                          Text(formatDuration(Duration(seconds: totalTimeToTrain))),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.train),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        timelineTile(context, true, 'G613BD', isFirst: true),
                        timelineTile(
                          context,
                          true,
                          '',
                          cardTopText: formatDuration(Duration(seconds: timeToDrive)),
                          cardBottomText: '${drivingDistance.toStringAsFixed(2)} miles',
                          icon: const Icon(Icons.drive_eta),
                          visibleDot: false,
                        ),
                        timelineTile(context, true, '', visibleDot: false),
                        timelineTile(context, true, 'G613BD', isLast: true),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        timelineTile(
                          context,
                          false,
                          'G613BD',
                          cardTopText: formatDuration(Duration(seconds: timeToOriginStation)),
                          cardBottomText: '$distToOriginStation miles',
                          icon: const Icon(Icons.directions_walk),
                          isFirst: true,
                        ),
                        timelineTile(
                          context,
                          false,
                          'Hillfoot',
                          cardTopText: formatDuration(Duration(seconds: timeOnTrain)),
                          cardBottomText: numChanges == 0 ? 'Direct' : '$numChanges change(s)',
                          icon: const Icon(Icons.train),
                        ),
                        timelineTile(
                          context,
                          false,
                          'Jordanhill',
                          cardTopText: formatDuration(Duration(seconds: timeToDestStation)),
                          cardBottomText: '$distToDestStation miles',
                          icon: const Icon(Icons.directions_walk),
                        ),
                        timelineTile(context, false, 'G613BD', isLast: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
