import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/theme.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late String defaultThemeMode;
  late dynamic defaultThemeColor;
  late bool oledEnhance;
  late bool useDynamicColor;
  late bool showWindowButton;
  late bool useSystemFont;
  late final ThemeProvider themeProvider;

  @override
  void initState() {
    super.initState();
    defaultThemeMode = GStorage.getSetting(SettingsKeys.themeMode);
    defaultThemeColor = GStorage.getSetting(SettingsKeys.themeColor);
    oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);
    useDynamicColor = GStorage.getSetting(SettingsKeys.useDynamicColor);
    showWindowButton = GStorage.getSetting(SettingsKeys.showWindowButton);
    useSystemFont = GStorage.getSetting(SettingsKeys.useSystemFont);
    themeProvider = context.read<ThemeProvider>();
  }

  void setTheme(Color? color) {
    var defaultDarkTheme = buildKazumiTheme(
        brightness: Brightness.dark,
        fontFamily: themeProvider.currentFontFamily,
        color: color);
    var oledTheme = oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      buildKazumiTheme(
          brightness: Brightness.light,
          fontFamily: themeProvider.currentFontFamily,
          color: color),
      oledEnhance ? oledTheme : defaultDarkTheme,
    );
    defaultThemeColor = color?.toARGB32().toRadixString(16) ?? 'default';
    GStorage.putSetting(SettingsKeys.themeColor, defaultThemeColor);
  }

  void resetTheme() {
    var defaultDarkTheme = buildKazumiTheme(
        brightness: Brightness.dark,
        fontFamily: themeProvider.currentFontFamily,
        color: Colors.green);
    var oledTheme = oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      buildKazumiTheme(
          brightness: Brightness.light,
          fontFamily: themeProvider.currentFontFamily,
          color: Colors.green),
      oledEnhance ? oledTheme : defaultDarkTheme,
    );
    defaultThemeColor = 'default';
    GStorage.putSetting(SettingsKeys.themeColor, 'default');
  }

  Future<void> updateTheme(String theme) async {
    if (theme == 'dark') {
      themeProvider.setThemeMode(ThemeMode.dark);
    }
    if (theme == 'light') {
      themeProvider.setThemeMode(ThemeMode.light);
    }
    if (theme == 'system') {
      themeProvider.setThemeMode(ThemeMode.system);
    }
    await GStorage.putSetting(SettingsKeys.themeMode, theme);
    setState(() {
      defaultThemeMode = theme;
    });
  }

  void updateOledEnhance() {
    dynamic color;
    oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);
    if (defaultThemeColor == 'default') {
      color = Colors.green;
    } else {
      color = Color(int.parse(defaultThemeColor, radix: 16));
    }
    setTheme(color);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('外观设置'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('外观'),
            tiles: [
              SettingsTile(
                leading: Icons.dark_mode_rounded,
                title: const Text('深色模式'),
                value: Text(themeModeLabel(defaultThemeMode)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onPressed: (_) => KazumiDialog.show<void>(
                  builder: (_) => _ThemeModeDialog(
                    value: defaultThemeMode,
                    onChanged: updateTheme,
                  ),
                ),
              ),
              SettingsTile(
                leading: Icons.palette_rounded,
                enabled: !useDynamicColor,
                onPressed: (_) async {
                  KazumiDialog.show(builder: (context) {
                    return AlertDialog(
                      title: Text('配色方案'),
                      content: StatefulBuilder(builder:
                          (BuildContext context, StateSetter setState) {
                        final List<Map<String, dynamic>> colorThemes =
                            colorThemeTypes;
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: isDesktop() ? 8 : 0,
                          children: [
                            ...colorThemes.map(
                              (e) {
                                final index = colorThemes.indexOf(e);
                                return GestureDetector(
                                  onTap: () {
                                    index == 0
                                        ? resetTheme()
                                        : setTheme(e['color']);
                                    KazumiDialog.dismiss();
                                  },
                                  child: Column(
                                    children: [
                                      PaletteCard(
                                        color: e['color'],
                                        selected: (e['color']
                                                    .value
                                                    .toRadixString(16) ==
                                                defaultThemeColor ||
                                            (defaultThemeColor == 'default' &&
                                                index == 0)),
                                      ),
                                      Text(e['label']),
                                    ],
                                  ),
                                );
                              },
                            )
                          ],
                        );
                      }),
                    );
                  });
                },
                title: Text('配色方案'),
              ),
              SettingsTile.switchTile(
                leading: Icons.colorize_rounded,
                enabled: !Platform.isIOS,
                onToggle: (value) async {
                  useDynamicColor = value ?? !useDynamicColor;
                  await GStorage.putSetting(
                      SettingsKeys.useDynamicColor, useDynamicColor);
                  themeProvider.setDynamic(useDynamicColor);
                  setState(() {});
                },
                title: Text('动态配色'),
                initialValue: useDynamicColor,
              ),
              SettingsTile.switchTile(
                leading: Icons.font_download_rounded,
                onToggle: (value) async {
                  useSystemFont = value ?? !useSystemFont;
                  await GStorage.putSetting(
                      SettingsKeys.useSystemFont, useSystemFont);
                  themeProvider.setFontFamily(useSystemFont);
                  dynamic color;
                  if (defaultThemeColor == 'default') {
                    color = Colors.green;
                  } else {
                    color = Color(int.parse(defaultThemeColor, radix: 16));
                  }
                  setTheme(color);
                  setState(() {});
                },
                title: Text('使用系统字体'),
                description: Text('关闭后使用 MI Sans 字体'),
                initialValue: useSystemFont,
              ),
            ],
            bottomInfo: Text('动态配色仅支持安卓12及以上和桌面平台'),
          ),
          SettingsSection(
            title: Text('显示'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.contrast_rounded,
                onToggle: (value) async {
                  oledEnhance = value ?? !oledEnhance;
                  await GStorage.putSetting(
                      SettingsKeys.oledEnhance, oledEnhance);
                  updateOledEnhance();
                  setState(() {});
                },
                title: Text('OLED优化'),
                description: Text('深色模式下使用纯黑背景'),
                initialValue: oledEnhance,
              ),
            ],
          ),
          if (Platform.isAndroid)
            SettingsSection(
              title: Text('屏幕'),
              tiles: [
                SettingsTile(
                  leading: Icons.sixty_fps_rounded,
                  onPressed: (_) async {
                    context.pushNamed('/settings/theme/display');
                  },
                  title: Text('屏幕帧率'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String themeModeLabel(String mode) => switch (mode) {
      'light' => '浅色',
      'dark' => '深色',
      _ => '跟随系统',
    };

class _ThemeModeDialog extends StatefulWidget {
  const _ThemeModeDialog({required this.value, required this.onChanged});

  final String value;
  final Future<void> Function(String) onChanged;

  @override
  State<_ThemeModeDialog> createState() => _ThemeModeDialogState();
}

class _ThemeModeDialogState extends State<_ThemeModeDialog> {
  static const _options = [
    ('system', '跟随系统'),
    ('light', '浅色'),
    ('dark', '深色'),
  ];

  late String _value = widget.value;
  bool _saving = false;

  Future<void> _select(String? mode) async {
    if (mode == null || _saving) return;
    setState(() {
      _value = mode;
      _saving = true;
    });
    await widget.onChanged(mode);
    if (!mounted) return;
    KazumiDialog.dismiss(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('深色模式'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: RadioGroup<String>(
          groupValue: _value,
          onChanged: _select,
          child: SplitListGroup(
            children: [
              for (final option in _options)
                SettingsTile<String>.radioTile(
                  title: Text(option.$2),
                  radioValue: option.$1,
                  enabled: !_saving,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => KazumiDialog.dismiss(context: context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
