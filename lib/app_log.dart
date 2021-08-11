library app_infra;

class AppLog {
  static void d(String tag, String msg) {
    print('$tag => $msg');
  }

  static void e(String tag, String msg) {
    print('$tag => $msg');
  }
}
