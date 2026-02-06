class ProfileCompletionResult {
  final bool isComplete;
  final List<String> missingFields;

  const ProfileCompletionResult({
    required this.isComplete,
    required this.missingFields,
  });
}

ProfileCompletionResult checkProfileCompletion(
  Map<String, dynamic>? metadata,
) {
  if (metadata == null) {
    return const ProfileCompletionResult(
      isComplete: false,
      missingFields: ['username', 'age', 'gender', 'city'],
    );
  }

  final missing = <String>[];

  final username = (metadata['username'] ?? '').toString().trim();
  if (username.isEmpty) missing.add('username');

  final ageRaw = metadata['age'];
  final age = ageRaw is int
      ? ageRaw
      : ageRaw is num
          ? ageRaw.toInt()
          : int.tryParse(ageRaw?.toString() ?? '');
  if (age == null || age < 13 || age > 120) missing.add('age');

  final genderRaw = (metadata['gender'] ?? '').toString().trim().toLowerCase();
  if (genderRaw != 'male' && genderRaw != 'female') missing.add('gender');

  final city = (metadata['city'] ?? '').toString().trim();
  if (city.isEmpty) missing.add('city');

  return ProfileCompletionResult(
    isComplete: missing.isEmpty,
    missingFields: missing,
  );
}
