import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/utils/hash_helper.dart';

void main() {
  test("HashHelper same input icin ayni hash'i uretir", () {
    expect(
      HashHelper.hashPassword("demo123"),
      HashHelper.hashPassword("demo123"),
    );
  });
}
