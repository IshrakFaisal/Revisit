import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/platform/external_links.dart';
import 'package:revisit/ui/revisit_app.dart';

RevisitApp createRevisitApp() => RevisitApp(
  openStore: BookmarkStore.local,
  openLink: openExternalLink,
  enableWindowsIntegration: true,
);
