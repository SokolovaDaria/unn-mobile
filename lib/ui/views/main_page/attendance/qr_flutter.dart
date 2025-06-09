import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injector/injector.dart';
import 'package:local_auth/local_auth.dart';
import 'package:unn_mobile/core/models/profile/student_data.dart';
import 'package:unn_mobile/core/services/implementations/common/storage_service_impl.dart';
import 'package:unn_mobile/core/viewmodels/main_page/common/profile_view_model.dart';
import 'package:unn_mobile/core/providers/interfaces/authorisation/auth_data_provider.dart';
import 'package:unn_mobile/core/providers/implementations/authorisation/authorisation_data_provider_impl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:unn_mobile/core/viewmodels/main_page/schedule/schedule_tab_view_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;

class GenerateQrScreenView extends StatefulWidget {
  const GenerateQrScreenView({Key? key}) : super(key: key);

  @override
  _GenerateQrScreenViewState createState() => _GenerateQrScreenViewState();
}

class _GenerateQrScreenViewState extends State<GenerateQrScreenView> {
  final LocalAuthentication auth = LocalAuthentication();

  String _statusMessage = 'Требуется аутентификация';
  bool _isUserAuthenticated = false;
  bool _isLoadingData = true;
  bool _isCheckingStatus = false;
  String? _qrDataString;
  String _errorMessage = '';

  String _studentFullname = '';
  String _studentId = '';
  String _phoneDeviceId = '';
  String _lecturerName = '';
  String _disciplineName = '';
  String _groupName = '';

  late ProfileViewModel _profileViewModel;
  late AuthDataProvider _authDataProvider;
  late ScheduleTabViewModel _scheduleVM;

  Timer? _statusCheckTimer;
  int _statusCheckAttempts = 0;
  final int _maxStatusCheckAttempts =
      5; 
  final Duration _statusCheckInterval =
      const Duration(seconds: 3); 
  final Duration _initialDelayBeforeStatusCheck =
      const Duration(seconds: 5); 

  final String _statusCheckServerUrl =
      "http://192.168.240.32:8080/api/v1/attendance/status";

  @override
  void initState() {
    super.initState();
    try {
      _scheduleVM = Injector.appInstance.get<ScheduleTabViewModel>();
    } catch (e) {
      debugPrint("Error initializing ScheduleTabViewModel in initState: $e");
    }
    _initiateAuthenticationAndDataLoading();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiateAuthenticationAndDataLoading() async {
    bool isAuthenticated = false;
    setState(() {
      _statusMessage = 'Требуется аутентификация...';
      _isLoadingData = true;
      _isCheckingStatus = false; 
      _errorMessage = '';
      _statusCheckTimer?.cancel(); 
      _statusCheckAttempts = 0; 
    });

    try {
      isAuthenticated = await auth.authenticate(
        localizedReason:
            'Пожалуйста, подтвердите личность для генерации QR-кода',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Ошибка аутентификации: ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Ошибка аутентификации: ${e.code}.\nПопробуйте снова.';
          _isLoadingData = false;
        });
      }
      return;
    }

    if (!mounted) return;

    if (isAuthenticated) {
      setState(() {
        _isUserAuthenticated = true;
        _statusMessage = 'Аутентификация пройдена. Подготовка данных...';
      });
      await _loadDataForQr();
    } else {
      setState(() {
        _isUserAuthenticated = false;
        _statusMessage = 'Аутентификация отменена или не удалась.';
        _isLoadingData = false;
        _errorMessage =
            'Для генерации QR-кода необходимо пройти аутентификацию.';
      });
    }
  }

  Future<void> _loadDisciplineName() async {
    try {
      final subjectName = await _scheduleVM.getCurrentSubjectName();
      if (mounted) {
        if (subjectName != null && subjectName.isNotEmpty) {
          _disciplineName = subjectName;
        } else {
          _disciplineName = 'Дисциплина не определена';
        }
      }
    } catch (e) {
      debugPrint("Error loading discipline name: $e");
      if (mounted) {
        _disciplineName = 'Ошибка загрузки дисциплины';
      }
    }
  }

  Future<void> _loadGroupName() async {
    if (_profileViewModel.loadedData != null &&
        _profileViewModel.loadedData is StudentData) {
      final studentData = _profileViewModel.loadedData as StudentData;
      if (mounted) {
        _groupName = studentData.eduGroup ?? 'Группа не определена';
        if (_groupName.isEmpty) _groupName = 'Группа не определена';
      }
    } else {
      if (mounted) {
        _groupName = 'Группа не определена';
      }
    }
  }

  Future<void> _loadDataForQr() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = '';
      _statusMessage = 'Загрузка данных для QR-кода...';
      _isCheckingStatus = false;
      _statusCheckTimer?.cancel();
      _statusCheckAttempts = 0;
    });

    try {
      _studentFullname = await _fetchStudentFullnameFromViewModel();
      await _loadGroupName();

      final storageService = StorageServiceImpl();
      _authDataProvider = AuthorisationDataProviderImpl(storageService);
      final authData = await _authDataProvider.getData();
      _studentId = authData.login;
      if (_studentId.isEmpty)
        throw Exception("Не удалось загрузить ID студента.");

      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Theme.of(context).platform == TargetPlatform.android) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _phoneDeviceId = androidInfo.id ?? "unknown_android_id";
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _phoneDeviceId = iosInfo.identifierForVendor ?? "unknown_ios_id";
      } else {
        _phoneDeviceId = "unknown_platform_id";
      }
      if (_phoneDeviceId.isEmpty)
        throw Exception("Не удалось получить ID устройства.");

      final teacherFromVM = await _scheduleVM.getCurrentTeacher();
      _lecturerName = (teacherFromVM != null && teacherFromVM.isNotEmpty)
          ? teacherFromVM
          : "Преподаватель не определен";
      await _loadDisciplineName();

      if (_studentFullname.isEmpty ||
          _studentFullname.contains("Ошибка") ||
          _studentFullname.contains("Таймаут") ||
          _studentFullname.contains("не получено")) {
        throw Exception("Не удалось загрузить ФИО студента.");
      }
      if (_groupName.isEmpty ||
          _groupName.contains("Ошибка") ||
          _groupName.contains("Таймаут") ||
          _groupName.contains("не определена") ||
          _groupName == "N/A (не студент)") {
        throw Exception("Не удалось определить группу студента.");
      }
      if (_disciplineName.isEmpty ||
          _disciplineName.contains("Ошибка") ||
          _disciplineName.contains("не определена")) {
        throw Exception("Не удалось определить название дисциплины.");
      }
      if (_lecturerName.isEmpty ||
          _lecturerName.contains("Ошибка") ||
          _lecturerName.contains("не определен")) {
        throw Exception("Не удалось определить имя преподавателя.");
      }

      _qrDataString =
          '$_studentFullname|$_studentId|$_phoneDeviceId|$_lecturerName|$_disciplineName|$_groupName';
      debugPrint("QR Data String for User $_studentId: $_qrDataString");

      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _statusMessage = 'QR-код готов.\nПокажите его сканеру.';
        });
        // запускаем таймер для проверки статуса ПОСЛЕ успешной генерации QR
        _startStatusCheckTimer();
      }
    } catch (e) {
      debugPrint("Error loading data for QR: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Ошибка подготовки данных:\n${e.toString()}";
          _isLoadingData = false;
        });
      }
    }
  }

  Future<String> _fetchStudentFullnameFromViewModel() async {
    final completer = Completer<String>();
    _profileViewModel = ProfileViewModel.currentUser();

    if (_profileViewModel.loadedData != null &&
        _profileViewModel.fullname.isNotEmpty &&
        _profileViewModel.fullname != 'Не удалось загрузить' &&
        !_profileViewModel.isLoading &&
        !_profileViewModel.hasError) {
      return _profileViewModel.fullname;
    }
    late Function() profileListener;
    profileListener = () {
      if (!mounted) {
        _profileViewModel.removeListener(profileListener);
        if (!completer.isCompleted)
          completer.completeError(StateError("Widget unmounted"));
        return;
      }
      if (!_profileViewModel.isLoading) {
        _profileViewModel.removeListener(profileListener);
        if (_profileViewModel.hasError ||
            _profileViewModel.fullname.isEmpty ||
            _profileViewModel.fullname == 'Не удалось загрузить') {
          if (!completer.isCompleted)
            completer.completeError(Exception(
                "Не удалось загрузить ФИО: ${_profileViewModel.hasError ?? 'неизвестная ошибка'}"));
        } else {
          if (!completer.isCompleted)
            completer.complete(_profileViewModel.fullname);
        }
      }
    };
    _profileViewModel.addListener(profileListener);
    if (!_profileViewModel.isLoading) {
      _profileViewModel.init(loadCurrentUser: true, force: false);
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      if (mounted) _profileViewModel.removeListener(profileListener);
      throw Exception("Таймаут загрузки ФИО студента.");
    } catch (e) {
      if (mounted) _profileViewModel.removeListener(profileListener);
      rethrow;
    }
  }

  void _startStatusCheckTimer() {
    _statusCheckTimer?.cancel(); 
    _statusCheckAttempts = 0; 

    _statusCheckTimer = Timer(_initialDelayBeforeStatusCheck, () {
      if (mounted && _isUserAuthenticated && _qrDataString != null) {
        _checkAttendanceStatus(); 
      }
    });
  }

  Future<void> _checkAttendanceStatus() async {
    if (!mounted || !_isUserAuthenticated || _qrDataString == null) {
      _statusCheckTimer?.cancel();
      return;
    }

    setState(() {
      _isCheckingStatus = true; 
    
    });

    _statusCheckAttempts++;
    debugPrint(
        "Checking attendance status, attempt: $_statusCheckAttempts for $_studentId");

    try {
     
      final uri = Uri.parse(_statusCheckServerUrl).replace(
        queryParameters: {
          'studentIdCard': _studentId,
          'disciplineName': _disciplineName,
          'teacherName': _lecturerName,
          'groupName': _groupName,
        
        },
      );

      debugPrint('Привет $uri');

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isCheckingStatus = false;
      });

      if (response.statusCode == 200) {
        String responseBody =
            utf8.decode(response.bodyBytes); 
        final Map<String, dynamic> responseData = jsonDecode(responseBody);
        final String serverStatus =
            responseData['status']?.toString().toUpperCase() ?? 'UNKNOWN';
        final String serverMessage =
            responseData['message'] ?? ''; 

        debugPrint(
            "Server status response for $_studentId: $serverStatus, Message: $serverMessage, Raw Body: $responseBody");

        if (serverStatus == 'MARKED_SUCCESSFULLY') {
          _statusCheckTimer?.cancel();
          setState(() {
            _statusMessage = 'Вы успешно отмечены!';
            
          });
        } else if (serverStatus == 'ALREADY_MARKED') {
          _statusCheckTimer?.cancel();
          setState(() {
            _statusMessage = 'Вы уже были отмечены ранее.';
           
          });
        } else if (serverStatus == 'MARKING_WINDOW_CLOSED' ||
            serverStatus == 'INVALID_TIME') {
          _statusCheckTimer?.cancel();
          setState(() {
            _statusMessage = 'Окно для отметки закрыто\nили время неверно.';
          });
        }
       
        else if (_statusCheckAttempts < _maxStatusCheckAttempts &&
            serverStatus == 'NOT_MARKED_YET') {
          _statusCheckTimer =
              Timer(_statusCheckInterval, _checkAttendanceStatus);
        } else if (_statusCheckAttempts >= _maxStatusCheckAttempts &&
            serverStatus == 'NOT_MARKED_YET') {
          _statusCheckTimer?.cancel();
          setState(() {
            _statusMessage =
                'Не удалось подтвердить отметку.\nПопробуйте обновить QR.';
           
          });
        } else {
          _statusCheckTimer?.cancel();
        }
      } else {
        debugPrint(
            "Failed to check status for $_studentId: ${response.statusCode}, Body: ${response.body}");
        if (_statusCheckAttempts < _maxStatusCheckAttempts) {
          _statusCheckTimer =
              Timer(_statusCheckInterval, _checkAttendanceStatus);
        } else {
          _statusCheckTimer?.cancel();
          setState(() {
            _statusMessage =
                'Ошибка проверки статуса отметки.\nПопробуйте обновить QR.';
          });
        }
      }
    } catch (e) {
      debugPrint("Exception while checking status for $_studentId: $e");
      if (!mounted) return;
      setState(() {
        _isCheckingStatus = false;
      });
      if (_statusCheckAttempts < _maxStatusCheckAttempts) {
        _statusCheckTimer = Timer(_statusCheckInterval, _checkAttendanceStatus);
      } else {
        _statusCheckTimer?.cancel();
        setState(() {
          _statusMessage = 'Ошибка сети при проверке статуса.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent;

    if (_isLoadingData) {
      mainContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(_statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ],
      );
    } else if (_errorMessage.isNotEmpty) {
      mainContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 20),
          Text(
            _errorMessage,
            style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Повторить"),
            onPressed: _initiateAuthenticationAndDataLoading,
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          )
        ],
      );
    } else if (_qrDataString != null && _isUserAuthenticated) {
      mainContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrImageView(
            data: _qrDataString!,
            version: QrVersions.auto,
            size: MediaQuery.of(context).size.width * 0.75,
            gapless: false,
            eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square, color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square, color: Colors.black),
          ),
          const SizedBox(height: 30),
          if (_isCheckingStatus &&
              !_statusMessage.toLowerCase().contains('успешно') &&
              !_statusMessage.toLowerCase().contains('уже были отмечены'))
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                      )),
                  SizedBox(width: 10),
                  Text("Проверка статуса...", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          Text(
            _statusMessage,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: _statusMessage.toLowerCase().contains('успешно')
                    ? Colors.green.shade700
                    : _statusMessage.toLowerCase().contains('уже были отмечены')
                        ? Colors.orange.shade700
                        : null),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (!_isCheckingStatus &&
              !_statusMessage.toLowerCase().contains('успешно') &&
              !_statusMessage.toLowerCase().contains('уже были отмечены'))
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Обновить QR-код"),
              onPressed: _loadDataForQr,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            )
        ],
      );
    } else {
      mainContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner_rounded,
              size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
              _statusMessage.isNotEmpty
                  ? _statusMessage
                  : 'Не удалось сгенерировать QR-код.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text("Пройти аутентификацию"),
            onPressed: _initiateAuthenticationAndDataLoading,
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          )
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR-код для отметки'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: mainContent),
      ),
    );
  }
}
