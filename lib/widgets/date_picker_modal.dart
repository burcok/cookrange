import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
            'Ocak',
            'Şubat',
            'Mart',
            'Nisan',
            'Mayıs',
            'Haziran',
            'Temmuz',
            'Ağustos',
            'Eylül',
            'Ekim',
            'Kasım',
            'Aralık',
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
                    const Text('Ay Seç',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
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
                          child: const Text(
                            'Seç',
                            style: TextStyle(
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
                    const Text('Yıl Seç',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
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
                          child: const Text(
                            'Seç',
                            style: TextStyle(
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
          const months = [
            '',
            'Ocak',
            'Şubat',
            'Mart',
            'Nisan',
            'Mayıs',
            'Haziran',
            'Temmuz',
            'Ağustos',
            'Eylül',
            'Ekim',
            'Kasım',
            'Aralık',
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
                const Text('Doğum Tarihini Seç',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: goToPrevMonth),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: selectMonth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(_monthName(displayMonth.month),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline)),
                          ),
                        ),
                        GestureDetector(
                          onTap: selectYear,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(displayMonth.year.toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline)),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: goToNextMonth),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Pzt'),
                    Text('Sal'),
                    Text('Çar'),
                    Text('Per'),
                    Text('Cum'),
                    Text('Cmt'),
                    Text('Paz'),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: daysInMonth(displayMonth) +
                      firstWeekdayOfMonth(displayMonth) -
                      1,
                  itemBuilder: (context, index) {
                    int firstDayOffset = firstWeekdayOfMonth(displayMonth) - 1;
                    if (index < firstDayOffset) {
                      return const SizedBox();
                    }
                    int day = index - firstDayOffset + 1;
                    DateTime thisDay =
                        DateTime(displayMonth.year, displayMonth.month, day);
                    bool isSelected = tempDate != null &&
                        tempDate!.year == thisDay.year &&
                        tempDate!.month == thisDay.month &&
                        tempDate!.day == thisDay.day;
                    bool isFuture = thisDay.isAfter(now);
                    return GestureDetector(
                      onTap: isFuture
                          ? null
                          : () {
                              setModalState(() {
                                tempDate = thisDay;
                              });
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onboardingNextButtonColor
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: isFuture
                                ? Colors.grey
                                : isSelected
                                    ? Colors.white
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: tempDate != null
                        ? () {
                            onSelected(tempDate!);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text(
                      'Seç',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
