/// The server's answer to "send this number a code".
///
/// Two facts travel together: the handle the server will recognise when the
/// code comes back, and which channel actually carried it — "check WhatsApp"
/// and "check your messages" send a member to different places, and being
/// pointed at the wrong one is indistinguishable from nothing arriving.
///
/// This is a type rather than a `String`, and that is the whole point. The two
/// values used to be packed into `"<id>|<channel>"` so the transport could stay
/// a plain String through the existing use-case signature — and the line that
/// built it read:
///
/// ```dart
/// return channel == null ? id : '\$id|\$channel';
/// ```
///
/// The `$` signs are escaped, so that expression is not interpolation. It is
/// the literal text `$id|$channel`. Every sign-in sent the server the handle
/// `"$id"`, which of course was never stored, and every member got
/// **"Invalid or expired verification ID"** the moment they typed a correct
/// code. The SMS always arrived, so the failure looked like anything but the
/// app: Twilio, the domain move, an expiry, a restart.
///
/// A String can hold a wrong String and no compiler will ever object. Two
/// fields with names cannot be swapped, concatenated, or silently emptied.
class OtpChallenge {
  /// The handle to send back with the typed code.
  final String id;

  /// 'sms' | 'whatsapp' | 'email' | 'log', or null if the server did not say.
  final String? channel;

  const OtpChallenge({required this.id, this.channel});

  @override
  bool operator ==(Object other) =>
      other is OtpChallenge && other.id == id && other.channel == channel;

  @override
  int get hashCode => Object.hash(id, channel);

  @override
  String toString() => 'OtpChallenge($id, $channel)';
}
