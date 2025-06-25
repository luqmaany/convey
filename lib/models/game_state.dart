import 'game_config.dart';
import '../screens/word_lists_manager_screen.dart';

enum PlayerRole { conveyor, guesser }

class TurnRecord {
  final int teamIndex;
  final int roundNumber;
  final int turnNumber;
  final String conveyor;
  final String guesser;
  final String category;
  final int score;
  final int skipsUsed;
  final List<String> wordsGuessed;
  final List<String> wordsSkipped;

  TurnRecord({
    required this.teamIndex,
    required this.roundNumber,
    required this.turnNumber,
    required this.conveyor,
    required this.guesser,
    required this.category,
    required this.score,
    required this.skipsUsed,
    required this.wordsGuessed,
    required this.wordsSkipped,
  });

  TurnRecord copyWith({
    int? teamIndex,
    int? roundNumber,
    int? turnNumber,
    String? conveyor,
    String? guesser,
    String? category,
    int? score,
    int? skipsUsed,
    List<String>? wordsGuessed,
    List<String>? wordsSkipped,
  }) {
    return TurnRecord(
      teamIndex: teamIndex ?? this.teamIndex,
      roundNumber: roundNumber ?? this.roundNumber,
      turnNumber: turnNumber ?? this.turnNumber,
      conveyor: conveyor ?? this.conveyor,
      guesser: guesser ?? this.guesser,
      category: category ?? this.category,
      score: score ?? this.score,
      skipsUsed: skipsUsed ?? this.skipsUsed,
      wordsGuessed: wordsGuessed ?? this.wordsGuessed,
      wordsSkipped: wordsSkipped ?? this.wordsSkipped,
    );
  }
}

class GameState {
  final GameConfig config;
  final List<int> teamScores;
  final List<TurnRecord> turnHistory;
  final int currentRound;
  final int currentTurn;
  final int currentTeamIndex;
  final bool isGameOver;
  final bool isTiebreaker;
  final List<int> tiebreakerTeams;
  final WordCategory? tiebreakerCategory;

  GameState({
    required this.config,
    required this.teamScores,
    required this.turnHistory,
    required this.currentRound,
    required this.currentTurn,
    required this.currentTeamIndex,
    required this.isGameOver,
    this.isTiebreaker = false,
    this.tiebreakerTeams = const [],
    this.tiebreakerCategory,
  });

  GameState.initial(GameConfig config)
      : config = config,
        teamScores = List.filled(config.teams.length, 0),
        turnHistory = [],
        currentRound = 1,
        currentTurn = 1,
        currentTeamIndex = 0,
        isGameOver = false,
        isTiebreaker = false,
        tiebreakerTeams = const [],
        tiebreakerCategory = null;

  GameState copyWith({
    GameConfig? config,
    List<int>? teamScores,
    List<TurnRecord>? turnHistory,
    int? currentRound,
    int? currentTurn,
    int? currentTeamIndex,
    bool? isGameOver,
    bool? isTiebreaker,
    List<int>? tiebreakerTeams,
    WordCategory? tiebreakerCategory,
  }) {
    return GameState(
      config: config ?? this.config,
      teamScores: teamScores ?? this.teamScores,
      turnHistory: turnHistory ?? this.turnHistory,
      currentRound: currentRound ?? this.currentRound,
      currentTurn: currentTurn ?? this.currentTurn,
      currentTeamIndex: currentTeamIndex ?? this.currentTeamIndex,
      isGameOver: isGameOver ?? this.isGameOver,
      isTiebreaker: isTiebreaker ?? this.isTiebreaker,
      tiebreakerTeams: tiebreakerTeams ?? this.tiebreakerTeams,
      tiebreakerCategory: tiebreakerCategory ?? this.tiebreakerCategory,
    );
  }

  // Helper methods
  bool isLastTeam() {
    if (!isTiebreaker) {
      return currentTeamIndex == config.teams.length - 1;
    } else {
      // In tiebreaker, only tiebreakerTeams play
      return tiebreakerTeams.indexOf(currentTeamIndex) == tiebreakerTeams.length - 1;
    }
  }

  int getNextTeamIndex() {
    if (!isTiebreaker) {
      return isLastTeam() ? 0 : currentTeamIndex + 1;
    } else {
      // In tiebreaker, cycle through tiebreakerTeams only
      int idx = tiebreakerTeams.indexOf(currentTeamIndex);
      if (idx == -1) {
        // If currentTeamIndex is not in tiebreakerTeams, start with the first one
        return tiebreakerTeams.isNotEmpty ? tiebreakerTeams[0] : 0;
      }
      // Move to next team in tiebreakerTeams, or back to first if at the end
      int nextIdx = (idx + 1) % tiebreakerTeams.length;
      return tiebreakerTeams[nextIdx];
    }
  }

  int getNextRound() => isLastTeam() ? currentRound + 1 : currentRound;

  int getNextTurn() => isLastTeam() ? currentTurn + 1 : currentTurn;

  GameState advanceTurn(TurnRecord turnRecord) {
    final newTeamScores = List<int>.from(teamScores);
    newTeamScores[turnRecord.teamIndex] += turnRecord.score;
    final newTurnHistory = List<TurnRecord>.from(turnHistory)..add(turnRecord);
    final nextTeamIndex = getNextTeamIndex();
    final nextRound = getNextRound();
    final nextTurn = getNextTurn();

    // Tiebreaker logic
    if (!isTiebreaker) {
      // Check if multiple teams reached or exceeded the target score in this round
      final teamsReachedTarget = <int>[];
      for (int i = 0; i < newTeamScores.length; i++) {
        if (newTeamScores[i] >= config.targetScore) {
          teamsReachedTarget.add(i);
        }
      }
      final isEndOfRound = isLastTeam();
      if (teamsReachedTarget.length > 1 && isEndOfRound) {
        // Start tiebreaker: only these teams play, scores reset for them
        final resetScores = List<int>.from(newTeamScores);
        for (int i = 0; i < resetScores.length; i++) {
          if (teamsReachedTarget.contains(i)) {
            resetScores[i] = 0;
          }
        }
        return copyWith(
          teamScores: resetScores,
          turnHistory: newTurnHistory,
          currentRound: nextRound,
          currentTurn: nextTurn,
          currentTeamIndex: teamsReachedTarget[0], // Always start with first tiebreaker team
          isGameOver: false,
          isTiebreaker: true,
          tiebreakerTeams: teamsReachedTarget,
          tiebreakerCategory: null, // Reset category for new tiebreaker round
        );
      }
      // Normal game over logic
      final hasReachedTargetScore = newTeamScores.any((score) => score >= config.targetScore);
      if (hasReachedTargetScore && isEndOfRound) {
        return copyWith(
          teamScores: newTeamScores,
          turnHistory: newTurnHistory,
          currentRound: nextRound,
          currentTurn: nextTurn,
          currentTeamIndex: nextTeamIndex,
          isGameOver: true,
        );
      }
      return copyWith(
        teamScores: newTeamScores,
        turnHistory: newTurnHistory,
        currentRound: nextRound,
        currentTurn: nextTurn,
        currentTeamIndex: nextTeamIndex,
      );
    } else {
      // In tiebreaker mode: only tiebreakerTeams play, winner is highest score after round
      final isEndOfRound = isLastTeam();
      if (isEndOfRound) {
        // Find the tiebreaker winner(s)
        int maxScore = 0;
        for (final i in tiebreakerTeams) {
          if (newTeamScores[i] > maxScore) maxScore = newTeamScores[i];
        }
        final winners = tiebreakerTeams.where((i) => newTeamScores[i] == maxScore).toList();
        if (winners.length == 1) {
          // Single winner, game over
          return copyWith(
            teamScores: newTeamScores,
            turnHistory: newTurnHistory,
            currentRound: nextRound,
            currentTurn: nextTurn,
            currentTeamIndex: winners[0],
            isGameOver: true,
            isTiebreaker: false,
            tiebreakerTeams: winners,
            tiebreakerCategory: null, // Reset category for new tiebreaker round
          );
        } else {
          // Still tied, start another tiebreaker round with only tied teams
          final resetScores = List<int>.from(newTeamScores);
          for (int i = 0; i < resetScores.length; i++) {
            if (winners.contains(i)) {
              resetScores[i] = 0;
            }
          }
          return copyWith(
            teamScores: resetScores,
            turnHistory: newTurnHistory,
            currentRound: nextRound,
            currentTurn: nextTurn,
            currentTeamIndex: winners[0], // Always start with first tiebreaker team
            isGameOver: false,
            isTiebreaker: true,
            tiebreakerTeams: winners,
            tiebreakerCategory: null, // Reset category for new tiebreaker round
          );
        }
      }
      return copyWith(
        teamScores: newTeamScores,
        turnHistory: newTurnHistory,
        currentRound: nextRound,
        currentTurn: nextTurn,
        currentTeamIndex: nextTeamIndex,
      );
    }
  }

  // Get statistics for a specific player
  Map<String, dynamic> getPlayerStats(String playerName) {
    int totalScore = 0;
    int timesConveyor = 0;
    int timesGuesser = 0;
    int totalWordsGuessed = 0;
    int totalSkips = 0;
    Map<String, int> categoryStats = {};

    for (final turn in turnHistory) {
      if (turn.conveyor == playerName) {
        timesConveyor++;
        totalScore += turn.score;
        totalSkips += turn.skipsUsed;
        categoryStats[turn.category] =
            (categoryStats[turn.category] ?? 0) + turn.score;
      }
      if (turn.guesser == playerName) {
        timesGuesser++;
        totalWordsGuessed += turn.wordsGuessed.length;
      }
    }

    return {
      'totalScore': totalScore,
      'timesConveyor': timesConveyor,
      'timesGuesser': timesGuesser,
      'totalWordsGuessed': totalWordsGuessed,
      'totalSkips': totalSkips,
      'categoryStats': categoryStats,
    };
  }

  // Get statistics for a specific team
  Map<String, dynamic> getTeamStats(int teamIndex) {
    int totalScore = teamScores[teamIndex];
    int totalTurns =
        turnHistory.where((turn) => turn.teamIndex == teamIndex).length;
    int totalWordsGuessed = 0;
    int totalSkips = 0;
    Map<String, int> categoryStats = {};

    for (final turn
        in turnHistory.where((turn) => turn.teamIndex == teamIndex)) {
      totalWordsGuessed += turn.wordsGuessed.length;
      totalSkips += turn.skipsUsed;
      categoryStats[turn.category] =
          (categoryStats[turn.category] ?? 0) + turn.score;
    }

    return {
      'totalScore': totalScore,
      'totalTurns': totalTurns,
      'totalWordsGuessed': totalWordsGuessed,
      'totalSkips': totalSkips,
      'categoryStats': categoryStats,
    };
  }
}
