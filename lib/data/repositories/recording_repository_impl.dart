import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/recording.dart';
import '../../domain/repositories/recording_repository.dart';
import '../api/api_client.dart';
import '../models/recording_model.dart';

/// Recording repository - NO CACHING. All operations fetch fresh from API.
class RecordingRepositoryImpl implements RecordingRepository {
  RecordingRepositoryImpl(this._client);

  final ApiClient _client;
  
  // Courts/courtrooms can be cached since they rarely change
  List<String>? _courtsCache;
  Map<String, List<String>>? _courtroomsByCourtCache;

  Future<List<String>> fetchCourts() async {
    // Courts can be cached - they rarely change
    if (_courtsCache != null) return _courtsCache!;
    final response = await _client.dio.get<dynamic>('/courts');
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? raw['data'] as List? : null);
    final courts = (list ?? [])
        .map((e) => e is Map<String, dynamic> ? e['court_name'] : e)
        .map((e) => e.toString())
        .toList();
    _courtsCache = courts;
    return courts;
  }

  Future<List<String>> fetchCourtrooms(String court) async {
    // Fetch fresh - courtrooms are part of the by_court map
    final response = await _client.dio.get<dynamic>('/courtrooms');
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? raw['data'] as List? : null);
    final rooms = (list ?? [])
        .map((e) => e is Map<String, dynamic> ? e['courtroom_name'] : e)
        .map((e) => e.toString())
        .toList();
    return rooms;
  }

  Future<Map<String, List<String>>> fetchCourtroomsByCourt() async {
    // Courtrooms by court can be cached - they rarely change
    if (_courtroomsByCourtCache != null) return _courtroomsByCourtCache!;
    final response = await _client.dio.get<dynamic>('/courtrooms');
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? raw['data'] as List? : null);
    final map = <String, List<String>>{};
    for (final item in list ?? const []) {
      if (item is! Map<String, dynamic>) continue;
      final courtName = (item['court_name'] ?? '').toString();
      final roomName = (item['courtroom_name'] ?? '').toString();
      if (courtName.isEmpty || roomName.isEmpty) continue;
      map.putIfAbsent(courtName, () => []);
      map[courtName]!.add(roomName);
    }
    for (final entry in map.entries) {
      entry.value.sort();
    }
    _courtroomsByCourtCache = map;
    return map;
  }

  @override
  Future<List<Recording>> fetchRecordings({
    required int page,
    required int pageSize,
    required RecordingFilters filters,
    String? userId,
  }) async {
    // NO CACHING - Always fetch fresh from API
    print(
      '[RecordingRepo] fetchRecordings (NO CACHE) page=$page size=$pageSize tab=${filters.tab.name} '
      'court=${filters.court} courtroom=${filters.courtroom} '
      'query=${filters.query} from=${filters.fromDate} to=${filters.toDate} userId=$userId',
    );

    final useUserEndpoint = filters.tab != RecordingTab.all;
    if (useUserEndpoint && (userId == null || userId.isEmpty)) {
      print('[RecordingRepo] missing userId for user recordings endpoint');
      throw DioException(
        requestOptions: RequestOptions(path: '/user/recordings/latest_paginated'),
        message: 'user_id is required for user recordings',
      );
    }

    final dateFormatter = DateFormat('yyyy-MM-dd');
    final offset = (page - 1) * pageSize;
    final hasSearch = filters.query != null && filters.query!.trim().isNotEmpty;
    final effectiveCourt = hasSearch ? null : filters.court;
    final effectiveCourtroom = hasSearch ? null : filters.courtroom;
    final hasCourt = effectiveCourt != null && effectiveCourt.trim().isNotEmpty;
    final hasCourtroom =
        effectiveCourtroom != null && effectiveCourtroom.trim().isNotEmpty;

    final endpoint = useUserEndpoint
        ? '/user/recordings/latest_paginated'
        : '/recordings/latest_paginated';

    // Use by_court endpoints only for "All Recordings" when no search is active
    if (!useUserEndpoint && !hasSearch && hasCourt) {
      final encodedCourt = Uri.encodeComponent(effectiveCourt.trim());
      if (hasCourtroom) {
        final encodedRoom = Uri.encodeComponent(effectiveCourtroom.trim());
        final courtEndpoint =
            '/recordings/by_court_and_room/$encodedCourt/$encodedRoom';
        print(
          '[RecordingRepo] endpoint(by_court_and_room)=$courtEndpoint '
          '(court=${effectiveCourt.trim()}, room=${effectiveCourtroom.trim()})',
        );
        final response = await _client.dio.get<List<dynamic>>(courtEndpoint);
        final items = (response.data ?? [])
            .map((json) => RecordingModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList();
        return items;
      }
      final courtEndpoint = '/recordings/by_court/$encodedCourt';
      print(
        '[RecordingRepo] endpoint(by_court)=$courtEndpoint '
        '(court=${effectiveCourt.trim()})',
      );
      final response = await _client.dio.get<List<dynamic>>(courtEndpoint);
      final items = (response.data ?? [])
          .map((json) => RecordingModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toEntity())
          .toList();
      return items;
    }

    final queryParameters = {
      'limit': pageSize,
      'offset': offset,
      'sort_by': 'date_stamp',
      'sort_dir': 'desc',
      if (filters.query != null && filters.query!.isNotEmpty) 'q': filters.query,
      if (effectiveCourt != null) 'court': effectiveCourt,
      if (effectiveCourtroom != null) 'courtroom': effectiveCourtroom,
      if (filters.fromDate != null)
        'start_date': dateFormatter.format(filters.fromDate!),
      if (filters.toDate != null)
        'end_date': dateFormatter.format(filters.toDate!),
      if (useUserEndpoint) 'user_id': userId,
    };
    print('[RecordingRepo] GET $endpoint params=$queryParameters');
    final response = await _client.dio.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: queryParameters,
    );

    final items = (response.data?['items'] as List<dynamic>? ?? [])
        .map((json) => RecordingModel.fromJson(json as Map<String, dynamic>))
        .map((model) => model.toEntity())
        .toList();

    print(
      '[RecordingRepo] response items=${items.length} '
      'total=${response.data?['total']} '
      'has_more=${response.data?['has_more']}',
    );
    return items;
  }

  @override
  Future<Recording> fetchRecording(String id) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/recordings/$id',
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Recording not found',
      );
    }
    return RecordingModel.fromJson(data).toEntity();
  }

}
