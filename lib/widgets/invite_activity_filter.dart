import 'package:flutter/material.dart';

class InviteActivityFilter extends StatelessWidget {
  final bool isSv;
  final String value;
  final ValueChanged<String?> onChanged;

  const InviteActivityFilter({
    super.key,
    required this.isSv,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
        ),
      ),
      dropdownColor: const Color(0xFF10201E),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      items: [
        DropdownMenuItem(
          value: 'all',
          child: Text(
            isSv ? 'Alla' : 'All',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DropdownMenuItem(
          value: 'walk',
          child: Text(
            isSv ? 'Promenad' : 'Walk',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DropdownMenuItem(
          value: 'workout',
          child: Text(
            isSv ? 'Träna' : 'Workout',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const DropdownMenuItem(
          value: 'coffee',
          child: Text(
            'Fika',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DropdownMenuItem(
          value: 'lunch',
          child: Text(
            isSv ? 'Luncha' : 'Lunch',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DropdownMenuItem(
          value: 'dinner',
          child: Text(
            isSv ? 'Middag' : 'Dinner',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
