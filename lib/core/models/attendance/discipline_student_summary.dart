import 'package:json_annotation/json_annotation.dart';

part 'discipline_student_summary.g.dart';

@JsonSerializable()
class DisciplineStudentSummary {
  final String studentFullName;

  // поля, которые приходят с сервера (соответствуют DisciplineStudentSummaryDto)
  final int attendedLessonsCount;
  final int approxTotalLessons;   
  final int approxMissedLessons;  

  final double approxAttendancePercentage; 

  final String distinctAttendedDates; 

  DisciplineStudentSummary({
    required this.studentFullName,
    required this.attendedLessonsCount,
    required this.approxTotalLessons,
    required this.approxMissedLessons,
    required this.approxAttendancePercentage,
    required this.distinctAttendedDates,
  });

  factory DisciplineStudentSummary.fromJson(Map<String, dynamic> json) =>
      _$DisciplineStudentSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$DisciplineStudentSummaryToJson(this);
}