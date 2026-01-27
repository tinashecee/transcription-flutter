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
    
    // Make both API calls in parallel for better performance
    final courtsResponse = _client.dio.get<dynamic>('/courts');
    final courtroomsResponse = _client.dio.get<dynamic>('/courtrooms');
    
    final results = await Future.wait([courtsResponse, courtroomsResponse]);
    final courtsRaw = results[0].data;
    
    final courtsList = courtsRaw is List
        ? courtsRaw
        : (courtsRaw is Map<String, dynamic> ? courtsRaw['data'] as List? : null);
    
    // Create a map of court_id -> court_name
    final courtIdToName = <int, String>{};
    for (final courtItem in courtsList ?? const []) {
      if (courtItem is! Map<String, dynamic>) continue;
      final courtId = courtItem['court_id'];
      final courtName = courtItem['court_name']?.toString() ?? '';
      if (courtId != null && courtName.isNotEmpty) {
        courtIdToName[courtId is int ? courtId : int.tryParse(courtId.toString()) ?? -1] = courtName;
      }
    }
    
    // Process courtrooms
    final raw = results[1].data;
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic> ? raw['data'] as List? : null);
    final map = <String, List<String>>{};
    for (final item in list ?? const []) {
      if (item is! Map<String, dynamic>) continue;
      
      // Try court_name first, then map court_id to court_name
      String? courtName = item['court_name']?.toString();
      if (courtName == null || courtName.isEmpty) {
        final courtId = item['court_id'];
        if (courtId != null) {
          final id = courtId is int ? courtId : int.tryParse(courtId.toString());
          if (id != null) {
            courtName = courtIdToName[id];
          }
        }
      }
      
      final roomName = (item['courtroom_name'] ?? '').toString();
      if (courtName == null || courtName.isEmpty || roomName.isEmpty) continue;
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

    final useUserEndpoint = filters.tab != RecordingTab.all;
    if (useUserEndpoint && (userId == null || userId.isEmpty)) {
      throw DioException(
        requestOptions: RequestOptions(path: '/user/recordings/latest_paginated'),
        message: 'user_id is required for user recordings',
      );
    }

    final dateFormatter = DateFormat('yyyy-MM-dd');
    final offset = (page - 1) * pageSize;
    final hasSearch = filters.query != null && filters.query!.trim().isNotEmpty;
    // When search is active, ignore court/courtroom filters
    // Otherwise, use the filters from the state
    final effectiveCourt = hasSearch ? null : (filters.court?.trim().isNotEmpty == true ? filters.court : null);
    final effectiveCourtroom = hasSearch ? null : (filters.courtroom?.trim().isNotEmpty == true ? filters.courtroom : null);
    final hasCourt = effectiveCourt != null && effectiveCourt.trim().isNotEmpty;
    final hasCourtroom =
        effectiveCourtroom != null && effectiveCourtroom.trim().isNotEmpty;

    final endpoint = useUserEndpoint
        ? '/user/recordings/latest_paginated'
        : '/recordings/latest_paginated';

    // Only use by_court endpoints when a courtroom is selected (not just court)
    // Court alone should not filter - only courtroom filters
    if (!useUserEndpoint && !hasSearch && hasCourtroom && hasCourt) {
      final encodedCourt = Uri.encodeComponent(effectiveCourt!.trim());
      final encodedRoom = Uri.encodeComponent(effectiveCourtroom!.trim());
      
      // Try using the paginated endpoint with filters for proper sorting
      // If that doesn't work, we'll fall back to by_court_and_room and sort client-side
      final queryParams = {
        'limit': pageSize,
        'offset': offset,
        'sort_by': 'date_stamp',
        'sort_dir': 'desc',
        'court': effectiveCourt.trim(),
        'courtroom': effectiveCourtroom!.trim(),
      };
      
      try {
        final response = await _client.dio.get<Map<String, dynamic>>(
          '/recordings/latest_paginated',
          queryParameters: queryParams,
        );
        
        final items = (response.data?['items'] as List<dynamic>? ?? [])
            .map((json) => RecordingModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList();
        
        return items;
      } catch (e) {
        // Fallback to by_court_and_room endpoint and sort client-side
        final courtEndpoint =
            '/recordings/by_court_and_room/$encodedCourt/$encodedRoom';
        
        final response = await _client.dio.get<List<dynamic>>(courtEndpoint);
        final items = (response.data ?? [])
            .map((json) => RecordingModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList();
        
        // Sort by date descending (latest first)
        items.sort((a, b) => b.date.compareTo(a.date));
        return items;
      }
    }

    final queryParameters = <String, dynamic>{
      'limit': pageSize,
      'offset': offset,
      'sort_by': 'date_stamp',
      'sort_dir': 'desc',
      if (filters.query != null && filters.query!.isNotEmpty) 'q': filters.query,
      // When courtroom is set, court must also be included (both are needed for filtering)
      if (effectiveCourtroom != null) 'courtroom': effectiveCourtroom,
      // Court should always be set when courtroom is selected
      if (effectiveCourtroom != null && effectiveCourt != null) 'court': effectiveCourt,
      if (filters.fromDate != null)
        'start_date': dateFormatter.format(filters.fromDate!),
      if (filters.toDate != null)
        'end_date': dateFormatter.format(filters.toDate!),
      if (useUserEndpoint) 'user_id': userId,
    };
    
    final response = await _client.dio.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: queryParameters,
    );

    final items = (response.data?['items'] as List<dynamic>? ?? [])
        .map((json) => RecordingModel.fromJson(json as Map<String, dynamic>))
        .map((model) => model.toEntity())
        .toList();

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
