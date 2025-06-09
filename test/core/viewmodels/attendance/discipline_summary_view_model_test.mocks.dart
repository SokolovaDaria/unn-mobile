import 'dart:async' as _i3;
import 'dart:io' as _i8;

import 'package:mockito/mockito.dart' as _i1;
import 'package:unn_mobile/core/models/attendance/attendance_record.dart'
    as _i6;
import 'package:unn_mobile/core/models/attendance/discipline_student_summary.dart'
    as _i4;
import 'package:unn_mobile/core/models/attendance/student_attendance.dart'
    as _i5;
import 'package:unn_mobile/core/services/attendance_service.dart' as _i2;
import 'package:unn_mobile/core/services/interfaces/feed/feed_file_downloader_service.dart'
    as _i7;

/// A class which mocks [AttendanceService].
///
/// See the documentation for Mockito's code generation for more information.
class MockAttendanceService extends _i1.Mock implements _i2.AttendanceService {
  MockAttendanceService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<List<_i4.DisciplineStudentSummary>> getDisciplineSummary({
    required String? teacherFullName,
    required String? disciplineName,
    required String? groupName,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getDisciplineSummary,
          [],
          {
            #teacherFullName: teacherFullName,
            #disciplineName: disciplineName,
            #groupName: groupName,
          },
        ),
        returnValue: _i3.Future<List<_i4.DisciplineStudentSummary>>.value(
            <_i4.DisciplineStudentSummary>[]),
      ) as _i3.Future<List<_i4.DisciplineStudentSummary>>);

  @override
  _i3.Future<List<_i5.StudentAttendance>> getAttendanceForLesson(
          String? lessonId) =>
      (super.noSuchMethod(
        Invocation.method(
          #getAttendanceForLesson,
          [lessonId],
        ),
        returnValue: _i3.Future<List<_i5.StudentAttendance>>.value(
            <_i5.StudentAttendance>[]),
      ) as _i3.Future<List<_i5.StudentAttendance>>);

  @override
  _i3.Future<List<_i6.AttendanceRecord>> getAttendanceListByTeacherAndPeriod({
    required String? teacherName,
    required DateTime? date,
    required DateTime? startTime,
    required DateTime? endTime,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getAttendanceListByTeacherAndPeriod,
          [],
          {
            #teacherName: teacherName,
            #date: date,
            #startTime: startTime,
            #endTime: endTime,
          },
        ),
        returnValue: _i3.Future<List<_i6.AttendanceRecord>>.value(
            <_i6.AttendanceRecord>[]),
      ) as _i3.Future<List<_i6.AttendanceRecord>>);
}

/// A class which mocks [FeedFileDownloaderService].
///
/// See the documentation for Mockito's code generation for more information.
class MockFeedFileDownloaderService extends _i1.Mock
    implements _i7.FeedFileDownloaderService {
  MockFeedFileDownloaderService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<_i8.File?> downloadFile({
    required String? fileName,
    required String? downloadUrl,
    required bool? force,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #downloadFile,
          [],
          {
            #fileName: fileName,
            #downloadUrl: downloadUrl,
            #force: force,
          },
        ),
        returnValue: _i3.Future<_i8.File?>.value(),
      ) as _i3.Future<_i8.File?>);

  @override
  _i3.Future<_i8.File?> saveGeneratedFile({
    required String? fileName,
    required List<int>? contentBytes,
    bool? pickLocation = true,
    String? mimeType,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #saveGeneratedFile,
          [],
          {
            #fileName: fileName,
            #contentBytes: contentBytes,
            #pickLocation: pickLocation,
            #mimeType: mimeType,
          },
        ),
        returnValue: _i3.Future<_i8.File?>.value(),
      ) as _i3.Future<_i8.File?>);

  @override
  _i3.Future<List<_i8.File>?> downloadFiles({
    required List<String>? fileNames,
    required String? downloadUrl,
    required bool? force,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #downloadFiles,
          [],
          {
            #fileNames: fileNames,
            #downloadUrl: downloadUrl,
            #force: force,
          },
        ),
        returnValue: _i3.Future<List<_i8.File>?>.value(),
      ) as _i3.Future<List<_i8.File>?>);
}
