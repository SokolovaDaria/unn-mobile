import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unn_mobile/core/misc/current_user_sync_storage.dart';
import 'package:unn_mobile/core/models/attendance/attendance_record.dart';
import 'package:unn_mobile/core/models/schedule/subject.dart';
import 'package:unn_mobile/core/services/attendance_service.dart';
import 'package:unn_mobile/ui/unn_mobile_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unn_mobile/core/models/profile/employee_data.dart';

class ScheduleItemNormal extends StatefulWidget {
  final Subject subject;
  final bool even;

  final CurrentUserSyncStorage? currentUserSyncStorage;

  const ScheduleItemNormal({
    super.key,
    required this.subject,
    this.even = false,
    this.currentUserSyncStorage,
  });

  @override
  State<ScheduleItemNormal> createState() => _ScheduleItemNormalState();
}

class _ScheduleItemNormalState extends State<ScheduleItemNormal>
    with TickerProviderStateMixin {
  bool _expanded = false;
  final vutsScheduleUri = 'http://www.ivo.unn.ru/raspisanie-vuts/';

  bool _isLoadingStudents = false;
  List<AttendanceRecord>? _attendedStudents;
  String? _studentsListError;
  bool _isFetching = false;
  bool _dataFetchedOnce = false;

  final AttendanceService _attendanceService = AttendanceService();

  Future<void> _fetchAttendedStudents() async {
    // определяем, является ли текущий пользователь преподавателем

    bool isCurrentUserLecturer = false;
    if (widget.currentUserSyncStorage != null) {
      isCurrentUserLecturer =
          widget.currentUserSyncStorage!.typeOfUser == EmployeeData;
    } else {
      isCurrentUserLecturer = true; // ВРЕМЕННАЯ ЗАГЛУШКА
      debugPrint(
          "[SCHEDULE ITEM DEBUG] currentUserSyncStorage is null, using fallback for isCurrentUserLecturer: $isCurrentUserLecturer");
    }

    if (_isFetching ||
        !isCurrentUserLecturer ||
        widget.subject.lecturer.isEmpty) {
      debugPrint(
          "[SCHEDULE ITEM DEBUG] _fetchAttendedStudents: Skipped. Fetching: $_isFetching, IsLecturer: $isCurrentUserLecturer, SubjectLecturerEmpty: ${widget.subject.lecturer.isEmpty}");
      return;
    }

    setState(() {
      _isLoadingStudents = true;

      _studentsListError = null;
      _isFetching = true;
    });
    debugPrint(
        "[SCHEDULE ITEM DEBUG] _fetchAttendedStudents: Started. isLoading: $_isLoadingStudents, isFetching: $_isFetching. For teacher: ${widget.subject.lecturer}");

    try {
      final students =
          await _attendanceService.getAttendanceListByTeacherAndPeriod(
        teacherName: widget.subject.lecturer,
        date: widget.subject.dateTimeRange.start, 
        startTime:
            widget.subject.dateTimeRange.start, 
        endTime:
            widget.subject.dateTimeRange.end, 
      );
      debugPrint(
          "[SCHEDULE ITEM DEBUG] _fetchAttendedStudents: SUCCESS, students count: ${students.length}");

      if (mounted) {
       
        setState(() {
          _attendedStudents = students;
          _dataFetchedOnce =
              true; 
        });
      }
    } catch (e) {
      debugPrint("[SCHEDULE ITEM DEBUG] _fetchAttendedStudents: ERROR: $e");
      if (mounted) {
        setState(() {
          _studentsListError =
              "Ошибка загрузки: ${e.toString().substring(0, (e.toString().length > 100) ? 100 : e.toString().length)}..."; // Обрезаем длинные ошибки
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
          _isFetching = false;
        });
        debugPrint(
            "[SCHEDULE ITEM DEBUG] _fetchAttendedStudents: Ended. isLoading: $_isLoadingStudents, isFetching: $_isFetching");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraColors = theme.extension<UnnMobileColors>()!;
    final DateFormat timeFormatter = DateFormat('HH:mm');
    const verticalPadding = 4.0;
    const horizontalPadding = 8.0;

    bool isCurrentUserLecturer = false;
    if (widget.currentUserSyncStorage != null) {
      isCurrentUserLecturer =
          widget.currentUserSyncStorage!.typeOfUser == EmployeeData;
    } else {
      isCurrentUserLecturer = true; // ВРЕМЕННАЯ ЗАГЛУШКА
    }

    debugPrint(
        "[SCHEDULE ITEM DEBUG] build(): expanded: $_expanded, isLecturer: $isCurrentUserLecturer, isLoading: $_isLoadingStudents, error: $_studentsListError, studentsCount: ${_attendedStudents?.length}, dataFetchedOnce: $_dataFetchedOnce");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      child: GestureDetector(
        onTap: () async {
          debugPrint(
              "[SCHEDULE ITEM DEBUG] onTap: START. Current _expanded: $_expanded");
          if (widget.subject.name == 'Военная подготовка') {
            final Uri url = Uri.parse(vutsScheduleUri);
            try {
              if (!await launchUrl(url)) {
                debugPrint('Could not launch $url');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Не удалось открыть ссылку: $url')),
                  );
                }
              }
            } catch (e) {
              debugPrint('Error launching url: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка при открытии ссылки: $e')),
                );
              }
            }
          } else {
            bool newExpandedState = !_expanded;

            setState(() {
              _expanded = newExpandedState;
            });
            debugPrint(
                "[SCHEDULE ITEM DEBUG] onTap: _expanded set to $newExpandedState");

            // Загружаем студентов, если:
            // 1. Элемент раскрывается (newExpandedState == true)
            // 2. Текущий пользователь - преподаватель
            // 3. Данные еще не были загружены успешно (_dataFetchedOnce == false)
            // 4. Загрузка не идет в данный момент (!_isFetching)
            if (newExpandedState &&
                isCurrentUserLecturer &&
                !_dataFetchedOnce &&
                !_isFetching) {
              debugPrint(
                  "[SCHEDULE ITEM DEBUG] onTap: Fetching students. newExpanded: $newExpandedState, isLecturer: $isCurrentUserLecturer, dataFetchedOnce: $_dataFetchedOnce, isFetching: $_isFetching");
              _fetchAttendedStudents();
            } else if (newExpandedState &&
                isCurrentUserLecturer &&
                _dataFetchedOnce &&
                !_isFetching) {
              debugPrint(
                  "[SCHEDULE ITEM DEBUG] onTap: Data already fetched and not refetching. newExpanded: $newExpandedState, isLecturer: $isCurrentUserLecturer, dataFetchedOnce: $_dataFetchedOnce, isFetching: $_isFetching");
            } else {
              debugPrint(
                  "[SCHEDULE ITEM DEBUG] onTap: Not fetching (or collapsing). newExpanded: $newExpandedState, isLecturer: $isCurrentUserLecturer, dataFetchedOnce: $_dataFetchedOnce, isFetching: $_isFetching");
            }
          }
          debugPrint("[SCHEDULE ITEM DEBUG] onTap: END");
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            shape: BoxShape.rectangle,
            color: theme.getTimeBasedSurfaceColor(
              widget.subject.dateTimeRange,
              isEven: widget.even,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 6,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    color: theme.getColorOfSubjectType(
                      widget.subject.subjectTypeEnum,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: verticalPadding,
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name,
                          style: theme.textTheme.titleMedium!
                              .copyWith(fontWeight: FontWeight.bold),
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                        _textWithIcon(
                          context,
                          Icons.location_on,
                          '${widget.subject.address.auditorium}/${widget.subject.address.building}',
                        ),
                        if (_expanded)
                          _textWithIcon(
                            context,
                            Icons.person,
                            widget.subject.lecturer,
                          ),
                        if (_expanded)
                          _textWithIcon(
                            context,
                            Icons.school,
                            "Поток: ${widget.subject.groups.join("|")}",
                          ),
                        Text(
                          widget.subject.subjectType,
                          style: theme.textTheme.labelLarge!.copyWith(
                            color: theme.getColorOfSubjectType(
                              widget.subject.subjectTypeEnum,
                            ),
                            fontStyle: FontStyle.italic,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // БЛОК ОТОБРАЖЕНИЯ СПИСКА СТУДЕНТОВ 
                        if (_expanded && isCurrentUserLecturer) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              "Отметившиеся студенты:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_isLoadingStudents)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                  width: 24,
                                  height: 24, 
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5)),
                            ))
                          else if (_studentsListError != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(_studentsListError!,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12)),
                            )
                          else if (!_dataFetchedOnce ||
                              _attendedStudents == null ||
                              _attendedStudents!.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("Нет отметившихся студентов",
                                  style: TextStyle(fontSize: 12)),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _attendedStudents!.map((student) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 1.0),
                                  child: Text(
                                    '• ${student.studentFullName} - ${DateFormat('HH:mm').format(student.dateTime.toLocal())}',
                                    style: theme.textTheme
                                        .bodySmall, 
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                        // КОНЕЦ БЛОКА ОТОБРАЖЕНИЯ 
                      ],
                    ),
                  ),
                ),
                Padding(
                  // Время начала и конца пары
                  padding: const EdgeInsets.symmetric(
                    vertical: verticalPadding,
                    horizontal: horizontalPadding,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeFormatter.format(
                            widget.subject.dateTimeRange.start.toLocal()),
                        style: theme.textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        timeFormatter
                            .format(widget.subject.dateTimeRange.end.toLocal()),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: extraColors.ligtherTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textWithIcon(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final extraColors = theme.extension<UnnMobileColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0, right: 4.0),
          child: Icon(
            icon,
            color: extraColors.ligtherTextColor,
            applyTextScaling: true,
            size: 16,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.labelLarge!
                .copyWith(color: extraColors.ligtherTextColor),
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            softWrap: _expanded, 
          ),
        ),
      ],
    );
  }
}
