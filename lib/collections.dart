library app_infra;

class Collections {
  static bool isEmpty(Object obj) {
    if (obj == null) {
      return true;
    }
    if (obj is List) {
      return obj.isEmpty;
    } else if (obj is Map) {
      return obj.isEmpty;
    } else if (obj is Set) {
      return obj.isEmpty;
    }
    return false;
  }

  static bool isNotEmpty(Object obj) {
    if (obj == null) {
      return false;
    }
    if (obj is List) {
      return obj.isNotEmpty;
    } else if (obj is Map) {
      return obj.isNotEmpty;
    } else if (obj is Set) {
      return obj.isNotEmpty;
    }
    return true;
  }
}
