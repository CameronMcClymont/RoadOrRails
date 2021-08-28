import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:road_or_rails/main.dart';
import 'package:road_or_rails/utils/color.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Setting extends StatelessWidget {
  final IconData iconData;
  final String title;
  final SharedPreferences prefs;
  final String prefKey;
  final Function() onChanged;
  final List<Widget> children;

  const Setting({Key? key, required this.iconData, required this.title, required this.prefs, required this.prefKey, required this.onChanged, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      child: InkWell(
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(iconData),
              const SizedBox(width: 24),
              Text(title),
              const Spacer(),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class SwitchSetting extends StatefulWidget {
  final IconData iconData;
  final String title;
  final SharedPreferences prefs;
  final String prefKey;
  final Function() onChanged;
  final bool defaultValue;

  const SwitchSetting({Key? key, required this.iconData, required this.title, required this.prefs, required this.prefKey, required this.onChanged, required this.defaultValue}) : super(key: key);

  @override
  _SwitchSettingState createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<SwitchSetting> {
  @override
  Widget build(BuildContext context) {
    return Setting(
      iconData: widget.iconData,
      title: widget.title,
      prefs: widget.prefs,
      prefKey: widget.prefKey,
      onChanged: () {
        setState(() {
          widget.prefs.setBool(widget.prefKey, !(widget.prefs.getBool(widget.prefKey) ?? widget.defaultValue));
        });
        widget.onChanged();
      },
      children: [
        Switch(
          activeColor: Theme.of(context).colorScheme.primary,
          value: widget.prefs.getBool(widget.prefKey) ?? widget.defaultValue,
          onChanged: (bool value) {
            setState(() {
              widget.prefs.setBool(widget.prefKey, value);
            });
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

class ColorSetting extends StatefulWidget {
  final IconData iconData;
  final String title;
  final SharedPreferences prefs;
  final String prefKey;
  final ThemeModel themeModel;

  const ColorSetting({Key? key, required this.iconData, required this.title, required this.prefs, required this.prefKey, required this.themeModel}) : super(key: key);

  @override
  _ColorSettingState createState() => _ColorSettingState();
}

class _ColorSettingState extends State<ColorSetting> {
  MaterialColor pickerColor = MaterialColor(Colors.red.value, {500: Color(Colors.red.value)});

  @override
  void initState() {
    super.initState();
    int colorValue = widget.prefs.getInt(Settings.accentColorKey) ?? Colors.red.value;
    pickerColor = generateMaterialColor(Color(colorValue));
  }

  @override
  Widget build(BuildContext context) {
    return Setting(
      iconData: widget.iconData,
      title: widget.title,
      prefs: widget.prefs,
      prefKey: widget.prefKey,
      onChanged: () {
        showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('Pick a color!'),
              content: SingleChildScrollView(
                child: MaterialPicker(
                  pickerColor: Color(widget.prefs.getInt(Settings.accentColorKey) ?? Theme.of(context).colorScheme.primary.value),
                  onColorChanged: (Color newColor) {
                    setState(() {
                      pickerColor = generateMaterialColor(newColor);
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Got it'),
                  onPressed: () {
                    setState(() {
                      widget.themeModel.setPrimaryColor(pickerColor);
                      widget.prefs.setInt(Settings.accentColorKey, pickerColor.value);
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class Settings extends StatefulWidget {
  static const String toggleDarkModeKey = 'toggle_dark_mode';
  static const String accentColorKey = 'accent_color';
  static const String toggleBannerAdsKey = 'toggle_banner_ads';

  final ThemeModel themeModel;

  const Settings({Key? key, required this.themeModel}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  SharedPreferences? prefs;

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
                  SwitchSetting(
                    iconData: Icons.dark_mode,
                    title: 'Toggle dark mode',
                    prefs: prefs!,
                    prefKey: Settings.toggleDarkModeKey,
                    onChanged: () => widget.themeModel.toggleMode(),
                    defaultValue: false,
                  ),
                  ColorSetting(
                    iconData: Icons.color_lens,
                    title: 'Accent color',
                    prefs: prefs!,
                    prefKey: Settings.accentColorKey,
                    themeModel: widget.themeModel,
                  ),
                  SwitchSetting(
                    iconData: Icons.ad_units,
                    title: 'Toggle banner ads',
                    prefs: prefs!,
                    prefKey: Settings.toggleBannerAdsKey,
                    onChanged: () {},
                    defaultValue: true,
                  ),
                ],
              ),
            )
          : const Center(child: Text("Couldn't fetch user settings.")),
    );
  }
}
