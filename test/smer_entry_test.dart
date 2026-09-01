import 'package:flutter_test/flutter_test.dart';
import 'package:smer/models/journal_analysis.dart';
import 'package:smer/models/smer_entry.dart';

void main() {
  test('entry survives SQLite row conversion', () {
    final entry = SmerEntry(
      id: '1',
      createdAt: DateTime(2026, 9, 1),
      occurredAt: DateTime(2026, 9, 1, 12),
      situation: 'Коллега не ответил',
      thoughts: ['Я ему не важен'],
      emotions: [const SmerEmotion(name: 'Тревога', intensity: 75)],
      bodyReaction: 'Напряжение',
      behaviorReaction: 'Проверял сообщения',
    );
    final restored = SmerEntry.fromRow(entry.toRow());
    expect(restored.situation, entry.situation);
    expect(restored.emotions.single.intensity, 75);
    expect(restored.thoughts, ['Я ему не важен']);
  });

  test('analysis groups emotions and calculates average intensity', () {
    final entries = [
      SmerEntry(
        id: '1',
        createdAt: DateTime(2026, 9, 1),
        occurredAt: DateTime(2026, 9, 1),
        situation: 'Первая',
        thoughts: const [],
        emotions: const [
          SmerEmotion(name: 'Тревога', intensity: 80),
          SmerEmotion(name: 'Грусть', intensity: 40),
        ],
        bodyReaction: '',
        behaviorReaction: '',
      ),
      SmerEntry(
        id: '2',
        createdAt: DateTime(2026, 9, 2),
        occurredAt: DateTime(2026, 9, 2),
        situation: 'Вторая',
        thoughts: const [],
        emotions: const [SmerEmotion(name: 'Тревога', intensity: 60)],
        bodyReaction: '',
        behaviorReaction: '',
      ),
    ];

    final analysis = JournalAnalysis.fromEntries(entries);

    expect(analysis.entryCount, 2);
    expect(analysis.emotionCount, 3);
    expect(analysis.emotions.first.name, 'Тревога');
    expect(analysis.emotions.first.count, 2);
    expect(analysis.emotions.first.averageIntensity, 70);
  });
}
