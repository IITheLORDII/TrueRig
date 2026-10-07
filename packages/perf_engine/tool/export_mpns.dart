// Prints one MPN per line for every seed catalog part that has one.
// Usage: dart run tool/export_mpns.dart > mpns.txt
import 'package:perf_engine/perf_engine.dart';

void main() {
  for (final part in PartCatalog.seed().all) {
    final mpn = part.mpn;
    if (mpn != null && mpn.trim().isNotEmpty) print(mpn.trim());
  }
}
