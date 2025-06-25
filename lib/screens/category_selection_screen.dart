import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'dart:async';
import 'word_lists_manager_screen.dart';
import 'role_assignment_screen.dart';
import '../services/game_state_provider.dart';
import '../screens/game_setup_screen.dart' show teamColors, TeamColor;
import 'package:convey/widgets/team_color_button.dart';

class CategorySelectionScreen extends ConsumerStatefulWidget {
  final int teamIndex;
  final int roundNumber;
  final int turnNumber;

  const CategorySelectionScreen({
    super.key,
    required this.teamIndex,
    required this.roundNumber,
    required this.turnNumber,
  });

  @override
  ConsumerState<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState
    extends ConsumerState<CategorySelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  bool _isSpinning = false;
  WordCategory? _selectedCategory;
  String _currentCategory = '';
  Timer? _categoryTimer;
  int _spinCount = 0;
  static const int _totalSpins = 30; // More spins for smoother effect
  static const int _initialDelay = 25; // Faster initial speed
  static const int _finalDelay = 120; // Smoother final speed

  @override
  void initState() {
    super.initState();

    // Scale animation controller for tap feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Setup animations
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _categoryTimer?.cancel();
    super.dispose();
  }

  String _getCategoryName(WordCategory category) {
    switch (category) {
      case WordCategory.person:
        return 'Person';
      case WordCategory.action:
        return 'Action';
      case WordCategory.world:
        return 'World';
      case WordCategory.random:
        return 'Random';
    }
  }

  Color _getCategoryColor(WordCategory category) {
    switch (category) {
      case WordCategory.person:
        return Colors.blue;
      case WordCategory.action:
        return Colors.green;
      case WordCategory.world:
        return Colors.orange;
      case WordCategory.random:
        return Colors.purple;
    }
  }

  WordCategory _getCategoryFromName(String categoryName) {
    switch (categoryName) {
      case 'Person':
        return WordCategory.person;
      case 'Action':
        return WordCategory.action;
      case 'World':
        return WordCategory.world;
      case 'Random':
        return WordCategory.random;
      default:
        return WordCategory.person; // fallback
    }
  }

  void _spinCategories() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _selectedCategory = null;
      _spinCount = 0;
    });

    // Add a subtle scale animation for feedback
    _scaleController.forward().then((_) => _scaleController.reverse());

    void updateCategory() {
      if (_spinCount >= _totalSpins) {
        _categoryTimer?.cancel();

        // Final selection with smooth transition
        final finalCategory = WordCategory
            .values[math.Random().nextInt(WordCategory.values.length)];

        setState(() {
          _isSpinning = false;
          _selectedCategory = finalCategory;
          _currentCategory = _getCategoryName(finalCategory);
        });

        // Add a celebration animation
        _scaleController.forward().then((_) => _scaleController.reverse());
        return;
      }

      setState(() {
        _currentCategory = _getCategoryName(WordCategory
            .values[math.Random().nextInt(WordCategory.values.length)]);
      });

      _spinCount++;

      // Use an easing curve for more natural deceleration
      final progress = _spinCount / _totalSpins;
      final easedProgress = Curves.easeInOut.transform(progress);
      final delay =
          (_initialDelay + ((_finalDelay - _initialDelay) * easedProgress))
              .round();

      _categoryTimer = Timer(Duration(milliseconds: delay), updateCategory);
    }

    updateCategory();
  }

  @override
  Widget build(BuildContext context) {
    final currentTeamPlayers = ref.watch(currentTeamPlayersProvider);
    final gameState = ref.watch(gameStateProvider);
    final isTiebreaker = gameState?.isTiebreaker ?? false;
    final tiebreakerCategory = gameState?.tiebreakerCategory;

    // If in tiebreaker and category is already set, skip spinner and go to role assignment
    if (isTiebreaker && tiebreakerCategory != null) {
      // Use a post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RoleAssignmentScreen(
              teamIndex: widget.teamIndex,
              roundNumber: widget.roundNumber,
              turnNumber: widget.turnNumber,
              category: tiebreakerCategory,
            ),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${currentTeamPlayers[0]} & ${currentTeamPlayers[1]}'s Turn",
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: (!_isSpinning && _selectedCategory == null)
                          ? _spinCategories
                          : null,
                      child: AnimatedBuilder(
                        animation: _scaleController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  transitionBuilder: (Widget child,
                                      Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    _currentCategory.isEmpty
                                        ? 'Tap to Spin'
                                        : _currentCategory,
                                    key: ValueKey<String>(_currentCategory),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(
                                          color: _currentCategory.isNotEmpty
                                              ? _getCategoryColor(
                                                  _getCategoryFromName(
                                                      _currentCategory))
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: AnimatedOpacity(
                opacity: _selectedCategory != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTeamColorButton(
                        context: context,
                        text: 'Next',
                        icon: Icons.arrow_forward,
                        color: teamColors[2], // Green
                        onPressed: _selectedCategory != null
                            ? () {
                                if (isTiebreaker && tiebreakerCategory == null) {
                                  // Set the tiebreaker category for this round
                                  ref.read(gameStateProvider.notifier).setTiebreakerCategory(_selectedCategory!);
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => RoleAssignmentScreen(
                                      teamIndex: widget.teamIndex,
                                      roundNumber: widget.roundNumber,
                                      turnNumber: widget.turnNumber,
                                      category: _selectedCategory!,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTeamColorButton({
  required BuildContext context,
  required String text,
  required IconData icon,
  required TeamColor color,
  required VoidCallback? onPressed,
}) {
  final bool enabled = onPressed != null;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: enabled ? color.background : color.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? color.border : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (enabled ? color.border : Colors.grey.shade300)
                  .withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 24, color: enabled ? color.border : Colors.grey.shade400),
            const SizedBox(width: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: enabled ? color.text : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TiebreakerCategorySelectionScreen extends ConsumerStatefulWidget {
  final int roundNumber;
  final List<int> tiebreakerTeams;
  const TiebreakerCategorySelectionScreen({
    Key? key,
    required this.roundNumber,
    required this.tiebreakerTeams,
  }) : super(key: key);

  @override
  ConsumerState<TiebreakerCategorySelectionScreen> createState() => _TiebreakerCategorySelectionScreenState();
}

class _TiebreakerCategorySelectionScreenState extends ConsumerState<TiebreakerCategorySelectionScreen> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isSpinning = false;
  WordCategory? _selectedCategory;
  String _currentCategory = '';
  Timer? _categoryTimer;
  int _spinCount = 0;
  static const int _totalSpins = 30;
  static const int _initialDelay = 25;
  static const int _finalDelay = 120;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _categoryTimer?.cancel();
    super.dispose();
  }

  String _getCategoryName(WordCategory category) {
    switch (category) {
      case WordCategory.person:
        return 'Person';
      case WordCategory.action:
        return 'Action';
      case WordCategory.world:
        return 'World';
      case WordCategory.random:
        return 'Random';
    }
  }

  Color _getCategoryColor(WordCategory category) {
    switch (category) {
      case WordCategory.person:
        return Colors.blue;
      case WordCategory.action:
        return Colors.green;
      case WordCategory.world:
        return Colors.orange;
      case WordCategory.random:
        return Colors.purple;
    }
  }

  WordCategory _getCategoryFromName(String categoryName) {
    switch (categoryName) {
      case 'Person':
        return WordCategory.person;
      case 'Action':
        return WordCategory.action;
      case 'World':
        return WordCategory.world;
      case 'Random':
        return WordCategory.random;
      default:
        return WordCategory.person;
    }
  }

  void _spinCategories() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _selectedCategory = null;
      _spinCount = 0;
    });
    _scaleController.forward().then((_) => _scaleController.reverse());
    void updateCategory() {
      if (_spinCount >= _totalSpins) {
        _categoryTimer?.cancel();
        final finalCategory = WordCategory.values[DateTime.now().millisecondsSinceEpoch % WordCategory.values.length];
        setState(() {
          _isSpinning = false;
          _selectedCategory = finalCategory;
          _currentCategory = _getCategoryName(finalCategory);
        });
        _scaleController.forward().then((_) => _scaleController.reverse());
        return;
      }
      setState(() {
        _currentCategory = _getCategoryName(WordCategory.values[DateTime.now().millisecondsSinceEpoch % WordCategory.values.length]);
      });
      _spinCount++;
      final progress = _spinCount / _totalSpins;
      final easedProgress = Curves.easeInOut.transform(progress);
      final delay = (_initialDelay + ((_finalDelay - _initialDelay) * easedProgress)).round();
      _categoryTimer = Timer(Duration(milliseconds: delay), updateCategory);
    }
    updateCategory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tiebreaker Category Selection')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tiebreaker Round: All teams will play with the same category!',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: (!_isSpinning && _selectedCategory == null) ? _spinCategories : null,
            child: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: Text(
                          _currentCategory.isEmpty ? 'Tap to Spin' : _currentCategory,
                          key: ValueKey<String>(_currentCategory),
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: _currentCategory.isNotEmpty
                                    ? _getCategoryColor(_getCategoryFromName(_currentCategory))
                                    : Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: AnimatedOpacity(
              opacity: _selectedCategory != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Start Tiebreaker'),
                      onPressed: _selectedCategory != null
                          ? () {
                              // Set the tiebreaker category in game state
                              ref.read(gameStateProvider.notifier).setTiebreakerCategory(_selectedCategory!);
                              // Navigate to the first team's role assignment
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => RoleAssignmentScreen(
                                    teamIndex: widget.tiebreakerTeams[0],
                                    roundNumber: widget.roundNumber,
                                    turnNumber: 1,
                                    category: _selectedCategory!,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
