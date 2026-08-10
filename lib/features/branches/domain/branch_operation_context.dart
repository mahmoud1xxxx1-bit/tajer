class BranchOperationContext {
  final String merchantId;
  final String branchId;

  const BranchOperationContext({
    required this.merchantId,
    required this.branchId,
  });

  bool get isValid => merchantId.isNotEmpty && branchId.isNotEmpty;
}
