// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttendanceRecord _$AttendanceRecordFromJson(Map<String, dynamic> json) =>
    AttendanceRecord(
      studentFullName: json['studentFullName'] as String,
      studentIdCard: _studentIdCardFromJsonValue(json['studentIdCard']),
      dateTime: DateTime.parse(json['dateTime'] as String),
    );

Map<String, dynamic> _$AttendanceRecordToJson(AttendanceRecord instance) =>
    <String, dynamic>{
      'studentFullName': instance.studentFullName,
      'studentIdCard': instance.studentIdCard,
      'dateTime': instance.dateTime.toIso8601String(),
    };
