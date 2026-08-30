import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';

IconData contactChannelIcon(ContactChannel channel) => switch (channel) {
  ContactChannel.phone => Icons.phone_outlined,
  ContactChannel.sms => Icons.sms_outlined,
  ContactChannel.email => Icons.mail_outline,
  ContactChannel.discord => Icons.forum_outlined,
  ContactChannel.log => Icons.receipt_long_outlined,
};

/// One row of the 寝坊連絡・共有履歴, on the tab's card and in the archive alike.
///
/// Extracted so the two lists cannot drift: the archive is the same history,
/// further back, and a row that read differently there would look like a
/// different kind of record.
class ContactEventTile extends StatelessWidget {
  const ContactEventTile({super.key, required this.event});

  final ContactEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('contactEvent-${event.id}'),
      leading: Icon(
        contactChannelIcon(event.channel),
        color: theme.colorScheme.error,
      ),
      // The name already carries its honorific — or is 「Discord 2件」, which
      // takes none — because it is the same phrase the countdown said out loud.
      title: Text('${event.contactName}へ'),
      subtitle: Text(
        [
          formatDateTime(event.firedAt),
          contactChannelLabel(event.channel),
          ?event.detail,
        ].join(' ・ '),
      ),
    );
  }
}
