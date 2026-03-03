# The Mirror — App Brief for Claude Code

## Overview

**Name:** The Mirror  
**Subtitle:** a timer for presence and awareness  
**Platform:** iOS (native Swift/SwiftUI)  
**Distribution:** TestFlight first, then App Store  
**Audience:** Students of Dzogchen teacher Namkhai Norbu, and practitioners of lucid dreaming  

The Mirror is a minimalist iOS app that trains presence and awareness through adaptive notification timing. The mechanic is simple: a notification arrives with a quote and two action buttons. The user responds. The next notification is scheduled based on the response using exponential backoff. The goal is maximum impact with minimum device interaction.

---

## Core Mechanic

An adaptive notification timer with three response states:

- **Present** (explicit tap) — interval doubles
- **Distracted** (explicit tap) — interval halves
- **Ignored** (no response within 5 minutes) — interval reduced by 25%

### Algorithm

```
next_interval = base_interval × multiplier
next_interval = next_interval × random(0.75, 1.25)  // ±25% randomness
next_interval = clamp(next_interval, 5 minutes, 90 minutes)
next_interval = floor(next_interval)  // round down to nearest minute
```

**Multipliers:**
- Present: ×2.0
- Distracted: ×0.5
- Ignored (5 min timeout): ×0.75

**Boundaries:**
- Minimum interval: 5 minutes
- Maximum interval: 90 minutes
- Default starting interval: 5 minutes

**Session reset:** Every time the user taps Stop and then Start, the interval resets to 5 minutes.

**Day boundary:** Same as session reset — if the app is stopped and restarted the next day, interval resets to 5 minutes.

**Ignored notification rule:** If the user does not respond within 5 minutes of a notification arriving, it is automatically counted as Distracted (×0.75 penalty) and the next notification is scheduled accordingly.

---

## Notifications

### Structure
- **Title:** The Mirror
- **Body:** A rotating quote from the active quote set (see Quote Sets)
- **Action buttons:** Two buttons visible on long-press or swipe — **Present** and **Distracted**
- **No question text** — the quote itself is the prompt. No additional question is displayed.

### Sound
- Default: Tibetan singing bowl strike (custom audio file bundled with app, max 30 seconds)
- Option: Silent / haptic only
- User can toggle between these in Settings

### iOS Implementation Notes
- Use `UNUserNotificationCenter` for scheduling
- Use `UNNotificationCategory` with two `UNNotificationAction` buttons: "Present" and "Distracted"
- On action tap, app wakes briefly in background to compute next interval and schedule next notification
- Notification permission must be requested on first launch with a brief explanation of why

---

## Quote Sets

Two built-in sets. Custom quotes are a future feature (not v1).

### Set 1: The Mirror
Quotes from Namkhai Norbu's text *The Mirror: Advice on the Presence of Awareness*:

1. "Spur on the horse of awareness with the whip of presence"
2. "A mind free of distraction is the basis of all paths"
3. "Not getting distracted means being present in everything we do"
4. "If awareness is not aroused by presence, it cannot function"
5. "There is nothing higher or clearer to seek beyond the recognition of our State of pure presence"
6. "The moment the thoughts are recognized, they relax into their own condition"
7. "The calm state is the essence of the mind and movement is its energy"
8. "To meditate only means to maintain presence — there is nothing on which to meditate"
9. "In every case, the point is to remain with the presence of the actual recognition of whatever we perceive"
10. "We've got eyes with which to see each other, but we need a mirror to see ourselves"

### Set 2: Dream Yoga
Quotes oriented toward lucid dreaming / reality checking. Put some placehoder quotes for now.

### Quote Rotation
Quotes rotate sequentially or randomly — developer's discretion, but should not repeat the same quote twice in a row.

---

## App Screen

### Launch
- Brief welcome screen with the app name and subtitle that fades out after ~1.5 seconds
- No interaction required — fades directly into the Settings screen

### Settings Screen (the only screen)

Three controls, one button:

1. **Start / Stop button** — prominent, clear state indicator (is the timer running or not?)
2. **Quote Set selector** — toggle or segmented control: The Mirror / Dream Yoga
3. **Sound selector** — toggle or segmented control: Bowl / Silent

No session history. No statistics. Nothing else.

### Aesthetic
Minimal. The interface should not compete with the practice. Warm, calm, unhurried. Inspired by the app icon (Tibetan melong mirror illustration, gold line art on cream/off-white background). Typography and color should reflect this — nothing clinical or productivity-app-like.

---

## App Icon

logo is in logo.png

---

## Technical Notes

### Notification Scheduling Chain
The core challenge: when a user taps Present or Distracted, the app must:
1. Wake briefly in the background (triggered by the notification action)
2. Compute the next interval using the algorithm above
3. Schedule the next `UNUserNotificationRequest`
4. Persist the current interval to UserDefaults in case of app restart

If the background wakeup is killed by iOS before scheduling completes, the chain breaks. Implement a fallback: on app foreground, check if a notification is pending. If not (and the timer is supposed to be running), schedule one immediately.

### Persistence
Store in UserDefaults:
- Current interval (minutes)
- Timer running state (bool)
- Active quote set
- Sound preference
- Current quote index

### Audio
Custom notification sound must be bundled as a `.caf`, `.aiff`, or `.wav` file (iOS requirement). A high-quality singing bowl strike recording should be included. File must be under 30 seconds.

### Background Execution
- Do not use background fetch or background processing — unnecessary for this app
- Rely solely on `UNUserNotificationCenter` for the timing mechanism
- The notification action handler is sufficient to maintain the chain

---

## What Is NOT in v1

- Custom quote entry by user
- Session history / statistics
- Home screen widget
- Apple Watch support
- Pause / Do Not Disturb (users should use iOS Focus modes for this)
- Dream Yoga mode question variations
- Multiple sound options beyond bowl / silent

---

## Distribution

- **Phase 1:** Install on developer's own iPhone via Xcode for testing
- **Phase 2:** TestFlight — share with Dzogchen community students
- **Phase 3:** App Store submission

**Privacy:** App collects no user data. Privacy nutrition label: all sections = "Data Not Collected."

---

## Development Approach

- Language: Swift / SwiftUI
- Minimum iOS target: iOS 16 (broad device support)
- No third-party dependencies if avoidable
- Build incrementally — get notifications working first, then the backoff logic, then the UI
- Test notifications on a real device (not simulator — notifications behave differently in simulator)

---

## First Steps for Claude Code

1. Create a new SwiftUI iOS project named "TheMirror"
2. Implement `UNUserNotificationCenter` setup and permission request
3. Implement notification categories with Present / Distracted action buttons
4. Implement the notification action handler (background wakeup)
5. Implement the backoff algorithm
6. Implement the ignored-notification timeout (5 minute fallback to Distracted)
7. Implement UserDefaults persistence
8. Build the Settings screen UI
9. Implement the welcome fade screen
10. Add singing bowl audio asset and sound preference toggle
11. Add quote sets and rotation logic
12. Test end-to-end on real device
