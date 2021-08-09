import 'package:flutter/material.dart';

class FABLocation extends FloatingActionButtonLocation {
  final FloatingActionButtonLocation _location;
  final double offsetX;
  final double offsetY;

  FABLocation(this._location, {@required this.offsetX, @required this.offsetY});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    Offset offset = _location.getOffset(scaffoldGeometry);
    return Offset(offset.dx + offsetX, offset.dy + offsetY);
  }
}
