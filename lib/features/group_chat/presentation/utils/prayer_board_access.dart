import 'package:flutter_pecha/features/group_profile/domain/entities/group_event.dart';
import 'package:flutter_pecha/features/group_profile/presentation/utils/group_event_live_utils.dart';

/// Whether a prayer board still takes new requests at [now]. Praying for the
/// requests already there stays open either way (#1098).
///
/// [event] is null for a space, which has no end, and while the event is
/// still loading: the board stays open then, since a failed fetch must not
/// lock it. A recurring event stays open too: its series has no end date, so
/// it never finishes, and requests are taken between occurrences as well.
/// The backend refuses with EVENT_ENDED if it ever disagrees.
bool prayerBoardTakesRequests({
  required GroupEvent? event,
  required DateTime now,
}) {
  if (event == null) return true;
  return !GroupEventLiveUtils.hasEnded(event, now);
}
