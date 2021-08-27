import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scotrail_sabotage/home.dart';
import 'package:scotrail_sabotage/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(),
      child: Consumer<ThemeModel>(
        builder: (_, model, __) {
          return MaterialApp(
            title: 'Road or Rails?',
            theme: ThemeData(
              primarySwatch: Colors.red,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.red,
              brightness: Brightness.dark,
            ),
            themeMode: model.mode,
            home: Home(
              themeModel: model,
            ),
          );
        },
      ),
    );
  }
}

class ThemeModel with ChangeNotifier {
  ThemeMode mode;

  ThemeModel({ThemeMode mode = ThemeMode.light}) : mode = mode;

  void toggleMode() {
    mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}