/// কুইজ — self-paced quiz list + player (B9). STUB — replaced by the full
/// screen; committed so the router resolves while work is ongoing.
library;

import 'package:flutter/material.dart';

class QuizzesScreen extends StatelessWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class QuizPlayerScreen extends StatelessWidget {
  const QuizPlayerScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
