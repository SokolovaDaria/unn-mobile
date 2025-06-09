import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; 
import 'package:unn_mobile/core/models/attendance/attendance_record.dart';
import 'package:unn_mobile/core/models/attendance/student_attendance.dart';
import 'package:unn_mobile/core/models/attendance/discipline_student_summary.dart';

class AttendanceService {
  final String _baseUrl = "http://192.168.240.32:8080/api/v1";

  Future<List<DisciplineStudentSummary>> getDisciplineSummary({
    required String teacherFullName,
    required String disciplineName,
    required String groupName,
  
  }) async {
    final Map<String, String> queryParameters = {
      'teacherFullName': teacherFullName,
      'disciplineName': disciplineName,
      'groupName': groupName,
    };


    final uri =
        Uri.parse('$_baseUrl/attendance/summary/by-discipline-group').replace(
      
      queryParameters: queryParameters,
    );

    try {
      print('[AttendanceService] Requesting discipline summary from: $uri');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
            jsonDecode(utf8.decode(response.bodyBytes));
        print('[AttendanceService] Received discipline summary: $jsonData');
        return jsonData
            .map((item) =>
                DisciplineStudentSummary.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        print(
            '[AttendanceService] Failed to load summary. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Ошибка загрузки сводки: ${response.statusCode}');
      }
    } catch (e) {
      print('[AttendanceService] Error during getDisciplineSummary: $e');
      throw Exception('Ошибка загрузки сводки: $e');
    }
  }

  Future<List<StudentAttendance>> getAttendanceForLesson(
      String lessonId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/attendance/$lessonId'));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      
      throw UnimplementedError(
          "StudentAttendance model or fromJson method needs to be checked/implemented if this method is still used.");
    } else {
      throw Exception('Ошибка загрузки списка посещаемости по ID урока');
    }
  }

  Future<List<AttendanceRecord>> getAttendanceListByTeacherAndPeriod({
    required String teacherName,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final DateTime combinedStartDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
      startTime.second,
    );
    final DateTime combinedEndDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
      endTime.second,
    );
    final DateFormat isoFormatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final String formattedStartDateTime =
        isoFormatter.format(combinedStartDateTime);
    final String formattedEndDateTime =
        isoFormatter.format(combinedEndDateTime);

    final uri = Uri.parse('$_baseUrl/attendance/by-teacher-and-time').replace(
      queryParameters: {
        'teacherName': teacherName,
        'startTime': formattedStartDateTime,
        'endTime': formattedEndDateTime,
      },
    );

    try {
      print('[AttendanceService] Requesting attendance list from: $uri');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
            jsonDecode(utf8.decode(response.bodyBytes));
        print('[AttendanceService] Received attendance list: $jsonData');
        return jsonData
            .map((item) =>
                AttendanceRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        print(
            '[AttendanceService] Failed to load attendance list. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception(
            'Ошибка загрузки списка отметившихся: ${response.statusCode}');
      }
    } catch (e) {
      print(
          '[AttendanceService] Error during getAttendanceListByTeacherAndPeriod: $e');
      throw Exception('Ошибка загрузки списка отметившихся: $e');
    }
  }
}
