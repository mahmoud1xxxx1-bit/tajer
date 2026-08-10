enum AppFailureKind {
  invalidCredentials,
  employeeDeleted,
  employeeDisabled,
  merchantNotFound,
  noAssignedBranch,
  subscriptionInactive,
  permissionDenied,
  network,
  sessionExpired,
  unknown,
}

class AppFailure implements Exception {
  final AppFailureKind kind;
  final String domain;
  final Object? cause;

  const AppFailure(this.kind, {this.domain = 'app', this.cause});

  @override
  String toString() => 'AppFailure($domain, $kind)';
}

class EmployeeLoginFailure extends AppFailure {
  const EmployeeLoginFailure(super.kind, {super.cause})
      : super(domain: 'employee-login');
}
