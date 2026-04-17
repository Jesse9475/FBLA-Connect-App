import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'celebration_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Create Event Screen — advisors/admins create chapter events with:
//   • Title, body, date/time pickers
//   • Google Places Autocomplete for location search
//   • Place photo as card background
//   • Registration deadline (optional)
//
// Location search uses Google Places Autocomplete API. When a place is
// selected, its photo reference is fetched and used as the event card
// background image via the Places Photos API.
// ─────────────────────────────────────────────────────────────────────────────

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _api = ApiService.instance;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  DateTime? _regDeadline;

  // Customization
  String? _category;
  String _accentColor = '#1A73E8'; // default FBLA blue
  int? _capacity;
  final _capacityCtrl = TextEditingController();
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  static const List<_EventCategory> _categories = [
    _EventCategory('Workshop',     Icons.build_rounded,           '#1A73E8'),
    _EventCategory('Conference',   Icons.groups_2_rounded,        '#7B1FA2'),
    _EventCategory('Competition',  Icons.emoji_events_rounded,    '#E65100'),
    _EventCategory('Fundraiser',   Icons.volunteer_activism,      '#C62828'),
    _EventCategory('Meeting',      Icons.how_to_vote_rounded,     '#00796B'),
    _EventCategory('Social',       Icons.celebration_rounded,     '#D81B60'),
    _EventCategory('Study Session',Icons.menu_book_rounded,       '#2E7D32'),
    _EventCategory('Volunteering', Icons.diversity_3_rounded,     '#5D4037'),
  ];

  static const List<String> _accentPalette = [
    '#1A73E8', '#7B1FA2', '#E65100', '#C62828',
    '#00796B', '#D81B60', '#2E7D32', '#5D4037',
  ];

  // Google Places
  List<Map<String, dynamic>> _placePredictions = [];
  String? _selectedPlaceId;
  String? _locationImageUrl;
  bool _searchingPlaces = false;
  Timer? _debounce;

  bool _submitting = false;

  // Google Places API key — set via --dart-define or hardcode for dev
  static const _placesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _locationCtrl.dispose();
    _capacityCtrl.dispose();
    _tagCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _addTag(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    if (t.isEmpty || _tags.contains(t) || _tags.length >= 10) {
      _tagCtrl.clear();
      return;
    }
    setState(() {
      _tags.add(t);
      _tagCtrl.clear();
    });
    HapticFeedback.selectionClick();
  }

  // ── Google Places Autocomplete ────────────────────────────────────────────

  void _onLocationChanged(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() => _placePredictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (_placesApiKey.isEmpty) return;
    setState(() => _searchingPlaces = true);

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'types': 'establishment|geocode',
          'key': _placesApiKey,
        },
      );
      final predictions =
          (response.data['predictions'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _placePredictions = predictions.take(5).toList();
          _searchingPlaces = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searchingPlaces = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'] as String;
    final description = prediction['description'] as String? ?? '';

    setState(() {
      _locationCtrl.text = description;
      _selectedPlaceId = placeId;
      _placePredictions = [];
    });

    HapticFeedback.selectionClick();

    // Fetch place details for photo
    if (_placesApiKey.isEmpty) return;
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'photos',
          'key': _placesApiKey,
        },
      );
      final photos =
          (response.data['result']?['photos'] as List?) ?? [];
      if (photos.isNotEmpty) {
        final photoRef = photos[0]['photo_reference'] as String;
        final photoUrl =
            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$_placesApiKey';
        if (mounted) setState(() => _locationImageUrl = photoUrl);
      }
    } catch (_) {}
  }

  // ── Date/Time Pickers ────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 15, minute: 0),
    );
    if (time != null) {
      setState(() => _startTime = time);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _endDate = date);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (time != null) {
      setState(() => _endTime = time);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickRegDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _regDeadline ?? _startDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _regDeadline = date);
      HapticFeedback.selectionClick();
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty &&
      _startDate != null &&
      _startTime != null &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();

    final startDt = DateTime(
      _startDate!.year, _startDate!.month, _startDate!.day,
      _startTime!.hour, _startTime!.minute,
    );

    DateTime? endDt;
    if (_endDate != null && _endTime != null) {
      endDt = DateTime(
        _endDate!.year, _endDate!.month, _endDate!.day,
        _endTime!.hour, _endTime!.minute,
      );
    }

    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'start_at': startDt.toUtc().toIso8601String(),
        'location': _locationCtrl.text.trim(),
      };
      if (endDt != null) body['end_at'] = endDt.toUtc().toIso8601String();
      if (_locationImageUrl != null) body['location_image_url'] = _locationImageUrl;
      if (_selectedPlaceId != null) body['place_id'] = _selectedPlaceId;
      if (_regDeadline != null) {
        body['registration_deadline'] = _regDeadline!.toUtc().toIso8601String();
      }
      if (_category != null)       body['category']     = _category;
      body['accent_color'] = _accentColor;
      if (_capacity != null)       body['capacity']     = _capacity;
      if (_tags.isNotEmpty)        body['tags']         = _tags;

      final result = await _api.post<Map<String, dynamic>>(
        '/events',
        body: body,
        parser: (data) => (data as Map<String, dynamic>?) ?? {},
      );
      final createdEvent = (result['event'] as Map<String, dynamic>?) ?? body;
      final eventId = createdEvent['id'] as String? ?? '';

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CelebrationScreen(
              contentType: 'event',
              contentId: eventId,
              content: createdEvent,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cancel and close',
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'New Event',
                    style: FblaFonts.heading(fontSize: 16),
                  ),
                  const Spacer(),
                  _PublishButton(
                    canSubmit: _canSubmit,
                    submitting: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Form ──────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  // Location image preview
                  if (_locationImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      child: Image.network(
                        _locationImageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel: 'Map preview of event location',
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
                        .scaleXY(begin: 0.98, end: 1.0, duration: 200.ms),

                  if (_locationImageUrl != null) const SizedBox(height: 20),

                  // Title
                  Semantics(
                    label: 'Event title',
                    textField: true,
                    child: TextField(
                      controller: _titleCtrl,
                      style: FblaFonts.heading(),
                      maxLength: 200,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Event title',
                        hintStyle: FblaFonts.heading().copyWith(
                          color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Location with autocomplete
                  _SectionLabel(label: 'Location'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locationCtrl,
                    style: FblaFonts.body(),
                    onChanged: _onLocationChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      hintStyle: FblaFonts.body().copyWith(
                        color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: isDark ? FblaColors.darkSurface : FblaColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),

                  // Place predictions dropdown
                  if (_placePredictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: isDark ? FblaColors.darkSurface : FblaColors.surface,
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        border: Border.all(
                          color: isDark ? FblaColors.darkOutline : FblaColors.outline,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _placePredictions.map((p) {
                          final desc = p['description'] as String? ?? '';
                          final structured = p['structured_formatting'] as Map<String, dynamic>? ?? {};
                          final mainText = structured['main_text'] as String? ?? desc;
                          final secondaryText = structured['secondary_text'] as String? ?? '';
                          return InkWell(
                            onTap: () => _selectPlace(p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                    color: FblaColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mainText,
                                          style: FblaFonts.body().copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (secondaryText.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            secondaryText,
                                            style: FblaFonts.body(fontSize: 12).copyWith(
                                              color: isDark
                                                  ? FblaColors.darkTextTertiary
                                                  : FblaColors.textTertiary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 120.ms)
                        .moveY(begin: -4, end: 0, duration: 120.ms),

                  if (_searchingPlaces)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FblaColors.primary,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Start date/time
                  _SectionLabel(label: 'Start'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeChip(
                          icon: Icons.calendar_today_rounded,
                          label: _startDate != null
                              ? dateFmt.format(_startDate!)
                              : 'Date',
                          isSet: _startDate != null,
                          onTap: _pickStartDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateTimeChip(
                          icon: Icons.access_time_rounded,
                          label: _startTime != null
                              ? _startTime!.format(context)
                              : 'Time',
                          isSet: _startTime != null,
                          onTap: _pickStartTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // End date/time
                  _SectionLabel(label: 'End (optional)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeChip(
                          icon: Icons.calendar_today_rounded,
                          label: _endDate != null
                              ? dateFmt.format(_endDate!)
                              : 'Date',
                          isSet: _endDate != null,
                          onTap: _pickEndDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateTimeChip(
                          icon: Icons.access_time_rounded,
                          label: _endTime != null
                              ? _endTime!.format(context)
                              : 'Time',
                          isSet: _endTime != null,
                          onTap: _pickEndTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Registration deadline
                  _SectionLabel(label: 'Registration deadline (optional)'),
                  const SizedBox(height: 8),
                  _DateTimeChip(
                    icon: Icons.event_available_rounded,
                    label: _regDeadline != null
                        ? dateFmt.format(_regDeadline!)
                        : 'Set deadline',
                    isSet: _regDeadline != null,
                    onTap: _pickRegDeadline,
                  ),

                  const SizedBox(height: 24),

                  // Category picker
                  _SectionLabel(label: 'Category'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final selected = _category == cat.label;
                        return _CategoryChip(
                          label: cat.label,
                          icon: cat.icon,
                          selected: selected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _category = selected ? null : cat.label;
                              if (_category != null) _accentColor = cat.color;
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Accent color
                  _SectionLabel(label: 'Accent Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _accentPalette.map((hex) {
                      return _ColorSwatch(
                        hex: hex,
                        selected: _accentColor == hex,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _accentColor = hex);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Capacity
                  _SectionLabel(label: 'Capacity (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _capacityCtrl,
                    style: FblaFonts.body(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      setState(() {
                        final n = int.tryParse(v);
                        _capacity = (n != null && n > 0) ? n : null;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. 40',
                      hintStyle: FblaFonts.body().copyWith(
                        color: isDark
                            ? FblaColors.darkTextTertiary
                            : FblaColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.people_outline_rounded,
                        size: 20,
                        color: isDark
                            ? FblaColors.darkTextTertiary
                            : FblaColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? FblaColors.darkSurface
                          : FblaColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tags
                  _SectionLabel(label: 'Tags (optional — up to 10)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tagCtrl,
                    style: FblaFonts.body(),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _addTag,
                    decoration: InputDecoration(
                      hintText: 'Add a tag and press enter',
                      hintStyle: FblaFonts.body().copyWith(
                        color: isDark
                            ? FblaColors.darkTextTertiary
                            : FblaColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.tag_rounded,
                        size: 20,
                        color: isDark
                            ? FblaColors.darkTextTertiary
                            : FblaColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? FblaColors.darkSurface
                          : FblaColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (_tags.isNotEmpty) const SizedBox(height: 8),
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags
                          .map((t) => InputChip(
                                label: Text('#$t',
                                    style: FblaFonts.body(fontSize: 12)),
                                onDeleted: () => setState(() => _tags.remove(t)),
                                backgroundColor: isDark
                                    ? FblaColors.darkSurface
                                    : FblaColors.surfaceVariant,
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 24),

                  // Description
                  _SectionLabel(label: 'Description'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    style: FblaFonts.body(),
                    maxLength: 4000,
                    maxLines: 6,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Event details, agenda, what to bring...',
                      hintStyle: FblaFonts.body().copyWith(
                        color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: isDark ? FblaColors.darkSurface : FblaColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      counterText: '',
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

// ── Publish Button ─────────────────────────────────────────────────────────

class _PublishButton extends StatelessWidget {
  const _PublishButton({
    required this.canSubmit,
    required this.submitting,
    required this.onPressed,
  });

  final bool canSubmit;
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: FblaMotion.fast,
      curve: FblaMotion.strongEaseOut,
      child: TextButton(
        onPressed: canSubmit ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: canSubmit ? FblaColors.secondary : Colors.transparent,
          foregroundColor: canSubmit ? Colors.white : FblaColors.textTertiary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Publish',
                style: FblaFonts.label().copyWith(
                  color: canSubmit ? Colors.white : FblaColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label.toUpperCase(),
      style: FblaFonts.label().copyWith(
        fontSize: 11,
        letterSpacing: 0.8,
        color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ── Event Category record ──────────────────────────────────────────────────

class _EventCategory {
  const _EventCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final String color;
}

// ── Category Chip ──────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? FblaColors.primary
          : (isDark ? FblaColors.darkSurface : FblaColors.surfaceVariant),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : (isDark
                        ? FblaColors.darkTextSecond
                        : FblaColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: FblaFonts.body(fontSize: 12).copyWith(
                  color: selected
                      ? Colors.white
                      : (isDark
                          ? FblaColors.darkTextPrimary
                          : FblaColors.textPrimary),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Color Swatch ───────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  static Color _hexToColor(String h) {
    final s = h.replaceAll('#', '');
    return Color(int.parse('0xFF$s'));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(hex);
    return Semantics(
      label: 'Accent color $hex',
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded,
                  size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

// ── Date/Time Chip ─────────────────────────────────────────────────────────

class _DateTimeChip extends StatelessWidget {
  const _DateTimeChip({
    required this.icon,
    required this.label,
    required this.isSet,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? FblaColors.darkSurface : FblaColors.surfaceVariant,
      borderRadius: BorderRadius.circular(FblaRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FblaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSet
                    ? FblaColors.primary
                    : (isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: FblaFonts.body(fontSize: 12).copyWith(
                  color: isSet
                      ? (isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary)
                      : (isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary),
                  fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
