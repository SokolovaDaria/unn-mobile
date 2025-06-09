import 'dart:io';
import 'dart:typed_data';
import 'dart:convert'; // для utf8.decode

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:unn_mobile/core/models/attendance/discipline_student_summary.dart';
import 'package:unn_mobile/core/services/attendance_service.dart';
import 'package:unn_mobile/core/services/interfaces/feed/feed_file_downloader_service.dart';
import 'package:unn_mobile/core/viewmodels/attendance/discipline_summary_view_model.dart';
import 'package:flutter/services.dart';

import 'discipline_summary_view_model_test.mocks.dart';

@GenerateMocks([AttendanceService, FeedFileDownloaderService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DisciplineSummaryViewModel viewModel;
  late MockAttendanceService mockAttendanceService;
  late MockFeedFileDownloaderService mockFileDownloaderService;

  const String hardcodedTeacherFullNameInViewModel =
      "Горбунов Максим Дмитриевич";

  setUpAll(() {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter/assets'),
      (MethodCall? methodCall) async {
        if (methodCall?.method == 'load') {
          final String? key = methodCall?.arguments as String?;
          if (key == 'assets/fonts/NotoSans-Regular.ttf' ||
              key == 'assets/fonts/NotoSans-Bold.ttf') {
            final Uint8List fontBytes = Uint8List(256);
            if (fontBytes.isNotEmpty)
              fontBytes[0] = 1; 
            return ByteData.view(fontBytes.buffer);
          }
        }
        return null;
      },
    );
  });

  tearDownAll(() {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter/assets'), null);
  });

  setUp(() {
    mockAttendanceService = MockAttendanceService();
    mockFileDownloaderService = MockFeedFileDownloaderService();
    viewModel = DisciplineSummaryViewModel(
      attendanceService: mockAttendanceService,
      fileDownloaderService: mockFileDownloaderService,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  final testSummaryList = [
    DisciplineStudentSummary(
        studentFullName: "Иванов Иван",
        attendedLessonsCount: 8,
        approxTotalLessons: 10,
        approxMissedLessons: 2,
        approxAttendancePercentage: 80.0,
        distinctAttendedDates: "2024-01-10,2024-01-17, 2024-02-01"),
    DisciplineStudentSummary(
        studentFullName: "Петров Петр",
        attendedLessonsCount: 10,
        approxTotalLessons: 10,
        approxMissedLessons: 0,
        approxAttendancePercentage: 100.0,
        distinctAttendedDates: "2024-01-10,2024-01-17,2024-01-24"),
  ];

  group('DisciplineSummaryViewModel Tests', () {
    group('fetchDisciplineSummaryForInput', () {
      test('should set error if discipline name is empty', () async {
        viewModel.disciplineNameController.text = '';
        viewModel.groupNameController.text = 'Group1';
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.error,
            contains('введите название дисциплины и номер группы'));
        expect(viewModel.summaryList, isEmpty);
      });

      test('should set error if group name is empty', () async {
        viewModel.disciplineNameController.text = 'Discipline1';
        viewModel.groupNameController.text = '';
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.error,
            contains('введите название дисциплины и номер группы'));
        expect(viewModel.summaryList, isEmpty);
      });

      test('should fetch, sort and set summary list on success', () async {
        viewModel.disciplineNameController.text = 'Math';
        viewModel.groupNameController.text = 'M-101';
        final unsortedListFromService = [
          testSummaryList[1],
          testSummaryList[0]
        ];
        when(mockAttendanceService.getDisciplineSummary(
          teacherFullName: hardcodedTeacherFullNameInViewModel,
          disciplineName: 'Math',
          groupName: 'M-101',
        )).thenAnswer((_) async => unsortedListFromService);
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.error, isNull);
        expect(viewModel.summaryList.length, 2);
        expect(viewModel.summaryList[0].studentFullName, "Иванов Иван");
        expect(viewModel.summaryList[1].studentFullName, "Петров Петр");
        verify(mockAttendanceService.getDisciplineSummary(
                teacherFullName: hardcodedTeacherFullNameInViewModel,
                disciplineName: 'Math',
                groupName: 'M-101'))
            .called(1);
      });

      test('should set error on service exception', () async {
        viewModel.disciplineNameController.text = 'Physics';
        viewModel.groupNameController.text = 'P-202';
        when(mockAttendanceService.getDisciplineSummary(
          teacherFullName: hardcodedTeacherFullNameInViewModel,
          disciplineName: 'Physics',
          groupName: 'P-202',
        )).thenThrow(Exception('Service error'));
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.error, contains('Service error'));
        expect(viewModel.summaryList, isEmpty);
      });
    });

    group('exportSummary - CSV content and formatting', () {
      test('CSV should contain correctly formatted dates from String',
          () async {
        viewModel.disciplineNameController.text = "ТестДисц";
        viewModel.groupNameController.text = "ТГ1";
        final summaryWithDates = [
          DisciplineStudentSummary(
            studentFullName: "Студент Даты",
            attendedLessonsCount: 2,
            approxTotalLessons: 2,
            approxMissedLessons: 0,
            approxAttendancePercentage: 100.0,
            distinctAttendedDates: "2024-03-05, 2024-03-12, 2023-12-25",
          )
        ];
        when(mockAttendanceService.getDisciplineSummary(
                teacherFullName: hardcodedTeacherFullNameInViewModel,
                disciplineName: "ТестДисц",
                groupName: "ТГ1"))
            .thenAnswer((_) async => summaryWithDates);
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.summaryList, isNotEmpty);

        when(mockFileDownloaderService.saveGeneratedFile(
          fileName: anyNamed('fileName'),
          contentBytes: anyNamed('contentBytes'),
          pickLocation: false,
          mimeType: 'text/csv',
        )).thenAnswer((_) async => File('dummy.csv'));
        await viewModel.exportSummary(
            format: ExportFormat.csv, pickLocation: false);

        final verificationResult = verify(
            mockFileDownloaderService.saveGeneratedFile(
                fileName: captureAnyNamed('fileName'),
                contentBytes: captureAnyNamed('contentBytes'),
                pickLocation: captureAnyNamed('pickLocation'),
                mimeType: captureAnyNamed('mimeType')));
        verificationResult.called(1);

        final List<int> capturedBytes =
            verificationResult.captured[1] as List<int>;
        final csvString = utf8.decode(capturedBytes.sublist(3));
        expect(csvString, contains("05.03, 12.03, 25.12"));
      });

      test('CSV should handle empty date string', () async {
        viewModel.disciplineNameController.text = "ТестДисц";
        viewModel.groupNameController.text = "ТГ1";
        final summaryWithEmptyDates = [
          DisciplineStudentSummary(
            studentFullName: "Студент Без Дат",
            attendedLessonsCount: 0,
            approxTotalLessons: 0,
            approxMissedLessons: 0,
            approxAttendancePercentage: 0.0,
            distinctAttendedDates: "",
          )
        ];
        when(mockAttendanceService.getDisciplineSummary(
                teacherFullName: hardcodedTeacherFullNameInViewModel,
                disciplineName: "ТестДисц",
                groupName: "ТГ1"))
            .thenAnswer((_) async => summaryWithEmptyDates);
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.summaryList, isNotEmpty);

        when(mockFileDownloaderService.saveGeneratedFile(
          fileName: anyNamed('fileName'),
          contentBytes: anyNamed('contentBytes'),
          pickLocation: false,
          mimeType: 'text/csv',
        )).thenAnswer((_) async => File('dummy.csv'));
        await viewModel.exportSummary(
            format: ExportFormat.csv, pickLocation: false);

        final verificationResult = verify(
            mockFileDownloaderService.saveGeneratedFile(
                fileName: captureAnyNamed('fileName'),
                contentBytes: captureAnyNamed('contentBytes'),
                pickLocation: captureAnyNamed('pickLocation'),
                mimeType: captureAnyNamed('mimeType')));
        verificationResult.called(1);

        final List<int> capturedBytes =
            verificationResult.captured[1] as List<int>;
        final csvString = utf8.decode(capturedBytes.sublist(3));
        expect(csvString.trimRight(), endsWith('Студент Без Дат;0;0;0;0.0%;'));
      });
    });

    group('exportSummary - PDF specific', () {
      test(
          'should set error and not call save if PDF generation fails (empty list)',
          () async {
        viewModel.disciplineNameController.text = "ТестПДФОшибки";
        viewModel.groupNameController.text = "ТГПДФО";
       
        expect(viewModel.summaryList, isEmpty);

        final file = await viewModel.exportSummary(
            format: ExportFormat.pdf, pickLocation: false);

        expect(file, isNull);
        expect(viewModel.error, contains('Нет данных для экспорта'));
        verifyNever(mockFileDownloaderService.saveGeneratedFile(
            fileName: anyNamed('fileName'),
            contentBytes: anyNamed('contentBytes'),
            pickLocation: anyNamed('pickLocation'),
            mimeType: anyNamed('mimeType')));
      });

      test(
          'PDF generation should set error due to font/format issue and not call saveFile',
          () async {
        viewModel.disciplineNameController.text = "ТестПДФ_ОшибкаШрифта";
        viewModel.groupNameController.text = "ТГПДФ_ОШ";
        final summaryWithDates = [
          DisciplineStudentSummary(
            studentFullName: "Студент Для ПДФ",
            attendedLessonsCount: 1,
            approxTotalLessons: 1,
            approxMissedLessons: 0,
            approxAttendancePercentage: 100.0,
            distinctAttendedDates: "2024-04-01",
          )
        ];
        when(mockAttendanceService.getDisciplineSummary(
                teacherFullName: hardcodedTeacherFullNameInViewModel,
                disciplineName: "ТестПДФ_ОшибкаШрифта",
                groupName: "ТГПДФ_ОШ"))
            .thenAnswer((_) async => summaryWithDates);
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.summaryList, isNotEmpty);

        File? resultFile = await viewModel.exportSummary(
            format: ExportFormat.pdf, pickLocation: false);

        expect(resultFile, isNull);
        expect(viewModel.error, isNotNull);
        expect(
            viewModel.error,
            anyOf(
                contains(
                    "Ошибка при создании или сохранении файла: FormatException"),
                contains("Не удалось сгенерировать PDF данные")));

        verifyNever(mockFileDownloaderService.saveGeneratedFile(
            fileName: anyNamed('fileName'),
            contentBytes: anyNamed('contentBytes'),
            pickLocation: anyNamed('pickLocation'),
            mimeType: anyNamed('mimeType')));
      });
    });

    group('exportSummary - General', () {
      setUp(() async {
        viewModel.disciplineNameController.text = "Общий Тест";
        viewModel.groupNameController.text = "ОТ-01";
        when(mockAttendanceService.getDisciplineSummary(
          teacherFullName: hardcodedTeacherFullNameInViewModel,
          disciplineName: "Общий Тест",
          groupName: "ОТ-01",
        )).thenAnswer(
            (_) async => List<DisciplineStudentSummary>.from(testSummaryList));
        await viewModel.fetchDisciplineSummaryForInput();
        expect(viewModel.summaryList, isNotEmpty,
            reason:
                "Setup for 'exportSummary - General' should populate summaryList");
      });

      test(
          'should set error if summary list is empty before export (using new viewModel)',
          () async {
        final emptyViewModel = DisciplineSummaryViewModel(
          attendanceService: mockAttendanceService,
          fileDownloaderService: mockFileDownloaderService,
        );
        final result =
            await emptyViewModel.exportSummary(format: ExportFormat.csv);
        expect(result, isNull);
        expect(emptyViewModel.error, contains('Нет данных для экспорта'));
      });

      test('CSV export should call saveGeneratedFile with correct parameters',
          () async {
        expect(viewModel.summaryList, isNotEmpty);
        when(mockFileDownloaderService.saveGeneratedFile(
          fileName: anyNamed('fileName'),
          contentBytes: anyNamed('contentBytes'),
          pickLocation: true,
          mimeType: 'text/csv',
        )).thenAnswer((_) async => File('dummy.csv'));

        await viewModel.exportSummary(
            format: ExportFormat.csv, pickLocation: true);

        final verificationResult = verify(
            mockFileDownloaderService.saveGeneratedFile(
                fileName: captureAnyNamed('fileName'),
                contentBytes: captureAnyNamed('contentBytes'),
                pickLocation: captureAnyNamed('pickLocation'),
                mimeType: captureAnyNamed('mimeType')));
        verificationResult.called(1);

        expect(verificationResult.captured[0] as String,
            startsWith('Сводка_Общий_Тест_ОТ-01_'));
        final List<int> capturedBytes =
            verificationResult.captured[1] as List<int>;
        expect(capturedBytes.sublist(0, 3), equals([0xEF, 0xBB, 0xBF]));
        expect(utf8.decode(capturedBytes.sublist(3)), contains("Иванов Иван"));
        expect(verificationResult.captured[2] as bool, true);
        expect(verificationResult.captured[3] as String, 'text/csv');
        expect(viewModel.error, isNull); // Добавлено
        expect(viewModel.isSavingFile, isFalse); // Добавлено
      });

      test(
          'General PDF export should set error due to font/format issue and not call saveFile',
          () async {
        
        expect(viewModel.summaryList, isNotEmpty);

        File? resultFile = await viewModel.exportSummary(
            format: ExportFormat.pdf, pickLocation: true);

        expect(resultFile, isNull);
        expect(viewModel.error, isNotNull);
        expect(
            viewModel.error,
            anyOf(
                contains(
                    "Ошибка при создании или сохранении файла: FormatException"),
                contains("Не удалось сгенерировать PDF данные")));

        verifyNever(mockFileDownloaderService.saveGeneratedFile(
            fileName: anyNamed('fileName'),
            contentBytes: anyNamed('contentBytes'),
            pickLocation: anyNamed('pickLocation'),
            mimeType: anyNamed('mimeType')));
      });

      test('should handle error from file downloader service', () async {
        expect(viewModel.summaryList, isNotEmpty);
        
        when(mockFileDownloaderService.saveGeneratedFile(
          fileName: anyNamed('fileName'),
          contentBytes: anyNamed('contentBytes'),
          pickLocation: true,
          mimeType: 'text/csv', 
        )).thenAnswer((_) async => null); 

        final file = await viewModel.exportSummary(
            format: ExportFormat.csv, pickLocation: true);
        expect(file, isNull);
        expect(viewModel.error, contains('Файл не был сохранен'));
        expect(viewModel.isSavingFile, isFalse);
      });

      test('should handle exception during file saving', () async {
        expect(viewModel.summaryList, isNotEmpty);
        
        when(mockFileDownloaderService.saveGeneratedFile(
                fileName: anyNamed('fileName'),
                contentBytes: anyNamed('contentBytes'),
                pickLocation: true,
                mimeType: 'text/csv'))
            .thenThrow(Exception("Disk full"));
        final file = await viewModel.exportSummary(
            format: ExportFormat.csv, pickLocation: true);
        expect(file, isNull);
        expect(
            viewModel.error,
            contains(
                "Ошибка при создании или сохранении файла: Exception: Disk full"));
        expect(viewModel.isSavingFile, isFalse);
      });
    });
  });
}
