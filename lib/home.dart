import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geocoder/geocoder.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:scotrail_sabotage/result.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String distanceMatrixKey = 'AIzaSyCRr4Jq5-rXRIX8NPBtH8OqQvYg9XGzhBU';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController originController = TextEditingController();
  final TextEditingController destController = TextEditingController();
  final TextEditingController numPassengersController = TextEditingController();
  final TextEditingController fuelEfficiencyController = TextEditingController();
  final TextEditingController parkingCostController = TextEditingController();
  final TextEditingController hoursParkedController = TextEditingController();
  final TextEditingController fuelPriceController = TextEditingController();
  bool isLoading = false;

  bool isReturnJourney = false;

  String originStation = '';
  String destStation = '';
  int timeToWalkToOriginStation = 0; // seconds
  int timeOnTrain = 0; // seconds
  int timeToWalkToDestStation = 0; // seconds
  double trainPrice = 0; // pounds
  static const double walkingSpeed = 3; // miles per hour

  int fuelType = 0; // 0 = petrol, 1 = diesel, 2 = electric
  List<double> fuelPrices = [0, 0, 0]; // pence (petrol), pence (diesel), pence (electric)
  double drivingDistance = 0; // miles
  int drivingTime = 0; // seconds
  double milesPerGallon = 0;

  Future setFuelPrices() async {
    final response = await http.get(Uri.parse('https://www.arval.co.uk/about-arval/insights/average-uk-fuel-prices'));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        var table = document.getElementById('tablefield-0')!.children[1];
        List<String> fuelProviders = table.children.map((row) => row.children[0].text).toList();
        List<double> petrolPrices = table.children.map((row) => double.parse(row.children[2].text)).toList();
        List<double> dieselPrices = table.children.map((row) => double.parse(row.children[1].text)).toList();

        print(fuelProviders);

        setState(() {
          fuelPrices = [petrolPrices.reduce(min), dieselPrices.reduce(min), 17.2];
          fuelPriceController.text = fuelPrices[fuelType].toStringAsFixed(1);
        });
      } catch (e) {
        print('(setFuelPrices) Error: ' + e.toString());
      }
    } else {
      print('(setFuelPrices) Error: response status code = ${response.statusCode.toString()}.');
    }
  }

  Future<bool> setTrainPriceTime() async {
    final response = await http.get(Uri.parse('https://traintimes.org.uk/$originStation/$destStation/first/today/last/today'));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        var firstTrain = document.getElementById('result0')!;
        String price;
        if (isReturnJourney) {
          price = firstTrain.getElementsByClassName('tooltip').first.text.substring(1);
        } else {
          price = firstTrain.getElementsByClassName('tooltip')[1].text.substring(1);
        }

        var timesElement = firstTrain.getElementsByTagName('strong').first;
        String timesElementText = timesElement.text.replaceAll('\n', '');
        timesElementText = timesElementText.replaceAll('\t', '');
        timesElementText = timesElementText.replaceAll(' ', '');

        String firstTime = timesElementText.substring(0, 5);
        String firstHour = firstTime.substring(0, 2);
        String firstMinute = firstTime.substring(3);

        String secondTime = timesElementText.substring(6);
        String secondHour = secondTime.substring(0, 2);
        String secondMinute = secondTime.substring(3);

        Duration travelDuration = DateTime(2021, 8, 25, int.parse(secondHour), int.parse(secondMinute)).difference(DateTime(2021, 8, 25, int.parse(firstHour), int.parse(firstMinute)));

        setState(() {
          trainPrice = double.parse(price);
          timeOnTrain = travelDuration.inSeconds;
        });
      } catch (e) {
        print('(setTrainPriceTime) Error: ' + e.toString());
        return false;
      }
    } else {
      print('(setTrainPriceTime) Error: response status code = ${response.statusCode.toString()}. Origin: $originStation, destination: $destStation');
      return false;
    }

    return true;
  }

  double calcCostToDrive() {
    double parkingCost = double.parse(parkingCostController.text);
    double hoursParked = double.parse(hoursParkedController.text);
    double parking = parkingCost * hoursParked;

    if (fuelType < 2) {
      // Petrol/diesel
      double milesPerGallon = double.parse(fuelEfficiencyController.text);
      if (milesPerGallon > 0) {
        double pencePerLitre = double.parse(fuelPriceController.text);
        double poundsPerLitre = pencePerLitre / 100;
        double poundsPerGallon = poundsPerLitre / 0.219969;
        double gallons = drivingDistance / milesPerGallon;

        double travel = poundsPerGallon * gallons;

        return travel + parking;
      }
    } else {
      // Electric
      double milesPerKwh = double.parse(fuelEfficiencyController.text);
      double pencePerKwh = double.parse(fuelPriceController.text);

      double poundsPerKwh = pencePerKwh / 100;
      double kwhPerMile = 1 / milesPerKwh;
      double kwhs = kwhPerMile * drivingDistance;

      double travel = kwhs * poundsPerKwh;

      return travel + parking;
    }

    return -1;
  }

  /// Finds the nearest train station to `postcode` and sets the origin station or
  /// destination station according to `isOrigin`.
  Future<bool> setNearestStation(String postcode, bool isOrigin) async {
    final response = await http.get(Uri.parse('https://traintimes.org.uk/$postcode/glc/first/today/last/today'));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        var content = document.getElementById('content')!;

        var header = content.getElementsByTagName('h2').first;
        String station = header.text.substring(0, header.text.indexOf('[')).trimRight();

        var distanceElement = header.getElementsByTagName('strong').first;
        String distance = distanceElement.text.substring(0, distanceElement.text.indexOf(' '));
        int walkingTime = (60 * 60 * double.parse(distance) / walkingSpeed).round();

        if (isOrigin) {
          setState(() {
            originStation = station;
            timeToWalkToOriginStation = walkingTime;
          });
        } else {
          setState(() {
            destStation = station;
            timeToWalkToDestStation = walkingTime;
          });
        }
      } catch (e) {
        print('(setNearestStation) Error: ' + e.toString());
        return false;
      }
    } else {
      print('(setNearestStation) Error: response status code = ${response.statusCode.toString()}. Postcode = $postcode, isOrigin = $isOrigin');
      return false;
    }

    return true;
  }

  Future<bool> setDrivingDistTime(String originPostcode, String destPostcode) async {
    Address originAddress;
    try {
      originAddress = (await Geocoder.local.findAddressesFromQuery(originPostcode)).first;
    } catch (e) {
      print('No address found for origin postcode: $originPostcode.');
      return false;
    }

    String originLat = originAddress.coordinates.latitude.toString();
    String originLong = originAddress.coordinates.longitude.toString();

    Address destAddress;
    try {
      destAddress = (await Geocoder.local.findAddressesFromQuery(destPostcode)).first;
    } catch (e) {
      print('No address found for destination postcode: $destPostcode.');
      return false;
    }

    String destLat = destAddress.coordinates.latitude.toString();
    String destLong = destAddress.coordinates.longitude.toString();

    final String query = 'origins=$originLat,$originLong&destinations=$destLat,$destLong';
    http.Response response = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/distancematrix/json?$query&key=$distanceMatrixKey'));
    Map<String, dynamic> result = jsonDecode(response.body)['rows'][0]['elements'][0];

    setState(() {
      drivingDistance = result['distance']['value'] / 1609;
      if (isReturnJourney) {
        drivingDistance *= 2;
      }

      drivingTime = result['duration']['value'];
    });

    return true;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance!.addPostFrameCallback((_) {
      setFuelPrices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Road or Rails?')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: originController,
                  decoration: const InputDecoration(labelText: 'Origin postcode'),
                  validator: (value) {
                    String postcode = value!.replaceAll(' ', '');
                    if (postcode.length >= 5 && postcode.length <= 6) {
                      return null;
                    }

                    return 'Postcode must be 5-6 characters.';
                  },
                ),
                TextFormField(
                  controller: destController,
                  decoration: const InputDecoration(labelText: 'Destination postcode'),
                  validator: (value) {
                    String postcode = value!.replaceAll(' ', '');
                    if (postcode.length >= 5 && postcode.length <= 6) {
                      return null;
                    }

                    return 'Postcode must be 5-6 characters.';
                  },
                ),
                TextFormField(
                  controller: numPassengersController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of passengers'),
                ),
                Row(
                  children: [
                    const Text('Return journey:'),
                    const SizedBox(width: 8),
                    DropdownButton(
                      value: isReturnJourney,
                      onChanged: (bool? newValue) {
                        setState(() {
                          isReturnJourney = newValue!;
                        });
                      },
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('True'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('False'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(thickness: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text('Fuel type:'),
                        const SizedBox(width: 8),
                        DropdownButton(
                          value: fuelType,
                          onChanged: (int? newValue) {
                            setState(() {
                              fuelType = newValue!;
                              fuelPriceController.text = fuelPrices[fuelType].toStringAsFixed(1);
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Petrol'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('Diesel'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Electric'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: fuelPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: fuelType == 2 ? 'Price per kWh (p)' : 'Price per litre (p)'),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: fuelEfficiencyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: fuelType == 2 ? 'Miles per kWh' : 'Miles per gallon'),
                  onChanged: (newValue) {
                    setState(() {
                      milesPerGallon = double.tryParse(newValue) ?? 0;
                    });
                  },
                ),
                TextFormField(
                  controller: parkingCostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Parking cost per hour (£)'),
                ),
                TextFormField(
                  controller: hoursParkedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hours parked'),
                ),
                const Divider(thickness: 1),
                TextButton(
                  child: const Text('Submit'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        isLoading = true;
                      });

                      String originPostcode = originController.text.replaceAll(' ', '');
                      String destPostcode = destController.text.replaceAll(' ', '');

                      setState(() {
                        setDrivingDistTime(originPostcode, destPostcode).then((wasSuccessful) {
                          if (!wasSuccessful) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to calculate driving time.")));
                            return;
                          }

                          setNearestStation(originPostcode, true).then((wasSuccessful) {
                            if (!wasSuccessful) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to find nearest origin train station.")));
                              return;
                            }

                            setNearestStation(destPostcode, false).then((wasSuccessful) {
                              if (!wasSuccessful) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to find nearest destination train station.")));
                                return;
                              }

                              if (originStation.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Origin station was empty.")));
                                return;
                              }

                              if (destStation.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Origin station was empty.")));
                                return;
                              }

                              setTrainPriceTime().then((wasSuccessful) {
                                if (!wasSuccessful) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't fetch train prices/times.")));
                                  return;
                                }

                                double costToDrive = calcCostToDrive();
                                if (costToDrive == -1) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't calculate cost to drive.")));
                                  return;
                                }

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => Result(
                                      originStation,
                                      destStation,
                                      drivingDistance,
                                      costToDrive,
                                      trainPrice * int.parse(numPassengersController.text),
                                      drivingTime,
                                      timeToWalkToOriginStation + timeOnTrain + timeToWalkToDestStation,
                                    ),
                                  ),
                                );
                              });
                            });
                          });
                        });
                      });
                    }

                    isLoading = false;
                  },
                ),
                Visibility(
                  visible: isLoading,
                  child: const CircularProgressIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
