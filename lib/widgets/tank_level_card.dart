import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class TankLevelCard extends StatelessWidget {
  final TankModel tank;
  final VoidCallback? onMeasureTap;

  const TankLevelCard({
    super.key,
    required this.tank,
    this.onMeasureTap,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'en_US');
    final isBenzin = tank.fuelType == 'بنزين';
    final fuelColor = isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;
    final hasCapacity = tank.hasCapacity;
    final percentage = tank.fillPercentage;
    final isOverfilled = hasCapacity && tank.currentDipLiters > tank.capacityLiters;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: fuelColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_gas_station_rounded,
                        color: fuelColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tank.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'نوع الوقود: ${tank.fuelType}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!hasCapacity)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'لم تُحدَّد السعة بعد',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isOverfilled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.dangerRed),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}% (تجاوز السعة!)',
                      style: const TextStyle(
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: fuelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: fuelColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Bar representing tank level
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: LinearProgressIndicator(
                  value: hasCapacity ? (percentage / 100).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverfilled ? AppTheme.dangerRed : fuelColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  'المخزون الحالي (المسطرة)',
                  '${numberFormat.format(tank.currentDipLiters)} لتر',
                  Colors.black87,
                ),
                _buildInfoItem(
                  'السعة الكلية للخزان',
                  hasCapacity ? '${numberFormat.format(tank.capacityLiters)} لتر' : 'لم تُحدَّد بعد',
                  hasCapacity ? Colors.grey.shade700 : Colors.amber.shade900,
                ),
                _buildInfoItem(
                  'المتبقي للامتلاء',
                  hasCapacity
                      ? '${numberFormat.format((tank.capacityLiters - tank.currentDipLiters).clamp(0, double.infinity))} لتر'
                      : 'لم تُحدَّد بعد',
                  hasCapacity ? Colors.grey.shade700 : Colors.grey.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
