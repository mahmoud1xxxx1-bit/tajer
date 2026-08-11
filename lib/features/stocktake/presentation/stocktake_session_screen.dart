import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/raw_material_repository.dart';
import '../data/stocktake_repository.dart';
import '../domain/stocktake.dart';

class StocktakeSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const StocktakeSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<StocktakeSessionScreen> createState() => _StocktakeSessionScreenState();
}

class _StocktakeSessionScreenState extends ConsumerState<StocktakeSessionScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final user = ref.watch(appUserProvider).value;
    if (user == null) return const Scaffold();
    
    final merchantId = currentEffectiveMerchantId(user);
    final sessionsAsync = ref.watch(stocktakeSessionsProvider('')); // Wait we need branchId to find session. Actually, we can fetch session from a unified list or just pass it in? 
    // Let's refetch session directly or assume we have it.
    // Instead of branch specific, let's watch the specific session or just use the lines provider.
    
    // We need the session to get branchId.
    // Let's do a future provider for session or just read it from the repository directly.
    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تفاصيل الجرد' : 'Stocktake Details', style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: FutureBuilder<StocktakeSession?>(
        future: _getSession(merchantId, widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final session = snapshot.data;
          if (session == null) return const Center(child: Text('Session not found'));
          
          return _SessionBody(session: session, searchQuery: _searchQuery, onSearch: (v) => setState(() => _searchQuery = v));
        },
      ),
    );
  }
  
  Future<StocktakeSession?> _getSession(String merchantId, String sessionId) async {
    return ref.read(stocktakeRepositoryProvider).getSession(merchantId, sessionId);
  }
}

class _SessionBody extends ConsumerWidget {
  final StocktakeSession session;
  final String searchQuery;
  final ValueChanged<String> onSearch;
  
  const _SessionBody({required this.session, required this.searchQuery, required this.onSearch});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
     return Center(child: Text('TODO: Implement full counting screen'));
  }
}
