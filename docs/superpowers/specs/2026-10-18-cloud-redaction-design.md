# Redacting personal details before third-party cloud models — design

Date: 2026-10-18
Status: approved in chat ("write it up and implement it")

## Intent

With the VoltaSDK integration, a chat can fall back to Anthropic, OpenAI or
Gemini using the user's own API key. Those vendors keep API traffic under their
own policies and nothing on the device can verify what happens to it. Before
any text reaches them, the app replaces anything that could identify the user
(names, places, organizations, contact details, ID numbers…) with placeholders,
and puts the real words back into the reply on the phone.

## Decisions made with the user

- **Scope: third-party vendors only.** The on-device model and Apple Private
  Cloud Compute are unchanged (PCC is stateless, has no privileged access,
  and is verifiable; it keeps today's consent alert).
- **Placeholders, restored on the phone.** "Marta" goes out as `[PERSON_1]`;
  the reply the user reads says "Marta" again.
- **Everything that goes out is redacted**: the prompt, every history turn
  (including the assistant's earlier, already-restored replies and research
  results folded into a prompt), and the instructions.
- **The user sees what is hidden and can let words through** (mockup A): the
  vendor consent alert becomes a sheet that shows the message with hidden
  words highlighted. Tapping a word toggles it between hidden and sent as is.
  The sheet also shows the exact text the vendor receives. Buttons: Send /
  Keep on Device.

## Behavior

1. A call is about to go to a vendor (after Volta's fallback chain picked it).
2. The app detects sensitive spans in all outgoing text and assigns each new
   one a placeholder, stable for the whole conversation
   (`[PERSON_1]` stays Marta in every turn).
3. If the vendor hasn't been allowed in this conversation yet, **or** the call
   contains a detected word the user hasn't reviewed yet, the sheet is shown.
   Otherwise the call goes out redacted with no prompt.
4. Send → the words in the sheet count as reviewed, the vendor is allowed for
   the rest of the conversation, the redacted call goes out. Keep on Device →
   nothing is sent, the newly detected words are forgotten (the chain falls
   through exactly as a consent "no" does today).
5. The reply is restored on the phone before it is shown or stored. Streaming
   holds back a trailing partial placeholder (`[PERS`) until it completes.
6. Other calls waiting for the same vendor while the sheet is up get the same
   answer; after a Send each one is re-checked and only shows a sheet if it
   carries words still unreviewed (e.g. the title call usually doesn't).

### What is detected (all on device, no new dependencies)

| Kind | Placeholder | How |
|---|---|---|
| Person | `PERSON` | `NLTagger` `.nameType` personalName |
| Place | `PLACE` | `NLTagger` placeName |
| Organization (employer, school, hospital…) | `ORG` | `NLTagger` organizationName |
| Street address | `ADDRESS` | `NSDataDetector` `.address` |
| Phone number | `PHONE` | `NSDataDetector` `.phoneNumber` |
| Link / URL | `LINK` | `NSDataDetector` `.link` (non-mailto) |
| Email | `EMAIL` | regex |
| @handle | `HANDLE` | regex |
| Card number | `CARD` | 13–19 digits passing Luhn |
| IBAN | `IBAN` | regex |
| Government / medical IDs (SSN, codice fiscale, UK NI, labelled numbers: MRN, NHS, passport, licence, account, policy, member…) | `ID` | regexes |
| Specific dates (with a year, or numeric d/m/y) | `DATE` | `NSDataDetector` `.date` + filter; relative dates ("this weekend") are kept |
| GPS coordinates | `COORDINATES` | regex |
| IP address | `IP` | regex (IPv4) |
| Secrets (API keys, tokens, `password: …`) | `SECRET` | regexes |

Once a word is known in a conversation, **every** occurrence of it in outgoing
text is replaced (case- and diacritic-insensitive, whole words), even where the
detector would miss it, e.g. inside a restored assistant reply.

A note is appended to the outgoing instructions only when something was
replaced: keep placeholders exactly as written and don't ask what they stand for.

## Architecture

### Fork (VoltaSDK)

`AIConfiguration.outboundFilter: (@Sendable (OutboundCall) async -> OutboundCall?)?`
(also on the provider-list `init`). `OutboundCall` carries `prompt`,
`instructions`, `history`, and the target `provider` and `privacyLevel`. Every
chain walk (buffered, structured, streaming) calls it after a provider is
admitted (so after the privacy disclosure) and sends what it returns; `nil`
skips the provider as `.privacyRestricted`. Default `nil` = unchanged
behavior. Additive and source-compatible, so it can go upstream.

The filter runs for every admitted provider, not only on a privacy downgrade,
so redaction can't be bypassed by a chain whose baseline is already external.

### App

- `Redaction/` feature folder:
  - `RedactionKind` — kinds, placeholder prefixes, display names.
  - `SensitiveTextDetector` — pure: text → `[DetectedSpan]`.
  - `RedactionSession` — value type: entities (placeholder, original, kind,
    revealed, reviewed), `redact(_:)`, `restore(_:)`,
    `restoreForDisplay(partial:)`, preview segments.
- `CloudConsentCoordinator`:
  - `request(_ downgrade:)` keeps today's flow for PCC. For vendor
    destinations it returns `true` without prompting, because the filter is
    where vendor consent is enforced (it needs the text to show the sheet).
  - New `review(_ call:) async -> OutboundCall?`, wired as the outbound
    filter. Pass-through for on-device and PCC; `nil` for an external
    provider the app can't describe; redact + maybe prompt for vendors.
  - Owns the conversation's `RedactionSession`; `resetConversationGrants()`
    clears it (new chat / resumed chat).
  - `ConsentRequest` gains an optional review payload; `toggleReveal` edits it.
- `CloudConsentAlertModifier` shows the existing alert for PCC and a new
  `RedactionReviewSheet` for vendors.
- `ConversationViewModel` restores replies whose `privacyLevel` is
  `.external` (buffered, streaming, title — the title call moves to
  `respondDetailed`).

### State lifetime (changed from the chat playback — my call)

The session lives in memory for the conversation only, not on disk. Stored
messages keep the real words (replies are restored on arrival) and every send
re-redacts the whole history, so placeholders are always consistent within a
call and nothing ever needs restoring later. Losing the session (new chat,
resumed chat, relaunch) only means the user reviews the words again. That's
the safe direction.

## My calls (not discussed)

- Uncertain detections are hidden (unhiding is one tap; a leak can't be undone).
- The review sheet shows for new words even when the vendor is "always
  allowed": always-allow covers consent, not the list of hidden words.
- The preview shows the prompt as sent (including PubMed evidence when the
  research path built it). Words found only in earlier messages appear as a
  separate "From earlier in this chat" row.

## Non-goals / known limits

- No detector catches everything: nicknames ("Nonna"), misspellings, lowercase
  names, and contextual clues ("the only Italian dentist in my village") can
  slip through. Redaction is a layer on top of consent, not a guarantee.
- Licence plates and postcodes outside an address aren't detected.
- PubMed / OpenFDA / ClinicalTrials search terms (sent to public APIs, not
  LLMs) are out of scope.
- `NLTagger` name recognition is best in English; other languages fall back
  to the pattern-based kinds.
