import 'json_utils.dart';

/// One page of a paginated list (`GET /api/mobile/tickets?page=&pageSize=`).
class PageResult<T> {
  const PageResult({required this.items, required this.page, required this.hasMore});

  /// Accepts a plain list, or an object with the items under `items`,
  /// `tickets`, `data` or `results` and the paging info either alongside
  /// them or under `pagination`.
  factory PageResult.fromJson(
    Object? data,
    T Function(Json json) parse, {
    required int page,
    required int pageSize,
  }) {
    if (data is List) {
      final items = asJsonList(data).map(parse).toList();
      return PageResult(items: items, page: page, hasMore: items.length >= pageSize);
    }
    final json = asJson(data);
    final rawItems =
        json['items'] ?? json['tickets'] ?? json['data'] ?? json['results'];
    final items = asJsonList(rawItems).map(parse).toList();

    final meta = json['pagination'] is Map ? asJson(json['pagination']) : json;
    final totalPages = readInt(meta['totalPages']);
    final total = readInt(meta['total'] ?? meta['totalItems'] ?? meta['totalCount']);
    final hasMoreFlag = meta['hasMore'];

    final bool hasMore = hasMoreFlag is bool
        ? hasMoreFlag
        : totalPages != null
            ? page < totalPages
            : total != null
                ? page * pageSize < total
                : items.length >= pageSize;
    return PageResult(items: items, page: page, hasMore: hasMore);
  }

  final List<T> items;
  final int page;
  final bool hasMore;
}
