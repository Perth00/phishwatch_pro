class VideoScenario {
  final String id;
  final String title;
  final String videoUrl;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String category;
  final String difficulty;

  VideoScenario({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
    required this.difficulty,
  });
}
