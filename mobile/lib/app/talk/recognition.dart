/// Compare meanings of whole recognizer alternatives before changing the
/// dialogue. Never combine the intent of one transcript with another's date.
library;

import 'dialog.dart';
import 'nlu.dart';

typedef TalkReading = ({String text, List<Frame> frames});
typedef TalkRecognition = ({TalkReading primary, TalkReading? alternative, Frame? tentative});

class _Interpretation {
  final TalkReading reading;
  final List<Frame> tentative;
  final Map<String, String> commitments;
  final bool relevant;

  _Interpretation._(this.reading, this.tentative, this.commitments, this.relevant);

  factory _Interpretation(String text, TalkNlu nlu, TalkDialog dialog) {
    final found = dialog.contextualFrames(text, nlu.parse([text]));
    final accepted = found.where((f) => f.conf >= TalkNlu.ok).toList(growable: false);
    final tentative = found.where((f) => f.conf >= TalkNlu.ask && f.conf < TalkNlu.ok).toList()
      ..sort((a, b) => b.conf.compareTo(a.conf));
    final commitments = dialog.commitments(text, accepted);
    const social = {'greet', 'thanks', 'closing'};
    final relevant = commitments.isNotEmpty || accepted.any((f) => !social.contains(f.act));
    return _Interpretation._((text: text, frames: accepted), tentative, commitments, relevant);
  }

  bool contradicts(_Interpretation other) {
    for (final entry in commitments.entries) {
      final alternativeValue = other.commitments[entry.key];
      if (alternativeValue != null && alternativeValue != entry.value) return true;
    }
    return false;
  }
}

TalkRecognition readTalkSpeech(TalkNlu nlu, TalkDialog dialog, List<String> alternatives) {
  final texts = alternatives.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet().take(5).toList();
  if (texts.isEmpty) return (primary: (text: '', frames: const []), alternative: null, tentative: null);
  final lead = _Interpretation(texts.first, nlu, dialog);

  // Android orders candidates by recognizer confidence. Only the best few
  // compete, and a strong alternative never replaces a clear reading silently.
  for (final text in texts.skip(1).take(3)) {
    final choice = _Interpretation(text, nlu, dialog);
    if (lead.contradicts(choice) || (!lead.relevant && choice.relevant)) {
      return (primary: lead.reading, alternative: choice.reading, tentative: null);
    }
  }
  final uncertain = lead.reading.frames.isEmpty ? lead.tentative.firstOrNull : null;
  return (primary: lead.reading, alternative: null, tentative: uncertain);
}
