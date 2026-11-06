import 'package:flutter/material.dart';

import '../application/windows_session.dart';

/// Presentation only. Recreating this widget never restarts native observation.
class WindowsIntegrationStatus extends StatelessWidget {
  const WindowsIntegrationStatus({super.key, required this.session});
  final WindowsSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        '${session.receiver}\n${session.notification}\n${session.processing}',
      ),
    ),
  );
}
