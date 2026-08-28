import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/link_request_provider.dart';
import 'link_request_screen.dart';
import 'resident_home_screen.dart';

class ResidentShell extends ConsumerWidget {
  const ResidentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkState = ref.watch(residentLinkProvider);

    if (linkState.status == LinkStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (linkState.status == LinkStatus.linked) {
      return const ResidentHomeScreen();
    }

    return const LinkRequestScreen();
  }
}
