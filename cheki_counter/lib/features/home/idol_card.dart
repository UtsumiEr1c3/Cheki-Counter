import 'package:flutter/material.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/shared/colors.dart';

class IdolCard extends StatelessWidget {
  final Idol idol;
  final VoidCallback onTap;
  final VoidCallback onAddRecord;

  const IdolCard({
    super.key,
    required this.idol,
    required this.onTap,
    required this.onAddRecord,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = colorFromValue(idol.colorValue);
    final isLight = borderColor.computeLuminance() > 0.7;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Tooltip(
                    message: idol.name,
                    child: Text(
                      idol.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${idol.totalCount} 切',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥${idol.totalAmount}',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '添加记录',
                    onPressed: onAddRecord,
                    icon: Icon(
                      Icons.add_circle,
                      color: isLight ? Colors.grey[700] : borderColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
