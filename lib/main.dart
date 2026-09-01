import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pinput/pinput.dart';

import 'data/smer_store.dart';
import 'models/journal_analysis.dart';
import 'models/smer_entry.dart';
import 'security/app_security.dart';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmerBootstrap());
}

class SmerBootstrap extends StatefulWidget {
  const SmerBootstrap({super.key});

  @override
  State<SmerBootstrap> createState() => _SmerBootstrapState();
}

class _SmerBootstrapState extends State<SmerBootstrap> {
  AppSecurity? _security;
  SqliteSmerStore? _store;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final security = AppSecurity();
    final databasePassword = await security.databasePassword();
    if (mounted) {
      setState(() {
        _security = security;
        _store = SqliteSmerStore(databasePassword: databasePassword);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_security == null || _store == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return SmerApp(store: _store!, security: _security!);
  }
}

class SmerApp extends StatelessWidget {
  const SmerApp({super.key, required this.store, required this.security});
  final SmerStore store;
  final AppSecurity security;

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
    home: AppLockGate(store: store, security: security),
  );
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.store, required this.security});
  final SmerStore store;
  final AppSecurity security;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool? _hasPin;
  var _isLocked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPinState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPinState() async {
    final hasPin = await widget.security.hasPin();
    if (mounted) setState(() => _hasPin = hasPin);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasPin == true &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      setState(() => _isLocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasPin!) {
      return PinSetupPage(
        security: widget.security,
        onComplete: () => setState(() {
          _hasPin = true;
          _isLocked = false;
        }),
      );
    }
    if (_isLocked) {
      return UnlockPage(
        security: widget.security,
        onUnlocked: () => setState(() => _isLocked = false),
      );
    }
    return JournalPage(store: widget.store);
  }
}

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({
    super.key,
    required this.security,
    required this.onComplete,
  });
  final AppSecurity security;
  final VoidCallback onComplete;

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final _controller = TextEditingController();
  String? _firstPin;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCompleted(String pin) async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _controller.clear();
      });
      return;
    }
    if (pin != _firstPin) {
      setState(() {
        _error = 'PIN-коды не совпадают. Попробуйте ещё раз.';
        _firstPin = null;
        _controller.clear();
      });
      return;
    }
    setState(() => _saving = true);
    await widget.security.setPin(pin);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                _firstPin == null ? 'Придумайте PIN-код' : 'Повторите PIN-код',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _firstPin == null
                    ? 'Шесть цифр защитят дневник и зашифрованную базу записей.'
                    : 'Введите те же шесть цифр ещё раз.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              _PinInput(
                controller: _controller,
                errorText: _error,
                enabled: !_saving,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onCompleted: _onCompleted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class UnlockPage extends StatefulWidget {
  const UnlockPage({
    super.key,
    required this.security,
    required this.onUnlocked,
  });
  final AppSecurity security;
  final VoidCallback onUnlocked;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final _controller = TextEditingController();
  var _error = false;
  var _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadBiometrics() async {
    final available = await widget.security.canUseBiometrics();
    if (mounted) setState(() => _biometricsAvailable = available);
  }

  Future<void> _unlockWithPin(String pin) async {
    if (await widget.security.verifyPin(pin)) {
      if (mounted) widget.onUnlocked();
      return;
    }
    setState(() {
      _error = true;
      _controller.clear();
    });
  }

  Future<void> _unlockWithBiometrics() async {
    if (await widget.security.authenticateWithBiometrics() && mounted) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Дневник заблокирован',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              _PinInput(
                controller: _controller,
                errorText: _error ? 'Неверный PIN-код' : null,
                onChanged: (_) {
                  if (_error) setState(() => _error = false);
                },
                onCompleted: _unlockWithPin,
              ),
              if (_biometricsAvailable) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _unlockWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Войти по биометрии'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _PinInput extends StatelessWidget {
  const _PinInput({
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    required this.onCompleted,
  });
  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final defaultTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: Theme.of(context).textTheme.headlineSmall,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
    );
    return Column(
      children: [
        Pinput(
          controller: controller,
          length: 6,
          autofocus: true,
          enabled: enabled,
          obscureText: true,
          obscuringCharacter: '•',
          enableInteractiveSelection: false,
          enableSuggestions: false,
          toolbarEnabled: false,
          hapticFeedbackType: HapticFeedbackType.lightImpact,
          defaultPinTheme: defaultTheme,
          focusedPinTheme: defaultTheme.copyWith(
            decoration: defaultTheme.decoration!.copyWith(
              border: Border.all(color: colors.primary, width: 2),
            ),
          ),
          errorPinTheme: defaultTheme.copyWith(
            decoration: defaultTheme.decoration!.copyWith(
              border: Border.all(color: colors.error, width: 2),
            ),
          ),
          forceErrorState: errorText != null,
          onChanged: onChanged,
          onCompleted: onCompleted,
          separatorBuilder: (_) => const SizedBox(width: 8),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            errorText!,
            style: TextStyle(color: colors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
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
        DetailSection(
          title: 'Ситуация',
          content: entry.situation.isEmpty ? 'Не указана' : entry.situation,
        ),
        DetailSection(
          title: 'Мысли',
          content: entry.thoughts.isEmpty
              ? 'Не указаны'
              : entry.thoughts.map((t) => '• $t').join('\n'),
        ),
        if (entry.thoughtBelief != null)
          DetailSection(
            title: 'Убеждённость в ключевой мысли',
            content: '${entry.thoughtBelief}%',
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
        if (entry.alternativeThought.isNotEmpty)
          DetailSection(
            title: 'Более сбалансированная мысль',
            content: entry.alternativeThought,
          ),
        if (entry.alternativeEmotions.isNotEmpty)
          DetailSection(
            title: 'Эмоции после пересмотра',
            content: entry.alternativeEmotions
                .map((emotion) => '${emotion.name} — ${emotion.intensity}%')
                .join('\n'),
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
  late final TextEditingController _alternativeThought;
  late final TextEditingController _body;
  late final TextEditingController _behavior;
  late DateTime _occurredAt;
  late List<SmerEmotion> _emotions;
  late List<SmerEmotion> _alternativeEmotions;
  late int _thoughtBelief;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _situation = TextEditingController(text: entry?.situation);
    _thoughts = TextEditingController(text: entry?.thoughts.join('\n'));
    _alternativeThought = TextEditingController(
      text: entry?.alternativeThought,
    );
    _body = TextEditingController(text: entry?.bodyReaction);
    _behavior = TextEditingController(text: entry?.behaviorReaction);
    _occurredAt = entry?.occurredAt ?? DateTime.now();
    _emotions = [...?entry?.emotions];
    _alternativeEmotions = [...?entry?.alternativeEmotions];
    _thoughtBelief = entry?.thoughtBelief ?? 50;
  }

  @override
  void dispose() {
    _situation.dispose();
    _thoughts.dispose();
    _alternativeThought.dispose();
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
        builder: (_) =>
            EmotionPickerPage(store: widget.store, initialEmotions: _emotions),
      ),
    );
    if (result != null) setState(() => _emotions = result);
  }

  Future<void> _rateEmotionsAgain() async {
    final result = await Navigator.push<List<SmerEmotion>>(
      context,
      MaterialPageRoute(
        builder: (_) => EmotionPickerPage(
          store: widget.store,
          initialEmotions: _alternativeEmotions.isEmpty
              ? _emotions
              : _alternativeEmotions,
        ),
      ),
    );
    if (result != null) setState(() => _alternativeEmotions = result);
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
        thoughtBelief: _thoughtBelief,
        alternativeThought: _alternativeThought.text.trim(),
        alternativeEmotions: _alternativeEmotions,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Разберите эпизод по шагам',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Записывайте то, что произошло, без попытки оценить себя.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _selectDate,
            icon: const Icon(Icons.schedule_outlined),
            label: Text(formatDate(_occurredAt)),
          ),
          const SizedBox(height: 28),
          EditorSection(
            number: '1',
            title: 'Ситуация',
            hint: 'Что произошло? Только наблюдаемые факты.',
            child: Field(
              hint: 'Например: коллега не ответил на сообщение',
              controller: _situation,
              minLines: 1,
              maxLines: 3,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Опишите ситуацию'
                  : null,
            ),
          ),
          EditorSection(
            number: '2',
            title: 'Автоматические мысли',
            hint: 'Какие слова или образы возникли в тот момент?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field(
                  hint: 'Каждая мысль с новой строки',
                  controller: _thoughts,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                Text(
                  'Насколько вы верите в ключевую мысль: $_thoughtBelief%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  value: _thoughtBelief.toDouble(),
                  max: 100,
                  divisions: 20,
                  label: '$_thoughtBelief%',
                  onChanged: (value) =>
                      setState(() => _thoughtBelief = value.round()),
                ),
              ],
            ),
          ),
          EditorSection(
            number: '3',
            title: 'Эмоции',
            hint: 'Выберите чувства и укажите силу каждой.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_emotions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emotions
                          .map(
                            (emotion) => InputChip(
                              label: Text(
                                '${emotion.name} ${emotion.intensity}%',
                              ),
                              onDeleted: () =>
                                  setState(() => _emotions.remove(emotion)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                FilledButton.tonalIcon(
                  onPressed: _addEmotion,
                  icon: const Icon(Icons.add_reaction_outlined),
                  label: Text(
                    _emotions.isEmpty ? 'Выбрать эмоции' : 'Изменить эмоции',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 12),
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Пересмотреть мысль (необязательно)'),
              subtitle: const Text(
                'Добавьте более сбалансированный взгляд, если хотите.',
              ),
              initiallyExpanded:
                  _alternativeThought.text.isNotEmpty ||
                  _alternativeEmotions.isNotEmpty,
              children: [
                Field(
                  hint: 'Более сбалансированная мысль',
                  controller: _alternativeThought,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                if (_alternativeEmotions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _alternativeEmotions
                          .map(
                            (emotion) => InputChip(
                              label: Text(
                                '${emotion.name} ${emotion.intensity}%',
                              ),
                              onDeleted: () => setState(
                                () => _alternativeEmotions.remove(emotion),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _rateEmotionsAgain,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Оценить эмоции повторно'),
                ),
              ],
            ),
          ),
          EditorSection(
            number: '4',
            title: 'Реакции',
            hint: 'Заметьте, как отреагировали тело и поведение.',
            child: Column(
              children: [
                Field(hint: 'Телесная реакция', controller: _body, maxLines: 3),
                const SizedBox(height: 12),
                Field(
                  hint: 'Поведенческая реакция',
                  controller: _behavior,
                  maxLines: 3,
                ),
              ],
            ),
          ),
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
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.minLines,
    this.validator,
  });
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    minLines: minLines ?? maxLines,
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      alignLabelWithHint: maxLines > 1,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: const OutlineInputBorder(),
    ),
  );
}

class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.number,
    required this.title,
    required this.hint,
    required this.child,
  });

  final String number;
  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                number,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 6),
        Text(hint, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class EmotionPickerPage extends StatefulWidget {
  const EmotionPickerPage({
    super.key,
    required this.store,
    required this.initialEmotions,
  });
  final SmerStore store;
  final List<SmerEmotion> initialEmotions;

  @override
  State<EmotionPickerPage> createState() => _EmotionPickerPageState();
}

class _EmotionPickerPageState extends State<EmotionPickerPage> {
  late List<SmerEmotion> _emotions;
  List<CustomEmotion>? _customEmotions;

  @override
  void initState() {
    super.initState();
    _emotions = [...widget.initialEmotions];
    _loadCustomEmotions();
  }

  Future<void> _loadCustomEmotions() async {
    final emotions = await widget.store.loadCustomEmotions();
    if (mounted) setState(() => _customEmotions = emotions);
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
    final customEmotion = await showDialog<CustomEmotion>(
      context: context,
      builder: (_) => _CustomEmotionDialog(
        groups: <String>{
          ...emotionGroups.keys,
          ..._customEmotions!.map((emotion) => emotion.group),
        }.toList(),
      ),
    );
    if (customEmotion == null) return;
    final name = customEmotion.name;
    final existsInCatalog =
        emotionGroups.values.any(
          (names) => names.any(
            (existingName) => existingName.toLowerCase() == name.toLowerCase(),
          ),
        ) ||
        _customEmotions!.any(
          (emotion) => emotion.name.toLowerCase() == name.toLowerCase(),
        );
    if (existsInCatalog) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Такая эмоция уже есть в каталоге.')),
        );
      }
      return;
    }
    await widget.store.saveCustomEmotion(customEmotion);
    if (!mounted) return;
    setState(() => _customEmotions = [..._customEmotions!, customEmotion]);
    await _editEmotionIntensity(name);
  }

  @override
  Widget build(BuildContext context) {
    final customEmotions = _customEmotions;
    if (customEmotions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final groups = <String, List<String>>{
      for (final group in emotionGroups.entries) group.key: [...group.value],
    };
    for (final emotion in customEmotions) {
      groups.putIfAbsent(emotion.group, () => []).add(emotion.name);
    }
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
                ...groups.entries.map(
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

class _CustomEmotionDialog extends StatefulWidget {
  const _CustomEmotionDialog({required this.groups});

  final List<String> groups;

  @override
  State<_CustomEmotionDialog> createState() => _CustomEmotionDialogState();
}

class _CustomEmotionDialogState extends State<_CustomEmotionDialog> {
  final _controller = TextEditingController();
  String? _group;
  String? _nameError;
  String? _groupError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addGroup() async {
    final group = await showDialog<String>(
      context: context,
      builder: (_) => const _GroupNameDialog(),
    );
    if (group != null && group.isNotEmpty && mounted) {
      setState(() => _group = group);
    }
  }

  void _submit() {
    final name = _controller.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Введите название эмоции' : null;
      _groupError = _group == null ? 'Выберите или создайте группу' : null;
    });
    if (_nameError != null || _groupError != null) return;
    Navigator.pop(context, CustomEmotion(name: name, group: _group!));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Своя эмоция'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Название эмоции',
              errorText: _nameError,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          Text('Группа', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.groups.map(
                (group) => ChoiceChip(
                  label: Text(group),
                  selected: _group == group,
                  onSelected: (_) => setState(() => _group = group),
                ),
              ),
              if (_group != null && !widget.groups.contains(_group))
                ChoiceChip(
                  label: Text(_group!),
                  selected: true,
                  onSelected: (_) {},
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Новая группа'),
                onPressed: _addGroup,
              ),
            ],
          ),
          if (_groupError != null) ...[
            const SizedBox(height: 8),
            Text(
              _groupError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Добавить')),
    ],
  );
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog();

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final group = _controller.text.trim();
    if (group.isNotEmpty) Navigator.pop(context, group);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Новая группа'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Название группы'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Создать')),
    ],
  );
}

String formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
