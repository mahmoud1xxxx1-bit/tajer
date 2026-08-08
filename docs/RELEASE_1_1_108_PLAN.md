# Tajer 1.1.108 Release Plan

Target release after completion and verification of all 16 multi-branch development stages.

## Version target

- Display version: `1.1.108`
- Build number: `108`
- Protected baseline: `1.0.107+107` on `main`
- Development branch: `feature/multi-branch-v1`

## Release gate

Do not bump `pubspec.yaml`, tag, merge to `main`, deploy Web, or publish Android until all 16 stages are complete and the final regression matrix passes.

Required final gates include:

- Flutter analysis passes.
- Multi-branch regression tests pass.
- Android release build passes.
- Web release build for `/taj/` passes.
- Arabic and English UI verification.
- Light and dark theme verification.
- Backward compatibility for v1.0.107 records.
- Branch isolation for orders, inventory, raw materials, shifts, expenses, supplier/customer accounting, reports, employees and permissions.
- Financial invariants and historical snapshots remain intact.
- Production Firebase is not modified during development/testing unless explicitly approved for release deployment.

The version bump to `1.1.108+108` is intentionally deferred until the final release stage so intermediate development commits cannot be confused with a releasable build.
