import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Temporary UX intent used when an operation sends the user to create a
/// missing category. It is not persisted and never affects accounting data.
final notebookPendingCategoryTypeProvider = StateProvider<String?>((ref) => null);
