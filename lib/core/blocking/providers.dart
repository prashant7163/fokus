import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blocking_adapter.dart';
import 'channel_blocking_adapter.dart';

/// The app-wide blocking facade. Tests override this with a fake adapter.
final blockingAdapterProvider = Provider<BlockingAdapter>(
  (ref) => ChannelBlockingAdapter(),
);
