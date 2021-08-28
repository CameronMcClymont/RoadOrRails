import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:road_or_rails/home.dart';

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
              primarySwatch: model.primaryColor,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: model.primaryColor,
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
  MaterialColor primaryColor;
  ThemeMode mode;

  ThemeModel({this.primaryColor = Colors.red, this.mode = ThemeMode.light});

  void toggleMode() {
    mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setPrimaryColor(MaterialColor newColor) {
    primaryColor = newColor;
    notifyListeners();
  }
}