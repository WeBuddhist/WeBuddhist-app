/// PostHog event names using [object]_[verb] convention.
abstract final class AnalyticsEvents {
  // Auth
  static const String authLoginSucceeded = 'auth_login_succeeded';
  static const String authLoginFailed = 'auth_login_failed';
  static const String authGuestStarted = 'auth_guest_started';
  static const String authLogout = 'auth_logout';
  static const String accountDeleted = 'account_deleted';

  // Onboarding
  static const String onboardingCompleted = 'onboarding_completed';

  // Plans
  static const String planEnrolled = 'plan_enrolled';
  static const String planViewed = 'plan_viewed';
  static const String planDayCompleted = 'plan_day_completed';
  static const String planPreviewed = 'plan_previewed';
  static const String planAddedToPractices = 'plan_added_to_practices';
  static const String planUnenrolled = 'plan_unenrolled';

  // Series
  static const String seriesViewed = 'series_viewed';
  static const String seriesBookmarked = 'series_bookmarked';
  static const String seriesAddedToPractices = 'series_added_to_practices';
  static const String seriesSearched = 'series_searched';

  // Search, every search box (`surface` says which)
  static const String searchPerformed = 'search_performed';
  static const String searchResultOpened = 'search_result_opened';

  // Group events
  static const String groupEventViewed = 'group_event_viewed';
  static const String groupEventAttended = 'group_event_attended';
  static const String groupEventLeft = 'group_event_left';
  static const String groupEventParticipationChanged =
      'group_event_participation_changed';
  static const String groupEventLiveEntered = 'group_event_live_entered';
  static const String groupEventLinkOpened = 'group_event_link_opened';
  static const String groupEventLiveOpened = 'group_event_live_opened';
  static const String groupEventLiveEnded = 'group_event_live_ended';
  static const String groupEventReplayOpened = 'group_event_replay_opened';
  static const String groupAccumulatorViewed = 'group_accumulator_viewed';

  // Connect and groups (§5.11)
  static const String connectTabViewed = 'connect_tab_viewed';
  static const String groupViewed = 'group_viewed';
  static const String groupFollowed = 'group_followed';
  static const String groupUnfollowed = 'group_unfollowed';
  static const String groupJoinRequested = 'group_join_requested';
  static const String groupAccumulatorJoined = 'group_accumulator_joined';
  static const String recitationCollectionOpened =
      'recitation_collection_opened';
  static const String recitationCollectionItemCompleted =
      'recitation_collection_item_completed';
  static const String recitationCollectionCompleted =
      'recitation_collection_completed';
  static const String groupTabViewed = 'group_tab_viewed';
  static const String postViewed = 'post_viewed';
  static const String postOpened = 'post_opened';
  static const String postLinkOpened = 'post_link_opened';
  static const String groupPostCreated = 'group_post_created';
  static const String postLiked = 'post_liked';
  static const String postUnliked = 'post_unliked';
  static const String postCommentCreated = 'post_comment_created';
  static const String postCommentDeleted = 'post_comment_deleted';

  // Audio and video
  static const String audioPlayed = 'audio_played';
  static const String audioSettingChanged = 'audio_setting_changed';
  static const String videoOpened = 'video_opened';

  // Reader settings and live recitation
  static const String readerSettingChanged = 'reader_setting_changed';
  static const String recitationLiveFollowed = 'recitation_live_followed';

  // Bookmarks and personal collections
  static const String bookmarkAdded = 'bookmark_added';
  static const String bookmarkRemoved = 'bookmark_removed';
  static const String bookmarksOpened = 'bookmarks_opened';
  static const String collectionCreated = 'collection_created';
  static const String collectionUpdated = 'collection_updated';
  static const String collectionDeleted = 'collection_deleted';

  // Mala settings
  static const String malaSettingChanged = 'mala_setting_changed';
  static const String malaCountReset = 'mala_count_reset';

  // Chat list and prayer list
  static const String chatsListOpened = 'chats_list_opened';
  static const String prayerRequestsOpened = 'prayer_requests_opened';

  // Event creation (admins)
  static const String groupEventPublished = 'group_event_published';
  static const String groupEventDraftSaved = 'group_event_draft_saved';
  static const String groupEventDeleted = 'group_event_deleted';

  // Calendar
  static const String calendarViewed = 'calendar_viewed';
  static const String calendarTypeChanged = 'calendar_type_changed';
  static const String personalEventCreated = 'personal_event_created';
  static const String personalEventUpdated = 'personal_event_updated';
  static const String personalEventDeleted = 'personal_event_deleted';

  // Entry points (plan §5.1)
  static const String deepLinkOpened = 'deep_link_opened';
  static const String installAttributed = 'install_attributed';
  static const String pushNotificationOpened = 'push_notification_opened';
  static const String localNotificationOpened = 'local_notification_opened';
  static const String notificationPermissionPrompted =
      'notification_permission_prompted';
  static const String notificationPermissionGranted =
      'notification_permission_granted';
  static const String notificationPermissionDenied =
      'notification_permission_denied';

  // Onboarding (§5.2)
  static const String onboardingStarted = 'onboarding_started';
  static const String onboardingStepViewed = 'onboarding_step_viewed';
  static const String onboardingLanguageSelected =
      'onboarding_language_selected';

  // Auth and guest conversion (§5.3)
  static const String authLoginStarted = 'auth_login_started';
  static const String loginPromptShown = 'login_prompt_shown';
  static const String loginPromptDismissed = 'login_prompt_dismissed';

  // Home (§5.4)
  static const String homeViewed = 'home_viewed';
  static const String tabViewed = 'tab_viewed';
  static const String homeCardTapped = 'home_card_tapped';
  static const String verseLiked = 'verse_liked';
  static const String verseUnliked = 'verse_unliked';
  static const String verseCommentPosted = 'verse_comment_posted';
  static const String seriesEnrolled = 'series_enrolled';

  // Me page
  static const String meItemTapped = 'me_item_tapped';

  // Sharing, cross-cutting (§5.15): one event, `surface` says what was shared
  static const String contentShared = 'content_shared';

  // Practice tab and routine (§5.5)
  static const String routineItemOpened = 'routine_item_opened';

  // Plans, day level (§5.6)
  static const String planDayViewed = 'plan_day_viewed';
  static const String planTaskCompleted = 'plan_task_completed';
  static const String planTaskUncompleted = 'plan_task_uncompleted';
  static const String planSubtaskCompleted = 'plan_subtask_completed';
  static const String planCompleted = 'plan_completed';

  // Reader (§5.7)
  static const String readerOpened = 'reader_opened';
  static const String readerPageLoaded = 'reader_page_loaded';
  static const String readerSessionEnded = 'reader_session_ended';
  static const String readerActionTapped = 'reader_action_tapped';

  // Mala sessions (§5.9)
  static const String malaSessionStarted = 'mala_session_started';
  static const String malaSessionEnded = 'mala_session_ended';
  static const String malaModeChanged = 'mala_mode_changed';
  static const String malaOfflineRoundsAdded = 'mala_offline_rounds_added';
  static const String malaSyncFailed = 'mala_sync_failed';

  // Timer (§5.10)
  static const String timerStarted = 'timer_started';
  static const String timerCompleted = 'timer_completed';
  static const String timerDiscarded = 'timer_discarded';
  static const String timerCreated = 'timer_created';
  static const String timerUpdated = 'timer_updated';
  static const String timerDeleted = 'timer_deleted';

  // Settings (§5.13)
  static const String contentLanguageChanged = 'content_language_changed';
  static const String uiLanguageChanged = 'ui_language_changed';
  static const String notificationSettingChanged =
      'notification_setting_changed';
  static const String traditionsChanged = 'traditions_changed';

  // Practice / Routine
  static const String routineSaved = 'routine_saved';

  // Mala
  static const String malaScreenOpened = 'mala_screen_opened';
  static const String malaRoundCompleted = 'mala_round_completed';
  static const String malaMantraSwitched = 'mala_mantra_switched';

  // Group chat
  static const String groupChatOpened = 'group_chat_opened';
  static const String directChatOpened = 'direct_chat_opened';
  static const String directMessageSent = 'direct_message_sent';
  static const String groupMessageSent = 'group_message_sent';
  static const String groupMessageDeleted = 'group_message_deleted';
  static const String groupMessageReacted = 'group_message_reacted';
  static const String groupMessageReplied = 'group_message_replied';
  static const String groupMessageReported = 'group_message_reported';

  // Prayer requests
  static const String prayerRequestCreated = 'prayer_request_created';
  static const String prayerRequestPrayed = 'prayer_request_prayed';
  static const String prayerRequestCompleted = 'prayer_request_completed';
  static const String prayerSupportersViewed = 'prayer_supporters_viewed';
  static const String prayerRandomOpened = 'prayer_random_opened';

  // Help & contact, which is also where feedback is sent from
  static const String helpContactOpened = 'help_contact_opened';
  static const String helpMessageSent = 'help_message_sent';
}

/// Shared analytics property keys.
abstract final class AnalyticsProperties {
  // Auth
  static const String method = 'method';
  static const String reason = 'reason';
  static const String reasonCode = 'reason_code';
  static const String reasonDetail = 'reason_detail';
  static const String isGuest = 'is_guest';

  // Plans
  static const String planId = 'plan_id';
  static const String planName = 'plan_name';
  static const String dayNumber = 'day_number';
  static const String totalDays = 'total_days';
  static const String completedDays = 'completed_days';

  // Routine
  static const String blockCount = 'block_count';
  static const String itemCount = 'item_count';

  // Group chat
  /// The sangha; PostHog attaches `$groups` per event from it.
  static const String groupId = 'group_id';
  static const String roomId = 'room_id';
  static const String messageId = 'message_id';
  static const String parentMessageId = 'parent_message_id';
  static const String isReply = 'is_reply';
  static const String emoji = 'emoji';
  static const String action = 'action';
  static const String source = 'source';

  // Prayer requests
  static const String prayerCount = 'prayer_count';

  // Help & contact
  static const String topic = 'topic';
  static const String imageCount = 'image_count';

  // Series
  static const String seriesId = 'series_id';
  static const String seriesTitle = 'series_title';
  static const String planCount = 'plan_count';
  static const String bookmarked = 'bookmarked';

  // Group events
  static const String eventId = 'event_id';
  static const String eventTitle = 'event_title';
  static const String eventFormat = 'event_format';
  static const String isRecurring = 'is_recurring';
  static const String participation = 'participation';
  static const String target = 'target';
  static const String linkType = 'link_type';
  static const String session = 'session';
  static const String videoId = 'video_id';

  // Search
  static const String queryLength = 'query_length';
  static const String resultCount = 'result_count';

  // Entry points
  static const String routeKind = 'route_kind';
  static const String targetId = 'target_id';
  static const String sessionType = 'session_type';
  static const String sourceId = 'source_id';
  static const String appState = 'app_state';
  static const String type = 'type';
  static const String minutesAfterScheduled = 'minutes_after_scheduled';
  static const String os = 'os';

  // Onboarding
  static const String step = 'step';
  static const String stepIndex = 'step_index';
  static const String uiLanguage = 'ui_language';
  static const String durationMs = 'duration_ms';
  static const String traditionsCount = 'traditions_count';
  static const String isFirstReport = 'is_first_report';

  // Auth
  static const String isNewUser = 'is_new_user';
  static const String feature = 'feature';
  static const String loginAttempted = 'login_attempted';

  // Home / sharing
  static const String hasRoutine = 'has_routine';
  static const String streakCurrent = 'streak_current';
  static const String surface = 'surface';
  static const String format = 'format';
  static const String tab = 'tab';
  static const String section = 'section';
  static const String verseId = 'verse_id';

  // Me page
  static const String item = 'item';

  // Routine
  static const String itemType = 'item_type';
  static const String itemId = 'item_id';
  static const String blockIndex = 'block_index';
  static const String minutesFromBlockTime = 'minutes_from_block_time';
  static const String sessionTypes = 'session_types';
  static const String reminderEnabled = 'reminder_enabled';
  static const String earliestBlockHour = 'earliest_block_hour';

  // Plans, day level
  static const String isEnrolled = 'is_enrolled';
  static const String isToday = 'is_today';
  static const String isMissed = 'is_missed';
  static const String taskId = 'task_id';
  static const String taskType = 'task_type';
  static const String isOnTime = 'is_on_time';
  static const String daysElapsed = 'days_elapsed';
  static const String daysCompleted = 'days_completed';
  static const String daysSinceEnrolled = 'days_since_enrolled';

  // Reader
  static const String textId = 'text_id';
  static const String textTitle = 'text_title';
  static const String language = 'language';
  static const String versionId = 'version_id';
  static const String script = 'script';
  static const String layout = 'layout';
  static const String entrySegment = 'entry_segment';
  static const String pageNumber = 'page_number';
  static const String segmentCount = 'segment_count';
  static const String loadMs = 'load_ms';
  static const String durationSeconds = 'duration_s';
  static const String pagesLoaded = 'pages_loaded';
  static const String maxSegmentNumber = 'max_segment_number';
  static const String segmentsTotal = 'segments_total';
  static const String pctReached = 'pct_reached';

  // Mala
  static const String presetId = 'preset_id';
  static const String groupAccumulatorId = 'group_accumulator_id';
  static const String mantraId = 'mantra_id';
  static const String mantraName = 'mantra_name';
  static const String mode = 'mode';
  static const String startingTotal = 'starting_total';
  static const String rounds = 'rounds';
  static const String secondsSinceLastRound = 'seconds_since_last_round';
  static const String beadsCounted = 'beads_counted';
  static const String roundsCompleted = 'rounds_completed';
  static const String input = 'input';
  static const String from = 'from';
  static const String to = 'to';
  static const String fromPresetId = 'from_preset_id';
  static const String toPresetId = 'to_preset_id';
  static const String via = 'via';
  static const String pendingDelta = 'pending_delta';

  // Timer
  static const String wasBackgrounded = 'was_backgrounded';
  static const String pauseCount = 'pause_count';
  static const String elapsedSeconds = 'elapsed_s';
  static const String timerKind = 'timer_kind';
  static const String ambientSoundId = 'ambient_sound_id';
  static const String hasAmbientSound = 'has_ambient_sound';
  static const String status = 'status';
  static const String utmSource = 'utm_source';
  static const String utmMedium = 'utm_medium';
  static const String utmCampaign = 'utm_campaign';
  static const String acquisitionChannel = 'acquisition_channel';
  static const String acquisitionCampaign = 'acquisition_campaign';
  static const String acquisitionAdGroup = 'acquisition_ad_group';
  static const String acquisitionAdCreative = 'acquisition_ad_creative';
  static const String pctComplete = 'pct_complete';

  // Settings
  static const String setting = 'setting';
  static const String enabled = 'enabled';

  // Connect and groups
  static const String subTab = 'sub_tab';
  static const String groupType = 'group_type';
  static const String followedGroupCount = 'followed_group_count';
  static const String isLive = 'is_live';
  static const String collectionId = 'collection_id';
  static const String completedCount = 'completed_count';
  static const String accumulatorId = 'accumulator_id';
  static const String postId = 'post_id';
  static const String position = 'position';
  static const String hasMedia = 'has_media';

  /// PostHog's per-event group map, e.g. `{sangha: <group id>}`.
  static const String groups = r'$groups';

  /// Person properties carried on an event: `$set` overwrites, `$set_once`
  /// keeps the first value.
  static const String personSet = r'$set';
  static const String personSetOnce = r'$set_once';

  // Push
  static const String notificationId = 'notification_id';
  static const String campaign = 'campaign';

  // Audio, video and settings
  static const String value = 'value';
  static const String listenedS = 'listened_s';
  static const String speed = 'speed';
  static const String repeat = 'repeat';
  static const String completed = 'completed';
  static const String followingS = 'following_s';
  static const String pausedCount = 'paused_count';
  static const String resumedCount = 'resumed_count';

  // Collections, events, calendar
  static const String itemsAdded = 'items_added';
  static const String itemsRemoved = 'items_removed';
  static const String reordered = 'reordered';
  static const String renamed = 'renamed';
  static const String imageChanged = 'image_changed';
  static const String hasImage = 'has_image';
  static const String hasUnread = 'has_unread';
  static const String scope = 'scope';
  static const String isEdit = 'is_edit';
  static const String hasPlan = 'has_plan';
  static const String hasSeries = 'has_series';
  static const String hasCollection = 'has_collection';
  static const String hasAccumulation = 'has_accumulation';
  static const String calendarType = 'calendar_type';
  static const String repeats = 'repeats';

  // Person properties
  static const String signupMethod = 'signup_method';
  static const String contentLanguage = 'content_language';
  static const String firstAppVersion = 'first_app_version';
  static const String onboardingCompletedAt = 'onboarding_completed_at';
  static const String signedUpAt = 'signed_up_at';
  static const String backendUserId = 'backend_user_id';

  /// The tradition codes the account follows. Sent inside `$set` only, never
  /// as an event property: see `TraditionAnalytics`.
  static const String traditions = 'traditions';
}

/// PostHog group types; a sangha is a WeBuddhist group.
abstract final class AnalyticsGroupTypes {
  static const String sangha = 'sangha';
}
