import 'dart:convert';

class CustomEmotion {
  const CustomEmotion({required this.name, required this.group});

  final String name;
  final String group;
}

class SmerEmotion {
  const SmerEmotion({required this.name, required this.intensity});
  final String name;
  final int intensity;
  Map<String, dynamic> toJson() => {'name': name, 'intensity': intensity};
  factory SmerEmotion.fromJson(Map<String, dynamic> json) => SmerEmotion(
    name: json['name'] as String,
    intensity: json['intensity'] as int,
  );
}

class SmerEntry {
  const SmerEntry({
    required this.id,
    required this.createdAt,
    required this.occurredAt,
    required this.situation,
    required this.thoughts,
    required this.emotions,
    required this.bodyReaction,
    required this.behaviorReaction,
    this.thoughtBelief,
    this.alternativeThought = '',
    this.alternativeEmotions = const [],
  });
  final String id;
  final DateTime createdAt;
  final DateTime occurredAt;
  final String situation;
  final List<String> thoughts;
  final List<SmerEmotion> emotions;
  final String bodyReaction;
  final String behaviorReaction;
  final int? thoughtBelief;
  final String alternativeThought;
  final List<SmerEmotion> alternativeEmotions;
  Map<String, Object?> toRow() => {
    'id': id,
    'created_at': createdAt.millisecondsSinceEpoch,
    'occurred_at': occurredAt.millisecondsSinceEpoch,
    'situation': situation,
    'thoughts': jsonEncode(thoughts),
    'emotions': jsonEncode(emotions.map((e) => e.toJson()).toList()),
    'thought_belief': thoughtBelief,
    'alternative_thought': alternativeThought,
    'alternative_emotions': jsonEncode(
      alternativeEmotions.map((e) => e.toJson()).toList(),
    ),
    'body_reaction': bodyReaction,
    'behavior_reaction': behaviorReaction,
  };
  factory SmerEntry.fromRow(Map<String, Object?> row) {
    final rawEmotions = jsonDecode(row['emotions']! as String) as List<dynamic>;
    final rawAlternativeEmotions =
        jsonDecode(row['alternative_emotions'] as String? ?? '[]')
            as List<dynamic>;
    return SmerEntry(
      id: row['id']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at']! as int,
      ),
      situation: row['situation']! as String,
      thoughts: List<String>.from(
        jsonDecode(row['thoughts']! as String) as List<dynamic>,
      ),
      emotions: rawEmotions
          .map((e) => SmerEmotion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      thoughtBelief: row['thought_belief'] as int?,
      alternativeThought: row['alternative_thought'] as String? ?? '',
      alternativeEmotions: rawAlternativeEmotions
          .map((e) => SmerEmotion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bodyReaction: row['body_reaction']! as String,
      behaviorReaction: row['behavior_reaction']! as String,
    );
  }
}
