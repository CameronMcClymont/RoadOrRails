import 'package:flutter/material.dart';

class Result extends StatelessWidget {
  final String originStation;
  final String destStation;
  final double drivingDistance;
  final double costToDrive;
  final double costToTrain;
  final int timeToDrive;
  final int timeToTrain;

  const Result(this.originStation, this.destStation, this.drivingDistance, this.costToDrive, this.costToTrain, this.timeToDrive, this.timeToTrain, {Key? key}) : super(key: key);

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Driving distance: ' + drivingDistance.toStringAsFixed(2) + ' miles'),
              Text('Time to drive: ' + formatDuration(Duration(seconds: timeToDrive))),
              Text('Time to take train: ' + formatDuration(Duration(seconds: timeToTrain))),
              Text('Nearest origin station: ' + originStation),
              Text('Nearest destination station: ' + destStation),
              const SizedBox(height: 16),
              Text('Cost to drive: £' + costToDrive.toStringAsFixed(2)),
              Text('Cost to take train: £' + costToTrain.toStringAsFixed(2)),
              if (costToDrive != 0 && costToTrain != 0)
                costToDrive < costToTrain
                    ? Text('Driving is ' + (costToTrain / costToDrive).toStringAsFixed(2) + ' times cheaper than taking the train!')
                    : Text('Taking the train is ' + (costToDrive / costToTrain).toStringAsFixed(2) + ' times cheaper than driving!')
            ],
          ),
        ),
      ),
    );
  }
}
