import 'package:app_infra/api.dart';
import 'package:app_infra/app_log.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

class Controller extends GetxController {
  static const String TAG = "Controller";

  Controller() {
    ApiClient.initialize(
      prod: "https://recruitment.class100.com",
      qa: "https://recruitment.qa.class100.com",
      dev: "https://recruitment.dev.class100.com",
    );

    ApiClient.switchEnvorment(HostEnv.Env_Dev);
  }

  void login() async {
    Response<dynamic> resp = await ApiClient.request(
      '/x-server/api/v1/student/login',
      method: 'post',
      param: {'mobile': '11600000001', 'code': '007007'},
    );

    AppLog.d(TAG, "resp:${resp.data}");
  }
}
