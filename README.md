# VoiceBind addon 0.4.1

0.4.1: the helper key overrides are only rewritten when they differ from what is bound. Setting an override fires UPDATE_BINDINGS itself, so 0.4.0 rebound its five keys on every UPDATE_BINDINGS, which kept that event going once per frame for every addon listening to it.

Use with `Utils\VoicePad\VoicePad.exe` (VoiceBind). Update/restart the companion and `/reload` WoW together.

- **244 x 60** collapsed listening/transcription bubble, bottom center by default.
- Click to review text; Shift-drag to move it. Position is saved in `VoicePadDB`.
- OpenWhispr stays in Tap / toggle mode with automatic paste ON. Clipboard retention is unchanged.
- The companion records your shortcut by keypress and your controller combo by button press/release.
- The addon receives native paste, validates the draft, and sends literal SAY only on a helper or manual Enter key event.
- The matching own-player `CHAT_MSG_SAY` event confirms success. Missing confirmation keeps a review draft and never triggers an automatic retry.
- Escape disarms automatic submission while keeping a target for late paste; a second Escape dismisses. Stop OpenWhispr and let transcription finish before dismissing a pending field.
- Focus loss, timeouts, rejected sends, and oversized text preserve drafts for manual review. A delayed start/commit cannot overwrite or submit a recovery draft.
- Internal signals are **Ctrl + Shift + F6-F10**; ordinary F-keys remain unchanged and existing conflicting user bindings are preserved.

Commands: `/vp test` opens a review-only test phrase; `/vp status` checks bindings; `/vp cancel` explicitly discards the draft; `/vp bubbles` enables normal game speech bubbles.

See `Utils\VoicePad\README.md` for full setup, recovery and architectural limits. The 0.4.0 behavior has offline regression tests, but still needs a live microphone-to-game test.
