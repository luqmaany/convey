import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'dart:async';
import 'word_lists_manager_screen.dart';
import '../services/game_navigation_service.dart';
import '../services/game_state_provider.dart';
import '../utils/category_utils.dart';
import 'package:convey/widgets/team_color_button.dart';

class CategorySelectionScreen extends ConsumerStatefulWidget {
  final int teamIndex;
  final int roundNumber;
  final int turnNumber;
  final String displayString;

  const CategorySelectionScreen({
    super.key,
    required this.teamIndex,
    required this.roundNumber,
    required this.turnNumber,
    required this.displayString,
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
          _currentCategory = CategoryUtils.getCategoryName(finalCategory);
        });

        // Add a celebration animation
        _scaleController.forward().then((_) => _scaleController.reverse());
        return;
      }

      setState(() {
        _currentCategory = CategoryUtils.getCategoryName(WordCategory
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
    // Get the team color for the current team
    final gameState = ref.watch(gameStateProvider);
    TeamColor teamColor;
    if (gameState != null) {
      final colorIndex =
          (gameState.config.teamColorIndices.length > widget.teamIndex)
              ? gameState.config.teamColorIndices[widget.teamIndex]
              : widget.teamIndex % teamColors.length;
      teamColor = teamColors[colorIndex];
    } else {
      // Fallback to first team color if game state is not available
      teamColor = teamColors[0];
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
                      widget.displayString,
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
                                  color: _currentCategory.isNotEmpty
                                      ? CategoryUtils.getCategoryColor(
                                          _getCategoryFromName(
                                              _currentCategory))
                                      : teamColor.text,
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
                                        ? 'TAP TO SPIN\nFOR CATEGORY!'
                                        : _currentCategory,
                                    key: ValueKey<String>(_currentCategory),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(
                                          color: _currentCategory.isNotEmpty
                                              ? CategoryUtils.getCategoryColor(
                                                  _getCategoryFromName(
                                                      _currentCategory))
                                              : teamColor.text,
                                          fontSize: _currentCategory.isEmpty
                                              ? 32
                                              : null,
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
                      child: TeamColorButton(
                        text: 'Next',
                        icon: Icons.arrow_forward,
                        color: uiColors[1], // Green
                        onPressed: _selectedCategory != null
                            ? () {
                                // Use navigation service to handle all navigation logic based on game state
                                GameNavigationService
                                    .navigateFromCategorySelection(
                                  context,
                                  ref,
                                  widget.teamIndex,
                                  widget.roundNumber,
                                  widget.turnNumber,
                                  _selectedCategory!,
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
