library app_infra;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import 'app_log.dart';
import 'collections.dart';
import 'strings.dart';

typedef void OnSuccess<T>(T data);
typedef void OnError(int code, String message);

enum HostEnv { Env_Prod, Env_Qa, Env_Env }

class ApiClient {
  static const String TAG = "ApiClient";

  static HostEnv _currEnv = HostEnv.Env_Prod;
  static Map<HostEnv, String> _apiHosts = Map();
  static Dio _dioInstance;

  static void initialize({@required String prod, String qa, String env}) {
    _apiHosts[HostEnv.Env_Prod] = prod;
    _apiHosts[HostEnv.Env_Qa] = qa;
    _apiHosts[HostEnv.Env_Env] = env;
  }

  static void switchEnvorment(HostEnv env) {
    if (Strings.isEmpty(_apiHosts[env])) {
      throw "Please call init() first !";
    }
    _currEnv = env;
  }

  static String getHost() {
    return _apiHosts[_currEnv];
  }

  static void post(String url,
      {Map<String, Object> header,
      Map<String, String> params,
      OnSuccess onSuccess,
      OnError onError}) {
    _sendRequest(url, "post",
        param: params, header: header, onSuccess: onSuccess, onError: onError);
  }

  static void get(String url,
      {Map<String, Object> header,
      Map<String, String> params,
      OnSuccess onSuccess,
      OnError onError}) {
    _sendRequest(url, "get",
        param: params, header: header, onSuccess: onSuccess, onError: onError);
  }

  static Future _sendRequest<T>(String url, String method,
      {Map<String, dynamic> param,
      Map<String, dynamic> header,
      OnSuccess onSuccess,
      OnError onError}) async {
    int _code;
    String _msg;
    var _data;

    if (Strings.isEmpty(url)) {
      throw Exception('url ($url) is invalid');
    }
    if (Collections.isEmpty(_apiHosts)) {
      throw Exception('have you forget invoke ApiClient.initialize() ?');
    }

    var _host = getHost();
    if (Strings.isEmpty(_host)) {
      throw Exception('not host defined for ${_currEnv.toString()}');
    }

    if (!_isDioInitialized()) {
      _initDioInstance();
    }

    _dioInstance.options.baseUrl = _host;
    try {
      header = _buildHeaders(header);
      param = _signParams(param);

      Response response;
      _dioInstance.options.headers.addAll(header);
      if (method.toLowerCase() == 'get') {
        try {
          response = await _dioInstance.get(
            url,
            queryParameters: param,
            options: Options(
              validateStatus: (status) => true,
              receiveDataWhenStatusError: true,
            ),
          );
        } catch (e) {
          AppLog.d(TAG, "++++++++ get $url error:${e.toString()} ++++++++");
        }
      } else {
        try {
          response = await _dioInstance.post(
            url,
            data: param,
            options: Options(
              validateStatus: (status) => true,
              receiveDataWhenStatusError: true,
            ),
          );
        } catch (e) {
          AppLog.d(TAG, "++++++++ post $url error:${e.toString()} ++++++++");
        }
      }

      if (response == null) {
        AppLog.d(TAG, 'response = null');
        _handleError(onError, 500, 'response return null');
        return;
      }

      if (response.statusCode != 200) {
        _handleError(onError, response.statusCode, response.statusMessage);
        return;
      }

      Map<String, dynamic> respData = jsonDecode(response.toString());

      _code = respData['code'];
      _msg = respData['msg'];
      _data = respData['data'];

      if (_code == 0) {
        if (onSuccess != null) {
          onSuccess(_data);
        }
      } else {
        _handleError(onError, _code, _msg);
      }
    } catch (e) {
      _handleError(onError, 400, e.toString());
    }
  }

  static bool _isDioInitialized() {
    return _dioInstance != null;
  }

  static void _initDioInstance() {
    if (_dioInstance != null) {
      return;
    }
    _dioInstance = new Dio();
    _dioInstance.options.connectTimeout = 5 * 1000;
    _dioInstance.options.receiveTimeout = 5 * 1000;
    _dioInstance.options.sendTimeout = 5 * 1000;
    _dioInstance.options.responseType = ResponseType.json;
    _dioInstance.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    Map<String, dynamic> header = {};
    header.putIfAbsent('Accept', () => 'text/plain');
    header.putIfAbsent('Content-Type', () => 'text/plain');
    var _platform = _getPlatform();
    if (_platform.isNotEmpty) {
      header.putIfAbsent("User-Agent", () => _platform);
    }
    _dioInstance.options.headers.addAll(header);
  }

  static Map<String, dynamic> _buildHeaders(Map<String, dynamic> headers) {
    if (headers == null) {
      headers = new Map();
    }
    return headers;
  }

  static Map<String, dynamic> _signParams(Map<String, dynamic> params) {
    return params;
  }

  static String _getPlatform() {
    try {
      return Platform.operatingSystem;
    } catch (e) {
      return "unkown";
    }
  }

  static void _handleError(OnError errFunc, int code, String errMsg) {
    if (errFunc != null) {
      errFunc(code, errMsg);
    }
  }
}
