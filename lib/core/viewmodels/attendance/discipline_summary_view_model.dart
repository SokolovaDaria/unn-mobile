import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:unn_mobile/core/models/attendance/discipline_student_summary.dart';
import 'package:unn_mobile/core/services/attendance_service.dart';
import 'package:injector/injector.dart';
import 'package:csv/csv.dart';
import 'package:unn_mobile/core/services/interfaces/feed/feed_file_downloader_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ExportFormat { csv, pdf }

class DisciplineSummaryViewModel extends ChangeNotifier {
  final AttendanceService _attendanceService;
  final FeedFileDownloaderService _fileDownloaderService;

  DisciplineSummaryViewModel({
    AttendanceService? attendanceService,
    FeedFileDownloaderService? fileDownloaderService,
  })  : _attendanceService =
            attendanceService ?? Injector.appInstance.get<AttendanceService>(),
        _fileDownloaderService = fileDownloaderService ??
            Injector.appInstance.get<FeedFileDownloaderService>();
  final TextEditingController disciplineNameController =
      TextEditingController();
  final TextEditingController groupNameController = TextEditingController();

  List<DisciplineStudentSummary> _summaryList = [];
  List<DisciplineStudentSummary> get summaryList => _summaryList;

  bool _isLoadingSummary = false;
  bool get isLoadingSummary => _isLoadingSummary;

  bool _isSavingFile = false;
  bool get isSavingFile => _isSavingFile;

  String? _error;
  String? get error => _error;

  final String _currentTeacherFullName = "Горбунов Максим Дмитриевич";

  get currentTeacherFullName => null;

  String? _buildCsvDataString() {
    if (_summaryList.isEmpty) {
      return null;
    }
    List<List<dynamic>> rows = [];
    rows.add([
      "Студент (ФИО)",
      "Посещено занятий (дней)",
      "Всего занятий (дней)",
      "Пропущено",
      "% посещаемости",
      "Даты посещений"
    ]);
    for (var summary in _summaryList) {
      String attendedDatesString;
      if (summary.distinctAttendedDates is List<DateTime>) {
        attendedDatesString = _formatAttendedDates(
            summary.distinctAttendedDates as List<DateTime>);
      } else if (summary.distinctAttendedDates is String &&
          (summary.distinctAttendedDates as String).isNotEmpty) {
        // попытка распарсить строку дат, если они пришли как строка "гггг-мм-дд, гггг-мм-дд"
        try {
          List<DateTime> parsedDates = (summary.distinctAttendedDates as String)
              .split(',')
              .map((s) => DateTime.parse(s.trim()))
              .toList();
          attendedDatesString = _formatAttendedDates(parsedDates);
        } catch (e) {
          attendedDatesString = summary.distinctAttendedDates.toString();
        }
      } else {
        attendedDatesString = summary.distinctAttendedDates.toString();
      }

      rows.add([
        summary.studentFullName,
        summary.attendedLessonsCount,
        summary.approxTotalLessons,
        summary.approxMissedLessons,
        '${summary.approxAttendancePercentage.toStringAsFixed(1)}%',
        attendedDatesString,
      ]);
    }
    return const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
  }

  Future<Uint8List?> _buildPdfData() async {
    if (_summaryList.isEmpty) {
      return null;
    }
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData =
        await rootBundle.load("assets/fonts/NotoSans-Bold.ttf");
    final ttfBold = pw.Font.ttf(boldFontData);

    final List<List<String>> dataForTable = [
      <String>[
        "Студент (ФИО)",
        "Посещено",
        "Всего (дн.)",
        "Пропущено",
        "% посещ.",
        "Даты посещений"
      ],
      ..._summaryList.map((summary) {
        String attendedDatesString;
        if (summary.distinctAttendedDates is List<DateTime>) {
          attendedDatesString = _formatAttendedDates(
              summary.distinctAttendedDates as List<DateTime>);
        } else if (summary.distinctAttendedDates is String &&
            (summary.distinctAttendedDates as String).isNotEmpty) {
          try {
            List<DateTime> parsedDates =
                (summary.distinctAttendedDates as String)
                    .split(',')
                    .map((s) => DateTime.parse(s.trim()))
                    .toList();
            attendedDatesString = _formatAttendedDates(parsedDates);
          } catch (e) {
            attendedDatesString = summary.distinctAttendedDates.toString();
          }
        } else {
          attendedDatesString = summary.distinctAttendedDates.toString();
        }

        return [
          summary.studentFullName,
          summary.attendedLessonsCount.toString(),
          summary.approxTotalLessons.toString(),
          summary.approxMissedLessons.toString(),
          '${summary.approxAttendancePercentage.toStringAsFixed(1)}%',
          attendedDatesString,
        ];
      }).toList(),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (pw.Context context) {
          return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
              padding: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom:
                          pw.BorderSide(width: 0.5, color: PdfColors.grey))),
              child: pw.Text(
                  'Сводка по посещаемости: ${disciplineNameController.text} - ${groupNameController.text}',
                  style: pw.Theme.of(context)
                      .defaultTextStyle
                      .copyWith(color: PdfColors.grey, fontSize: 12)));
        },
        build: (pw.Context context) => <pw.Widget>[
          pw.Header(
            level: 0,
            child: pw.Text("Дисциплина: ${disciplineNameController.text}",
                style: pw.TextStyle(font: ttfBold, fontSize: 18)),
          ),
          pw.Paragraph(text: "Группа: ${groupNameController.text}"),
          pw.Paragraph(text: "Преподаватель: $_currentTeacherFullName"),
          pw.Paragraph(
              text:
                  "Дата генерации: ${DateTime.now().toLocal().toString().substring(0, 16)}"),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: dataForTable.first,
            data: List<List<String>>.from(dataForTable.skip(1)),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            headerStyle:
                pw.TextStyle(font: ttfBold, fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Студент
              1: const pw.FlexColumnWidth(1.5), // Посещено
              2: const pw.FlexColumnWidth(1.5), // Всего
              3: const pw.FlexColumnWidth(1.5), // Пропущено
              4: const pw.FlexColumnWidth(1.5), // %
              5: const pw.FlexColumnWidth(3), // Даты
            },
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  String _formatAttendedDates(List<DateTime> dates) {
    if (dates.isEmpty) {
      return "";
    }
    final DateFormat formatter = DateFormat('dd.MM');
    return dates.map((date) => formatter.format(date)).join(', ');
  }

  Future<File?> exportSummary(
      {required ExportFormat format, bool pickLocation = true}) async {
    if (_summaryList.isEmpty) {
      _error = "Нет данных для экспорта. Сначала загрузите отчет";
      notifyListeners();
      return null;
    }

    _isSavingFile = true;
    _error = null;
    notifyListeners();

    File? savedFile;
    List<int>? fileBytes;
    String fileExtension;
    String mimeType;

    try {
      String sanitizeForFileName(String input, {String replacement = '_'}) {
        String sanitized =
            input.replaceAll(RegExp(r'[\\/:*?"<>|]+'), replacement);
        sanitized = sanitized.replaceAll(RegExp(r'\s+'), replacement);
        return sanitized.trim();
      }

      final String disciplinePart = sanitizeForFileName(
          disciplineNameController.text.trim().isNotEmpty
              ? disciplineNameController.text.trim()
              : "дисциплина");
      final String groupPart = sanitizeForFileName(
          groupNameController.text.trim().isNotEmpty
              ? groupNameController.text.trim()
              : "группа");
      final String dateTimePart = DateTime.now()
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(':', '-')
          .replaceAll('T', '_');

      if (format == ExportFormat.csv) {
        final String? csvDataString = _buildCsvDataString();
        if (csvDataString == null) {
          _error = "Не удалось сгенерировать CSV данные.";
          return null;
        }
        final bom = [0xEF, 0xBB, 0xBF];
        fileBytes = bom + utf8.encode(csvDataString);
        fileExtension = "csv";
        mimeType = "text/csv";
      } else if (format == ExportFormat.pdf) {
        final Uint8List? pdfBytesUint8 = await _buildPdfData();
        if (pdfBytesUint8 == null) {
          _error = "Не удалось сгенерировать PDF данные.";
          return null;
        }
        fileBytes = pdfBytesUint8;
        fileExtension = "pdf";
        mimeType = "application/pdf";
      } else {
        _error = "Неизвестный формат экспорта.";
        return null;
      }

      final String fileName =
          'Сводка_${disciplinePart}_${groupPart}_$dateTimePart.$fileExtension';

      savedFile = await _fileDownloaderService.saveGeneratedFile(
        fileName: fileName,
        contentBytes: fileBytes,
        pickLocation: pickLocation,
        mimeType: mimeType,
      );

      if (savedFile == null) {
        _error =
            "Файл не был сохранен. Возможно, операция была отменена пользователем или произошла ошибка.";
      } else {
        _error = null;
      }
    } catch (e, s) {
      _error = "Ошибка при создании или сохранении файла: $e";
      savedFile = null;
    } finally {
      _isSavingFile = false;
      notifyListeners();
    }
    return savedFile;
  }

  Future<void> fetchDisciplineSummaryForInput() async {
    final String disciplineName = disciplineNameController.text.trim();
    final String groupName = groupNameController.text.trim();

    if (disciplineName.isEmpty || groupName.isEmpty) {
      _error = "Пожалуйста, введите название дисциплины и номер группы";
      _summaryList = [];
      notifyListeners();
      return;
    }

    if (_currentTeacherFullName.isEmpty) {
      _error = "ФИО преподавателя не установлено";
      notifyListeners();
      return;
    }

    _isLoadingSummary = true;
    _error = null;
    _summaryList = [];
    notifyListeners();

    try {
      final summary = await _attendanceService.getDisciplineSummary(
        teacherFullName: _currentTeacherFullName,
        disciplineName: disciplineName,
        groupName: groupName,
      );
      summary.sort((a, b) => a.studentFullName
          .toLowerCase()
          .compareTo(b.studentFullName.toLowerCase()));
      _summaryList = summary;
    } catch (e) {
      _error = "Ошибка при загрузке сводки: $e";
      _summaryList = [];
    } finally {
      _isLoadingSummary = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disciplineNameController.dispose();
    groupNameController.dispose();
    super.dispose();
  }
}
