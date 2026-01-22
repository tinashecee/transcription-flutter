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
    required this.hasMore,
    required this.page,
    required this.filters,
    required this.totalItems,
    required this.pageSize,
    this.errorMessage,
  });

  final List<Recording> items;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final RecordingFilters filters;
  final int totalItems;
  final int pageSize;
  final String? errorMessage;

  RecordingsState copyWith({
    List<Recording>? items,
    bool? isLoading,
    bool? hasMore,
    int? page,
    RecordingFilters? filters,
    int? totalItems,
    int? pageSize,
    String? errorMessage,
  }) {
    return RecordingsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      filters: filters ?? this.filters,
      totalItems: totalItems ?? this.totalItems,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage,
    );
  }

  factory RecordingsState.initial() => RecordingsState(
        items: const [],
        isLoading: false,
        hasMore: true,
        page: 1,
        totalItems: 0,
        pageSize: 20,
        filters: const RecordingFilters(tab: RecordingTab.all),
      );
}

class RecordingsController extends StateNotifier<RecordingsState> {
  RecordingsController(this._ref) : super(RecordingsState.initial());

  final Ref _ref;
  Future<void> loadInitial() async {
    state = state.copyWith(
      items: const [],
      isLoading: true,
      hasMore: true,
      page: 1,
      errorMessage: null,
    );
    await _load(page: 1);
  }

  Future<void> setPage(int page) async {
    if (state.isLoading || page == state.page || page < 1) return;
    state = state.copyWith(isLoading: true);
    await _load(page: page);
  }

  Future<void> setPageSize(int size) async {
    if (state.pageSize == size) return;
    state = state.copyWith(pageSize: size, page: 1, isLoading: true, items: []);
    await _load(page: 1);
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

    state = state.copyWith(filters: normalized, page: 1, items: [], hasMore: true);
    await loadInitial();
  }

  Future<void> fullRefresh() async {
    _ref.read(recordingRepositoryProvider).clearCache();
    await loadInitial();
  }

  Future<void> clearFilters() async {
    // Keeps the current tab but clears everything else
    final defaultFilters = RecordingFilters(tab: state.filters.tab);
    await updateFilters(defaultFilters);
  }

  Future<void> _load({required int page}) async {
    try {
      final repo = _ref.read(recordingRepositoryProvider);
      final userId = _ref.read(authSessionProvider).user?.id;
      
      final response = await repo.fetchRecordings(
        page: page,
        pageSize: state.pageSize,
        filters: state.filters,
        userId: userId,
      );
      
      final hasMore = response.items.length >= state.pageSize;
      
      state = state.copyWith(
        isLoading: false,
        hasMore: hasMore,
        page: page,
        items: response.items,
        totalItems: response.total,
      );
    } catch (error) {
      print('[RecordingsController] load error: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: mapDioError(error),
      );
    }
  }

  void updateRecordingStatus(String id, String newStatus) {
    if (state.isLoading) return;
    
    // Normalize status to lowercase/snake_case for consistency
    final normalized = newStatus.trim().toLowerCase().replaceAll(' ', '_');
    
    final index = state.items.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updatedItems = List<Recording>.from(state.items);
      updatedItems[index] = updatedItems[index].copyWith(status: normalized);
      state = state.copyWith(items: updatedItems);
    }
  }
}

final recordingsControllerProvider =
    StateNotifierProvider<RecordingsController, RecordingsState>((ref) {
  return RecordingsController(ref)..loadInitial();
});
