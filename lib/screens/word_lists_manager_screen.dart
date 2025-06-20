import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/word_lists.dart';

// TODO: Move these to a separate models file later
enum WordCategory {
  person,
  action,
  world,
  random,
}

class Word {
  final String text;
  final WordCategory category;
  int usageCount;

  Word({
    required this.text,
    required this.category,
    this.usageCount = 0,
  });
}

// TODO: Move to a separate providers file later
final wordsProvider = StateNotifierProvider<WordsNotifier, List<Word>>((ref) {
  return WordsNotifier();
});

class WordsNotifier extends StateNotifier<List<Word>> {
  WordsNotifier() : super([]) {
    _initializeWords();
  }

  void _initializeWords() {
    // Add all words to state
    state = [
      ...WordLists.people
          .map((word) => Word(text: word, category: WordCategory.person)),
      ...WordLists.actions
          .map((word) => Word(text: word, category: WordCategory.action)),
      ...WordLists.locations
          .map((word) => Word(text: word, category: WordCategory.world)),
      ...WordLists.random
          .map((word) => Word(text: word, category: WordCategory.random)),
    ];
  }

  void addWord(Word word) {
    state = [...state, word];
  }

  void deleteWord(Word word) {
    state = state.where((w) => w.text != word.text).toList();
  }

  void resetUsageCounts() {
    state = state
        .map((word) => Word(
              text: word.text,
              category: word.category,
              usageCount: 0,
            ))
        .toList();
  }

  void purgeLowFrequencyWords(int threshold) {
    state = state.where((word) => word.usageCount >= threshold).toList();
  }

  void updateWords(List<Word> updatedWords) {
    state = updatedWords;
  }
}

class WordListsManagerScreen extends ConsumerStatefulWidget {
  const WordListsManagerScreen({super.key});

  @override
  ConsumerState<WordListsManagerScreen> createState() =>
      _WordListsManagerScreenState();
}

class _WordListsManagerScreenState
    extends ConsumerState<WordListsManagerScreen> {
  WordCategory _selectedCategory = WordCategory.person;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final words = ref.watch(wordsProvider);
    final filteredWords = words.where((word) {
      final matchesCategory = word.category == _selectedCategory;
      final matchesSearch =
          word.text.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Lists Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Purge Low Frequency Words',
            onPressed: () => _showPurgeDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Usage Counts',
            onPressed: () => _showResetDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Category selector
                SegmentedButton<WordCategory>(
                  segments: const [
                    ButtonSegment(
                      value: WordCategory.person,
                      label: Text('Person'),
                    ),
                    ButtonSegment(
                      value: WordCategory.action,
                      label: Text('Action'),
                    ),
                    ButtonSegment(
                      value: WordCategory.world,
                      label: Text('World'),
                    ),
                    ButtonSegment(
                      value: WordCategory.random,
                      label: Text('Random'),
                    ),
                  ],
                  selected: {_selectedCategory},
                  onSelectionChanged: (Set<WordCategory> selected) {
                    setState(() {
                      _selectedCategory = selected.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Search bar
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search words...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),
          // Word list
          Expanded(
            child: ListView.builder(
              itemCount: filteredWords.length,
              itemBuilder: (context, index) {
                final word = filteredWords[index];
                return ListTile(
                  title: Text(word.text),
                  subtitle: Text('Used ${word.usageCount} times'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteDialog(context, word),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWordDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWordDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Word',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WordCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: WordCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                ref.read(wordsProvider.notifier).addWord(
                      Word(
                        text: textController.text,
                        category: _selectedCategory,
                      ),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Word word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Are you sure you want to delete "${word.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(wordsProvider.notifier).deleteWord(word);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPurgeDialog(BuildContext context) {
    final thresholdController = TextEditingController(text: '3');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purge Low Frequency Words'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter minimum usage count threshold:'),
            const SizedBox(height: 16),
            TextField(
              controller: thresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final threshold = int.tryParse(thresholdController.text) ?? 3;
              ref
                  .read(wordsProvider.notifier)
                  .purgeLowFrequencyWords(threshold);
              Navigator.pop(context);
            },
            child: const Text('Purge'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Usage Counts'),
        content: const Text(
            'Are you sure you want to reset all word usage counts to zero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(wordsProvider.notifier).resetUsageCounts();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
