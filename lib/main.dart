import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/smer_store.dart';
import 'models/journal_analysis.dart';
import 'models/smer_entry.dart';

const emotionGroups = {
  'Радость': [
    'Радость',
    'Интерес',
    'Воодушевление',
    'Облегчение',
    'Удовлетворение',
    'Благодарность',
  ],
  'Грусть': ['Грусть', 'Тоска', 'Разочарование', 'Одиночество', 'Сожаление'],
  'Тревога и страх': [
    'Тревога',
    'Беспокойство',
    'Напряжение',
    'Неуверенность',
    'Страх',
  ],
  'Злость': ['Злость', 'Раздражение', 'Обида', 'Возмущение'],
  'Стыд и вина': ['Стыд', 'Вина', 'Смущение'],
  'Спокойствие': [
    'Спокойствие',
    'Безопасность',
    'Уверенность',
    'Умиротворение',
  ],
};

void main() => runApp(SmerApp(store: SqliteSmerStore()));

class SmerApp extends StatelessWidget {
  const SmerApp({super.key, required this.store});
  final SmerStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'СМЭР',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('ru')],
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9B5A42),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFF8F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFF8F5),
        surfaceTintColor: Colors.transparent,
      ),
      useMaterial3: true,
    ),
    home: JournalPage(store: store),
  );
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.store});
  final SmerStore store;
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  List<SmerEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _showOnboardingIfNeeded();
  }

  Future<void> _showOnboardingIfNeeded() async {
    if (await widget.store.isOnboardingSeen() || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Дневник СМЭР'),
        content: const Text(
          'СМЭР помогает заметить связь между ситуацией, автоматическими мыслями, эмоциями и реакциями. Это инструмент самонаблюдения, а не замена медицинской или психологической помощи.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
    await widget.store.markOnboardingSeen();
  }

  Future<void> _loadEntries() async {
    final entries = await widget.store.loadEntries();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _openEditor([SmerEntry? entry]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorPage(store: widget.store, entry: entry),
      ),
    );
    if (saved == true) await _loadEntries();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('СМЭР'),
      actions: [
        TextButton.icon(
          onPressed: _entries == null
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnalysisPage(entries: _entries!),
                  ),
                ),
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Анализ'),
        ),
      ],
    ),
    body: _entries == null
        ? const Center(child: CircularProgressIndicator())
        : _entries!.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Здесь появятся ваши наблюдения.\nСоздайте первую запись, когда захотите разобрать эпизод.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _entries!.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => EntryCard(
              entry: _entries![index],
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntryViewPage(
                      store: widget.store,
                      entry: _entries![index],
                    ),
                  ),
                );
                if (changed == true) await _loadEntries();
              },
            ),
          ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _openEditor,
      icon: const Icon(Icons.add),
      label: const Text('Запись'),
    ),
  );
}

class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.onTap});
  final SmerEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(
        entry.situation,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatDate(entry.occurredAt)}${entry.emotions.isEmpty ? '' : ' · ${entry.emotions.map((e) => '${e.name} ${e.intensity}%').join(', ')}'}',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key, required this.entries});
  final List<SmerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final analysis = JournalAnalysis.fromEntries(entries);
    return Scaffold(
      appBar: AppBar(title: const Text('Анализ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Ваши наблюдения',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Это сводка данных из ваших записей, а не оценка психологического состояния.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _AnalysisMetric(
                    value: '${analysis.entryCount}',
                    label: 'записей',
                  ),
                  const SizedBox(width: 24),
                  _AnalysisMetric(
                    value: '${analysis.emotionCount}',
                    label: 'эмоций отмечено',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Частые эмоции', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (analysis.emotions.isEmpty)
            const Text(
              'Добавьте эмоции в записи, чтобы увидеть закономерности.',
            )
          else
            ...analysis.emotions
                .take(5)
                .map(
                  (emotion) => Card(
                    child: ListTile(
                      title: Text(emotion.name),
                      subtitle: Text(
                        '${emotion.count} раз · средняя интенсивность ${emotion.averageIntensity}%',
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _AnalysisMetric extends StatelessWidget {
  const _AnalysisMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class EntryViewPage extends StatelessWidget {
  const EntryViewPage({super.key, required this.store, required this.entry});
  final SmerStore store;
  final SmerEntry entry;
  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.deleteEntry(entry.id);
      if (context.mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          onPressed: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EntryEditorPage(store: store, entry: entry),
              ),
            );
            if (changed == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          icon: const Icon(Icons.edit),
        ),
        IconButton(
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          formatDate(entry.occurredAt),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        DetailSection(title: 'Ситуация', content: entry.situation),
        DetailSection(
          title: 'Мысли',
          content: entry.thoughts.isEmpty
              ? 'Не указаны'
              : entry.thoughts.map((t) => '• $t').join('\n'),
        ),
        DetailSection(
          title: 'Эмоции',
          content: entry.emotions.isEmpty
              ? 'Не указаны'
              : entry.emotions
                    .map((e) => '${e.name} — ${e.intensity}%')
                    .join('\n'),
        ),
        DetailSection(
          title: 'Телесная реакция',
          content: entry.bodyReaction.isEmpty
              ? 'Не указана'
              : entry.bodyReaction,
        ),
        DetailSection(
          title: 'Поведенческая реакция',
          content: entry.behaviorReaction.isEmpty
              ? 'Не указана'
              : entry.behaviorReaction,
        ),
      ],
    ),
  );
}

class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.content});
  final String title;
  final String content;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(content),
      ],
    ),
  );
}

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({super.key, required this.store, this.entry});
  final SmerStore store;
  final SmerEntry? entry;
  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _situation;
  late final TextEditingController _thoughts;
  late final TextEditingController _body;
  late final TextEditingController _behavior;
  late DateTime _occurredAt;
  late List<SmerEmotion> _emotions;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _situation = TextEditingController(text: entry?.situation);
    _thoughts = TextEditingController(text: entry?.thoughts.join('\n'));
    _body = TextEditingController(text: entry?.bodyReaction);
    _behavior = TextEditingController(text: entry?.behaviorReaction);
    _occurredAt = entry?.occurredAt ?? DateTime.now();
    _emotions = [...?entry?.emotions];
  }

  @override
  void dispose() {
    _situation.dispose();
    _thoughts.dispose();
    _body.dispose();
    _behavior.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _occurredAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _addEmotion() async {
    final result = await Navigator.push<List<SmerEmotion>>(
      context,
      MaterialPageRoute(
        builder: (_) => EmotionPickerPage(initialEmotions: _emotions),
      ),
    );
    if (result != null) setState(() => _emotions = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    await widget.store.saveEntry(
      SmerEntry(
        id: widget.entry?.id ?? now.microsecondsSinceEpoch.toString(),
        createdAt: widget.entry?.createdAt ?? now,
        occurredAt: _occurredAt,
        situation: _situation.text.trim(),
        thoughts: _thoughts.text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        emotions: _emotions,
        bodyReaction: _body.text.trim(),
        behaviorReaction: _behavior.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.entry == null ? 'Новая запись' : 'Редактирование'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата и время эпизода'),
            subtitle: Text(formatDate(_occurredAt)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _selectDate,
          ),
          const SizedBox(height: 12),
          Field(
            label: 'Ситуация',
            hint: 'Что произошло? Только наблюдаемые факты.',
            controller: _situation,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Опишите ситуацию'
                : null,
          ),
          Field(
            label: 'Автоматические мысли',
            hint: 'Каждая мысль с новой строки',
            controller: _thoughts,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          Text('Эмоции', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Отметьте чувства, которые возникли в ситуации.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_emotions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emotions
                    .map(
                      (emotion) => InputChip(
                        label: Text('${emotion.name} ${emotion.intensity}%'),
                        onDeleted: () =>
                            setState(() => _emotions.remove(emotion)),
                      ),
                    )
                    .toList(),
              ),
            ),
          FilledButton.tonalIcon(
            onPressed: _addEmotion,
            icon: const Icon(Icons.add),
            label: Text(
              _emotions.isEmpty ? 'Выбрать эмоции' : 'Изменить эмоции',
            ),
          ),
          const SizedBox(height: 20),
          Field(
            label: 'Телесная реакция',
            hint: 'Что происходило в теле?',
            controller: _body,
            maxLines: 3,
          ),
          Field(
            label: 'Поведенческая реакция',
            hint: 'Что вы сделали или чего избегали?',
            controller: _behavior,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: FilledButton(
        onPressed: _save,
        child: const Text('Сохранить запись'),
      ),
    ),
  );
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 2,
    this.validator,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class EmotionPickerPage extends StatefulWidget {
  const EmotionPickerPage({super.key, required this.initialEmotions});
  final List<SmerEmotion> initialEmotions;

  @override
  State<EmotionPickerPage> createState() => _EmotionPickerPageState();
}

class _EmotionPickerPageState extends State<EmotionPickerPage> {
  late List<SmerEmotion> _emotions;

  @override
  void initState() {
    super.initState();
    _emotions = [...widget.initialEmotions];
  }

  SmerEmotion? _emotionByName(String name) {
    for (final emotion in _emotions) {
      if (emotion.name == name) return emotion;
    }
    return null;
  }

  void _removeEmotion(String name) {
    setState(() {
      _emotions.removeWhere((emotion) => emotion.name == name);
    });
  }

  Future<void> _editEmotionIntensity(String name) async {
    final current = _emotionByName(name);
    var intensity = current?.intensity ?? 50;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Интенсивность: $intensity%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: intensity.toDouble(),
                max: 100,
                divisions: 100,
                label: '$intensity%',
                onChanged: (value) =>
                    setDialogState(() => intensity = value.round()),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Едва заметна'), Text('Очень сильная')],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _emotions = _emotions
          .map(
            (emotion) => emotion.name == name
                ? SmerEmotion(name: emotion.name, intensity: intensity)
                : emotion,
          )
          .toList();
      if (current == null) {
        _emotions.add(SmerEmotion(name: name, intensity: intensity));
      }
    });
  }

  Future<void> _addCustomEmotion() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Своя эмоция'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Название эмоции'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    if (_emotions.any(
      (emotion) => emotion.name.toLowerCase() == name.toLowerCase(),
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Эта эмоция уже добавлена.')),
        );
      }
      return;
    }
    await _editEmotionIntensity(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Эмоции')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'Что вы чувствуете?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Можно выбрать несколько эмоций и настроить силу каждой.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (_emotions.isNotEmpty) ...[
                  Text(
                    'Выбрано',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _emotions
                        .map(
                          (emotion) => InputChip(
                            label: Text(
                              '${emotion.name} ${emotion.intensity}%',
                            ),
                            onPressed: () =>
                                _editEmotionIntensity(emotion.name),
                            onDeleted: () => _removeEmotion(emotion.name),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                ...emotionGroups.entries.map(
                  (group) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      title: Text(group.key),
                      initiallyExpanded: group.key == 'Радость',
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: group.value
                                .map(
                                  (name) => FilterChip(
                                    label: Text(name),
                                    selected: _emotions.any(
                                      (emotion) => emotion.name == name,
                                    ),
                                    onSelected: (_) =>
                                        _editEmotionIntensity(name),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCustomEmotion,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить свою эмоцию'),
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _emotions),
                child: Text(
                  'Готово${_emotions.isEmpty ? '' : ' · ${_emotions.length}'}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
