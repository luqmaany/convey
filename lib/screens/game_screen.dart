import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'dart:async';
import 'word_lists_manager_screen.dart';
import '../services/game_setup_provider.dart';
import '../services/game_state_provider.dart';
import '../models/game_state.dart';
import 'game_over_screen.dart';
import 'category_selection_screen.dart';
import 'scoreboard_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int teamIndex;
  final int roundNumber;
  final int turnNumber;
  final WordCategory category;

  const GameScreen({
    super.key,
    required this.teamIndex,
    required this.roundNumber,
    required this.turnNumber,
    required this.category,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late int _timeLeft;
  late int _skipsLeft;
  int _correctCount = 0;
  Timer? _timer;
  bool _isTurnOver = false;
  List<Word> _currentWords = [];
  Set<String> _usedWords = {};
  final CardSwiperController _topCardController = CardSwiperController();
  final CardSwiperController _bottomCardController = CardSwiperController();
  List<String> _wordsGuessed = [];
  List<String> _wordsSkipped = [];
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

  String _getPerformanceMessage() {
    final gameConfig = ref.read(gameSetupProvider);
    final maxPossibleScore = gameConfig.roundTimeSeconds ~/
        3; // Rough estimate of max possible score
    final scorePercentage = _correctCount / maxPossibleScore;

    if (scorePercentage >= 0.7) {
      return _getRandomMessage(_highScoreMessages);
    } else if (_correctCount == 0) {
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

  @override
  void initState() {
    super.initState();
    final gameConfig = ref.read(gameSetupProvider);
    _timeLeft = gameConfig.roundTimeSeconds;
    _skipsLeft = gameConfig.allowedSkips;
    _startTimer();
    _loadInitialWords();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _topCardController.dispose();
    _bottomCardController.dispose();
    super.dispose();
  }

  void _startTimer() {
    debugPrint(
        'Starting timer for round ${widget.roundNumber}, turn ${widget.turnNumber}');
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          if (_timeLeft % 5 == 0) {
            // Print every 5 seconds
            debugPrint('Time left: $_timeLeft seconds');
          }
        } else {
          debugPrint('Timer reached zero, ending turn');
          _endTurn();
        }
      });
    });
  }

  void _endTurn() {
    debugPrint('\n=== TURN ENDED ===');
    debugPrint('Round ${widget.roundNumber}, Turn ${widget.turnNumber}');
    debugPrint('Final Score: $_disputedScore');
    debugPrint('Skips Remaining: $_skipsLeft');

    _timer?.cancel();
    setState(() {
      _isTurnOver = true;
    });

    // Log detailed score information with a small delay to ensure visibility
    Future.delayed(const Duration(milliseconds: 100), () {
      final gameState = ref.read(gameStateProvider);
      if (gameState != null) {
        debugPrint('\n=== Turn ${widget.turnNumber} Results ===');
        debugPrint('Team ${widget.teamIndex + 1} Turn Details:');
        debugPrint('- Correct Guesses: $_disputedScore');
        debugPrint('- Disputed Words: ${_disputedWords.join(", ")}');
        debugPrint(
            '- Skips Used: ${ref.read(gameSetupProvider).allowedSkips - _skipsLeft}');
        debugPrint(
            '- Words Guessed: ${_wordsGuessed.where((word) => !_disputedWords.contains(word)).join(", ")}');
        debugPrint('- Words Skipped: ${_wordsSkipped.join(", ")}');
        debugPrint('\nCurrent Team Scores:');
        for (var i = 0; i < gameState.teamScores.length; i++) {
          debugPrint('Team ${i + 1}: ${gameState.teamScores[i]} points');
        }
        debugPrint('===========================\n');
      }
    });
  }

  void _onWordGuessed(String word) {
    setState(() {
      _correctCount++;
      _wordsGuessed.add(word);
    });
  }

  void _onWordSkipped(String word) {
    if (_skipsLeft > 0) {
      setState(() {
        _skipsLeft--;
        _wordsSkipped.add(word);
      });
    }
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
    return _correctCount - _disputedWords.length;
  }

  void _incrementWordUsage(Word word) {
    final words = ref.read(wordsProvider);
    final updatedWords = words.map((w) {
      if (w.text == word.text) {
        return Word(
          text: w.text,
          category: w.category,
          usageCount: w.usageCount + 1,
        );
      }
      return w;
    }).toList();
    ref.read(wordsProvider.notifier).updateWords(updatedWords);
  }

  void _loadInitialWords() {
    final words = ref.read(wordsProvider);
    final categoryWords =
        words.where((word) => word.category == widget.category).toList();

    if (categoryWords.isEmpty) {
      setState(() {
        _isTurnOver = true;
      });
      return;
    }

    // Get two random words from the category
    categoryWords.shuffle();
    _currentWords = categoryWords.take(2).toList();
    _usedWords.addAll(_currentWords.map((w) => w.text));
  }

  Word? _getNextWord(WordCategory category) {
    final words = ref.read(wordsProvider);
    final categoryWords = words
        .where((word) =>
            word.category == category && !_usedWords.contains(word.text))
        .toList();

    if (categoryWords.isEmpty) {
      // If we've used all words, reset the used words set
      _usedWords.clear();
      return words.firstWhere((word) => word.category == category);
    }

    categoryWords.shuffle();
    return categoryWords.first;
  }

  void _loadNewWord(int index) {
    final newWord = _getNextWord(widget.category);
    if (newWord != null) {
      setState(() {
        _currentWords[index] = newWord;
        _usedWords.add(newWord.text);
      });
    }
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

  Widget _buildCard(Word word) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          word.text,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
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
        skipsUsed: ref.read(gameSetupProvider).allowedSkips - _skipsLeft,
        wordsGuessed: _wordsGuessed
            .where((word) => !_disputedWords.contains(word))
            .toList(),
        wordsSkipped: _wordsSkipped,
      );

      ref.read(gameStateProvider.notifier).recordTurn(turnRecord);

      // Navigate to next screen
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
      } else {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final isGameOver = ref.watch(isGameOverProvider);

    if (isGameOver) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Game Over!',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              Text(
                'Final Scores:',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              ...gameState!.teamScores.asMap().entries.map((entry) {
                final teamIndex = entry.key;
                final score = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Team ${teamIndex + 1}: $score points',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                );
              }),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  ref.read(gameStateProvider.notifier).resetGame();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('New Game'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isTurnOver) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Turn Over!',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Score: $_disputedScore',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tap words to contest them',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
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
                        if (_wordsGuessed.isNotEmpty) ...[
                          for (var i = 0; i < _wordsGuessed.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _onWordDisputed(_wordsGuessed[i]),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: _disputedWords
                                                  .contains(_wordsGuessed[i])
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .errorContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _disputedWords
                                                    .contains(_wordsGuessed[i])
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _wordsGuessed[i],
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            if (_disputedWords
                                                .contains(_wordsGuessed[i]))
                                              Icon(
                                                Icons.close,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: i + 1 < _wordsGuessed.length
                                        ? GestureDetector(
                                            onTap: () => _onWordDisputed(
                                                _wordsGuessed[i + 1]),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: _disputedWords.contains(
                                                        _wordsGuessed[i + 1])
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .errorContainer
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      _disputedWords.contains(
                                                              _wordsGuessed[
                                                                  i + 1])
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .error
                                                          : Colors.transparent,
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
                                                      _wordsGuessed[i + 1],
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  if (_disputedWords.contains(
                                                      _wordsGuessed[i + 1]))
                                                    Icon(
                                                      Icons.close,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error,
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getPerformanceMessage(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
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
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getRandomMessage(_zeroScoreMessages),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (_wordsSkipped.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Words Skipped:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          for (var word in _wordsSkipped)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  word,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
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
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _confirmScore,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 32),
                        minimumSize: const Size(double.infinity, 60),
                      ),
                      child: const Text(
                        'Confirm Score',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    if (_currentWords.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Title showing current players
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "${ref.read(currentTeamPlayersProvider)[0]} & ${ref.read(currentTeamPlayersProvider)[1]}'s Turn",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // Top bar with timer, skips, and category
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Score indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Score: $_correctCount',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Category: ${_getCategoryName(widget.category)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Timer and skips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_timeLeft s',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      // Skip counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Skips: $_skipsLeft',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Word cards with Swiper
            Expanded(
              child: Column(
                children: [
                  // Top card
                  Expanded(
                    child: CardSwiper(
                      controller: _topCardController,
                      cardsCount: 1,
                      cardBuilder: (context,
                          index,
                          horizontalThresholdPercentage,
                          verticalThresholdPercentage) {
                        return _buildCard(_currentWords[0]);
                      },
                      onSwipe: (previousIndex, currentIndex, direction) {
                        if (direction == CardSwiperDirection.right) {
                          // Correct guess
                          _onWordGuessed(_currentWords[0].text);
                          _incrementWordUsage(_currentWords[0]);
                          _loadNewWord(0);
                          return true;
                        } else if (direction == CardSwiperDirection.left) {
                          // Skip
                          if (_skipsLeft > 0) {
                            _onWordSkipped(_currentWords[0].text);
                            setState(() {
                              _loadNewWord(0);
                            });
                            return true;
                          } else {
                            // Show feedback for no skips left
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('No skips left!'),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                        return false;
                      },
                      allowedSwipeDirection: AllowedSwipeDirection.symmetric(
                          horizontal: true, vertical: false),
                      numberOfCardsDisplayed: 1,
                      padding: const EdgeInsets.all(24.0),
                    ),
                  ),
                  // Bottom card
                  Expanded(
                    child: CardSwiper(
                      controller: _bottomCardController,
                      cardsCount: 1,
                      cardBuilder: (context,
                          index,
                          horizontalThresholdPercentage,
                          verticalThresholdPercentage) {
                        return _buildCard(_currentWords[1]);
                      },
                      onSwipe: (previousIndex, currentIndex, direction) {
                        if (direction == CardSwiperDirection.right) {
                          // Correct guess
                          _onWordGuessed(_currentWords[1].text);
                          _incrementWordUsage(_currentWords[1]);
                          _loadNewWord(1);
                          return true;
                        } else if (direction == CardSwiperDirection.left) {
                          // Skip
                          if (_skipsLeft > 0) {
                            _onWordSkipped(_currentWords[1].text);
                            setState(() {
                              _loadNewWord(1);
                            });
                            return true;
                          } else {
                            // Show feedback for no skips left
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('No skips left!'),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                        return false;
                      },
                      allowedSwipeDirection: AllowedSwipeDirection.symmetric(
                          horizontal: true, vertical: false),
                      numberOfCardsDisplayed: 1,
                      padding: const EdgeInsets.all(24.0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
