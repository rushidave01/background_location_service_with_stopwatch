import 'package:flutter_timer_location_service/common/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefManager {
  static final SharedPrefManager _instance = SharedPrefManager._internal();

  factory SharedPrefManager() {
    return _instance;
  }

  SharedPrefManager._internal();

  Future<void> writeDate(String data) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(AppConstants.STORE_TIME, data);
  }

  Future<String> readDate() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(AppConstants.STORE_TIME);
  }
}
