import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

@JsonSerializable(genericArgumentFactories: true, nullable: false)
class ApiResponse<T> {
  final int code;
  final String msg;
  final T data;

  ApiResponse({this.code, this.msg, this.data});

  factory ApiResponse.fromJson(
          Map<String, dynamic> map, T Function(dynamic json) fromJsonT) =>
      _$ApiResponseFromJson(map, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}
