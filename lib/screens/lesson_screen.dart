import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';

class LessonScreen extends StatefulWidget {
  final String lessonId;
  const LessonScreen({super.key, required this.lessonId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _selected = -1;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final lesson = LearningRepository.getLesson(widget.lessonId)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: ListView(
          children: [
            Text(lesson.content, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Text('Quick check', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final q in lesson.miniQuiz) ...[
              Text(q.prompt, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              ...List.generate(q.options.length, (i) {
                return RadioListTile<int>(
                  value: i,
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v ?? -1),
                  title: Text(q.options[i]),
                );
              }),
              const SizedBox(height: 8),
              if (_selected != -1)
                Text(
                  _selected == q.correctIndex
                      ? 'Correct! ${q.explanation ?? ''}'
                      : 'Not quite. ${q.explanation ?? ''}',
                  style: TextStyle(
                    color:
                        _selected == q.correctIndex
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                  ),
                ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _completed
                      ? null
                      : () async {
                        await context.read<ProgressService>().completeLesson(
                          lesson.id,
                        );
                        if (mounted) setState(() => _completed = true);
                      },
              child: Text(_completed ? 'Completed' : 'Mark lesson complete'),
            ),
          ],
        ),
      ),
    );
  }
}





