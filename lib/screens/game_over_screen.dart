import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_state_provider.dart';

class GameOverScreen extends ConsumerWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    if (gameState == null) return const SizedBox.shrink();

    // If tiebreakerTeams is not empty, only show those teams
    List<int> sortedTeamIndices;
    if (gameState.tiebreakerTeams.isNotEmpty) {
      sortedTeamIndices = List<int>.from(gameState.tiebreakerTeams)
        ..sort((a, b) => gameState.teamScores[b].compareTo(gameState.teamScores[a]));
    } else {
      sortedTeamIndices = List.generate(gameState.teamScores.length, (i) => i)
        ..sort((a, b) => gameState.teamScores[b].compareTo(gameState.teamScores[a]));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(27.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Game Over!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Final Scores',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: List.generate(
                  sortedTeamIndices.length,
                  (i) {
                    final teamIndex = sortedTeamIndices[i];
                    final playerNames =
                        gameState.config.teams[teamIndex].join(' & ');
                    final totalScore = gameState.teamScores[teamIndex];
                    final isWinner = i == 0 && totalScore > 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isWinner ? '$playerNames 🏆' : playerNames,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                            ),
                          ),
                          CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            radius: 18,
                            child: Text(
                              totalScore.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(gameStateProvider.notifier).resetGame();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      minimumSize: const Size(0, 60), // Only control height
                    ),
                    child: const Text(
                      'New Game',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      minimumSize: const Size(0, 60), // Only control height
                      backgroundColor:
                          Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    child: const Text(
                      'Home',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
