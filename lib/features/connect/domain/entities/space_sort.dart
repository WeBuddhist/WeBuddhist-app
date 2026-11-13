/// Order of the spaces list, as offered under "Looking for".
enum SpaceSort {
  popular('member_count'),
  newlyAdded('created_at'),
  mostActive('updated_at');

  const SpaceSort(this.apiValue);

  /// `sort_by` on `GET /api/v2/spaces`; always sent with `sort_order=desc`.
  final String apiValue;
}
