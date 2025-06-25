import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_setup_provider.dart';
import '../services/game_state_provider.dart';
import '../models/game_state.dart';
import '../models/game_config.dart';
import 'game_over_screen.dart';
import 'category_selection_screen.dart';
import 'scoreboard_screen.dart';
import 'word_lists_manager_screen.dart';
import 'package:convey/widgets/team_color_button.dart';
import 'role_assignment_screen.dart';

class TurnOverScreen extends ConsumerStatefulWidget {
  final int teamIndex;
  final int roundNumber;
  final int turnNumber;
  final WordCategory category;
  final int correctCount;
  final int skipsLeft;
  final List<String> wordsGuessed;
  final List<String> wordsSkipped;
  final Set<String> disputedWords;

  const TurnOverScreen({
    super.key,
    required this.teamIndex,
    required this.roundNumber,
    required this.turnNumber,
    required this.category,
    required this.correctCount,
    required this.skipsLeft,
    required this.wordsGuessed,
    required this.wordsSkipped,
    required this.disputedWords,
  });

  @override
  ConsumerState<TurnOverScreen> createState() => _TurnOverScreenState();
}

class _TurnOverScreenState extends ConsumerState<TurnOverScreen> {
  Set<String> _disputedWords = {};

  static const List<Map<String, String>> _highScoreMessages = [
    {'text': 'You\'re the dynamic duo of word games!', 'emoji': '🦸‍♂️'},
    {
      'text': 'Like Batman and Robin, but with better communication!',
      'emoji': '🦇'
    },
    {
      'text': 'You two are the word game equivalent of a perfect handshake!',
      'emoji': '🤝'
    },
    {
      'text': 'More coordinated than a synchronized dance routine!',
      'emoji': '💃'
    },
    {'text': 'You\'re like a well-tuned word orchestra!', 'emoji': '🎻'},
  ];

  static const List<Map<String, String>> _lowScoreMessages = [
    {'text': 'Well... at least you tried!', 'emoji': '🤷'},
    {'text': 'Like two ships passing in the night...', 'emoji': '🚢'},
    {'text': 'You two are like a broken telephone game!', 'emoji': '📞'},
    {
      'text': 'More confused than a cat in a room full of rocking chairs!',
      'emoji': '😺'
    },
    {
      'text': 'Like trying to solve a Rubik\'s cube in the dark!',
      'emoji': '🎲'
    },
  ];

  static const List<Map<String, String>> _zeroScoreMessages = [
    {
      'text':
          'Not a single word guessed! The conveyor must be playing charades instead!',
      'emoji': '🎭'
    },
    {
      'text': 'Zero points! Did the conveyor forget how to speak?',
      'emoji': '🤐'
    },
    {
      'text': 'The guesser\'s mind-reading skills need some serious work!',
      'emoji': '🧠'
    },
    {'text': 'Maybe try using actual words next time?', 'emoji': '📝'},
    {
      'text': 'The conveyor and guesser must be speaking different languages!',
      'emoji': '🌍'
    },
  ];

  @override
  void initState() {
    super.initState();
    _disputedWords = Set.from(widget.disputedWords);
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

  String _getPerformanceMessage() {
    final gameConfig = ref.read(gameSetupProvider);
    final maxPossibleScore = gameConfig.roundTimeSeconds ~/
        3; // Rough estimate of max possible score
    final scorePercentage = widget.correctCount / maxPossibleScore;

    if (scorePercentage >= 0.7) {
      return _getRandomMessage(_highScoreMessages);
    } else if (widget.correctCount == 0) {
      return _getRandomMessage(_zeroScoreMessages);
    } else {
      return _getRandomMessage(_lowScoreMessages);
    }
  }

  String _getRandomMessage(List<Map<String, String>> messages) {
    final random =
        messages[DateTime.now().millisecondsSinceEpoch % messages.length];
    return '${random['text']} ${random['emoji']}';
  }

  void _onWordDisputed(String word) {
    setState(() {
      if (_disputedWords.contains(word)) {
        _disputedWords.remove(word);
      } else {
        _disputedWords.add(word);
      }
    });
  }

  int get _disputedScore {
    return widget.correctCount - _disputedWords.length;
  }

  void _confirmScore() {
    // Record the turn in game state with final disputed score
    final currentTeamPlayers = ref.read(currentTeamPlayersProvider);
    if (currentTeamPlayers.length >= 2) {
      final isLastTeamThisRound = widget.teamIndex ==
          ref.read(gameStateProvider)!.config.teams.length - 1;
      final turnRecord = TurnRecord(
        teamIndex: widget.teamIndex,
        roundNumber: widget.roundNumber,
        turnNumber: widget.turnNumber,
        conveyor: currentTeamPlayers[0],
        guesser: currentTeamPlayers[1],
        category: widget.category.toString(),
        score: _disputedScore,
        skipsUsed: ref.read(gameSetupProvider).allowedSkips - widget.skipsLeft,
        wordsGuessed: widget.wordsGuessed
            .where((word) => !_disputedWords.contains(word))
            .toList(),
        wordsSkipped: widget.wordsSkipped,
      );

      ref.read(gameStateProvider.notifier).recordTurn(turnRecord);

      // Use post-frame callback to ensure state is updated before navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final gameState = ref.read(gameStateProvider);
        if (gameState == null) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        if (gameState.isGameOver) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const GameOverScreen(),
            ),
          );
        } else if (isLastTeamThisRound) {
          // End of round: show scoreboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ScoreboardScreen(
                roundNumber: gameState.currentRound - 1,
              ),
            ),
          );
        } else if (gameState.isTiebreaker && gameState.tiebreakerCategory != null) {
          // In tiebreaker: go directly to next team's role assignment with the same category
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RoleAssignmentScreen(
                teamIndex: gameState.currentTeamIndex,
                roundNumber: gameState.currentRound,
                turnNumber: gameState.currentTurn,
                category: gameState.tiebreakerCategory!,
              ),
            ),
          );
        } else {
          // Normal round: go to category selection for next team
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CategorySelectionScreen(
                teamIndex: gameState.currentTeamIndex,
                roundNumber: gameState.currentRound,
                turnNumber: gameState.currentTurn,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Column(
            children: [
              // Category display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(widget.category).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getCategoryColor(widget.category),
                    width: 2,
                  ),
                ),
                child: Text(
                  _getCategoryName(widget.category),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              // Score display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(widget.category),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color:
                          _getCategoryColor(widget.category).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Score: $_disputedScore',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Words Guessed:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        if (widget.wordsGuessed.isNotEmpty) ...[
                          for (var i = 0;
                              i < widget.wordsGuessed.length;
                              i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _onWordDisputed(
                                          widget.wordsGuessed[i]),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: _disputedWords.contains(
                                                  widget.wordsGuessed[i])
                                              ? Colors.red.withOpacity(0.1)
                                              : _getCategoryColor(
                                                      widget.category)
                                                  .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _disputedWords.contains(
                                                    widget.wordsGuessed[i])
                                                ? Colors.red
                                                : _getCategoryColor(
                                                    widget.category),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.wordsGuessed[i],
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            if (_disputedWords.contains(
                                                widget.wordsGuessed[i]))
                                              Icon(
                                                Icons.close,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: i + 1 < widget.wordsGuessed.length
                                        ? GestureDetector(
                                            onTap: () => _onWordDisputed(
                                                widget.wordsGuessed[i + 1]),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: _disputedWords.contains(
                                                        widget.wordsGuessed[
                                                            i + 1])
                                                    ? Colors.red
                                                        .withOpacity(0.1)
                                                    : _getCategoryColor(
                                                            widget.category)
                                                        .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _disputedWords
                                                          .contains(widget
                                                                  .wordsGuessed[
                                                              i + 1])
                                                      ? Colors.red
                                                      : _getCategoryColor(
                                                          widget.category),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      widget
                                                          .wordsGuessed[i + 1],
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  if (_disputedWords.contains(
                                                      widget
                                                          .wordsGuessed[i + 1]))
                                                    Icon(
                                                      Icons.close,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap words to contest them',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: _getCategoryColor(widget.category),
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(widget.category)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getCategoryColor(widget.category),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getPerformanceMessage(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.black,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getRandomMessage(_zeroScoreMessages),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.black,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (widget.wordsSkipped.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Words Skipped:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          for (var word in widget.wordsSkipped)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(widget.category)
                                      .withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getCategoryColor(widget.category)
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  word,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.black,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    if (_disputedWords.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          '${_disputedWords.length} word${_disputedWords.length == 1 ? '' : 's'} contested',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.red,
                                  ),
                        ),
                      ),
                    TeamColorButton(
                      text: 'Confirm Score',
                      icon: Icons.check,
                      color: TeamColor(
                        'Category',
                        _getCategoryColor(widget.category).withOpacity(0.1),
                        _getCategoryColor(widget.category),
                        _getCategoryColor(widget.category),
                      ),
                      onPressed: _confirmScore,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
