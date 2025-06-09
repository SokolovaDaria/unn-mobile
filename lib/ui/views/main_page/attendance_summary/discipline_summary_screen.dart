import 'dart:io';
import 'package:flutter/material.dart';
import 'package:injector/injector.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import 'package:unn_mobile/core/models/attendance/discipline_student_summary.dart';
import 'package:unn_mobile/core/viewmodels/attendance/discipline_summary_view_model.dart';
import 'package:intl/intl.dart';

class DisciplineSummaryScreen extends StatefulWidget {
  const DisciplineSummaryScreen({Key? key}) : super(key: key);

  @override
  State<DisciplineSummaryScreen> createState() =>
      _DisciplineSummaryScreenState();
}

class _DisciplineSummaryScreenState extends State<DisciplineSummaryScreen> {
  late DisciplineSummaryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = Injector.appInstance.get<DisciplineSummaryViewModel>();
    _viewModel.addListener(_onViewModelUpdate);
  }

  void _onViewModelUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showExportFormatDialog(DisciplineSummaryViewModel vm) async {
    if (!mounted) return;

    if (vm.summaryList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для экспорта.')),
      );
      return;
    }

    ph.PermissionStatus storageStatus = await ph.Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await ph.Permission.storage.request();
    }

    if (!storageStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешение на доступ к хранилищу не предоставлено'),
          ),
        );
      }
      return;
    }

    showDialog<ExportFormat>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите формат экспорта'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('CSV (Excel)'),
                onTap: () {
                  Navigator.of(context).pop(ExportFormat.csv);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF'),
                onTap: () {
                  Navigator.of(context).pop(ExportFormat.pdf);
                },
              ),
            ],
          ),
        );
      },
    ).then((selectedFormat) {
      if (selectedFormat != null) {
        _performExport(vm, selectedFormat);
      }
    });
  }

  String _formatDatesForTable(dynamic distinctAttendedDates) {
    if (distinctAttendedDates is List<DateTime> &&
        distinctAttendedDates.isNotEmpty) {
      final DateFormat formatter = DateFormat('dd.MM');
      return distinctAttendedDates
          .map((date) => formatter.format(date))
          .join(', ');
    } else if (distinctAttendedDates is String) {
      try {
        if (distinctAttendedDates.isEmpty) return "";
        final DateFormat formatter = DateFormat('dd.MM');
        List<DateTime> parsedDates = distinctAttendedDates
            .split(',')
            .map((s) => DateTime.parse(s.trim()))
            .toList();
        return parsedDates.map((date) => formatter.format(date)).join(', ');
      } catch (e) {
        return distinctAttendedDates;
      }
    }
    return "";
  }

  Future<void> _performExport(
      DisciplineSummaryViewModel vm, ExportFormat format) async {
    if (!mounted) return;

    final File? savedFile =
        await vm.exportSummary(format: format, pickLocation: true);

    if (!mounted) return;

    if (savedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Файл ${format.name.toUpperCase()} сохранен: ${savedFile.path}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(vm.error ??
                'Не удалось сохранить файл ${format.name.toUpperCase()} или операция отменена.')),
      );
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Сводка по дисциплине'),
          actions: [
            Consumer<DisciplineSummaryViewModel>(builder: (context, vm, _) {
              if (vm.summaryList.isNotEmpty &&
                  !vm.isLoadingSummary &&
                  !vm.isSavingFile) {
                return IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Экспорт',
                  onPressed: () {
                    _showExportFormatDialog(vm);
                  },
                );
              } else if (vm.isSavingFile) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer<DisciplineSummaryViewModel>(
              builder: (context, vm, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: vm.disciplineNameController,
                  decoration: InputDecoration(
                    labelText: 'Название дисциплины',
                    hintText: 'Например, Высшая математика',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: vm.groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Номер группы',
                    hintText: 'Например, 3821Б1ПР1',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!vm.isLoadingSummary && !vm.isSavingFile) {
                      FocusScope.of(context).unfocus();
                      vm.fetchDisciplineSummaryForInput();
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (vm.isLoadingSummary || vm.isSavingFile)
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          vm.fetchDisciplineSummaryForInput();
                        },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16)),
                  child: (vm.isLoadingSummary || vm.isSavingFile)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Получить отчет'),
                ),
                const SizedBox(height: 20),
                if (vm.error != null && vm.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text("Ошибка: ${vm.error}",
                        style:
                            const TextStyle(color: Colors.red, fontSize: 14)),
                  ),
                if (vm.isLoadingSummary)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (vm.error == null && vm.summaryList.isNotEmpty)
                  Expanded(
                    child: _buildSummaryTable(vm.summaryList),
                  )
                else if (vm.error == null &&
                    (vm.disciplineNameController.text.isNotEmpty ||
                        vm.groupNameController.text.isNotEmpty) &&
                    vm.summaryList.isEmpty &&
                    !vm.isLoadingSummary)
                  const Expanded(
                      child: Center(
                          child: Text(
                              "Нет данных о посещаемости для указанных параметров"))),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSummaryTable(List<DisciplineStudentSummary> summaryList) {
    return SingleChildScrollView(
      key: ValueKey(summaryList.hashCode),
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12.0,
          headingRowHeight: 40.0,
          dataRowMinHeight: 35.0,
          dataRowMaxHeight: 45.0,
          border: TableBorder.all(
              color: Colors.grey.shade400,
              width: 1,
              borderRadius: BorderRadius.circular(4)),
          columns: const [
            DataColumn(
                label: Text('Студент',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Посещено',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Всего пар',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Пропущено',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('% посещ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Даты посещения',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: summaryList.map((summary) {
            return DataRow(cells: [
              DataCell(Text(summary.studentFullName)),
              DataCell(
                  Center(child: Text(summary.attendedLessonsCount.toString()))),
              DataCell(
                  Center(child: Text(summary.approxTotalLessons.toString()))),
              DataCell(
                  Center(child: Text(summary.approxMissedLessons.toString()))),
              DataCell(Center(
                  child: Text(
                      '${summary.approxAttendancePercentage.toStringAsFixed(1)}%'))),
              DataCell(SizedBox(
                  width: 150,
                  child: Text(
                    _formatDatesForTable(summary.distinctAttendedDates),
                    overflow: TextOverflow.ellipsis,
                  ))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
