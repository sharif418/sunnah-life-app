/// কোর্স — course catalog with enrollment progress (B9). STUB — replaced by
/// the full screen; committed so the router resolves while work is ongoing.
library;

import 'package:flutter/material.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    super.key,
    required this.courseId,
    this.openLessonId,
  });

  final String courseId;
  final String? openLessonId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
