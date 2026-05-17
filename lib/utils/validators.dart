// Dart validators — mirror the strict server-side rules in
// GharKaMali_Backend/src/middleware/validators.js.
//
// Usage with TextFormField:
//   TextFormField(validator: Validators.phone)
//
// Usage as pre-submit gate:
//   final err = Validators.firstError([
//     Validators.phone(_phoneCtrl.text),
//     Validators.email(_emailCtrl.text, optional: true),
//   ]);
//   if (err != null) { showMsg(context, err, err: true); return; }
//   // ...submit

class Validators {
  // ── Atoms — return null when valid, else an error message ──────────────
  static String? phone(String? value, {bool optional = false}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return optional ? null : 'Phone is required';
    final s = raw.replaceAll(RegExp(r'[\s-]'), '').replaceFirst(RegExp(r'^(\+?91|0)'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(s)) return 'Enter a valid 10-digit Indian mobile number';
    return null;
  }

  static String? otp(String? value, {int min = 4, int max = 6}) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return 'OTP is required';
    if (!RegExp('^\\d{$min,$max}\$').hasMatch(s)) return 'OTP must be $min-$max digits';
    return null;
  }

  static String? email(String? value, {bool optional = false}) {
    final s = (value ?? '').trim().toLowerCase();
    if (s.isEmpty) return optional ? null : 'Email is required';
    if (s.length > 120) return 'Email is too long';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  static String? name(String? value, {String field = 'Name', int min = 2, int max = 80, bool optional = false}) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return optional ? null : '$field is required';
    if (s.length < min || s.length > max) return '$field must be $min-$max characters';
    if (!RegExp(r"^[A-Za-zऀ-ॿ .'\-]+$").hasMatch(s)) return '$field contains invalid characters';
    return null;
  }

  static String? pincode(String? value, {bool optional = false}) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return optional ? null : 'Pincode is required';
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(s)) return 'Enter a valid 6-digit pincode';
    return null;
  }

  static String? gstin(String? value, {bool optional = true}) {
    final s = (value ?? '').trim().toUpperCase();
    if (s.isEmpty) return optional ? null : 'GSTIN is required';
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(s)) {
      return 'Invalid GSTIN — must be 15 characters in the official format';
    }
    return null;
  }

  static String? amount(String? value, {String field = 'Amount', num min = 1, num max = 1000000, bool optional = false}) {
    if (value == null || value.isEmpty) return optional ? null : '$field is required';
    final n = num.tryParse(value);
    if (n == null) return '$field must be a number';
    if (n < min || n > max) return '$field must be between $min and $max';
    return null;
  }

  static String? integer(String? value, {String field = 'Value', int min = 0, int max = 1000000, bool optional = false}) {
    if (value == null || value.isEmpty) return optional ? null : '$field is required';
    final n = int.tryParse(value);
    if (n == null) return '$field must be a whole number';
    if (n < min || n > max) return '$field must be between $min and $max';
    return null;
  }

  static String? text(String? value, {String field = 'Field', int min = 0, int max = 5000, bool optional = false}) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return optional ? null : '$field is required';
    if (s.length < min) return '$field must be at least $min characters';
    if (s.length > max) return '$field must be at most $max characters';
    return null;
  }

  static String? required(String? value, {String field = 'Field'}) {
    if ((value ?? '').trim().isEmpty) return '$field is required';
    return null;
  }

  // ── Aggregators ────────────────────────────────────────────────────────
  /// Returns the first non-null error from a list of validator results.
  static String? firstError(List<String?> errors) {
    for (final e in errors) {
      if (e != null) return e;
    }
    return null;
  }

  /// Returns true if every result is null.
  static bool allValid(List<String?> errors) => errors.every((e) => e == null);

  // ── Helpers ────────────────────────────────────────────────────────────
  /// Normalize phone to backend-friendly 10-digit form.
  static String normalizePhone(String raw) =>
      raw.replaceAll(RegExp(r'[\s-]'), '').replaceFirst(RegExp(r'^(\+?91|0)'), '');
}
