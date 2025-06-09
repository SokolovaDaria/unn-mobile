class StudentAttendance {
  final String fullname;
  final String studentId;

  StudentAttendance({required this.fullname, required this.studentId});

  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    return StudentAttendance(
      fullname: json['fullname'],
      studentId: json['studentId'],
    );
  }
}
