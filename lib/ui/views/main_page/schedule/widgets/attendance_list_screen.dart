import 'package:flutter/material.dart';
import 'package:unn_mobile/core/models/attendance/attendance_record.dart'; 
import 'package:unn_mobile/core/viewmodels/attendance/attendance_list_view_model.dart';
import 'package:intl/intl.dart'; 

class AttendanceListScreen extends StatelessWidget {
  final String lessonId; 

  const AttendanceListScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    final viewModel =
        AttendanceListViewModel(); 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отметившиеся студенты'),
      ),
      body: FutureBuilder<List<AttendanceRecord>>(
        
        future: viewModel.fetchAttendanceList(
            lessonId), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Никто не отметился'));
          }

          final students = snapshot.data!;
          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(student.studentFullName), 
                subtitle:
                    Text('Студенческий: ${student.studentIdCard}'), 
                trailing: Text(DateFormat('HH:mm:ss')
                    .format(student.dateTime)), 
              );
            },
          );
        },
      ),
    );
  }
}
