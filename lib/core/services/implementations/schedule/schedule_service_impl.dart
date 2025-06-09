import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:unn_mobile/core/constants/api/path.dart';
import 'package:unn_mobile/core/misc/api_helpers/api_helper.dart';
import 'package:unn_mobile/core/misc/dio_options_factory/options_with_expected_type_factory.dart';
import 'package:unn_mobile/core/misc/json_iterable_parser.dart';
import 'package:unn_mobile/core/models/schedule/schedule_filter.dart';
import 'package:unn_mobile/core/models/schedule/subject.dart';
import 'package:unn_mobile/core/services/interfaces/schedule/schedule_service.dart';
import 'package:unn_mobile/core/services/interfaces/common/logger_service.dart';

class _QueryParameterKeys {
  static const String _start = 'start';
  static const String _finish = 'finish';
  static const String _lng = 'lng';
}

class ScheduleServiceImpl implements ScheduleService {
  final LoggerService _loggerService;
  final ApiHelper _apiHelper;

  ScheduleServiceImpl(this._loggerService, this._apiHelper);

  @override
  Future<List<Subject>?> getSchedule(ScheduleFilter scheduleFilter) async {
    final path =
        '${ApiPath.schedule}${scheduleFilter.idType.name}/${scheduleFilter.id}';

    Response response;
    try {
      response = await _apiHelper.get(
        path: path,
        queryParameters: {
          _QueryParameterKeys._start: scheduleFilter.dateTimeRange.start
              .toIso8601String()
              .split('T')[0]
              .replaceAll('-', '.'),
          _QueryParameterKeys._finish: scheduleFilter.dateTimeRange.end
              .toIso8601String()
              .split('T')[0]
              .replaceAll('-', '.'),
          _QueryParameterKeys._lng: '1',
        },
        options: OptionsWithExpectedTypeFactory.list,
      );
    } catch (error, stackTrace) {
      _loggerService.logError(error, stackTrace);
      return null;
    }

    return parseJsonIterable<Subject>(
      response.data,
      Subject.fromJson,
      _loggerService,
    );
  }

  @override
  Future<String?> getCurrentPairTeacher(ScheduleFilter baseFilter) async {
    try {
      final now = DateTime.now().toLocal();

      // Создаем фильтр на текущий день
      final todayFilter = ScheduleFilter(
        baseFilter.idType,
        baseFilter.id,
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      );

      // Получаем расписание на сегодня
      final todaySchedule = await getSchedule(todayFilter);
      if (todaySchedule == null) return null;

      // Ищем текущую пару
      for (final subject in todaySchedule) {
        final lessonStart = subject.dateTimeRange.start.toLocal();
        final lessonEnd = subject.dateTimeRange.end.toLocal();

        // Валидация временного интервала
        if (lessonStart.isAfter(lessonEnd)) {
          _loggerService.logError(
            'Некорректное время занятия: ${subject.name}',
            StackTrace.current,
          );
          continue;
        }

        // Проверка текущего времени
        if (baseFilter.dateTimeRange.start.isAfter(lessonStart) &&
            baseFilter.dateTimeRange.end.isBefore(lessonEnd)) {
          return subject.lecturer.isNotEmpty
              ? subject.lecturer
              : 'Преподаватель не указан';
        }
      }
    } catch (e, st) {
      _loggerService.logError(e, st);
    }
    return null;
  }

  @override
  Future<String?> getCurrentPairName(ScheduleFilter baseFilter) async {
    // НОВЫЙ МЕТОД
    try {
      final now = DateTime.now().toLocal();

      // Создаем фильтр на текущий день
      final todayFilter = ScheduleFilter(
        baseFilter.idType,
        baseFilter.id,
        DateTimeRange(
          start:
              DateTime(now.year, now.month, now.day, 0, 0, 0), // С начала дня
          end: DateTime(
              now.year, now.month, now.day, 23, 59, 59), // До конца дня
        ),
      );

      final todaySchedule = await getSchedule(todayFilter);
      if (todaySchedule == null || todaySchedule.isEmpty) {
        return null;
      }

      for (final subject in todaySchedule) {
        final lessonStart = subject.dateTimeRange.start.toLocal();
        final lessonEnd = subject.dateTimeRange.end.toLocal();

        if (lessonStart.isAfter(lessonEnd)) {
          _loggerService.logError(
            'Некорректное время занятия (для имени): ${subject.name} ($lessonStart - $lessonEnd)',
            StackTrace.current,
          );
          continue;
        }

        // Проверка, что текущее время 'now' (из baseFilter) попадает в интервал пары
        // baseFilter.dateTimeRange.start - это время, для которого мы ищем пару (обычно текущее)
        if (!now.isBefore(lessonStart) && now.isBefore(lessonEnd)) {
          return subject.name.isNotEmpty
              ? subject.name
              : 'Название пары не указано';
        }
      }
    } catch (e, st) {
      _loggerService.logError('Ошибка в getCurrentPairName: $e', st);
    }
    return null;
  }
}
