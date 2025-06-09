import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injector/injector.dart';
import 'package:local_auth/local_auth.dart';
import 'package:unn_mobile/core/models/profile/student_data.dart';

import 'package:unn_mobile/core/models/schedule/subject.dart';
import 'package:unn_mobile/core/services/implementations/common/storage_service_impl.dart';
import 'package:unn_mobile/core/viewmodels/main_page/common/profile_view_model.dart';
import 'package:unn_mobile/core/providers/interfaces/authorisation/auth_data_provider.dart';
import 'package:unn_mobile/core/providers/implementations/authorisation/authorisation_data_provider_impl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:unn_mobile/core/viewmodels/main_page/schedule/schedule_tab_view_model.dart';

class AttendanceScreenView extends StatefulWidget {
  final Subject? subject;

  const AttendanceScreenView({Key? key, this.subject}) : super(key: key);

  @override
  _AttendanceScreenViewState createState() => _AttendanceScreenViewState();
}

class _AttendanceScreenViewState extends State<AttendanceScreenView> {
  static const platform = MethodChannel('nfc_channel');
  final LocalAuthentication auth = LocalAuthentication();

  String _status = 'Требуется аутентификация';
  bool _isNfcAvailable = true;
  bool _isUserAuthenticated = false;

  late ProfileViewModel _profileViewModel;
  late AuthDataProvider _authDataProvider;
  late ScheduleTabViewModel _scheduleVM;
  String _fullname = 'Загрузка...';
  String _studentId = 'Загрузка...';
  String _lecturerName = 'Загрузка...';
  String _disciplineName = 'Загрузка...';
  String _groupName = 'Загрузка...';

  Future<void> _clearNativeNfcData() async {
    try {
      await platform.invokeMethod('clearNfcData');
      debugPrint("NFC data cleared on native side.");
    } on PlatformException catch (e) {
      debugPrint("Failed to clear NFC data: ${e.message}");
    }
  }

  @override
  void initState() {
    super.initState();

    _scheduleVM = Injector.appInstance.get<ScheduleTabViewModel>();

    _lecturerName = widget.subject?.lecturer ?? 'неизвестно';
    _disciplineName = widget.subject?.name ?? "Неизвестная дисциплина";
    _clearNativeNfcData().then((_) {
      _initiateAuthenticationAndNfcProcess();
    });
  }

  @override
  void dispose() {
    _clearNativeNfcData();
    super.dispose();
  }

  Future<void> _initiateAuthenticationAndNfcProcess() async {
    bool isAuthenticated = false;
    try {
      isAuthenticated = await auth.authenticate(
        localizedReason: 'Пожалуйста, подтвердите личность для отметки',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Ошибка аутентификации: ${e.message}');
      if (mounted) {
        setState(() {
          _status = 'Ошибка аутентификации: ${e.code}';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    if (!mounted) return;

    if (isAuthenticated) {
      setState(() {
        _isUserAuthenticated = true;
        _status = 'Аутентификация пройдена.\nЗагрузка данных...';
      });
      await _setupAfterAuthentication();
    } else {
      await _clearNativeNfcData();
      setState(() {
        _status = 'Аутентификация отменена\nили не удалась.';
      });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _setupAfterAuthentication() async {
    final storageService = StorageServiceImpl();
    _authDataProvider = AuthorisationDataProviderImpl(storageService);
    _profileViewModel = ProfileViewModel.currentUser();

    platform.setMethodCallHandler(_handleMethodCall);
    await _checkNfcAvailability();

    if (!_isNfcAvailable) {
      if (mounted) {
        setState(() {
          _status = 'NFC недоступен.\nОтметка невозможна.';
        });
      }
      return;
    }

    await _loadProfileData();
    await _loadAuthData();
    await _loadLecturerData();
    await _loadSubjectName();
    if (mounted) {
      _trySendToNfc();
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (!_isUserAuthenticated) {
      debugPrint(
          'NFC событие проигнорировано: пользователь не аутентифицирован.');
      return;
    }
    switch (call.method) {
      case 'nfcStatus':
        String message = call.arguments as String;
        debugPrint('Сообщение от нативной части: $message');
        if (mounted) {
          setState(() {
            _status = message;
          });
        }
        break;
      default:
        debugPrint('Неизвестный метод от нативной части: ${call.method}');
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final bool isAvailable =
          await platform.invokeMethod('checkNfcAvailability');
      if (mounted) {
        setState(() {
          _isNfcAvailable = isAvailable;
          if (!isAvailable) _status = 'NFC недоступен\nна устройстве.';
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Ошибка проверки NFC:\n${e.message}';
          _isNfcAvailable = false;
        });
      }
    }
  }

  Future<void> _sendToNfc() async {
    if (!_isUserAuthenticated) {
      if (mounted)
        setState(() {
          _status = 'Требуется аутентификация\nперед отправкой.';
        });
      return;
    }
    if (!_isNfcAvailable) {
      if (mounted)
        setState(() {
          _status = 'NFC недоступен\nна устройстве.';
        });
      return;
    }

    String studentId = _studentId;
    String fullname = _fullname;
    String deviceId = await getDeviceId();
    String lecturerName = _lecturerName;
    String disciplineName = _disciplineName;
    String groupName = _groupName;

    if (studentId == 'Загрузка...' ||
        fullname == 'Загрузка...' ||
        lecturerName == 'Загрузка...' ||
        disciplineName == 'Загрузка...' ||
        groupName == 'Загрузка...' ||
        fullname.isEmpty ||
        studentId.isEmpty ||
        lecturerName.isEmpty ||
        disciplineName.isEmpty ||
        groupName.isEmpty ||
        disciplineName == 'Неизвестная дисциплина' ||
        lecturerName == 'неизвестно' ||
        groupName == 'Группа не найдена') {
      if (mounted) {
        setState(() {
          _status =
              'Не все данные для отметки\n(вкл. группу) загружены\nили корректны.';
        });
      }
      return;
    }
    // ФИО|IDстуд|IDустройства|ФИОпреподавателя|Дисциплина|Группа
    String dataToSend =
        '$fullname|$studentId|$deviceId|$_lecturerName|$_disciplineName|$groupName';
    debugPrint('Данные для отправки на NFC (Flutter): $dataToSend');

    try {
      // ЖДЕМ завершения platform.invokeMethod, прежде чем менять статус
      final String? nativeResponse =
          await platform.invokeMethod('sendNfcData', {'data': dataToSend});

      if (mounted) {
        setState(() {
          // Меняем статус только ПОСЛЕ того, как нативная часть подтвердила получение данных
          _status = nativeResponse ??
              'Поднесите телефон. Ошибка ответа от NFC модуля.';
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Ошибка подготовки NFC:\n${e.message}';
        });
      }
    }
  }

  Future<void> _loadProfileData() async {
    final completer = Completer<void>();

    if (_profileViewModel.loadedData != null &&
        _profileViewModel.fullname.isNotEmpty &&
        _profileViewModel.fullname != 'Не удалось загрузить' &&
        !_profileViewModel.isLoading &&
        !_profileViewModel.hasError) {
      if (mounted) {
        setState(() {
          _fullname = _profileViewModel.fullname;
          if (_profileViewModel.loadedData is StudentData) {
            _groupName =
                (_profileViewModel.loadedData as StudentData).eduGroup ??
                    'Группа не найдена';
            if (_groupName.isEmpty) _groupName = 'Группа не найдена';
          } else {
            _groupName = 'N/A (не студент)';
          }
        });
      }
      completer.complete();
      return completer.future;
    }

    void profileListener() {
      if (!mounted) {
        _profileViewModel.removeListener(profileListener);
        if (!completer.isCompleted) {
          completer.completeError(
              StateError("Widget unmounted during profile load"));
        }
        return;
      }
      if (!_profileViewModel.isLoading) {
        if (_profileViewModel.hasError) {
          if (mounted) {
            setState(() {
              _fullname = "Ошибка загрузки ФИО";
              _groupName = "Ошибка загрузки группы";
            });
          }
          if (!completer.isCompleted) {
            completer
                .completeError(Exception("ProfileViewModel reported an error"));
          }
        } else if (_profileViewModel.loadedData != null &&
            _profileViewModel.fullname.isNotEmpty &&
            _profileViewModel.fullname != 'Не удалось загрузить') {
          if (mounted) {
            setState(() {
              _fullname = _profileViewModel.fullname;
              if (_profileViewModel.loadedData is StudentData) {
                _groupName =
                    (_profileViewModel.loadedData as StudentData).eduGroup ??
                        'Группа не найдена';
                if (_groupName.isEmpty) _groupName = 'Группа не найдена';
              } else {
                _groupName = 'N/A (не студент)';
              }
            });
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        } else {
          if (mounted) {
            setState(() {
              _fullname = "ФИО не получено";
              _groupName = "Группа не получена";
            });
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
        _profileViewModel.removeListener(profileListener);
      }
    }

    _profileViewModel.addListener(profileListener);
    _profileViewModel.init(loadCurrentUser: true, force: false);
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      if (!completer.isCompleted) {
        _profileViewModel.removeListener(profileListener);
        if (mounted) {
          setState(() {
            if (_fullname == 'Загрузка...') _fullname = "Таймаут загрузки ФИО";
            if (_groupName == 'Загрузка...')
              _groupName = "Таймаут загрузки группы";
          });
        }
      }
    }).catchError((error) {
      if (mounted) {
        if (_fullname == 'Загрузка...') _fullname = "Ошибка при загрузке ФИО";
        if (_groupName == 'Загрузка...')
          _groupName = "Ошибка при загрузке группы";
        setState(() {});
      }
    });
  }

  Future<void> _loadAuthData() async {
    try {
      final authData = await _authDataProvider.getData();
      if (mounted) {
        setState(() {
          _studentId = authData.login;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _studentId = 'Ошибка получения ID';
        });
      }
    }
  }

  Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    return "UnknownDevice";
  }

  Future<void> _loadLecturerData() async {
    try {
      final teacher = await _scheduleVM.getCurrentTeacher();
      if (mounted && teacher != null && teacher.isNotEmpty) {
        setState(() {
          _lecturerName = teacher;
        });
      } else if (mounted &&
          (_lecturerName == 'Загрузка...' || _lecturerName == 'неизвестно')) {
        setState(() {
          _lecturerName = 'Преподаватель не определен';
        });
      }
    } catch (e) {
      if (mounted &&
          (_lecturerName == 'Загрузка...' || _lecturerName == 'неизвестно')) {
        setState(() {
          _lecturerName = 'Ошибка получения преподавателя';
        });
      }
    }
  }

  void _trySendToNfc() {
    if (_isUserAuthenticated &&
        _fullname != 'Загрузка...' &&
        _fullname.isNotEmpty &&
        !_fullname.contains("Ошибка") &&
        !_fullname.contains("Таймаут") &&
        !_fullname.contains("не получено") &&
        _studentId != 'Загрузка...' &&
        _studentId.isNotEmpty &&
        !_studentId.contains("Ошибка") &&
        !_studentId.contains("не найден") &&
        _lecturerName != 'Загрузка...' &&
        _lecturerName.isNotEmpty &&
        !_lecturerName.contains("Ошибка") &&
        _lecturerName != 'неизвестно' &&
        _lecturerName != 'Преподаватель не определен' &&
        _disciplineName != 'Загрузка...' &&
        _disciplineName.isNotEmpty &&
        _disciplineName != 'Неизвестная дисциплина' &&
        _groupName != 'Загрузка...' &&
        _groupName.isNotEmpty &&
        !_groupName.contains("Ошибка") &&
        _groupName != 'Группа не найдена' &&
        _groupName != 'N/A' &&
        _isNfcAvailable) {
      _sendToNfc();
    } else if (_isUserAuthenticated) {
      if (mounted) {
        setState(() {
          if (!_isNfcAvailable) {
            _status = 'NFC недоступен.\nОтметка невозможна.';
          } else {
            _status =
                'Не все данные для отметки\n(ФИО, ID, Преподаватель, Дисциплина, Группа)\nзагружены или корректны.';
            debugPrint(
                "Данные для NFC не готовы: Fullname: $_fullname, StudentID: $_studentId, Lecturer: $_lecturerName, Discipline: $_disciplineName, Group: $_groupName, NFC Available: $_isNfcAvailable");
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отметка присутствия')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_isUserAuthenticated ||
                  ((_fullname == 'Загрузка...' ||
                          _studentId == 'Загрузка...' ||
                          _lecturerName == 'Загрузка...') &&
                      _status.toLowerCase().contains('загрузка')))
                const CircularProgressIndicator()
              else
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    double idealSize = constraints.maxWidth * 0.4;
                    double actualSize = idealSize.clamp(80.0, 180.0);

                    Widget displayWidget;

                    final statusLowerCase = _status.toLowerCase();

                    if (statusLowerCase.contains('успешно') ||
                        statusLowerCase.contains('вы успешно отметились')) {
                      displayWidget = Icon(Icons.check_circle_outline,
                          size: actualSize * 0.7, color: Colors.green);
                    } else if (statusLowerCase.contains('ошибка') ||
                        statusLowerCase.contains('не удалось') ||
                        statusLowerCase.contains('уже отметились') ||
                        statusLowerCase.contains('не время отметки')) {
                      displayWidget = Icon(Icons.error_outline,
                          size: actualSize * 0.7, color: Colors.red);
                    } else {
                      displayWidget = Icon(
                        Icons.nfc,
                        size: actualSize,
                        color: const Color(0xFF1A63B7),
                      );
                    }
                    return displayWidget;
                  },
                ),
              const SizedBox(height: 30),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.black87, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSubjectName() async {
    try {
      final subjectName = await _scheduleVM.getCurrentSubjectName();
      if (mounted && subjectName != null && subjectName.isNotEmpty) {
        setState(() {
          _disciplineName = subjectName;
        });
      } else if (mounted &&
          (_disciplineName == 'Загрузка...' ||
              _disciplineName == 'неизвестно')) {
        setState(() {
          _disciplineName = 'Название предмета не определено';
        });
      }
    } catch (e) {
      if (mounted &&
          (_disciplineName == 'Загрузка...' ||
              _disciplineName == 'неизвестно')) {
        setState(() {
          _disciplineName = 'Ошибка получения названия предмета';
        });
      }
    }
  }
}
