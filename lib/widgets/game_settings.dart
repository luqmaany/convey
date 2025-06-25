import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_setup_provider.dart';

class GameSettings extends ConsumerStatefulWidget {
  const GameSettings({super.key});

  @override
  GameSettingsState createState() => GameSettingsState();
}

class GameSettingsState extends ConsumerState<GameSettings> {
  late final TextEditingController _roundTimeController;
  late final TextEditingController _targetScoreController;
  late final TextEditingController _allowedSkipsController;

  @override
  void initState() {
    super.initState();
    final gameConfig = ref.read(gameSetupProvider);
    _roundTimeController =
        TextEditingController(text: gameConfig.roundTimeSeconds.toString());
    _targetScoreController =
        TextEditingController(text: gameConfig.targetScore.toString());
    _allowedSkipsController =
        TextEditingController(text: gameConfig.allowedSkips.toString());

    // Validate initial values after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateRoundTime(gameConfig.roundTimeSeconds.toString());
      _validateTargetScore(gameConfig.targetScore.toString());
      _validateAllowedSkips(gameConfig.allowedSkips.toString());
    });
  }

  @override
  void dispose() {
    _roundTimeController.dispose();
    _targetScoreController.dispose();
    _allowedSkipsController.dispose();
    super.dispose();
  }

  void _validateRoundTime(String value) {
    if (value.isEmpty) {
      ref.read(settingsValidationProvider.notifier).setRoundTimeValid(false);
      return;
    }
    final seconds = int.tryParse(value);
    final isValid = seconds != null && seconds >= 1 && seconds <= 120;
    if (mounted) {
      ref.read(settingsValidationProvider.notifier).setRoundTimeValid(isValid);
      if (isValid) {
        ref.read(gameSetupProvider.notifier).setRoundTime(seconds);
      }
    }
  }

  void _validateTargetScore(String value) {
    if (value.isEmpty) {
      ref.read(settingsValidationProvider.notifier).setTargetScoreValid(false);
      return;
    }
    final score = int.tryParse(value);
    final isValid = score != null && score >= 1 && score <= 100;
    if (mounted) {
      ref
          .read(settingsValidationProvider.notifier)
          .setTargetScoreValid(isValid);
      if (isValid) {
        ref.read(gameSetupProvider.notifier).setTargetScore(score);
      }
    }
  }

  void _validateAllowedSkips(String value) {
    if (value.isEmpty) {
      ref.read(settingsValidationProvider.notifier).setAllowedSkipsValid(false);
      return;
    }
    final skips = int.tryParse(value);
    final isValid = skips != null && skips >= 0 && skips <= 5;
    if (mounted) {
      ref
          .read(settingsValidationProvider.notifier)
          .setAllowedSkipsValid(isValid);
      if (isValid) {
        ref.read(gameSetupProvider.notifier).setAllowedSkips(skips);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationState = ref.watch(settingsValidationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _roundTimeController,
          decoration: InputDecoration(
            labelText: 'Round Time (seconds)',
            border: const OutlineInputBorder(),
            errorText: validationState.isRoundTimeValid
                ? null
                : 'Must be between 10 and 120 seconds',
            helperText: '10-120 seconds',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: _validateRoundTime,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _targetScoreController,
          decoration: InputDecoration(
            labelText: 'Target Score',
            border: const OutlineInputBorder(),
            errorText: validationState.isTargetScoreValid
                ? null
                : 'Must be between 10 and 100',
            helperText: '10-100 points',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: _validateTargetScore,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _allowedSkipsController,
          decoration: InputDecoration(
            labelText: 'Allowed Skips',
            border: const OutlineInputBorder(),
            errorText: validationState.isAllowedSkipsValid
                ? null
                : 'Must be between 0 and 5',
            helperText: '0-5 skips',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: _validateAllowedSkips,
        ),
      ],
    );
  }
}
