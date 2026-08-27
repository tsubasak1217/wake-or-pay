import 'package:flutter/foundation.dart';

/// One person in the in-app 連絡帳.
///
/// The address book is the app's own — it never reads the device's contacts —
/// so this is exactly what the user typed, held on the device.
///
/// An entry is *referenced* by an alarm rather than embedded in it: the alarm
/// keeps a snapshot of the name and the two addresses, so deleting an entry
/// here never leaves an alarm with nobody to call.
@immutable
class ContactEntry {
  const ContactEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    this.reading,
    this.phone,
    this.email,
  });

  final String id;
  final String name;

  /// よみがな. Used **only** for sorting, never shown as the contact's name and
  /// never sent anywhere. Optional, because plenty of names do not need one.
  final String? reading;

  final String? phone;
  final String? email;
  final DateTime createdAt;

  bool get hasPhone => (phone ?? '').trim().isNotEmpty;

  bool get hasEmail => (email ?? '').trim().isNotEmpty;

  /// A name and at least one way to reach them. An entry that can be reached
  /// by neither phone nor mail is not a contact, and the editor refuses to
  /// save one.
  bool get isUsable => name.trim().isNotEmpty && (hasPhone || hasEmail);

  /// What the list is ordered by: the よみがな when there is one, the name
  /// otherwise.
  String get sortKey {
    final read = reading?.trim() ?? '';
    return read.isEmpty ? name.trim() : read;
  }

  ContactEntry copyWith({
    String? id,
    String? name,
    String? reading,
    bool clearReading = false,
    String? phone,
    bool clearPhone = false,
    String? email,
    bool clearEmail = false,
    DateTime? createdAt,
  }) => ContactEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    reading: clearReading ? null : (reading ?? this.reading),
    phone: clearPhone ? null : (phone ?? this.phone),
    email: clearEmail ? null : (email ?? this.email),
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ContactEntry &&
      other.id == id &&
      other.name == name &&
      other.reading == reading &&
      other.phone == phone &&
      other.email == email &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, reading, phone, email, createdAt);

  @override
  String toString() => 'ContactEntry($id, $name, reading $reading)';
}

/// The order the 連絡帳 lists people in. Pure.
///
/// A plain Dart string comparison of [ContactEntry.sortKey] — UTF-16 code unit
/// order, not a Japanese collation. Kana sort the way kana are encoded, which
/// is the ordinary あいうえお order; kanji names with no よみがな land in
/// codepoint order, which is why the field exists. Ties break on the creation
/// time so the list never reshuffles under the user.
int compareContactEntries(ContactEntry a, ContactEntry b) {
  final byKey = a.sortKey.compareTo(b.sortKey);
  if (byKey != 0) return byKey;
  return a.createdAt.compareTo(b.createdAt);
}

List<ContactEntry> sortedContactEntries(Iterable<ContactEntry> entries) =>
    [...entries]..sort(compareContactEntries);
