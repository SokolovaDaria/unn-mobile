import 'package:json_annotation/json_annotation.dart';

part 'attendance_record.g.dart'; 

@JsonSerializable()
class AttendanceRecord {
  final String studentFullName;

  // указываем, как парсить studentIdCard из JSON
  @JsonKey(fromJson: _studentIdCardFromJsonValue)
  final String studentIdCard;

  final DateTime dateTime;

  AttendanceRecord({
    required this.studentFullName,
    required this.studentIdCard,
    required this.dateTime,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      _$AttendanceRecordFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceRecordToJson(this);
}

String _studentIdCardFromJsonValue(dynamic value) {
  if (value is String) {
    return value;
  }
  if (value is num) { 
    return value.toString();
  }
 
  throw FormatException(
      'Неожиданный тип для studentIdCard: ${value.runtimeType}, значение: $value');
}