/// Stable (deterministic) hashing for notification IDs.
///
/// IMPORTANT: don't use String.hashCode because it isn't stable across app runs.
int fnv1a32(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811c9dc5;
  for (final int c in input.codeUnits) {
    hash ^= c;
    hash = (hash * fnvPrime) & 0xffffffff;
  }
  // Keep it positive to satisfy platform id constraints.
  return hash & 0x7fffffff;
}
