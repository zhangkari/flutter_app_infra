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

enum HostEnv { Env_Prod, Env_Qa, Env_Dev }

class ApiClient {
  static const String TAG = "ApiClient";

  static HostEnv _currEnv = HostEnv.Env_Prod;
  static Map<HostEnv, String> _apiHosts = Map();
  static Dio _dioInstance;
  static Map<String, String> _hostGroups;

  static void initialize({@required String prod, String qa, String dev}) {
    _apiHosts[HostEnv.Env_Prod] = prod;
    _apiHosts[HostEnv.Env_Qa] = qa;
    _apiHosts[HostEnv.Env_Dev] = dev;
  }

  static void switchEnvorment(HostEnv env) {
    if (Strings.isEmpty(_apiHosts[env])) {
      throw "Please call init() first !";
    }
    _currEnv = env;
  }

  static void supportMultiHost(Map<String, String> hostGroups) {
    _hostGroups = hostGroups;
  }

  static String getHost({String group}) {
    if (group == null) {
      return _apiHosts[_currEnv];
    } else {
      if (Collections.isEmpty(_hostGroups)) {
        throw "Please call supportMultiHost first !";
      }
      if (!_hostGroups.containsKey(group)) {
        throw "Can not find host for group:$group";
      }
      return _hostGroups[group];
    }
  }

  static Future request(
    String url, {
    String method = "get",
    Map<String, dynamic> param,
    Map<String, dynamic> header,
    String group,
  }) async {
    if (Strings.isEmpty(url)) {
      throw Exception('url ($url) is invalid');
    }
    if (Collections.isEmpty(_apiHosts)) {
      throw Exception('have you forget invoke ApiClient.initialize() ?');
    }

    var _host = getHost(group: group);
    if (Strings.isEmpty(_host)) {
      throw Exception('not host defined for ${_currEnv.toString()}');
    }

    if (!_isDioInitialized()) {
      _initDioInstance();
    }
    _dioInstance.options.baseUrl = _host;
    header = _buildHeaders(header);
    param = _signParams(param);
    _dioInstance.options.headers.addAll(header);
    Options options = Options();
    options.method = method;
    try {
      final result = await _dioInstance.request(url,
          queryParameters: param, data: param, options: options);
      return result;
    } on DioError catch (error) {
      throw error;
    }
  }

  static void post(String url,
      {String group,
      Map<String, Object> header,
      Map<String, Object> params,
      OnSuccess onSuccess,
      OnError onError}) {
    _sendRequest(url, "post",
        group: group,
        param: params,
        header: header,
        onSuccess: onSuccess,
        onError: onError);
  }

  static void get(String url,
      {String group,
      Map<String, Object> header,
      Map<String, Object> params,
      OnSuccess onSuccess,
      OnError onError}) {
    _sendRequest(url, "get",
        group: group,
        param: params,
        header: header,
        onSuccess: onSuccess,
        onError: onError);
  }

  static Future _sendRequest<T>(String url, String method,
      {String group,
      Map<String, dynamic> param,
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

    var _host = getHost(group: group);
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
