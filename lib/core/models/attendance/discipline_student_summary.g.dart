// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discipline_student_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DisciplineStudentSummary _$DisciplineStudentSummaryFromJson(
        Map<String, dynamic> json) =>
    DisciplineStudentSummary(
      studentFullName: json['studentFullName'] as String,
      attendedLessonsCount: (json['attendedLessonsCount'] as num).toInt(),
      approxTotalLessons: (json['approxTotalLessons'] as num).toInt(),
      approxMissedLessons: (json['approxMissedLessons'] as num).toInt(),
      approxAttendancePercentage:
          (json['approxAttendancePercentage'] as num).toDouble(),
      distinctAttendedDates: json['distinctAttendedDates'] as String,
    );

Map<String, dynamic> _$DisciplineStudentSummaryToJson(
        DisciplineStudentSummary instance) =>
    <String, dynamic>{
      'studentFullName': instance.studentFullName,
      'attendedLessonsCount': instance.attendedLessonsCount,
      'approxTotalLessons': instance.approxTotalLessons,
      'approxMissedLessons': instance.approxMissedLessons,
      'approxAttendancePercentage': instance.approxAttendancePercentage,
      'distinctAttendedDates': instance.distinctAttendedDates,
    };
