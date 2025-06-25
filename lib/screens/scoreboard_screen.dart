import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/game_state_provider.dart';
import 'category_selection_screen.dart';
import 'package:convey/widgets/team_color_button.dart';
import 'role_assignment_screen.dart';
import 'category_selection_screen.dart' show TiebreakerCategorySelectionScreen;

class ScoreboardScreen extends ConsumerWidget {
  final int roundNumber;

  const ScoreboardScreen({Key? key, required this.roundNumber})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTiebreaker = gameState.isTiebreaker;
    final tiebreakerTeams = gameState.tiebreakerTeams;

    // Detect if this is a repeated tiebreaker (i.e., previous round was also a tiebreaker with a subset of teams)
    // We'll show the previous tiebreaker round's scores for the current tiebreaker teams
    List<int>? previousTiebreakerTeams;
    Map<int, int>? previousTiebreakerScores;
    if (isTiebreaker && roundNumber > 1) {
      // Find the previous round's tiebreaker teams and their scores
      // Look back in the turnHistory for the previous round
      final prevRound = roundNumber - 1;
      // Find which teams played in the previous round (those with a turn in prevRound)
      final prevTeams = <int>{};
      final prevScores = <int, int>{};
      for (final turn in gameState.turnHistory.where((t) => t.roundNumber == prevRound)) {
        prevTeams.add(turn.teamIndex);
        prevScores[turn.teamIndex] = (prevScores[turn.teamIndex] ?? 0) + turn.score;
      }
      // Only show if the previous tiebreaker teams are a superset of the current tiebreaker teams
      if (prevTeams.length > tiebreakerTeams.length && tiebreakerTeams.every((t) => prevTeams.contains(t))) {
        previousTiebreakerTeams = tiebreakerTeams;
        previousTiebreakerScores = { for (var t in tiebreakerTeams) t: prevScores[t] ?? 0 };
      }
    }

    // Find each team's score for this round
    final teamsCount = gameState.teamScores.length;
    final roundScores = List<int>.filled(teamsCount, 0);
    for (final turn in gameState.turnHistory
        .where((turn) => turn.roundNumber == roundNumber)) {
      roundScores[turn.teamIndex] += turn.score;
    }
    final topRoundScore = roundScores.isNotEmpty
        ? roundScores.reduce((a, b) => a > b ? a : b)
        : 0;

    // Calculate total scores up to previous round and up to current round
    final totalScoresPrev = List<int>.filled(teamsCount, 0);
    final totalScoresCurr = List<int>.filled(teamsCount, 0);
    for (final turn in gameState.turnHistory) {
      if (turn.roundNumber < roundNumber) {
        totalScoresPrev[turn.teamIndex] += turn.score;
      }
      if (turn.roundNumber <= roundNumber) {
        totalScoresCurr[turn.teamIndex] += turn.score;
      }
    }
    // Get rankings: higher score = higher rank (lower index)
    List<int> getRankings(List<int> scores) {
      final indexed =
          List.generate(scores.length, (i) => MapEntry(i, scores[i]));
      indexed.sort((a, b) => b.value.compareTo(a.value));
      final ranks = List<int>.filled(scores.length, 0);
      for (int rank = 0; rank < indexed.length; rank++) {
        ranks[indexed[rank].key] = rank;
      }
      return ranks;
    }

    final prevRanks = getRankings(totalScoresPrev);
    final currRanks = getRankings(totalScoresCurr);

    // Sort team indices by total score (descending)
    List<int> sortedTeamIndices;
    if (isTiebreaker) {
      sortedTeamIndices = List<int>.from(tiebreakerTeams)
        ..sort((a, b) => totalScoresCurr[b].compareTo(totalScoresCurr[a]));
    } else {
      sortedTeamIndices = List.generate(teamsCount, (i) => i)
        ..sort((a, b) => totalScoresCurr[b].compareTo(totalScoresCurr[a]));
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
            if (isTiebreaker && previousTiebreakerTeams != null && previousTiebreakerScores != null) ...[
              Text(
                'Previous Tiebreaker Scores',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: previousTiebreakerTeams.map((teamIndex) {
                    final playerNames = gameState.config.teams[teamIndex].join(' & ');
                    final score = previousTiebreakerScores![teamIndex] ?? 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: teamColors[gameState.config.teamColorIndices.length > teamIndex
                                ? gameState.config.teamColorIndices[teamIndex]
                                : teamIndex % teamColors.length].background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: teamColors[gameState.config.teamColorIndices.length > teamIndex
                                  ? gameState.config.teamColorIndices[teamIndex]
                                  : teamIndex % teamColors.length].border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              playerNames,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: teamColors[gameState.config.teamColorIndices.length > teamIndex
                                            ? gameState.config.teamColorIndices[teamIndex]
                                            : teamIndex % teamColors.length].text,
                                  ),
                            ),
                          ),
                          Text(
                            score.toString(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isTiebreaker) ...[
              Text(
                'Tiebreaker Round',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Only teams that reached the target score last round are playing. Highest score this round wins!',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                'Round $roundNumber',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: List.generate(
                  sortedTeamIndices.length,
                  (i) {
                    final teamIndex = sortedTeamIndices[i];
                    final playerNames =
                        gameState.config.teams[teamIndex].join(' & ');
                    final totalScore = totalScoresCurr[teamIndex];
                    final isTopThisRound =
                        roundScores[teamIndex] == topRoundScore &&
                            topRoundScore > 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: teamColors[gameState
                                        .config.teamColorIndices.length >
                                    teamIndex
                                ? gameState.config.teamColorIndices[teamIndex]
                                : teamIndex % teamColors.length]
                            .background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: teamColors[gameState
                                          .config.teamColorIndices.length >
                                      teamIndex
                                  ? gameState.config.teamColorIndices[teamIndex]
                                  : teamIndex % teamColors.length]
                              .border,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isTopThisRound ? '$playerNames 🏆' : playerNames,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: teamColors[gameState.config
                                                      .teamColorIndices.length >
                                                  teamIndex
                                              ? gameState.config
                                                  .teamColorIndices[teamIndex]
                                              : teamIndex % teamColors.length]
                                          .text),
                            ),
                          ),
                          CircleAvatar(
                            backgroundColor: teamColors[
                                    gameState.config.teamColorIndices.length >
                                            teamIndex
                                        ? gameState
                                            .config.teamColorIndices[teamIndex]
                                        : teamIndex % teamColors.length]
                                .border,
                            radius: 18,
                            child: Text(
                              totalScore.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Arrow for leaderboard movement
                          Text(
                            roundNumber == 1
                                ? ''
                                : currRanks[teamIndex] < prevRanks[teamIndex]
                                    ? '▲'
                                    : currRanks[teamIndex] >
                                            prevRanks[teamIndex]
                                        ? '▼'
                                        : '',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: roundNumber == 1
                                  ? Colors.transparent
                                  : currRanks[teamIndex] < prevRanks[teamIndex]
                                      ? Colors.green
                                      : currRanks[teamIndex] >
                                              prevRanks[teamIndex]
                                          ? Colors.red
                                          : Colors.transparent,
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
                  child: TeamColorButton(
                    text: isTiebreaker ? 'Next Tiebreaker Round' : 'Next Round',
                    icon: Icons.arrow_forward,
                    color: teamColors[2], // Green
                    onPressed: () {
                      final nextRound = roundNumber + 1;
                      if (isTiebreaker) {
                        if (gameState.tiebreakerCategory == null && gameState.currentTeamIndex == tiebreakerTeams[0]) {
                          // Only the first team in the tiebreaker round spins for the category
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => TiebreakerCategorySelectionScreen(
                                roundNumber: nextRound,
                                tiebreakerTeams: tiebreakerTeams,
                              ),
                            ),
                          );
                        } else {
                          // All teams use the stored tiebreaker category
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => RoleAssignmentScreen(
                                teamIndex: gameState.currentTeamIndex,
                                roundNumber: nextRound,
                                turnNumber: 1,
                                category: gameState.tiebreakerCategory!,
                              ),
                            ),
                          );
                        }
                      } else {
                        // Normal round: go to category selection
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => CategorySelectionScreen(
                              teamIndex: gameState.currentTeamIndex,
                              roundNumber: nextRound,
                              turnNumber: 1,
                            ),
                          ),
                        );
                      }
                    },
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
