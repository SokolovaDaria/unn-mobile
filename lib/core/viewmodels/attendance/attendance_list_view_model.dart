import 'package:unn_mobile/core/models/attendance/attendance_record.dart';
import 'package:unn_mobile/core/services/attendance_service.dart';
 

class AttendanceListViewModel {
  final AttendanceService _attendanceService = AttendanceService(); 

  Future<List<AttendanceRecord>> fetchAttendanceList(String lessonId) async {
    
    final String teacherName = "Петров Петр Петрович"; 
    final DateTime date = DateTime.now(); 
    final DateTime startTime = DateTime(date.year, date.month, date.day, 10, 0); 
    final DateTime endTime = DateTime(date.year, date.month, date.day, 11, 30); 

    if (teacherName.isEmpty) { 
        throw Exception("Не удалось определить преподавателя для lessonId: $lessonId");
    }

    try {
      return await _attendanceService.getAttendanceListByTeacherAndPeriod(
        teacherName: teacherName,
        date: date,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      
      print('Error in AttendanceListViewModel.fetchAttendanceList: $e');
      rethrow; 
    }
  }
}