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
    final borderColor = colorFor(idol.color);
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      idol.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      onPressed: onAddRecord,
                      icon: Icon(
                        Icons.add_circle,
                        color: isLight ? Colors.grey[700] : borderColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${idol.totalCount} 切',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              Text(
                '¥${idol.totalAmount}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
