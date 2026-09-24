import receive_sharing_intent

/// The "PiChat" entry in the system share sheet.
///
/// No UI of its own: the plugin copies what was shared into the app group
/// and opens PiChat, which shows its own "Send to…" screen where the agent
/// picks the conversation.
class ShareViewController: RSIShareViewController {
  override func shouldAutoRedirect() -> Bool {
    return true
  }
}
