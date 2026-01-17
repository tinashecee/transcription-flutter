import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/recording.dart';
import '../../domain/repositories/recording_repository.dart';
import '../api/api_client.dart';
import '../cache/session_cache.dart';
import '../cache/ttl_cache.dart';
import '../models/recording_model.dart';

class RecordingRepositoryImpl implements RecordingRepository {
  RecordingRepositoryImpl(this._client)
      : _courtsCache = TtlCache<List<String>>(const Duration(minutes: 5)),
        _courtroomsCache = TtlCache<List<String>>(const Duration(minutes: 5)),
        _courtroomsByCourtCache =
            TtlCache<Map<String, List<String>>>(const Duration(minutes: 5));

  final ApiClient _client;
  final SessionCache<List<Recording>> _sessionCache = SessionCache();
  final TtlCache<List<String>> _courtsCache;
  final TtlCache<List<String>> _courtroomsCache;
  final TtlCache<Map<String, List<String>>> _courtroomsByCourtCache;

  Future<List<String>> fetchCourts() async {
    final cached = _courtsCache.get('courts');
    if (cached != null) return cached;
    final response = await _client.dio.get<dynamic>('/courts');
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? raw['data'] as List? : null);
    final courts = (list ?? [])
        .map((e) => e is Map<String, dynamic> ? e['court_name'] : e)
        .map((e) => e.toString())
        .toList();
    _courtsCache.set('courts', courts);
    return courts;
  }

  Future<List<String>> fetchCourtrooms(String court) async {
    final key = 'courtrooms:$court';
    final cached = _courtroomsCache.get(key);
    if (cached != null) return cached;
    final response = await _client.dio.get<dynamic>('/courtrooms');
    final raw = response.data;
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? raw['data'] as List? : null);
    final rooms = (list ?? [])
        .map((e) => e is Map<String, dynamic> ? e['courtroom_name'] : e)
        .map((e) => e.toString())
        .toList();
    _courtroomsCache.set(key, rooms);
    return rooms;
  }

  Future<Map<String, List<String>>> fetchCourtroomsByCourt() async {
    final cached = _courtroomsByCourtCache.get('courtrooms_by_court');
    if (cached != null) return cached;
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
    _courtroomsByCourtCache.set('courtrooms_by_court', map);
    return map;
  }

  @override
  Future<List<Recording>> fetchRecordings({
    required int page,
    required int pageSize,
    required RecordingFilters filters,
    String? userId,
  }) async {
    print(
      '[RecordingRepo] fetchRecordings page=$page size=$pageSize tab=${filters.tab.name} '
      'court=${filters.court} courtroom=${filters.courtroom} '
      'query=${filters.query} from=${filters.fromDate} to=${filters.toDate} userId=$userId',
    );
    final key = _cacheKey(page, pageSize, filters, userId);
    final cached = _sessionCache.get(key);
    if (cached != null) {
      print('[RecordingRepo] cache hit key=$key count=${cached.length}');
      return cached;
    }

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
        _sessionCache.set(key, items);
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
      _sessionCache.set(key, items);
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
    _sessionCache.set(key, items);
    return items;
  }

  @override
  Future<Recording> fetchRecording(String id) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/recordings/$id',
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

  String _cacheKey(
    int page,
    int pageSize,
    RecordingFilters filters,
    String? userId,
  ) {
    return [
      'page=$page',
      'size=$pageSize',
      'court=${filters.court ?? ''}',
      'courtroom=${filters.courtroom ?? ''}',
      'query=${filters.query ?? ''}',
      'from=${filters.fromDate?.toIso8601String() ?? ''}',
      'to=${filters.toDate?.toIso8601String() ?? ''}',
      'tab=${filters.tab.name}',
      'userId=${userId ?? ''}',
    ].join('&');
  }
}
