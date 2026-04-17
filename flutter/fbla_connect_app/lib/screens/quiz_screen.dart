import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Quiz Screen — two modes:
//
// PRACTICE (Flashcards): Swipeable cards, tap to flip and reveal answer.
//   Self-grade: "Got it" / "Missed it". No timer. No pressure.
//
// TEST (Multiple Choice): Timed, 4-option questions. Instant green/red
//   feedback on tap. Score + points at the end.
//
// Points earned go to the same profile points pool as event attendance.
// ─────────────────────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.quiz,
    required this.mode,
  });

  final Map<String, dynamic> quiz;
  /// 'practice' or 'test'
  final String mode;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _api = ApiService.instance;

  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  int _currentIndex = 0;
  bool _showAnswer = false; // Flashcard mode
  int? _selectedOption; // Test mode
  bool _answered = false;
  int _correctCount = 0;
  bool _quizComplete = false;
  int _pointsEarned = 0;

  // Timer (test mode only)
  Timer? _timer;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;

  String get _quizId => widget.quiz['id'] as String? ?? '';
  String get _title => widget.quiz['title'] as String? ?? 'Quiz';
  int get _pointsPerCorrect => widget.quiz['points_per_correct'] as int? ?? 5;
  bool get _isPractice => widget.mode == 'practice';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await _api.get<List<Map<String, dynamic>>>(
        '/quizzes/$_quizId/questions',
        parser: (data) =>
            (data['questions'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        setState(() {
          _questions = data;
          _loading = false;
        });
        if (!_isPractice) {
          final timeLimit = widget.quiz['time_limit_seconds'] as int?;
          _totalSeconds = timeLimit ?? (_questions.length * 30); // 30s per question default
          _secondsRemaining = _totalSeconds;
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _finishQuiz();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  // ── Flashcard Actions ─────────────────────────────────────────────────────

  void _flipCard() {
    HapticFeedback.lightImpact();
    setState(() => _showAnswer = !_showAnswer);
  }

  void _markCorrect() {
    setState(() {
      _correctCount++;
      _showAnswer = false;
    });
    _nextQuestion();
  }

  void _markIncorrect() {
    setState(() => _showAnswer = false);
    _nextQuestion();
  }

  // ── Test Mode Actions ─────────────────────────────────────────────────────

  void _selectOption(int index) {
    if (_answered) return;
    HapticFeedback.mediumImpact();

    final question = _questions[_currentIndex];
    final options = question['options'] as List? ?? [];
    final correctAnswer = question['correct_answer'] as String? ?? '';

    setState(() {
      _selectedOption = index;
      _answered = true;
      if (index < options.length && options[index].toString() == correctAnswer) {
        _correctCount++;
      }
    });

    // Auto-advance after feedback delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _answered) _nextQuestion();
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _finishQuiz();
      return;
    }
    setState(() {
      _currentIndex++;
      _showAnswer = false;
      _selectedOption = null;
      _answered = false;
    });
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    final points = _correctCount * _pointsPerCorrect;
    setState(() {
      _quizComplete = true;
      _pointsEarned = points;
    });

    // Submit attempt to backend
    try {
      await _api.post(
        '/quiz-attempts',
        body: {
          'quiz_id': _quizId,
          'mode': widget.mode,
          'score': ((_correctCount / _questions.length) * 100).round(),
          'total_questions': _questions.length,
          'correct_count': _correctCount,
          'time_taken_seconds': _totalSeconds - _secondsRemaining,
          'points_earned': points,
        },
        parser: (data) => data,
      );
    } catch (_) {
      // Silent fail — points will be awarded by DB trigger
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined, size: 48,
                    color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary),
                const SizedBox(height: 16),
                Text('No questions available', style: FblaFonts.heading(fontSize: 16)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_quizComplete) return _buildResults(isDark);

    return Scaffold(
      backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            if (!_isPractice) _buildTimer(isDark),
            _buildProgressBar(isDark),
            Expanded(
              child: _isPractice
                  ? _buildFlashcard(isDark)
                  : _buildTestQuestion(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close quiz',
            icon: Icon(Icons.close_rounded,
                color: isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _title,
                style: FblaFonts.heading(fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(
            '${_currentIndex + 1}/${_questions.length}',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTimer(bool isDark) {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final isLow = _secondsRemaining < 30;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: isLow ? FblaColors.error : (isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isLow ? FblaColors.error : (isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: isDark ? FblaColors.darkSurfaceHigh : FblaColors.surfaceVariant,
          color: FblaColors.primary,
          minHeight: 3,
        ),
      ),
    );
  }

  // ── Flashcard Mode ────────────────────────────────────────────────────────

  Widget _buildFlashcard(bool isDark) {
    final question = _questions[_currentIndex];
    final questionText = question['question_text'] as String? ?? '';
    final answer = question['correct_answer'] as String? ?? '';
    final explanation = question['explanation'] as String?;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedSwitcher(
                duration: FblaMotion.fast,
                child: Container(
                  key: ValueKey(_showAnswer),
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? FblaColors.darkSurface : FblaColors.surface,
                    borderRadius: BorderRadius.circular(FblaRadius.xl),
                    border: Border.all(
                      color: _showAnswer
                          ? FblaColors.primary.withOpacity(0.3)
                          : (isDark ? FblaColors.darkOutline : FblaColors.outline),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAnswer ? 'ANSWER' : 'QUESTION',
                        style: FblaFonts.label().copyWith(
                          letterSpacing: 1.5,
                          color: _showAnswer
                              ? FblaColors.primary
                              : (isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _showAnswer ? answer : questionText,
                        style: FblaFonts.heading().copyWith(
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_showAnswer && explanation != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          explanation,
                          style: FblaFonts.body(fontSize: 12).copyWith(
                            color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (!_showAnswer)
                        Text(
                          'Tap to reveal',
                          style: FblaFonts.body(fontSize: 12).copyWith(
                            color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Grade buttons (only when answer is shown)
          if (_showAnswer)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markIncorrect,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Missed it'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FblaColors.error,
                      side: BorderSide(color: FblaColors.error.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _markCorrect,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Got it!'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FblaColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 200.ms).moveY(begin: 8, end: 0, duration: 200.ms),
        ],
      ),
    );
  }

  // ── Test Mode ─────────────────────────────────────────────────────────────

  Widget _buildTestQuestion(bool isDark) {
    final question = _questions[_currentIndex];
    final questionText = question['question_text'] as String? ?? '';
    final options = (question['options'] as List?)?.cast<String>() ?? [];
    final correctAnswer = question['correct_answer'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            questionText,
            style: FblaFonts.heading(fontSize: 16).copyWith(
              height: 1.4,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 28),

          ...List.generate(options.length, (i) {
            final option = options[i];
            final isSelected = _selectedOption == i;
            final isCorrect = option == correctAnswer;
            final showResult = _answered;

            Color? bgColor;
            Color? borderColor;
            if (showResult && isCorrect) {
              bgColor = FblaColors.success.withOpacity(0.12);
              borderColor = FblaColors.success;
            } else if (showResult && isSelected && !isCorrect) {
              bgColor = FblaColors.error.withOpacity(0.12);
              borderColor = FblaColors.error;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bgColor ?? (isDark ? FblaColors.darkSurface : FblaColors.surface),
                borderRadius: BorderRadius.circular(FblaRadius.md),
                child: InkWell(
                  onTap: _answered ? null : () => _selectOption(i),
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(
                        color: borderColor ??
                            (isSelected
                                ? FblaColors.primary
                                : (isDark ? FblaColors.darkOutline : FblaColors.outline)),
                        width: isSelected && !showResult ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Letter badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected && !showResult
                                ? FblaColors.primary
                                : (isDark ? FblaColors.darkSurfaceHigh : FblaColors.surfaceVariant),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + i), // A, B, C, D
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected && !showResult
                                    ? Colors.white
                                    : (isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option,
                            style: FblaFonts.body(),
                          ),
                        ),
                        if (showResult && isCorrect)
                          const Icon(Icons.check_circle_rounded,
                              size: 20, color: FblaColors.success),
                        if (showResult && isSelected && !isCorrect)
                          const Icon(Icons.cancel_rounded,
                              size: 20, color: FblaColors.error),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Results Screen ────────────────────────────────────────────────────────

  Widget _buildResults(bool isDark) {
    final percentage = (_correctCount / _questions.length * 100).round();
    final isPassing = percentage >= 70;

    return Scaffold(
      backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Score circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isPassing ? FblaColors.success : FblaColors.error)
                      .withOpacity(0.12),
                  border: Border.all(
                    color: isPassing ? FblaColors.success : FblaColors.error,
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: isPassing ? FblaColors.success : FblaColors.error,
                      ),
                    ),
                    Text(
                      '$_correctCount/${_questions.length}',
                      style: FblaFonts.body(fontSize: 12).copyWith(
                        color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .scale(begin: const Offset(0.9, 0.9), duration: FblaMotion.standard, curve: FblaMotion.strongEaseOut)
                  .fadeIn(duration: FblaMotion.standard),

              const SizedBox(height: 28),

              Text(
                isPassing ? 'Great work!' : 'Keep practicing!',
                style: FblaFonts.display(),
              ).animate(delay: 100.ms).fadeIn(duration: 200.ms),

              const SizedBox(height: 8),

              Text(
                _isPractice
                    ? 'You got $_correctCount out of ${_questions.length} correct'
                    : 'You earned $_pointsEarned points!',
                style: FblaFonts.body().copyWith(
                  color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 200.ms),

              if (!_isPractice && _pointsEarned > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: FblaColors.secondary.withOpacity(0.15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, size: 18, color: FblaColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        '+$_pointsEarned points',
                        style: TextStyle(
                          fontFamily: 'Josefin Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FblaColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 200.ms).scale(
                    begin: const Offset(0.9, 0.9), duration: 200.ms, curve: FblaMotion.strongEaseOut),
              ],

              const Spacer(),

              // Actions
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Reset and retry
                    setState(() {
                      _currentIndex = 0;
                      _correctCount = 0;
                      _showAnswer = false;
                      _selectedOption = null;
                      _answered = false;
                      _quizComplete = false;
                      _pointsEarned = 0;
                      if (!_isPractice) {
                        _secondsRemaining = _totalSeconds;
                        _startTimer();
                      }
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: FblaColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: FblaFonts.body().copyWith(
                    color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
