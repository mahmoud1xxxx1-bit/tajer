import 'package:flutter/material.dart';
import '../../subscriptions/presentation/paywall_screen.dart';

/// Legacy route kept for backward compatibility.
/// All subscription entry points must use the real RevenueCat-backed paywall.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) => const PaywallScreen();
}
