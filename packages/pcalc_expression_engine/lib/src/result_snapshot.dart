/// Owned result data: no evaluator pointers, lazy callbacks, or rounded doubles
/// standing in for integers. Backends must report truncation explicitly.
sealed class ResultSnapshot {
  const ResultSnapshot({required this.typeName});
  final String typeName;
  Object toJson();
}

final class ScalarSnapshot extends ResultSnapshot {
  ScalarSnapshot.integer(
    String value, {
    required super.typeName,
    required int width,
    required bool signed,
  }) : exactValue = value,
       bitWidth = width,
       isSigned = signed,
       floatingValue = null {
    if (width < 1 || width > 64) throw ArgumentError('Width must be 1–64');
    final integer = BigInt.parse(value);
    final bound = BigInt.one << (signed ? width - 1 : width);
    if (integer < (signed ? -bound : BigInt.zero) || integer >= bound) {
      throw ArgumentError('Integer does not fit its declared type');
    }
  }

  const ScalarSnapshot.floating(
    String value, {
    required super.typeName,
    required double numericValue,
  }) : exactValue = value,
       floatingValue = numericValue,
       bitWidth = null,
       isSigned = null;

  final String exactValue;
  final int? bitWidth;
  final bool? isSigned;
  final double? floatingValue;

  @override
  Object toJson() => {
    'type': typeName,
    'value': exactValue,
    if (bitWidth != null) 'bitWidth': bitWidth,
    if (isSigned != null) 'signed': isSigned,
  };
}

final class ContainerSnapshot extends ResultSnapshot {
  ContainerSnapshot({
    required super.typeName,
    required List<ResultSnapshot> elements,
    int? totalCount,
  }) : elements = List.unmodifiable(elements),
       totalCount = totalCount ?? elements.length {
    if (this.totalCount < elements.length) {
      throw ArgumentError('Invalid total count');
    }
    if (nodeCount > 4096 || depth > 8) {
      throw ArgumentError('Snapshot exceeds 4096 nodes or 8 levels');
    }
  }
  final List<ResultSnapshot> elements;
  final int totalCount;
  bool get isTruncated => totalCount > elements.length;
  int get nodeCount =>
      1 +
      elements.fold<int>(
        0,
        (sum, e) => sum + (e is ContainerSnapshot ? e.nodeCount : 1),
      );
  int get depth =>
      1 +
      elements.fold<int>(0, (max, e) {
        final depth = e is ContainerSnapshot ? e.depth : 0;
        return depth > max ? depth : max;
      });
  @override
  Object toJson() => {
    'type': typeName,
    'totalCount': totalCount,
    'truncated': isTruncated,
    'elements': elements.map((e) => e.toJson()).toList(),
  };
}
