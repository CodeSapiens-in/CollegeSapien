# Firebase, Google Play Services, and flutter_local_notifications all ship their own
# consumer ProGuard rules inside their AARs, which R8 merges in automatically — no manual
# -keep rules are needed for them here. Add app-specific rules below if R8 ever strips
# something reflection-based that isn't covered by a dependency's consumer rules.
