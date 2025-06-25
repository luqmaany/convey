import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_setup_provider.dart';
import '../services/game_state_provider.dart';
import 'game_screen.dart';
import 'word_lists_manager_screen.dart';
import 'package:convey/widgets/team_color_button.dart';

class RoleAssignmentScreen extends ConsumerStatefulWidget {
  final int teamIndex;
  final int roundNumber;
  final int turnNumber;
  final WordCategory category;

  const RoleAssignmentScreen({
    super.key,
    required this.teamIndex,
    required this.roundNumber,
    required this.turnNumber,
    required this.category,
  });

  @override
  ConsumerState<RoleAssignmentScreen> createState() =>
      _RoleAssignmentScreenState();
}

class _RoleAssignmentScreenState extends ConsumerState<RoleAssignmentScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedGuesser;
  String? _selectedConveyor;
  bool _isTransitioning = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _assignRandomRoles();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _assignRandomRoles() {
    final gameConfig = ref.read(gameSetupProvider);
    final gameState = ref.read(gameStateProvider);
    final currentTeamIndex = gameState?.currentTeamIndex ?? widget.teamIndex;
    final teams = gameConfig.teams;

    if (teams.isEmpty || currentTeamIndex >= teams.length) {
      return;
    }

    final team = teams[currentTeamIndex];
    if (team.length < 2) {
      return;
    }

    final random = team.toList()..shuffle();
    setState(() {
      _selectedGuesser = random[0];
      _selectedConveyor = random[1];
    });
  }

  void _showTransitionScreen() {
    setState(() {
      _isTransitioning = true;
    });
  }

  void _switchRoles() {
    setState(() {
      final temp = _selectedGuesser;
      _selectedGuesser = _selectedConveyor;
      _selectedConveyor = temp;
    });
    _animationController.forward(from: 0).then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedGuesser == null || _selectedConveyor == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Get the team color for the current team
    final gameConfig = ref.watch(gameSetupProvider);
    final gameState = ref.watch(gameStateProvider);
    final currentTeamIndex = gameState?.currentTeamIndex ?? widget.teamIndex;
    final colorIndex = (gameConfig.teamColorIndices.length > currentTeamIndex)
        ? gameConfig.teamColorIndices[currentTeamIndex]
        : currentTeamIndex % teamColors.length;
    final teamColor = teamColors[colorIndex];

    if (_isTransitioning) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pass the phone to',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _selectedConveyor!,
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Conveyor',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: TeamColorButton(
                  text: 'Start',
                  icon: Icons.play_arrow,
                  color: teamColors[2], // Green
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => GameScreen(
                          teamIndex: currentTeamIndex,
                          roundNumber: widget.roundNumber,
                          turnNumber: widget.turnNumber,
                          category: widget.category,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("${_selectedConveyor!} & ${_selectedGuesser!}'s Turn"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose Roles',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Column(
                children: [
                  // Conveyor Box
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_animation.value * 0.03),
                          child: Container(
                            decoration: BoxDecoration(
                              color: teamColor.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: teamColor.border,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    _selectedConveyor!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(color: Colors.black),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      'Conveyor',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: teamColor.text,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Switch Button
                  IconButton(
                    onPressed: _switchRoles,
                    icon: Icon(
                      Icons.swap_vert,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Guesser Box
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_animation.value * 0.03),
                          child: Container(
                            decoration: BoxDecoration(
                              color: teamColor.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: teamColor.border,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    _selectedGuesser!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(color: Colors.black),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      'Guesser',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: teamColor.text,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 200,
                child: TeamColorButton(
                  text: 'Random',
                  icon: Icons.shuffle,
                  color: teamColors[1], // Blue
                  onPressed: () {
                    _assignRandomRoles();
                    _showTransitionScreen();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: TeamColorButton(
                text: 'Next',
                icon: Icons.arrow_forward,
                color: teamColors[2], // Green
                onPressed: () {
                  _showTransitionScreen();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
