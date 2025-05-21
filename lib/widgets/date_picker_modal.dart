import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class DatePickerModal extends StatelessWidget {
  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;
  final void Function(DateTime date) onSelected;
  const DatePickerModal(
      {Key? key,
      required this.initialDate,
      required this.minDate,
      required this.maxDate,
      required this.onSelected})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
    DateTime? tempDate = initialDate;
    final localizations = AppLocalizations.of(context);
    return StatefulBuilder(
      builder: (context, setModalState) {
        void goToPrevMonth() {
          setModalState(() {
            displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
          });
        }

        void goToNextMonth() {
          setModalState(() {
            displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
          });
        }

        int daysInMonth(DateTime date) {
          return DateTime(date.year, date.month + 1, 0).day;
        }

        int firstWeekdayOfMonth(DateTime date) {
          return DateTime(date.year, date.month, 1).weekday;
        }

        Future<void> selectMonth() async {
          final months = [
            localizations.translate('profile.birthday.months.january'),
            localizations.translate('profile.birthday.months.february'),
            localizations.translate('profile.birthday.months.march'),
            localizations.translate('profile.birthday.months.april'),
            localizations.translate('profile.birthday.months.may'),
            localizations.translate('profile.birthday.months.june'),
            localizations.translate('profile.birthday.months.july'),
            localizations.translate('profile.birthday.months.august'),
            localizations.translate('profile.birthday.months.september'),
            localizations.translate('profile.birthday.months.october'),
            localizations.translate('profile.birthday.months.november'),
            localizations.translate('profile.birthday.months.december'),
          ];
          int initialIndex = displayMonth.month - 1;
          int? selected = await showModalBottomSheet<int>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (context) {
              int tempIndex = initialIndex >= 0 ? initialIndex : 0;
              return SizedBox(
                height: 300,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      localizations.translate('profile.birthday.select_month'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 44,
                        diameterRatio: 1.2,
                        perspective: 0.003,
                        physics: const FixedExtentScrollPhysics(),
                        controller:
                            FixedExtentScrollController(initialItem: tempIndex),
                        onSelectedItemChanged: (i) {
                          tempIndex = i;
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, i) {
                            if (i < 0 || i >= months.length) return null;
                            return Center(
                              child: Text(months[i],
                                  style: const TextStyle(fontSize: 20)),
                            );
                          },
                          childCount: months.length,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onboardingNextButtonColor,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onboardingNextButtonBorderColor,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(tempIndex + 1);
                          },
                          child: Text(
                            localizations.translate('common.select'),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          if (selected != null) {
            setModalState(() {
              displayMonth = DateTime(displayMonth.year, selected);
            });
          }
        }

        Future<void> selectYear() async {
          int minYear = minDate.year;
          int maxYear = maxDate.year;
          List<int> years = [for (int y = maxYear; y >= minYear; y--) y];
          int initialIndex = years.indexOf(displayMonth.year);
          int? selected = await showModalBottomSheet<int>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (context) {
              int tempIndex = initialIndex >= 0 ? initialIndex : 0;
              return SizedBox(
                height: 300,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      localizations.translate('profile.birthday.select_year'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 44,
                        diameterRatio: 1.2,
                        perspective: 0.003,
                        physics: const FixedExtentScrollPhysics(),
                        controller:
                            FixedExtentScrollController(initialItem: tempIndex),
                        onSelectedItemChanged: (i) {
                          tempIndex = i;
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, i) {
                            if (i < 0 || i >= years.length) return null;
                            return Center(
                              child: Text(years[i].toString(),
                                  style: const TextStyle(fontSize: 20)),
                            );
                          },
                          childCount: years.length,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onboardingNextButtonColor,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onboardingNextButtonBorderColor,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(years[tempIndex]);
                          },
                          child: Text(
                            localizations.translate('common.select'),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          if (selected != null) {
            setModalState(() {
              displayMonth = DateTime(selected, displayMonth.month);
            });
          }
        }

        String _monthName(int month) {
          final months = [
            '',
            localizations.translate('profile.birthday.months.january'),
            localizations.translate('profile.birthday.months.february'),
            localizations.translate('profile.birthday.months.march'),
            localizations.translate('profile.birthday.months.april'),
            localizations.translate('profile.birthday.months.may'),
            localizations.translate('profile.birthday.months.june'),
            localizations.translate('profile.birthday.months.july'),
            localizations.translate('profile.birthday.months.august'),
            localizations.translate('profile.birthday.months.september'),
            localizations.translate('profile.birthday.months.october'),
            localizations.translate('profile.birthday.months.november'),
            localizations.translate('profile.birthday.months.december'),
          ];
          return months[month];
        }

        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  localizations.translate('profile.birthday.title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: goToPrevMonth,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    GestureDetector(
                      onTap: selectMonth,
                      child: Text(
                        _monthName(displayMonth.month),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: selectYear,
                      child: Text(
                        displayMonth.year.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: goToNextMonth,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final weekdays = ['P', 'P', 'S', 'Ç', 'P', 'C', 'C'];
                    return Center(
                      child: Text(
                        weekdays[index],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: 42,
                  itemBuilder: (context, index) {
                    final firstWeekday = firstWeekdayOfMonth(displayMonth);
                    final daysInCurrentMonth = daysInMonth(displayMonth);
                    final day = index - firstWeekday + 1;
                    final isCurrentMonth = day > 0 && day <= daysInCurrentMonth;
                    final isSelected = isCurrentMonth &&
                        day == tempDate?.day &&
                        displayMonth.month == tempDate?.month &&
                        displayMonth.year == tempDate?.year;
                    final isToday = isCurrentMonth &&
                        day == now.day &&
                        displayMonth.month == now.month &&
                        displayMonth.year == now.year;

                    return GestureDetector(
                      onTap: isCurrentMonth
                          ? () {
                              setModalState(() {
                                tempDate = DateTime(
                                    displayMonth.year, displayMonth.month, day);
                              });
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onboardingNextButtonColor
                              : isToday
                                  ? Colors.grey[200]
                                  : null,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            isCurrentMonth ? day.toString() : '',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? Colors.black
                                      : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onboardingNextButtonColor,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onboardingNextButtonBorderColor,
                    ),
                    onPressed: tempDate != null
                        ? () {
                            onSelected(tempDate!);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: Text(
                      localizations.translate('common.save'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
