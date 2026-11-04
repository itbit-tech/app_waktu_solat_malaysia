import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:get_storage/get_storage.dart';
import 'package:waktusolat_api_client/waktusolat_api_client.dart';

import '../constants/constants.dart';

/// Homescreen widget utility helper
class Homescreen {
  /// Save the whole month prayer time data as json
  static Future<void> savePrayerDataAndUpdateWidget(
    MPTWaktuSolatV2 prayerData,
    String widgetTitle,
  ) async {
    await HomeWidget.saveWidgetData('prayer_data', jsonEncode(prayerData.toJson()));
    await HomeWidget.saveWidgetData('widget_title', widgetTitle);
    await HomeWidget.saveWidgetData('last_updated', DateTime.now().toString());
    await HomeWidget.saveWidgetData(
      'widget_language',
      GetStorage().read<String>(kAppLanguage) ?? 'en',
    );
    await HomeWidget.saveWidgetData(
      'widget_time_is_12',
      GetStorage().read<bool>(kStoredTimeIs12) ?? true,
    );

    // Trigger widgets update to show the new data
    await HomeWidget.updateWidget(name: 'SolatHorizontalWidget', iOSName: 'SolatHorizontalWidget');

    await HomeWidget.updateWidget(name: 'SolatVerticalWidget', iOSName: 'SolatVerticalWidget');
  }
}
