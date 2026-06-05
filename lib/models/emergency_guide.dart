class EmergencyGuide {
  const EmergencyGuide({
    required this.id,
    required this.title,
    required this.description,
    required this.priorityLevel,
    required this.steps,
    required this.whatNotToDo,
    required this.whenToSeekHelp,
  });

  final String id;
  final String title;
  final String description;
  final String priorityLevel;
  final List<EmergencyGuideStep> steps;
  final List<String> whatNotToDo;
  final List<String> whenToSeekHelp;
}

class EmergencyGuideStep {
  const EmergencyGuideStep({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;
}