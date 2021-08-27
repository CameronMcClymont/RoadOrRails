import 'package:flutter/material.dart';
import 'package:scotrail_sabotage/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  static const String toggleBannerAdsKey = 'toggle_banner_ads';
  static const String toggleDarkModeKey = 'toggle_dark_mode';

  final ThemeModel themeModel;

  const Settings({Key? key, required this.themeModel}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  SharedPreferences? prefs;

  Widget setting(IconData iconData, String title, String prefKey, bool defaultValue, Function() onChanged) {
    return InkWell(
      onTap: () {
        setState(() {
          prefs!.setBool(prefKey, !(prefs!.getBool(prefKey) ?? defaultValue));
        });
        onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(iconData),
            const SizedBox(width: 24),
            Text(title),
            const Spacer(),
            Switch(
              value: prefs!.getBool(prefKey) ?? defaultValue,
              onChanged: (bool value) {
                setState(() {
                  prefs!.setBool(prefKey, value);
                });
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  getSharedPrefs() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    setState(() {
      prefs = sharedPreferences;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      getSharedPrefs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: prefs != null
          ? SingleChildScrollView(
              child: Column(
                children: [
                  setting(Icons.ad_units, 'Toggle banner ads', Settings.toggleBannerAdsKey, true, () {}),
                  setting(Icons.dark_mode, 'Toggle dark mode', Settings.toggleDarkModeKey, false, () => widget.themeModel.toggleMode()),
                ],
              ),
            )
          : const Center(child: Text("Couldn't fetch user settings.")),
    );
  }
}
