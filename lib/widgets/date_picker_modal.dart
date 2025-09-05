import 'package:cookrange/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import 'package:intl/intl.dart';
import 'package:cookrange/core/localization/app_localizations.dart';

class DatePickerModal extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;
  final void Function(DateTime date) onSelected;

  const DatePickerModal({
    super.key,
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
    required this.onSelected,
  });

  @override
  State<DatePickerModal> createState() => _DatePickerModalState();
}

class _DatePickerModalState extends State<DatePickerModal> {
  late DateTime _selectedDate;
  late DateTime _displayMonth;
  late final ScrollController _yearScrollController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _yearScrollController = ScrollController(
      initialScrollOffset:
          (widget.initialDate.year - widget.minDate.year) * 52.0,
    );
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  void _changeYear(int year) {
    setState(() {
      _displayMonth = DateTime(year, _displayMonth.month);
    });
  }

  void _previousMonth() {
    if (_displayMonth.year == widget.minDate.year &&
        _displayMonth.month == widget.minDate.month) {
      return;
    }
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _nextMonth() {
    if (_displayMonth.year == widget.maxDate.year &&
        _displayMonth.month == widget.maxDate.month) {
      return;
    }
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    if (date.isBefore(widget.minDate) || date.isAfter(widget.maxDate)) {
      return;
    }
    setState(() {
      _selectedDate = date;
    });
  }

  int _calculateInitialEmptyDays(int weekdayOfFirstDay, int firstDayOfWeek) {
    if (firstDayOfWeek == DateTime.monday) {
      return weekdayOfFirstDay - 1;
    } else {
      return weekdayOfFirstDay % 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final weekdayFormatter = DateFormat.E(localizations.locale.toLanguageTag());

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.backgroundColor2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, localizations, theme),
              const SizedBox(height: 16),
              _buildWeekdays(context, weekdayFormatter),
              const SizedBox(height: 8),
              _buildCalendar(context, weekdayFormatter),
              const SizedBox(height: 24),
              _buildSaveButton(context, localizations),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        GestureDetector(
          onTap: () => _showYearPicker(context),
          child: Text(
            DateFormat.yMMMM(localizations.locale.toLanguageTag())
                .format(_displayMonth),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  void _showYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        final years = List.generate(
            widget.maxDate.year - widget.minDate.year + 1,
            (index) => widget.minDate.year + index);
        return SizedBox(
          height: 300,
          child: ListWheelScrollView.useDelegate(
            controller: FixedExtentScrollController(
                initialItem: years.indexOf(_displayMonth.year)),
            itemExtent: 50,
            onSelectedItemChanged: (index) {
              _changeYear(years[index]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                return Center(
                  child: Text(
                    years[index].toString(),
                    style: const TextStyle(fontSize: 22),
                  ),
                );
              },
              childCount: years.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekdays(BuildContext context, DateFormat formatter) {
    final List<String> weekdays =
        formatter.dateSymbols.SHORTWEEKDAYS.map((e) => e[0]).toList();

    // Adjust for locale's first day of week
    final int firstDayOfWeek = formatter.dateSymbols.FIRSTDAYOFWEEK;
    final List<String> orderedWeekdays =
        List.from(weekdays.sublist(firstDayOfWeek))
          ..addAll(weekdays.sublist(0, firstDayOfWeek));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: orderedWeekdays
          .map((day) => Text(day,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))
          .toList(),
    );
  }

  Widget _buildCalendar(BuildContext context, DateFormat formatter) {
    final theme = Theme.of(context);
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_displayMonth.year, _displayMonth.month, 1);
    final weekdayOfFirstDay = firstDayOfMonth.weekday;

    final int firstDayOfWeek = formatter.dateSymbols.FIRSTDAYOFWEEK;

    final initialEmptyDays =
        _calculateInitialEmptyDays(weekdayOfFirstDay, firstDayOfWeek);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: daysInMonth + initialEmptyDays,
      itemBuilder: (context, index) {
        if (index < initialEmptyDays) {
          return const SizedBox.shrink();
        }
        final day = index - initialEmptyDays + 1;
        final date = DateTime(_displayMonth.year, _displayMonth.month, day);
        final bool isSelected = date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;

        final isEnabled =
            !date.isBefore(widget.minDate) && !date.isAfter(widget.maxDate);

        return GestureDetector(
          onTap: isEnabled ? () => _selectDate(date) : null,
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isEnabled
                          ? theme.colorScheme.onboardingSubtitleColor
                          : Colors.grey,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton(
      BuildContext context, AppLocalizations localizations) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          widget.onSelected(_selectedDate);
          Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(localizations.translate('common.save')),
      ),
    );
  }
}
