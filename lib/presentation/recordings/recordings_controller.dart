import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../services/auth_session.dart';
import '../../domain/entities/recording.dart';
import '../../domain/repositories/recording_repository.dart';
import '../../services/dio_error_mapper.dart';

class RecordingsState {
  RecordingsState({
    required this.items,
    required this.isLoading,
    required this.page,
    required this.filters,
    this.errorMessage,
  });

  final List<Recording> items;
  final bool isLoading;
  final int page;
  final RecordingFilters filters;
  final String? errorMessage;

  RecordingsState copyWith({
    List<Recording>? items,
    bool? isLoading,
    int? page,
    RecordingFilters? filters,
    String? errorMessage,
  }) {
    return RecordingsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      page: page ?? this.page,
      filters: filters ?? this.filters,
      errorMessage: errorMessage,
    );
  }

  factory RecordingsState.initial() => RecordingsState(
        items: const [],
        isLoading: false,
        page: 1,
        filters: const RecordingFilters(tab: RecordingTab.myList),
      );
}

class RecordingsController extends StateNotifier<RecordingsState> {
  RecordingsController(this._ref) : super(RecordingsState.initial());

  final Ref _ref;
  static const _pageSize = 20;

  Future<void> loadInitial() async {
    // Clear current state completely before fetching fresh from API
    state = RecordingsState(
      items: const [], // Clear all items
      isLoading: true,
      page: 1,
      filters: state.filters,
      errorMessage: null,
    );
    print('[RecordingsController] State cleared, fetching fresh from API...');
    await _load(page: 1, replace: true);
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    await _load(page: state.page + 1, replace: false);
  }

  Future<void> updateFilters(RecordingFilters filters) async {
    final current = state.filters;
    final hasQuery = filters.query != null && filters.query!.trim().isNotEmpty;
    final courtChanged =
        filters.court != current.court || filters.courtroom != current.courtroom;
    final queryChanged = filters.query != current.query;

    var normalized = filters;
    if (hasQuery) {
      normalized = RecordingFilters(
        court: null,
        courtroom: null,
        query: filters.query?.trim(),
        fromDate: filters.fromDate,
        toDate: filters.toDate,
        tab: filters.tab,
      );
    } else if (courtChanged && queryChanged) {
      // Court selection should clear search to avoid conflict.
      normalized = RecordingFilters(
        court: filters.court,
        courtroom: filters.courtroom,
        query: null,
        fromDate: filters.fromDate,
        toDate: filters.toDate,
        tab: filters.tab,
      );
    } else if (courtChanged && !hasQuery) {
      normalized = RecordingFilters(
        court: filters.court,
        courtroom: filters.courtroom,
        query: null,
        fromDate: filters.fromDate,
        toDate: filters.toDate,
        tab: filters.tab,
      );
    }

    state = state.copyWith(filters: normalized, page: 1, items: []);
    await loadInitial();
  }

  Future<void> _load({required int page, required bool replace}) async {
    try {
      final repo = _ref.read(recordingRepositoryProvider);
      final userId = _ref.read(authSessionProvider).user?.id;
      print(
        '[RecordingsController] load page=$page replace=$replace '
        'tab=${state.filters.tab.name} userId=$userId',
      );
      final items = await repo.fetchRecordings(
        page: page,
        pageSize: _pageSize,
        filters: state.filters,
        userId: userId,
      );
      state = state.copyWith(
        isLoading: false,
        page: page,
        items: replace ? items : [...state.items, ...items],
      );
    } catch (error) {
      print('[RecordingsController] load error: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: mapDioError(error),
      );
    }
  }
}

final recordingsControllerProvider =
    StateNotifierProvider<RecordingsController, RecordingsState>((ref) {
  return RecordingsController(ref)..loadInitial();
});
