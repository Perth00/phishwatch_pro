import 'package:flutter/material.dart';

// Core learning content models and a simple in-memory repository of defaults

class MultipleChoiceQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  const MultipleChoiceQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });
}

class Lesson {
  final String id;
  final String category; // Basics, Email Security, Web Safety, Advanced
  final String title;
  final String content; // short text lesson
  final List<MultipleChoiceQuestion> miniQuiz;

  const Lesson({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.miniQuiz,
  });
}

class Quiz {
  final String id;
  final String title;
  final String difficulty; // Beginner, Intermediate, Advanced
  final List<MultipleChoiceQuestion> questions;
  final int passPercent; // e.g. 70

  const Quiz({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.questions,
    this.passPercent = 70,
  });
}

class Scenario {
  final String id;
  final String title;
  final String description; // scenario text like an email/message
  final bool isPhishing;
  final String rationale; // why

  const Scenario({
    required this.id,
    required this.title,
    required this.description,
    required this.isPhishing,
    required this.rationale,
  });
}

class LearningRepository {
  // Default beginner lesson
  static final List<Lesson> lessons = <Lesson>[
    Lesson(
      id: 'lesson_basics_1',
      category: 'Basics',
      title: 'What is Phishing?',
      content:
          'Phishing is a social engineering attack in which attackers trick you into revealing sensitive information or installing malware. Common signs include urgent language, suspicious links, and requests for credentials or payments.',
      miniQuiz: const [
        MultipleChoiceQuestion(
          id: 'q1',
          prompt: 'Which is a common sign of a phishing message?',
          options: [
            'A personal greeting from a known contact',
            'A request to verify your account urgently',
            'An email sent from your own address',
            'A message using proper grammar and spelling',
          ],
          correctIndex: 1,
          explanation:
              'Phishing messages often use urgency to pressure you into acting without thinking.',
        ),
      ],
    ),
  ];

  static final List<Quiz> quizzes = <Quiz>[
    Quiz(
      id: 'quiz_1',
      title: 'Phishing Basics',
      difficulty: 'Beginner',
      questions: const [
        MultipleChoiceQuestion(
          id: 'qb1',
          prompt:
              'A link shows bank.com but points to b4nk.com. Safe to click?',
          options: ['Yes', 'No'],
          correctIndex: 1,
          explanation:
              'Look closely: typosquatting (b4nk.com) is a phishing sign.',
        ),
        MultipleChoiceQuestion(
          id: 'qb2',
          prompt: 'What should you do with unexpected attachments (.exe/.scr)?',
          options: ['Open to check', 'Scan and verify first'],
          correctIndex: 1,
          explanation:
              'Executable attachments are high risk. Verify with IT/security.',
        ),
      ],
    ),
    Quiz(
      id: 'quiz_2',
      title: 'Email Security',
      difficulty: 'Intermediate',
      questions: const [
        MultipleChoiceQuestion(
          id: 'qe1',
          prompt: 'DMARC/ SPF/ DKIM help with which of the following?',
          options: [
            'Preventing spear phishing fully',
            'Authenticating sender domains',
            'Encrypting email content',
            'Blocking all spam automatically',
          ],
          correctIndex: 1,
          explanation:
              'These protocols authenticate sender domains; they do not encrypt content.',
        ),
      ],
    ),
  ];

  static final List<Scenario> scenarios = <Scenario>[
    Scenario(
      id: 'scenario_1',
      title: 'Banking Email',
      description:
          'Subject: URGENT: Account Locked\n\nDear customer, your account will be closed in 24 hours. Verify now: http://secure-bank-help.com',
      isPhishing: true,
      rationale:
          'Urgent threat, generic greeting, and suspicious URL that is not the official bank domain.',
    ),
    Scenario(
      id: 'scenario_2',
      title: 'Security Notification',
      description:
          'We detected a new login from your device. If this was you, ignore. If not, visit https://example.com/security to review.',
      isPhishing: false,
      rationale:
          'Legitimate services send notifications with official domains and without asking for passwords via email.',
    ),
  ];

  static Lesson? getLesson(String id) => lessons.firstWhere(
    (l) => l.id == id,
    orElse:
        () => const Lesson(
          id: 'missing',
          category: 'Basics',
          title: 'Lesson not found',
          content:
              'This is placeholder content. The requested lesson is missing in the dataset.',
          miniQuiz: <MultipleChoiceQuestion>[],
        ),
  );

  static Quiz? getQuiz(String id) => quizzes.firstWhere(
    (q) => q.id == id,
    orElse:
        () => const Quiz(
          id: 'missing',
          title: 'Quiz not found',
          difficulty: 'Beginner',
          questions: <MultipleChoiceQuestion>[],
        ),
  );

  static Scenario? getScenario(String id) => scenarios.firstWhere(
    (s) => s.id == id,
    orElse:
        () => const Scenario(
          id: 'missing',
          title: 'Scenario not found',
          description: 'This is a placeholder scenario.',
          isPhishing: true,
          rationale: 'No rationale available.',
        ),
  );
}
