import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoder/geocoder.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:scotrail_sabotage/results.dart';
import 'package:scotrail_sabotage/settings.dart';
import 'package:scotrail_sabotage/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class Home extends StatefulWidget {
  final ThemeModel themeModel;

  const Home({Key? key, required this.themeModel}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String distanceMatrixKey = 'AIzaSyCRr4Jq5-rXRIX8NPBtH8OqQvYg9XGzhBU';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController originController = TextEditingController();
  final TextEditingController destController = TextEditingController();
  final TextEditingController fuelEfficiencyController = TextEditingController();
  final TextEditingController parkingCostController = TextEditingController();
  final TextEditingController hoursParkedController = TextEditingController();
  final TextEditingController fuelPriceController = TextEditingController();

  double loadingProgress = 0;
  String loadingMessage = '';

  int numAdults = 1;
  int numKids = 0;
  bool isReturnJourney = false;
  List<String> railcards = ['None'];
  String railcard = 'None';
  int numRailcards = 1;

  int fuelType = 0; // 0 = petrol, 1 = diesel, 2 = electric
  List<double> fuelPrices = [0, 0, 0]; // pence (petrol), pence (diesel), pence (electric)
  double drivingDistance = 0; // miles
  int timeToDrive = 0; // seconds
  double milesPerGallon = 0;

  String originStation = '';
  String destStation = '';
  double distToOriginStation = 0; // miles
  double distToDestStation = 0; // miles
  int timeToOriginStation = 0; // seconds
  int timeToDestStation = 0; // seconds
  int timeOnTrain = 0; // seconds
  double costToTrain = 0; // pounds
  int numChanges = 0;
  static const double walkingSpeed = 3; // miles per hour

  Future setFuelPricesAndRailcards() async {
    // Fetch fuel prices
    http.Response response = await http.get(Uri.parse('https://www.arval.co.uk/about-arval/insights/average-uk-fuel-prices'));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        var table = document.getElementById('tablefield-0')!.children[1];
        List<String> fuelProviders = table.children.map((row) => row.children[0].text).toList();
        List<double> petrolPrices = table.children.map((row) => double.parse(row.children[2].text)).toList();
        List<double> dieselPrices = table.children.map((row) => double.parse(row.children[1].text)).toList();

        setState(() {
          fuelPrices = [petrolPrices.reduce(min), dieselPrices.reduce(min), 17.2];
          fuelPriceController.text = fuelPrices[fuelType].toStringAsFixed(1);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't fetch latest fuel price.")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't fetch latest fuel price.")));
    }

    // Fetch railcards
    response = await http.get(Uri.parse('https://traintimes.org.uk'));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        var dropdown = document.getElementById('railcard')!.children.sublist(1); // Skip 'None' value
        setState(() {
          railcards.addAll(dropdown.map((e) => e.text));
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't fetch railcards.")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't fetch railcards.")));
    }
  }

  double calcCostToDrive() {
    double parkingCost = double.tryParse(parkingCostController.text) ?? 0;
    double hoursParked = double.tryParse(hoursParkedController.text) ?? 0;
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

  Future<bool> setDrivingDistTime(String originPostcode, String destPostcode) async {
    Address originAddress;
    try {
      originAddress = (await Geocoder.local.findAddressesFromQuery(originPostcode)).first;
    } catch (e) {
      return false;
    }

    String originLat = originAddress.coordinates.latitude.toString();
    String originLong = originAddress.coordinates.longitude.toString();

    Address destAddress;
    try {
      destAddress = (await Geocoder.local.findAddressesFromQuery(destPostcode)).first;
    } catch (e) {
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

      timeToDrive = result['duration']['value'];
    });

    return true;
  }

  /// Finds the nearest train station to `postcode` and sets the origin station or
  /// destination station according to `isOrigin`.
  Future<bool> setNearestStation(String postcode, bool isOrigin) async {
    final response = await http.get(Uri.parse('https://traintimes.org.uk/$postcode/glc/first/tomorrow/last/tomorrow'));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        var content = document.getElementById('content')!;

        var header = content.getElementsByTagName('h2').first;
        String station = header.text.substring(0, header.text.indexOf('[')).trimRight();

        var distanceElement = header.getElementsByTagName('strong').first;
        double distance = double.parse(distanceElement.text.substring(0, distanceElement.text.indexOf(' ')));
        int walkingTime = (60 * 60 * distance / walkingSpeed).round();

        if (isOrigin) {
          setState(() {
            originStation = station;
            timeToOriginStation = walkingTime;
            distToOriginStation = distance;
          });
        } else {
          setState(() {
            destStation = station;
            timeToDestStation = walkingTime;
            distToDestStation = distance;
          });
        }
      } catch (e) {
        return false;
      }
    } else {
      return false;
    }

    return true;
  }

  Future<bool> setTrainPriceAndTime() async {
    String url = 'https://traintimes.org.uk/$originStation/$destStation/first/tomorrow/last/tomorrow?adults=$numAdults&kids=$numKids';
    if (railcard != 'None') {
      url += '&railcard=${railcard.substring(railcard.indexOf('(') + 1, railcard.indexOf(')'))}&railcardN=$numRailcards';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      try {
        // Get the first result
        var firstTrain = document.getElementById('result0')!;

        // Get the number of changes
        // .substring(0, 2) assumes 99 or fewer changes
        String numChangesStr = firstTrain.getElementsByClassName('change_link').first.text.substring(0, 2).trimRight();
        // If the number of changes can't be parsed, the string is 'Direct' so there are no changes
        numChanges = int.tryParse(numChangesStr) ?? 0;

        // Get the train cost
        String price;
        if (isReturnJourney) {
          // The return ticket price is in the first element with the 'tooltip' class
          price = firstTrain.getElementsByClassName('tooltip').first.text.substring(1);
        } else {
          // The single ticket price is in the first element with the 'tooltip' class
          price = firstTrain.getElementsByClassName('tooltip')[1].text.substring(1);
        }

        // Get the time spend on the train
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
          costToTrain = double.parse(price);
          timeOnTrain = travelDuration.inSeconds;
        });
      } catch (e) {
        return false;
      }
    } else {
      return false;
    }

    return true;
  }

  setSharedPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (prefs.getBool(Settings.toggleDarkModeKey) ?? false) {
        setState(() {
          widget.themeModel.mode = ThemeMode.dark;
        });
      } else {
        setState(() {
          widget.themeModel.mode = ThemeMode.light;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance!.addPostFrameCallback((_) {
      setSharedPrefs();
      setFuelPricesAndRailcards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road or Rails?'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Settings(themeModel: widget.themeModel),
                ),
              );
            },
            icon: const Icon(Icons.settings),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                PostcodeField(controller: originController, label: 'Origin postcode'),
                PostcodeField(controller: destController, label: 'Destination postcode'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Row(
                      children: [
                        const Text('Adults:'),
                        IconButton(
                          onPressed: () {
                            if (numAdults > 0) {
                              setState(() {
                                numAdults -= 1;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove),
                        ),
                        Text(numAdults.toString()),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              numAdults += 1;
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Text('Kids:'),
                        IconButton(
                          onPressed: () {
                            if (numKids > 0) {
                              setState(() {
                                numKids -= 1;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove),
                        ),
                        Text(numKids.toString()),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              numKids += 1;
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
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
                const Divider(thickness: 1),
                Row(
                  children: [
                    const Text('Railcard:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton(
                        isExpanded: true,
                        value: railcard,
                        onChanged: (String? newValue) {
                          setState(() {
                            railcard = newValue!;
                          });
                        },
                        items: railcards.map(
                          (railcard) => DropdownMenuItem(
                            child: Text(railcard),
                            value: railcard,
                          ),
                        ).toList(),
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: railcard != 'None',
                  child: Row(
                    children: [
                      const Text('Quantity:'),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          if (numRailcards > 1) {
                            setState(() {
                              numRailcards -= 1;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      Text(numRailcards.toString()),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            numRailcards += 1;
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                Row(
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
                        decoration: InputDecoration(labelText: fuelType == 2 ? 'Price per kWh' : 'Price per litre', hintText: 'Pennies'),
                        validator: (value) {
                          if (value != null && double.parse(value) <= 0) {
                            return 'Value must be greater than 0.';
                          }
                        },
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: fuelEfficiencyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: fuelType == 2 ? 'Miles per kWh' : 'Miles per gallon', hintText: 'Miles'),
                  onChanged: (newValue) {
                    setState(() {
                      milesPerGallon = double.tryParse(newValue) ?? 0;
                    });
                  },
                  validator: (value) {
                    if (value != null) {
                      if (value.isEmpty) {
                        return 'Field cannot be empty.';
                      }

                      if (double.parse(value) < 0) {
                        return 'Value must be at least 0.';
                      }
                    }
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: parkingCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Parking cost per hour', hintText: '(Optional) £'),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.parse(value) < 0) {
                            return 'Value must be at least 0.';
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: hoursParkedController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hours parked', hintText: '(Optional) hours'),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && double.parse(value) < 0) {
                            return 'Value must be at least 0.';
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(thickness: 1),
                TextButton(
                  child: const Text('Calculate'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (numAdults == 0 && numKids == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add some passengers!")));
                      } else {
                        if (numRailcards > numAdults + numKids) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("There can't be more railcards than passengers!")));
                        } else {
                          String originPostcode = originController.text.replaceAll(' ', '');
                          String destPostcode = destController.text.replaceAll(' ', '');

                          setState(() {
                            loadingProgress = 0.1;
                            loadingMessage = 'Finding origin station...';
                          });

                          bool wasSuccessful = await setNearestStation(originPostcode, true);
                          if (!wasSuccessful) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to find nearest origin train station.")));
                          } else {
                            setState(() {
                              loadingProgress = 0.35;
                              loadingMessage = 'Finding destination station...';
                            });

                            wasSuccessful = await setNearestStation(destPostcode, false);
                            if (!wasSuccessful) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to find nearest destination train station.")));
                            } else {
                              setState(() {
                                loadingProgress = 0.55;
                                loadingMessage = 'Fetching train times...';
                              });

                              wasSuccessful = await setTrainPriceAndTime();
                              if (!wasSuccessful) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't fetch train prices/times.")));

                              } else {
                                setState(() {
                                  loadingProgress = 0.99;
                                  loadingMessage = 'Calculating driving time...';
                                });

                                if (originStation.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Origin station was empty.")));
                                  return;
                                }

                                if (destStation.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Origin station was empty.")));
                                  return;
                                }

                                wasSuccessful = await setDrivingDistTime(originPostcode, destPostcode);
                                if (!wasSuccessful) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't calculate route. Please make sure both postcodes are correct.")));
                                } else {
                                  double costToDrive = calcCostToDrive();
                                  if (costToDrive == -1) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't calculate cost to drive.")));
                                    return;
                                  }

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => Results(
                                        costToDrive: costToDrive,
                                        timeToDrive: timeToDrive,
                                        originPostcode: originController.text,
                                        destPostcode: destController.text,
                                        drivingDistance: drivingDistance,
                                        costToTrain: costToTrain,
                                        timeToOriginStation: timeToOriginStation,
                                        timeOnTrain: timeOnTrain,
                                        timeToDestStation: timeToDestStation,
                                        originStation: originStation,
                                        destStation: destStation,
                                        distToOriginStation: distToOriginStation,
                                        distToDestStation: distToDestStation,
                                        numChanges: numChanges,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        }
                      }
                    }

                    setState(() {
                      loadingProgress = 0;
                      loadingMessage = '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: max(0, loadingProgress - 0.25), end: loadingProgress),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, value, __) => CircularProgressIndicator(value: value),
                ),
                const SizedBox(height: 16),
                Text(loadingMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
