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
  Future<PaginatedRecordings> fetchRecordings({
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

    // Use by_court endpoints only for "All Recordings" when no search or date filters are active
    final hasDateFilter = filters.fromDate != null || filters.toDate != null;
    if (!useUserEndpoint && !hasSearch && !hasDateFilter && hasCourt) {
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
        return PaginatedRecordings(items: items, total: items.length);
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
      return PaginatedRecordings(items: items, total: items.length);
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

    final total = (response.data?['total'] as num?)?.toInt() ?? items.length;

    print(
      '[RecordingRepo] response items=${items.length} '
      'total=$total '
      'has_more=${response.data?['has_more']}',
    );
    return PaginatedRecordings(items: items, total: total);
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

  @override
  void clearCache() {
    _courtsCache = null;
    _courtroomsByCourtCache = null;
  }

  @override
  Stream<String> retranscribe(String id) async* {
    yield '[Status] Starting retranscription...';
    
    try {
      // 1. Initiate retranscription
      final response = await _client.dio.post<dynamic>(
        '/retranscribe',
        data: {'id': id},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json, 
        ),
      );

      final data = response.data;
      
      // 2. Handle response
      if (data is Map<String, dynamic>) {
        if (data['job_id'] != null || data['queued'] == true) {
          yield '[Queue] 📥 Job queued. Waiting for position...';
          final jobId = data['job_id'] as int?;
          
          if (jobId != null) {
            yield* _pollTranscriptionStatus(id, jobId);
          }
        } else if (data['message'] != null) {
           yield '[Backend]: ${data['message']}';
        } else if (data['transcript'] != null) {
           // Immediate result
           yield data['transcript'].toString();
           return;
        }
      } else {
        // Unexpected response format
        yield '[Error] Unexpected response format from backend.';
      }
      
    } on DioException catch (e) {
      yield '[Error] Request failed: ${e.message}';
      if (e.response != null) {
        yield '[Error] Backend details: ${e.response?.data}';
      }
      rethrow;
    } catch (e) {
      yield '[Error] $e';
      rethrow;
    }
  }

  Stream<String> _pollTranscriptionStatus(String recordingId, int expectedJobId) async* {
    const maxPolls = 120; // 10 minutes
    const pollInterval = Duration(seconds: 4);
    
    int lastQueuePosition = -1;
    bool shownRunningMessage = false;

    // We can't use a regular for loop with async* efficiently if we want delays?
    // Actually we can await Future.delayed.
    
    for (var i = 0; i < maxPolls; i++) {
      try {
        final response = await _client.dio.get<Map<String, dynamic>>(
          '/case_recordings/$recordingId/transcription_status',
        );
        
        final status = response.data;
        if (status == null) continue;

        // Check last_job
        final lastJob = status['last_job'];
        if (lastJob != null && lastJob['id'] == expectedJobId) {
          final jobStatus = lastJob['status'];
          
          if (jobStatus == 'completed') {
            yield '\n[Queue] ✅ Transcription completed!';
            
            // Fetch updated recording to ensure backend is ready
            try {
              await fetchRecording(recordingId);
            } catch (e) {
              print('Failed to fetch updated recording: $e');
            }
            
            if (lastJob['transcript'] != null) {
              yield lastJob['transcript'].toString();
              return;
            }
            // If we completed but got no transcript, just return what we have or nothing?
            // The stream closing marks the end.
            return;
            
          } else if (jobStatus == 'failed') {
            yield '\n[Queue] ❌ Transcription failed: ${lastJob['error_message'] ?? "Unknown error"}';
            return;
          } else if (jobStatus == 'running' && !shownRunningMessage) {
            yield '\n[Queue] 🎉 Now your turn! Transcription in progress...';
            shownRunningMessage = true;
          }
        }

        // Check active active_jobs
        final activeJobs = status['active_jobs'] as List?;
        if (activeJobs != null && activeJobs.isNotEmpty) {
           // Find our job or fallback to first
           // The web code tries to find exact job ID
           final jobMatch = activeJobs.firstWhere(
             (j) => j['id'] == expectedJobId, 
             orElse: () => null,
           );
           
           if (jobMatch != null) {
             final activeJob = jobMatch;
             final queuePosition = activeJob['queue_position'] as int?;
             final jobStatus = activeJob['status'];
             
             final isActuallyRunning = jobStatus == 'running' && 
                 (queuePosition == null || queuePosition <= 1);

             if (isActuallyRunning) {
               if (!shownRunningMessage) {
                 yield '\n[Queue] 🎉 Now your turn! Transcription in progress...';
                 shownRunningMessage = true;
               }
               // Periodically show progress dots
               if (i > 0 && i % 3 == 0) yield '.';
               
             } else if (queuePosition != null && queuePosition > 0) {
               if (queuePosition != lastQueuePosition) {
                 lastQueuePosition = queuePosition;
                 yield '\n[Queue] 📋 You are in queue position $queuePosition. Please be patient...';
               }
             } else {
                if (lastQueuePosition != -2) {
                  lastQueuePosition = -2;
                  yield '\n[Queue] 📋 Waiting in queue...';
                }
             }
           }
        } else if (status['active_jobs_count'] == 0 && lastJob != null && lastJob['id'] == expectedJobId) {
             // Fallback if active_jobs is empty but last_job is ours and completed/failed
             // This logic was covered in the first last_job check, but let's double check logic order.
             // The web logic checks active_jobs first, then last_job if active is empty.
             // We checked last_job first. That's probably fine as last_job is definitive for completion.
        }
        
      } catch (e) {
        print('Poll error: $e');
        // Continue polling despite temporary network errors
      }

      await Future.delayed(pollInterval);
    }
    
    yield '[Error] Transcription timed out.';
  }
}
