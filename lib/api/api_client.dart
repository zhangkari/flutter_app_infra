part of app_infra;

typedef void OnSuccess<T>(T data);
typedef void OnError(int code, String message);

enum HostEnv { Env_Prod, Env_Qa, Env_Dev }

class ApiClient {
  static const String TAG = "ApiClient";

  static HostEnv _currEnv = HostEnv.Env_Prod;
  static Map<HostEnv, String> _apiHosts = Map();
  static Dio _dioInstance;
  static Map<String, String> _hostGroups;
  static String _x_auth;

  static String proxy_ip = '192.168.1.100';
  static int proxy_port = 8888;

  static void setProxy(String ip, int port) {
    assert(Strings.isNotEmpty(ip));
    assert(port > 0 && port < 65535);
    proxy_ip = ip;
    proxy_port = port;
  }

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

  static void setAuthToken(String token) {
    if (Strings.isNotEmpty(token)) {
      _x_auth = token;
    }
  }

  static String getAuthToken() {
    return _x_auth;
  }

  static void clearAuthToken(String token) {
    _x_auth = '';
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

  static Future request<T>(
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
      final result = await _dioInstance.request<T>(url,
          data: param, queryParameters: param, options: options);
      String _auth = result.headers.value('x-authorization');
      setAuthToken(_auth);
      return result;
    } on DioError catch (error) {
      throw error;
    }
  }

  static void post<T>(String url,
      {String group,
      Map<String, Object> header,
      Map<String, Object> params,
      OnSuccess onSuccess,
      OnError onError}) {
    _sendRequest<T>(url, "post",
        group: group,
        param: params,
        header: header,
        onSuccess: onSuccess,
        onError: onError);
  }

  static void get<T>(String url,
      {String group,
      Map<String, Object> header,
      Map<String, Object> params,
      OnSuccess onSuccess,
      OnError onError}) {
    _sendRequest<T>(url, "get",
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
      OnSuccess<T> onSuccess,
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

      String _auth = response.headers.value('x-authorization');
      setAuthToken(_auth);

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
    _dioInstance.options.connectTimeout = 30 * 1000;
    _dioInstance.options.receiveTimeout = 30 * 1000;
    _dioInstance.options.sendTimeout = 30 * 1000;
    _dioInstance.options.responseType = ResponseType.json;
    _dioInstance.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
    _setupProxy();

    Map<String, dynamic> header = {};
    header.putIfAbsent('Accept', () => 'text/plain');
    header.putIfAbsent('Content-Type', () => 'application/json');
    var _platform = _getPlatform();
    if (_platform.isNotEmpty) {
      header.putIfAbsent("User-Agent", () => _platform);
    }
    _dioInstance.options.headers.addAll(header);
  }

  static void _setupProxy() {
    if (_dioInstance == null) {
      return;
    }
    (_dioInstance.httpClientAdapter as DefaultHttpClientAdapter)
        .onHttpClientCreate = (client) {
      //解决安卓https抓包的问题
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return Platform.isAndroid;
      };
      client.findProxy = (uri) {
        return "PROXY $proxy_ip:$proxy_port";
      };
    };
  }

  static Map<String, dynamic> _buildHeaders(Map<String, dynamic> headers) {
    if (headers == null) {
      headers = new Map();
    }
    headers['x-authorization'] = _x_auth;
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
