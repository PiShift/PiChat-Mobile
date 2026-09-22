import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/application/message_provider.dart';

/// Which voice note follows which, so a run of them plays through.
///
/// Only *consecutive* notes are linked. A text message, an image or a call
/// between two notes ends the run: the agent asked for the next voice note,
/// not for everything below it. Direction is deliberately ignored — a customer
/// note answered by an agent note is still one exchange to listen through.
class VoiceChain {
  const VoiceChain({this.autoPlay});

  /// The note that should start playing now, if any.
  ///
  /// Only used when the shared player does not know where the next note's file
  /// is; otherwise it starts it itself, without needing a bubble on screen.
  final String? autoPlay;

  VoiceChain copyWith({String? autoPlay, bool clearAutoPlay = false}) {
    return VoiceChain(autoPlay: clearAutoPlay ? null : (autoPlay ?? this.autoPlay));
  }
}

/// The links for one conversation, derived from its messages.
///
/// Computed rather than pushed. It used to be handed in from the thread's
/// itemBuilder via a post-frame callback, which mutated a provider while the
/// frame was still settling — during navigation that reached elements already
/// being torn down, which is the `_lifecycleState != defunct` assertion.
/// Deriving it means nothing is written during a build at all.
final voiceLinksProvider = Provider.family<Map<String, String>, int>(
  (ref, contactId) {
    final messages = ref.watch(messagesProvider(contactId)).value;

    return messages == null ? const {} : voiceLinksFrom(messages);
  },
);

/// Link each voice note to the one directly after it.
///
/// Anything that is not a voice note ends the run, so a note above a photo does
/// not roll on into one below it. Direction is not considered: an exchange of
/// notes back and forth is still one thing to listen to.
Map<String, String> voiceLinksFrom(List<Chat> messages) {
  final links = <String, String>{};

  String? previous;

  for (final message in messages) {
    final id = voiceMediaId(message);

    if (id == null) {
      previous = null;
      continue;
    }

    if (previous != null) links[previous] = id;

    previous = id;
  }

  return links;
}

/// The media id of [message] when it is a recorded voice note.
///
/// Mirrors what the bubble treats as a voice note: WhatsApp's own `voice` flag,
/// or an opus/ogg container, with .m4a covering what iPhones record before the
/// server converts it.
String? voiceMediaId(Chat message) {
  final media = message.media;

  if (media == null) return null;

  final block = (message.metadata ?? const <String, dynamic>{})['audio'];

  final type = media.type?.toLowerCase() ?? '';
  final path = media.path?.toLowerCase() ?? '';

  final isVoice = (block is Map && block['voice'] == true) ||
      type.contains('ogg') ||
      type.contains('opus') ||
      type == 'audio/mp4' ||
      path.endsWith('.ogg');

  return isVoice ? media.id.toString() : null;
}

class VoiceChainNotifier extends StateNotifier<VoiceChain> {
  VoiceChainNotifier() : super(const VoiceChain());

  /// Ask for [mediaId] to start playing.
  void requestAutoPlay(String mediaId) {
    state = state.copyWith(autoPlay: mediaId);
  }

  /// The bubble has taken the request, so it must not fire again — otherwise
  /// pausing the note it just started would immediately restart it.
  void consume(String mediaId) {
    if (state.autoPlay != mediaId) return;

    state = state.copyWith(clearAutoPlay: true);
  }

  /// Stop the run — the agent pressed pause, or left the thread.
  void cancel() {
    if (state.autoPlay == null) return;

    state = state.copyWith(clearAutoPlay: true);
  }

}

final voiceChainProvider =
    StateNotifierProvider<VoiceChainNotifier, VoiceChain>(
  (ref) => VoiceChainNotifier(),
);
