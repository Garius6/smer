import 'smer_entry.dart';

class EmotionInsight {
  const EmotionInsight({
    required this.name,
    required this.count,
    required this.averageIntensity,
  });

  final String name;
  final int count;
  final int averageIntensity;
}

class JournalAnalysis {
  const JournalAnalysis({
    required this.entryCount,
    required this.emotionCount,
    required this.emotions,
  });

  final int entryCount;
  final int emotionCount;
  final List<EmotionInsight> emotions;

  factory JournalAnalysis.fromEntries(List<SmerEntry> entries) {
    final intensitiesByEmotion = <String, List<int>>{};
    for (final entry in entries) {
      for (final emotion in entry.emotions) {
        intensitiesByEmotion
            .putIfAbsent(emotion.name, () => [])
            .add(emotion.intensity);
      }
    }
    final emotions =
        intensitiesByEmotion.entries
            .map(
              (entry) => EmotionInsight(
                name: entry.key,
                count: entry.value.length,
                averageIntensity:
                    entry.value.reduce((sum, value) => sum + value) ~/
                    entry.value.length,
              ),
            )
            .toList()
          ..sort((left, right) {
            final byCount = right.count.compareTo(left.count);
            return byCount != 0 ? byCount : left.name.compareTo(right.name);
          });
    return JournalAnalysis(
      entryCount: entries.length,
      emotionCount: intensitiesByEmotion.values.fold(
        0,
        (sum, intensities) => sum + intensities.length,
      ),
      emotions: emotions,
    );
  }
}
