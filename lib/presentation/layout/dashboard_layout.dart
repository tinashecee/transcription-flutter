import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../recordings/recordings_controller.dart';
import '../../domain/repositories/recording_repository.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/sidebar_provider.dart';

class DashboardLayout extends ConsumerWidget {
  final Widget child;
  final String location;

  const DashboardLayout({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingsControllerProvider);
    final controller = ref.read(recordingsControllerProvider.notifier);
    final isSidebarHidden = ref.watch(sidebarHiddenProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSidebarHidden)
            CollapsibleSidebar(
              selectedCourt: state.filters.court,
              selectedCourtroom: state.filters.courtroom,
              onCourtSelected: (court) {
                controller.updateFilters(
                  RecordingFilters(
                    court: court,
                    courtroom: null,
                    query: state.filters.query,
                    fromDate: state.filters.fromDate,
                    toDate: state.filters.toDate,
                    tab: state.filters.tab,
                  ),
                );

                // If we're on a detail page or status page, navigate back to recordings
                if (location != '/recordings') {
                  context.go('/recordings');
                }
              },
              onCourtroomSelected: (courtroom) {
                controller.updateFilters(
                  RecordingFilters(
                    court: state.filters.court,
                    courtroom: courtroom,
                    query: state.filters.query,
                    fromDate: state.filters.fromDate,
                    toDate: state.filters.toDate,
                    tab: state.filters.tab,
                  ),
                );
                
                if (location != '/recordings') {
                  context.go('/recordings');
                }
              },
            ),
          
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
