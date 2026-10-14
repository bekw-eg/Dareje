import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/local_achievement_service.dart';
import '../utils/achievement_date.dart';
import '../utils/category_visuals.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_widgets.dart';

class AddAchievementScreen extends StatefulWidget {
  const AddAchievementScreen({
    super.key,
    required this.service,
    this.achievement,
  });

  final LocalAchievementService service;
  final Achievement? achievement;

  @override
  State<AddAchievementScreen> createState() => _AddAchievementScreenState();
}

class _AddAchievementScreenState extends State<AddAchievementScreen> {
  late final _achievementId = widget.achievement?.id ?? Achievement.createId();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _date = TextEditingController();
  String? _category;
  String? _error;
  bool _saving = false;
  bool _submitted = false;

  bool get _isEditing => widget.achievement != null;

  @override
  void initState() {
    super.initState();
    final item = widget.achievement;
    if (item != null) {
      _title.text = item.title;
      _description.text = item.description;
      _date.text = formatAchievementDate(item.date);
      _category = item.category;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final achievement = Achievement(
        id: _achievementId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category!,
        date: parseAchievementDate(_date.text)!,
      );
      if (_isEditing) {
        await widget.service.update(widget.achievement!, achievement);
      } else {
        await widget.service.add(achievement);
      }
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop(true);
      }
    } on AchievementException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Жетістік сақталмады. Қайта көріңіз';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Жетістікті өңдеу' : 'Жетістік қосу'),
          leading: BackButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpacing.page(context),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppReveal(
                        child: AppSurface(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Row(
                            children: [
                              Icon(
                                CategoryVisuals.icon(_category ?? 'Other'),
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isEditing
                                          ? 'Жетістікті жаңарту'
                                          : 'Жаңа жетістік',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isEditing
                                          ? 'Өзгерістерден кейін балл қайта есептеледі.'
                                          : 'Әр жеңісің маңызды.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _title,
                        enabled: !_saving,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Жетістік атауы',
                          hintText: 'Мысалы, хакатондағы жеңіс',
                          counterText: '',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Жетістік атауын енгізіңіз'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _description,
                        enabled: !_saving,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Сипаттама',
                          hintText: 'Жетістігің туралы қысқаша',
                          counterText: '',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Сипаттаманы енгізіңіз'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Санат'),
                        items: Achievement.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(CategoryVisuals.label(category)),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _category = value),
                        validator: (value) =>
                            value == null ? 'Санатты таңдаңыз' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _date,
                        enabled: !_saving,
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _save(),
                        decoration: const InputDecoration(
                          labelText: 'Алынған күні',
                          hintText: '08.10.2026',
                          helperText: 'КК.АА.ЖЖЖЖ',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (value) =>
                            parseAchievementDate(value ?? '') == null
                            ? 'Күнді КК.АА.ЖЖЖЖ форматында дұрыс енгізіңіз'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: AppButtonContent(
                          busy: _saving,
                          label: 'Сақтау',
                          busyLabel: 'Сақталуда…',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
