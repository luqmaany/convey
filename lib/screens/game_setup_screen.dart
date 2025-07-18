import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_setup_provider.dart';
import '../services/game_navigation_service.dart';
import '../models/game_config.dart';
import '../widgets/player_input.dart';
import 'package:convey/widgets/team_color_button.dart';
import '../widgets/team_display_box.dart';

class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({super.key});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen>
    with TickerProviderStateMixin {
  List<AnimationController> _controllers = [];
  List<Animation<double>> _animations = [];
  List<List<String>> _prevTeams = [];
  bool _dropAcceptedByTeam = false;

  @override
  void initState() {
    super.initState();
    final gameConfig = ref.read(gameSetupProvider);
    _initControllers(gameConfig.teams);
    _prevTeams = gameConfig.teams.map((t) => List<String>.from(t)).toList();

    // Load saved data from storage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameSetupProvider.notifier).loadFromStorage();
    });
  }

  @override
  void didUpdateWidget(covariant GameSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final gameConfig = ref.read(gameSetupProvider);
    _updateTeamControllers(gameConfig.teams);
  }

  void _initControllers(List<List<String>> teams) {
    _controllers = List.generate(
      teams.length,
      (_) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    for (final c in _controllers) {
      c.forward(from: 0);
    }
  }

  void _updateTeamControllers(List<List<String>> teams) {
    // If team count increased, add controllers
    if (_controllers.length < teams.length) {
      final toAdd = teams.length - _controllers.length;
      for (int i = 0; i < toAdd; i++) {
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        );
        _controllers.add(c);
        _animations.add(Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        ));
        c.forward(from: 0);
      }
    }
    // If team count decreased, dispose and remove extra controllers
    if (_controllers.length > teams.length) {
      final toRemove = _controllers.length - teams.length;
      for (int i = 0; i < toRemove; i++) {
        _controllers.last.dispose();
        _controllers.removeLast();
        _animations.removeLast();
      }
    }
    // Animate only changed teams
    for (int i = 0; i < teams.length; i++) {
      if (_prevTeams.length <= i || !_listEquals(_prevTeams[i], teams[i])) {
        _controllers[i].forward(from: 0);
      }
    }
    _prevTeams = teams.map((t) => List<String>.from(t)).toList();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameConfig>(gameSetupProvider, (previous, next) {
      _updateTeamControllers(next.teams);
    });
    final gameConfig = ref.watch(gameSetupProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Global DragTarget for removing players (background)
          Positioned.fill(
            child: DragTarget<String>(
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Colors.red.withOpacity(0.1)
                        : Colors.transparent,
                    border: candidateData.isNotEmpty
                        ? Border.all(
                            color: Colors.red,
                            width: 2,
                            style: BorderStyle.solid)
                        : null,
                  ),
                  child: candidateData.isNotEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Drop to remove player',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : null,
                );
              },
              onWillAccept: (player) => true,
              onAccept: (player) {
                _dropAcceptedByTeam =
                    true; // Prevent onDragEnd from removing the player
                ref.read(gameSetupProvider.notifier).removePlayer(player);
              },
            ),
          ),
          // Main content with teams and players
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 48),
                    const Center(
                      child: Text(
                        'Team Setup',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      gameConfig.playerNames.length >= 12
                          ? 'Maximum 12 players reached. Remove players to add more.'
                          : 'Tap a name to add to a team.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: gameConfig.playerNames.length >= 12
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const PlayerInput(),
                    const SizedBox(height: 0),
                    if (gameConfig.teams.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio:
                              1, // Changed to 0.7 for the right height
                        ),
                        itemCount: gameConfig.teams.length,
                        itemBuilder: (context, index) {
                          final team = gameConfig.teams[index];
                          final colorIndex =
                              gameConfig.teamColorIndices.length > index
                                  ? gameConfig.teamColorIndices[index]
                                  : index % teamColors.length;
                          final color = teamColors[colorIndex];

                          return AnimatedBuilder(
                            animation: _animations.length > index
                                ? _animations[index]
                                : kAlwaysDismissedAnimation,
                            builder: (context, child) {
                              final scale = _animations.length > index
                                  ? 1.0 + (_animations[index].value * 0.03)
                                  : 1.0;
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: TeamDisplayBox(
                              teamName: '${color.name} Team',
                              color: color,
                              children: team
                                  .where((player) => player.isNotEmpty)
                                  .map((player) {
                                return DragTarget<String>(
                                  builder:
                                      (context, candidateData, rejectedData) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: candidateData.isNotEmpty
                                            ? color.background.withOpacity(0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: candidateData.isNotEmpty
                                            ? Border.all(
                                                color: color.border, width: 2)
                                            : null,
                                      ),
                                      child: Draggable<String>(
                                        data: player,
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: Chip(
                                            label: Text(player),
                                            backgroundColor: color.background,
                                            side:
                                                BorderSide(color: color.border),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.5,
                                          child: Chip(label: Text(player)),
                                        ),
                                        child: Chip(
                                          label: Text(player),
                                          backgroundColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? color.background
                                                      .withOpacity(0.2)
                                                  : color.background,
                                          side: BorderSide(color: color.border),
                                        ),
                                        onDragStarted: () {
                                          _dropAcceptedByTeam = false;
                                        },
                                        onDragEnd: (details) {
                                          if (!_dropAcceptedByTeam) {
                                            ref
                                                .read(
                                                    gameSetupProvider.notifier)
                                                .removePlayer(player);
                                          }
                                          _dropAcceptedByTeam = false;
                                        },
                                      ),
                                    );
                                  },
                                  onWillAccept: (draggedPlayer) =>
                                      draggedPlayer != player,
                                  onAccept: (draggedPlayer) {
                                    _dropAcceptedByTeam = true;
                                    ref
                                        .read(gameSetupProvider.notifier)
                                        .swapPlayers(draggedPlayer, player);
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    if (gameConfig.teams.expand((t) => t).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 150,
                              child: TeamColorButton(
                                text: 'Clear',
                                icon: Icons.clear,
                                color: uiColors[2],
                                onPressed: () {
                                  ref
                                      .read(gameSetupProvider.notifier)
                                      .clearAllPlayers();
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 150,
                              child: TeamColorButton(
                                text: 'Shuffle',
                                icon: Icons.shuffle,
                                color: uiColors[0],
                                onPressed: () {
                                  ref
                                      .read(gameSetupProvider.notifier)
                                      .shuffleTeams();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TeamColorButton(
                        text: 'Home',
                        icon: Icons.home,
                        color: uiColors[0],
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TeamColorButton(
                        text: 'Next',
                        icon: Icons.arrow_forward,
                        color: uiColors[1],
                        onPressed: gameConfig.teams.length >= 2 &&
                                gameConfig.teams.every((team) =>
                                    team
                                        .where((player) => player.isNotEmpty)
                                        .length ==
                                    2)
                            ? () async {
                                // Add current players to suggestion queue
                                await ref
                                    .read(gameSetupProvider.notifier)
                                    .addCurrentPlayersToQueue();
                                // Use navigation service to navigate to game settings
                                GameNavigationService.navigateToGameSettings(
                                    context);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
