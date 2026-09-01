import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
        seedColor: const Color(0xFF85695E),
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
  static const _pinLength = 4;
  var _pin = '';
  String? _firstPin;
  String? _error;
  var _saving = false;

  Future<void> _onCompleted(String pin) async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _pin = '';
      });
      return;
    }
    if (pin != _firstPin) {
      setState(() {
        _error = 'PIN-коды не совпадают. Попробуйте ещё раз.';
        _firstPin = null;
        _pin = '';
      });
      return;
    }
    setState(() => _saving = true);
    await widget.security.setPin(pin);
    if (mounted) widget.onComplete();
  }

  void _appendDigit(String digit) {
    if (_saving || _pin.length == _pinLength) return;
    final pin = '$_pin$digit';
    setState(() {
      _pin = pin;
      _error = null;
    });
    if (pin.length == _pinLength) _onCompleted(pin);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: _PinScreen(
        title: _firstPin == null ? 'Придумайте PIN-код' : 'Повторите PIN-код',
        subtitle: _firstPin == null
            ? 'Четыре цифры защитят дневник и ваши записи.'
            : 'Введите те же четыре цифры ещё раз.',
        value: _pin,
        length: _pinLength,
        errorText: _error,
        enabled: !_saving,
        onDigit: _appendDigit,
        onBackspace: () => setState(
          () => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1),
        ),
        onClear: () => setState(() => _pin = ''),
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
  var _pin = '';
  var _error = false;
  bool? _biometricsAvailable;
  var _showPinEntry = false;
  var _isAuthenticating = false;
  var _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
    _loadPinLength();
  }

  Future<void> _loadBiometrics() async {
    final available = await widget.security.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricsAvailable = available);
    if (available) await _unlockWithBiometrics();
  }

  Future<void> _loadPinLength() async {
    final length = await widget.security.pinLength();
    if (mounted) setState(() => _pinLength = length);
  }

  Future<void> _unlockWithPin(String pin) async {
    if (await widget.security.verifyPin(pin)) {
      if (mounted) widget.onUnlocked();
      return;
    }
    setState(() {
      _error = true;
      _pin = '';
    });
  }

  void _appendDigit(String digit) {
    if (_pin.length == _pinLength) return;
    final pin = '$_pin$digit';
    setState(() {
      _pin = pin;
      _error = false;
    });
    if (pin.length == _pinLength) _unlockWithPin(pin);
  }

  Future<void> _unlockWithBiometrics() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);
    final authenticated = await widget.security.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
    if (authenticated) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    if (_biometricsAvailable == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: _biometricsAvailable! && !_showPinEntry
            ? _BiometricUnlockScreen(
                isAuthenticating: _isAuthenticating,
                onBiometrics: _unlockWithBiometrics,
                onUsePin: () => setState(() => _showPinEntry = true),
              )
            : _PinScreen(
                title: 'Введите PIN-код',
                subtitle: 'Дневник защищён и доступен только вам.',
                value: _pin,
                length: _pinLength,
                errorText: _error ? 'Неверный PIN-код' : null,
                onDigit: _appendDigit,
                onBackspace: () => setState(
                  () => _pin = _pin.isEmpty
                      ? ''
                      : _pin.substring(0, _pin.length - 1),
                ),
                onClear: () => setState(() => _pin = ''),
              ),
      ),
    );
  }
}

class _BiometricUnlockScreen extends StatelessWidget {
  const _BiometricUnlockScreen({
    required this.isAuthenticating,
    required this.onBiometrics,
    required this.onUsePin,
  });

  final bool isAuthenticating;
  final VoidCallback onBiometrics;
  final VoidCallback onUsePin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 36),
        Text(
          'Откройте дневник',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Text(
          'Подтвердите личность с помощью биометрии.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Spacer(),
        Icon(
          Icons.fingerprint,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isAuthenticating ? null : onBiometrics,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Войти по биометрии'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onUsePin, child: const Text('Ввести PIN-код')),
        const Spacer(flex: 2),
      ],
    ),
  );
}

class _PinScreen extends StatelessWidget {
  const _PinScreen({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.length,
    this.errorText,
    this.enabled = true,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });
  final String title;
  final String subtitle;
  final String value;
  final int length;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 36, 32, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 112,
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
        _PinDots(value: value, length: length, hasError: errorText != null),
        SizedBox(height: errorText == null ? 28 : 8),
        if (errorText != null)
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const Spacer(flex: 4),
        _PinKeypad(
          enabled: enabled,
          onDigit: onDigit,
          onBackspace: onBackspace,
          onClear: onClear,
        ),
      ],
    ),
  );
}

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.value,
    required this.length,
    required this.hasError,
  });

  final String value;
  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      length,
      (index) => Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasError
              ? Theme.of(context).colorScheme.error
              : index < value.length
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['clear', '0', 'backspace'],
      ])
        Row(
          children: row
              .map(
                (key) => Expanded(
                  child: _PinKey(
                    keyName: key,
                    enabled: enabled,
                    onPressed: () {
                      if (key == 'clear') return onClear();
                      if (key == 'backspace') return onBackspace();
                      onDigit(key);
                    },
                  ),
                ),
              )
              .toList(),
        ),
    ],
  );
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.keyName,
    required this.enabled,
    required this.onPressed,
  });

  final String keyName;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = switch (keyName) {
      'clear' => const Icon(Icons.close, size: 28),
      'backspace' => const Icon(Icons.backspace_outlined, size: 26),
      _ => Text(keyName, style: Theme.of(context).textTheme.headlineMedium),
    };
    return Semantics(
      button: true,
      label: keyName == 'clear'
          ? 'Очистить PIN-код'
          : keyName == 'backspace'
          ? 'Удалить последнюю цифру'
          : keyName,
      child: InkResponse(
        onTap: enabled ? onPressed : null,
        radius: 36,
        child: SizedBox(height: 80, child: Center(child: child)),
      ),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
