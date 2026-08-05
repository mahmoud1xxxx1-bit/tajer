import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // Initial state
  }

  Future<void> signInAnonymously() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInAnonymously();
    });
  }

  Future<void> linkWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInOrLinkWithGoogle();
      state = AsyncValue.data(repo.currentUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
