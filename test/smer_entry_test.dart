import 'package:flutter_test/flutter_test.dart';
import 'package:smer/models/journal_analysis.dart';
import 'package:smer/models/smer_entry.dart';
import 'package:smer/security/app_security.dart';

void main() {
  test('entry survives SQLite row conversion', () {
    final entry = SmerEntry(
      id: '1',
      createdAt: DateTime(2026, 9, 1),
      occurredAt: DateTime(2026, 9, 1, 12),
      situation: 'Коллега не ответил',
      thoughts: ['Я ему не важен'],
      emotions: [const SmerEmotion(name: 'Тревога', intensity: 75)],
      thoughtBelief: 80,
      alternativeThought: 'Он может быть занят.',
      alternativeEmotions: [const SmerEmotion(name: 'Тревога', intensity: 45)],
      bodyReaction: 'Напряжение',
      behaviorReaction: 'Проверял сообщения',
    );
    final restored = SmerEntry.fromRow(entry.toRow());
    expect(restored.situation, entry.situation);
    expect(restored.emotions.single.intensity, 75);
    expect(restored.thoughtBelief, 80);
    expect(restored.alternativeThought, 'Он может быть занят.');
    expect(restored.alternativeEmotions.single.intensity, 45);
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

  test('PIN hash depends on both PIN and salt', () {
    final hash = AppSecurity.hashPin('1234', 'salt');

    expect(hash, AppSecurity.hashPin('1234', 'salt'));
    expect(hash, isNot(AppSecurity.hashPin('1235', 'salt')));
    expect(hash, isNot(AppSecurity.hashPin('1234', 'other-salt')));
  });

  test('custom emotion keeps its group', () {
    const emotion = CustomEmotion(name: 'Надежда', group: 'Ожидание');

    expect(emotion.name, 'Надежда');
    expect(emotion.group, 'Ожидание');
  });
}
