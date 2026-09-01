import 'package:flutter_test/flutter_test.dart';
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
}
