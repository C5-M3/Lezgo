# Lezgo User Stories

- **Challenge statement:** Make group road trips feel together.
- **App statement:** An app that helps a group of cars stay coordinated during casual trips by sharing a dynamic route guided by a lead driver.

Every story title follows one format: **As a [user], I want [something] so that [benefit].**
The lo-fi screens attached to each GitHub issue are the source of truth for screens and copy. Anything that has no lo-fi yet is marked **Needs lo-fi**.
Each story becomes one parent issue in the GitHub Project; its tasks become sub-issues.

## Stories

| ID | Story |
| --- | --- |
| [US-01](#us-01) | As a leader, I want to plan a route with a start point, checkpoints and a destination so that the group knows where we are going. |
| [US-02](#us-02) | As a member, I want to join a trip with a room code or an invite link so that my car is added to the group in seconds. |
| [US-03](#us-03) | As a leader or member, I want to see my unfinished trip when I open the app so that I can continue it or start a new one. |
| [US-04](#us-04) | As a leader or member, I want a Trip Room that shows the route, who joined and who is ready so that the group can gather before leaving. |
| [US-05](#us-05) | As a leader, I want to manage the group and start the trip for everyone so that the right cars leave together. |
| [US-06](#us-06) | As a leader or member, I want to see the shared route, every car and silent alerts on one map so that we stay together on the road. |
| [US-07](#us-07) | As a leader or member, I want to arrive, continue, leave or end the trip clearly so that nobody is ever stuck in a trip. |

---

## Shared rules

### Roles

There are only two roles.

| Role | Who |
| --- | --- |
| **Leader** | The one person who leads the trip: plans and changes the route, manages the group, starts and ends the trip. Exactly one per trip. |
| **Member** | Everyone else in the trip. |

- **One car = one person = one phone.** Only one person per car joins the trip, usually the driver. Passengers in that car do not join.
- A member who is driving alone is simply a member. There is no separate "driver" role.
- "Leader or member" in a story means everyone in the trip.

### Words (use them everywhere: UI, code, tests)

| Term | Meaning |
| --- | --- |
| Trip | One group journey. One room code and one route at a time. |
| Trip Room | The waiting room before the trip starts. |
| Room code | 6 digits, numbers only (`897654`), typed with the number pad. |
| Invite link | `lezgo://join?code=897654` |
| Start point, checkpoint, destination | The three kinds of waypoint: 1 start point, 0 or more checkpoints, 1 destination. |
| Ready | The member's car is within 100 m of the start point (detected automatically). |
| Arrived | The member's car is within 20 m of the destination. |
| Start Trip / New Trip / Continue Trip / New Destination / End Trip / Exit Trip | The only names for these actions. |

All user-facing copy is English and goes through the String Catalog.

### Trip status

```
LOBBY ──Start Trip──► IN_TRIP ──End Trip / leader leaves──► ENDED
  ▲                      │
  └───New Destination────┘
LOBBY ──leader leaves──► CANCELLED
```

- The leader owns the trip. When the leader leaves on purpose (Exit, New Trip, End Trip), the trip ends for everyone, after a warning, like "End meeting for all" in Zoom. To leave without ending it, the leader hands over the lead first.
- A trip can be joined in `LOBBY` (opens the Trip Room) and `IN_TRIP` (late joiner, opens the map). `ENDED` and `CANCELLED` reject joins.

### Data model

| Entity | Fields | Notes |
| --- | --- | --- |
| `Trip` | `id`, `roomCode`, `status`, `leaderParticipantID`, `currentWaypointIndex`, `routeVersion`, `createdAt`, `startedAt`, `endedAt` | The leader is stored **only** here, so there can never be two leaders. |
| `Waypoint` | `id`, `tripID`, `orderIndex`, `kind` (`start`, `checkpoint`, `destination`), `name`, `latitude`, `longitude` | Order: start point `0`, checkpoints `1…n`, destination `n + 1`. Visited when `orderIndex < Trip.currentWaypointIndex`. |
| `Participant` | `id`, `tripID`, `userRecordID`, `displayName`, `carDescription`, `latitude`, `longitude`, `speedKmh`, `motionState` (`driving`, `stopped`), `alert` (`none`, `offRoute`, `passedCheckpoint`, `aheadOfLeader`), `lastSeenAt` | One record per person (= per car). `id` is the CloudKit record name; `userRecordID` is the iCloud user, unique per trip. Leader when `id == Trip.leaderParticipantID`, otherwise member. |
| `Route` | `id`, `tripID`, `version`, `polyline` | The road path. A new version replaces the old one. |

### Sync and timing

- Each phone sends its location **every 1 second** while the trip is open, moving or stopped. Sharing starts in the Trip Room and runs in the background during the trip ("Always" location permission, asked with a clear reason).
- Every phone shows another car's new position and any status change (join, leave, remove, start, end, new route, new leader) **within 2 seconds**. Start Trip reaches every phone **within 1 second**. Phones listen to a CloudKit subscription and also fetch every 1 second while the app is open; silent pushes alone are not enough because iOS delays and drops them.
- Arrival and checkpoints use a **20 m radius**, checked on every 1-second location update instead of an iOS region geofence (region geofences fire late or not at all for a radius this small). At highway speed a car moves about 28 m per second, so a car also counts as arriving when the line between two updates passes within 20 m of the point.
- A person is **offline** when `lastSeenAt` is older than **2 minutes**.
- Alerts on the road are visual only. No sound, no vibration.
- Every destructive action asks for confirmation, and every flow has a way out.

### Not in scope (no lo-fi, not in the app statement)

Trip recap, trip history, SOS button, prolonged-stop alerts, sound notifications, "Cancel Trip" menu item, Apple CarPlay.

---

<a id="us-01"></a>
## US-01 — As a leader, I want to plan a route with a start point, checkpoints and a destination so that the group knows where we are going.

**Lo-fi:** `HOME`, `SEARCH ROUTE`, `ADD CHECKPOINT`, `PREVIEW ROUTE Copy`, `PREVIEW ROUTE CHECKPOINT Copy`, `EDIT ROUTE`

### Rules

- Whoever creates the trip becomes its leader.
- The planner opens from the search bar on Home ("Where do you want to travel?").
- The start point is the current location by default and can be changed by search.
- Search uses MapKit suggestions with distance. A picked result stores its name and coordinate.
- Checkpoints: 0 or more; add with "+ Add Stop", remove, and reorder with the drag handle.
- The preview map shows the road route and travel time before saving.
- Saving creates the trip in `LOBBY` with a unique 6-digit room code and opens the Trip Room.
- The same planner is reused to change the route on the road and to plan a New Destination (US-06, US-07).

### Acceptance criteria

```gherkin
Feature: Plan a route

  Scenario: Pick a destination from search
    Given I am on Home
    When I tap "Where do you want to travel?" and type "Pakuwon"
    Then I see matching places with their distance
    When I pick "Pakuwon mall"
    Then the preview shows a route from my current location to "Pakuwon mall"

  Scenario: Add, reorder and remove checkpoints
    Given the preview goes from "Jl. Surabaya no 203" to "Pakuwon mall"
    When I tap "Add Stop" and pick "Ciputra World"
    Then "Ciputra World" is a checkpoint between the start point and the destination
    When I drag "Ciputra World" below "Pakuwon mall"
    Then "Ciputra World" becomes the destination and the route is recalculated
    When I remove a checkpoint
    Then the route is recalculated without it

  Scenario: Save and open the Trip Room
    Given the route has a start point and a destination
    When I save the route
    Then a trip in LOBBY is created with a 6-digit room code
    And I am the leader in the Trip Room

  Scenario: No search results
    When I search for "xqzv"
    Then I see "No places found. Check the spelling."

  Scenario: No road route
    Given MapKit cannot find a road route between the points
    Then I see "We couldn't find a route. Try another place."
    And saving is disabled
```

### Data

| Input | Entity | Fields |
| --- | --- | --- |
| Start point / checkpoints / destination | `Waypoint` | `kind`, `orderIndex`, `name`, `latitude`, `longitude` |
| Road path | `Route` | `version: 1`, `polyline` |
| New trip | `Trip` | `status: LOBBY`, `roomCode`, `leaderParticipantID`, `currentWaypointIndex: 0`, `routeVersion: 1` |

---

<a id="us-02"></a>
## US-02 — As a member, I want to join a trip with a room code or an invite link so that my car is added to the group in seconds.

**Lo-fi:** `HOME`, `JOIN ROUTE`, `JOIN ROUTE KEYBOARD SHOW`

### Rules

- "Enter room code" opens from the join button on Home. The field uses the number pad: digits only, exactly 6. "Enter" is disabled until 6 digits are typed.
- An invite link opens the same dialog with the code filled in.
- No form. My name and car description come from my saved profile (US-04); the first time, the name is "Member" plus the last 4 characters of my iCloud user ID.
- `LOBBY` → I join as a member and the Trip Room opens. `IN_TRIP` → I join as a late member and the map opens.
- `ENDED` or `CANCELLED` → join is rejected.
- Joining the same trip again with the same iCloud account returns to my existing record; it never adds a second car.

### Acceptance criteria

```gherkin
Feature: Join a trip

  Scenario: Join a trip in the Trip Room
    Given trip "897654" is in LOBBY
    When I enter "897654" and tap "Enter"
    Then I am a member of the trip and the Trip Room opens

  Scenario: Join with an invite link
    When I open "lezgo://join?code=897654"
    Then "Enter room code" shows "897654"
    When I tap "Enter"
    Then the Trip Room opens

  Scenario: Join late
    Given trip "897654" is IN_TRIP
    When I enter "897654" and tap "Enter"
    Then I am a member of the trip and the map opens with the current route

  Scenario: Wrong or closed code
    When I enter "000000" and tap "Enter"
    Then I see "No trip found with this code."
    Given trip "897654" is ENDED
    When I enter "897654" and tap "Enter"
    Then I see "This trip has already ended."

  Scenario: Code not complete
    When I have entered "8976"
    Then "Enter" is disabled

  Scenario: Join twice
    Given I already joined trip "897654"
    When I enter "897654" again
    Then I return to the same trip without a second car

  Scenario: Go back
    When I tap "Back"
    Then I am on Home
```

### Data

| Item | Entity | Fields |
| --- | --- | --- |
| Lookup | `Trip` | `roomCode`, `status` |
| New member | `Participant` | `userRecordID`, `displayName`, `carDescription`, `motionState: stopped` |
| Local pointer | Device | `activeTripID` |

---

<a id="us-03"></a>
## US-03 — As a leader or member, I want to see my unfinished trip when I open the app so that I can continue it or start a new one.

**Lo-fi:** `SPLASH SCREEN`, `Draft road trip`, `Confirm New Trip`

### Rules

- After the splash screen the app checks the device for an active trip. If there is none, Home opens.
- If there is one, the card "You have a trip in progress" shows the start point, destination and people in the trip, with "New Trip" and "Continue Trip". It appears at once from the saved summary; the server status is checked in the background.
- "Continue Trip" opens the Trip Room (`LOBBY`) or the map (`IN_TRIP`).
- "New Trip" asks first, leaves the old trip like Exit (US-07), then opens the planner:
  - Member: "Create a new trip?"
  - Leader: "Create a new trip? Your current trip will end for everyone." The old trip ends for all members.
- If the server says the trip is `ENDED` or `CANCELLED`, the card is removed and Home shows "Your last trip has ended."

### Acceptance criteria

```gherkin
Feature: Resume an unfinished trip

  Scenario: Continue a trip
    Given my device has trip "897654" saved
    When I open the app
    Then I see "You have a trip in progress"
    When I tap "Continue Trip"
    Then the Trip Room opens if the trip is in LOBBY
    And the map opens if the trip is IN_TRIP

  Scenario: Member starts a new trip
    Given I am a member of trip "897654"
    When I tap "New Trip" and confirm "Create"
    Then I leave trip "897654" and the planner opens

  Scenario: Leader starts a new trip
    Given I am the leader of trip "897654" with 2 members
    When I tap "New Trip"
    Then I see "Create a new trip? Your current trip will end for everyone."
    When I tap "Create"
    Then trip "897654" ends and the 2 members see "The leader ended the trip."
    And the planner opens for me

  Scenario: Cancel
    When I tap "New Trip" and then "Cancel"
    Then nothing changes

  Scenario: Saved trip has ended
    Given my device has trip "897654" saved but it is ENDED
    When I open the app
    Then Home opens with "Your last trip has ended."
```

### Data

| Item | Where | Fields |
| --- | --- | --- |
| Pointer and card summary | Device | `activeTripID`, `roomCode`, `startName`, `destinationName`, `memberNames`, `status` |
| Status check | `Trip` | `status` |

---

<a id="us-04"></a>
## US-04 — As a leader or member, I want a Trip Room that shows the route, who joined and who is ready so that the group can gather before leaving.

**Lo-fi:** `TRIP ROOM (LEADER)`, `TRIP ROOM (JOINER)`, `TRIP ROOM (INVITE FRIENDS)`, `TRIP ROOM (INVITE FRIENDS) (JOINER)`

### Rules

**Room**
- "Route Trip" lists the start point, checkpoints and destination.
- "Participants" lists everyone with name and car description; the leader has a crown.
- The list updates within 2 seconds when someone joins, leaves, is removed, edits their profile, or the leader changes.
- The leader sees "Start Trip" and the `...` menu (US-05). Members see "Waiting for others ...".
- Top-left button: Exit (US-07). When the trip starts, every phone moves to the map.

**Invite**
- `+` next to "Participants" opens a sheet with the room code in large text, "or", and "Share Link" (iOS share sheet with the invite link). Leader and members can both invite.

**Edit my name and car** — **Needs lo-fi** (tap my own row → edit sheet)
- I can only edit my own row. Name: 1–30 characters, required. Car description: optional, up to 40 characters ("White Avanza"). Spaces are trimmed.
- Saved on my device and reused next time I join. Not editable during the trip (safety).

**Ready**
- Detected automatically; nobody taps a button.
- Ready = within 100 m of the start point. Unknown location (no permission or offline) = not ready.
- Each row shows a dot and text: green "ready at startpoint" or grey "not ready at startpoint" (never colour alone).
- Not ready never blocks the start; it only adds a warning (US-05).

### Acceptance criteria

```gherkin
Feature: Trip Room

  Background:
    Given trip "897654" is in LOBBY with start point "Universitas Ciputra"
    And leader "Agus" and member "Budi" are in the Trip Room

  Scenario: See the shared plan
    When "Budi" opens the Trip Room
    Then "Budi" sees the route, "Agus" with a crown and "Budi"
    And "Budi" sees "Waiting for others ..."
    And "Agus" sees "Start Trip" and the "..." menu

  Scenario: Someone joins
    When "Citra" joins with the room code
    Then "Agus" and "Budi" see "Citra" within 2 seconds

  Scenario: Invite friends
    When "Budi" taps "+"
    Then "Budi" sees "897654" in large text
    When "Budi" taps "Share Link"
    Then the share sheet opens with "lezgo://join?code=897654"

  Scenario: Edit my name and car
    When "Budi" taps his own row and sets "Budi" and "White Avanza"
    Then everyone sees "White Avanza" on the row of "Budi" within 2 seconds
    And next time "Budi" joins a trip he joins as "Budi" with "White Avanza"

  Scenario: Cannot edit someone else
    When "Budi" taps the row of "Agus"
    Then no edit sheet opens

  Scenario: Empty name
    When "Budi" clears his name
    Then saving is disabled

  Scenario: Arrive at the start point
    Given "Budi" is 2 km away and shows "not ready at startpoint"
    When "Budi" comes within 100 m of "Universitas Ciputra"
    Then "Agus" sees "Budi" as "ready at startpoint" within 2 seconds

  Scenario: No location permission
    Given "Budi" denied location permission
    Then "Budi" shows "not ready at startpoint"
    And "Budi" sees how to turn on location in Settings
```

### Data

| Element | Entity | Fields |
| --- | --- | --- |
| Route | `Waypoint` | `name`, `kind`, `orderIndex` |
| Rows | `Participant` | `displayName`, `carDescription`, `latitude`, `longitude`, `lastSeenAt` |
| Crown | `Trip` | `leaderParticipantID` |
| Saved profile | Device | `displayName`, `carDescription` |

---

<a id="us-05"></a>
## US-05 — As a leader, I want to manage the group and start the trip for everyone so that the right cars leave together.

**Lo-fi:** `TRIP ROOM (EDIT)`, `SLIDE DELETE IF NOT LEADER`, `SLIDE DELETE IF LEADER`, `REMOVE PERSON POP UP ALERT CONFIRM VIA SLIDER`, `SELECT MEMBERS`, `MORE THAN 3 REMOVAL POP UP ALERT CONFIRM`, `SET LEAD IF NOT LEADER VIA SLIDER`, `SET LEAD IF LEADERS IS SELECTED VIA SLIDER`, `POP UP ALERT CONFIRM SET LEADER`, `PICK LEADER`, `LEADER POP UP ALERT CONFIRM`, `LEADER BECOMES JOINER`, `CONFIRM START TRIP`, `CONFIRM START TRIP WHEN NOT ALL MEMBER READY`

### Rules

Only the leader sees these actions, and only in the Trip Room.

**Remove members**
- Swipe a row left → "Kick", or `...` → "Select" → tick rows (or "Select all") → "Remove".
- The leader cannot remove themselves ("Kick" disabled, no checkbox on the leader's row).
- Confirm: "Remove XX from the trip?" or "Remove XX and N others from the trip?" → "Cancel" / "Remove".
- A removed member sees "You were removed from the trip." and returns to Home. They can join again with the code.

**Hand over the lead**
- Swipe a member's row right → "Set Lead", or `...` → "Set leader" → "Pick Your New Leader" → tap a member.
- "Set Lead" is disabled on the leader's own row. "Cancel" on the picker changes nothing.
- Confirm: "Set XX as Trip Leader?" → "Cancel" / "Confirm".
- The crown moves; the new leader gets "Start Trip" and `...`; the old leader becomes a member ("Waiting for others ..."). Saved with a conditional write so two leaders can never exist.
- Handing over is how a leader leaves without ending the trip: hand over, then Exit as a member.

**Start the trip**
- "Start Trip" needs at least one member besides the leader; otherwise it is disabled with "Invite at least one friend to start."
- Everyone ready → "Start trip?". Someone not ready → "Some participants are not yet ready, are you sure you want to start the trip?" → "Cancel" / "Start".
- Start sets the trip to `IN_TRIP` and moves every phone to the map within 1 second.

### Acceptance criteria

```gherkin
Feature: Manage the group and start

  Background:
    Given trip "897654" is in LOBBY with leader "Agus" and members "Budi", "Citra", "Doni", "Eka", "Fajar"

  Scenario: Remove one member by swiping
    When "Agus" swipes "Doni" left, taps "Kick" and confirms "Remove Doni from the trip?"
    Then "Doni" is no longer in Participants
    And "Doni" sees "You were removed from the trip." and returns to Home

  Scenario: Remove several members
    When "Agus" taps "..." and "Select", ticks "Citra", "Doni", "Eka" and "Fajar", and taps "Remove"
    Then "Agus" sees "Remove Citra and 3 others from the trip?"
    When "Agus" taps "Remove"
    Then Participants shows only "Agus" and "Budi"

  Scenario: Cancel a removal
    When "Agus" swipes "Doni" left, taps "Kick" and then "Cancel"
    Then "Doni" stays

  Scenario: Leader cannot remove or hand over to himself
    When "Agus" swipes his own row
    Then "Kick" and "Set Lead" are disabled

  Scenario: Members cannot manage the group
    When "Budi" swipes the row of "Citra"
    Then no action appears

  Scenario: Hand over the lead
    When "Agus" swipes "Budi" right, taps "Set Lead" and confirms "Set Budi as Trip Leader?"
    Then "Budi" has the crown and sees "Start Trip"
    And "Agus" sees "Waiting for others ..."

  Scenario: Hand over from the menu
    When "Agus" taps "..." and "Set leader", taps "Budi" and confirms
    Then "Budi" is the leader

  Scenario: Start with everyone ready
    Given everyone is "ready at startpoint"
    When "Agus" taps "Start Trip" and confirms "Start trip?"
    Then the trip is IN_TRIP
    And every phone shows the map within 1 second

  Scenario: Start with someone not ready
    Given "Budi" is "not ready at startpoint"
    When "Agus" taps "Start Trip"
    Then "Agus" sees "Some participants are not yet ready, are you sure you want to start the trip?"
    When "Agus" taps "Start"
    Then the trip is IN_TRIP

  Scenario: Leader alone
    Given every member left
    Then "Start Trip" is disabled with "Invite at least one friend to start."
```

### Data

| Action | Entity | Effect |
| --- | --- | --- |
| Remove | `Participant` | delete the selected records |
| Hand over | `Trip` | `leaderParticipantID` (conditional save) |
| Start | `Trip` | `status: IN_TRIP`, `startedAt: now`, `currentWaypointIndex: 1` |

---

<a id="us-06"></a>
## US-06 — As a leader or member, I want to see the shared route, every car and silent alerts on one map so that we stay together on the road.

**Lo-fi:** `TRIP COORDINATE`, `TRIP COORDINATE 2`, `MEMBER`, `MEMBER FOCUS`, `FOCUS ON ONE OF CAR`, `FOCUS ON ONE OF CAR 5`, `MEMBER WRONG ROUTE`, `MEMBER WRONG ROUTE FOCUS`, `MEBER PASS CHECKPOINT`, `MEBER PASS CHECKPOINT FOCUS`, `MEBER PRECEDE LEADER`, `MEBER PRECEDE LEADER FOCUS`, `EDGE CASE - OUT OF THE WAY`, `EDGE CASE - OUT OF THE WAY Copy`, `EDIT ROUTE`

### Rules

**Map**
- Shows the route, every checkpoint, the destination and every car.
- Top card: next turn ("200 m, Turn right"). Bottom card: "To [destination]" and time left ("50 min").
- Map buttons: show the whole route, and follow my car.
- Checkpoints follow the leader: when the leader's car is within 20 m of the next checkpoint, it is visited for everyone. The app does not wait for members.

**Car status**
- Tap a car → card with name, status and street ("Driving at Ahmad Yani Street"), and ETA to the destination ("50 min").
- "Driving" while moving; "Stopped" after speed 0 for 30 seconds, shown on the pin by colour **and** icon, without sound.
- Offline cars are faded at their last position and show "Last seen 3 min ago".
- Tap elsewhere or swipe down to close.
- The card has a round "Follow Budi" button: the map stays on that car while it moves. Closing the card returns the map to my car.
- An offline car's card shows no ETA, because its last position is out of date.
- Until the street and ETA are known (or without network), the card shows the status alone ("Driving").

**Formation alerts (members only)**

| Alert | When | Banner | Map |
| --- | --- | --- | --- |
| Off route | More than 100 m from the route for 15 s | "You're out of the way" | Fastest way back to the route |
| Passed checkpoint | Past the next unvisited checkpoint by more than 200 m | "You pass a checkpoint" | Guides back to that checkpoint |
| Ahead of leader | More than 200 m ahead of the leader for 15 s | "You Precede The Leader" | Nothing; slow down or wait |

- Visual only, under the turn card. One banner at a time (off route > passed checkpoint > ahead of leader). It disappears when the condition ends; ⓧ hides it until it happens again.
- Everyone else sees "Car X - Out of The Way" / "Car X - Precede The Leader" and the car highlighted.
- The time and distance limits stop flicker from GPS noise.

**Route changes (leader only)**
- Automatic: the leader more than 100 m off the route for 15 s → new route from the leader through the unvisited checkpoints to the destination.
- Manual: Edit Route opens the planner (US-01) with the leader's position as start point. The button that opens it on the map **needs lo-fi**.
- Each new route has `routeVersion + 1`; members switch within 2 seconds and never go back to an older version.
- **Rerouting notice** (like Apple Maps and Google Maps), visual only, on every phone. **Needs lo-fi.**
  - While the new route is being calculated, the turn card shows "Rerouting…" on the leader's phone.
  - When the new route arrives, every phone shows a banner under the turn card for 5 seconds, then it hides on its own:
    - Leader left the route: "New route · Following Agus" with the new time ("52 min").
    - Leader edited the route: "Route updated by Agus" with the new destination or checkpoint and the new time.
  - The map animates to the new route line and the old line disappears; guidance continues without any tap.
  - A formation alert (off route, passed checkpoint, ahead of leader) has priority and stays on top; the rerouting notice waits until it is gone.
  - Several reroutes in a row show only the latest one.
- No network → the old route stays, the leader sees "Couldn't update the route. Trying again." and the app retries every 30 s.

**Leader offline** — banner **needs lo-fi**
- Covers a leader who disappears without leaving (dead phone, no signal, app deleted). A leader who leaves on purpose ends the trip (US-07).
- Offline 2 min → everyone sees "Agus is offline"; navigation continues on the current route; checkpoint progress and "ahead of leader" pause. If the leader returns within 5 min, nothing else changes.
- Offline 5 min → every member can open "Pick Your New Leader" (same picker as US-05). It never blocks the map. The first confirmed choice wins (conditional save); everyone sees "Budi is now the leader".
- Only one member left → that member becomes leader automatically.
- An old leader who returns after a new leader was picked becomes a member.
- Why: the group keeps moving on the last known state, waits briefly in case the leader returns, then chooses a successor itself; the server decides when two people pick at once.

### Acceptance criteria

```gherkin
Feature: Drive together

  Background:
    Given trip "897654" is IN_TRIP with leader "Agus" and members "Budi" and "Citra"
    And the route goes through checkpoint "Ciputra World" to "Pakuwon mall"

  Scenario: See the group
    When "Budi" opens the map
    Then "Budi" sees the route, "Ciputra World", "Pakuwon mall" and every car
    And the bottom card shows "To Pakuwon mall" with the time left

  Scenario: Leader reaches a checkpoint
    When "Agus" comes within 20 m of "Ciputra World"
    Then "Ciputra World" is visited on every phone within 2 seconds
    And guidance points to "Pakuwon mall"

  Scenario: Member reaches a checkpoint first
    When "Budi" comes within 20 m of "Ciputra World" before "Agus"
    Then "Ciputra World" stays not visited

  Scenario: Tap a car
    Given "Budi" is driving on "Ahmad Yani Street", 50 minutes from the destination
    When "Agus" taps the car of "Budi"
    Then "Agus" sees "Budi", "Driving at Ahmad Yani Street" and "50 min"

  Scenario: A car stops
    Given "Budi" has had speed 0 for 30 seconds
    Then the pin of "Budi" shows the stopped style and no sound plays

  Scenario: Member leaves the route
    When "Budi" is more than 100 m off the route for 15 seconds
    Then "Budi" sees "You're out of the way" and the way back
    And "Agus" sees "Car Budi - Out of The Way"
    When "Budi" is back on the route
    Then the banner disappears

  Scenario: Member passes a checkpoint
    When "Budi" passes unvisited "Ciputra World" by more than 200 m
    Then "Budi" sees "You pass a checkpoint" and is guided back to it

  Scenario: Member drives ahead of the leader
    When "Budi" is 250 m ahead of "Agus" for 15 seconds
    Then "Budi" sees "You Precede The Leader"

  Scenario: GPS jump
    When "Budi" appears 150 m off the route for 3 seconds
    Then no alert appears

  Scenario: Leader takes another road
    When "Agus" is more than 100 m off the route for 15 seconds
    Then a new route through "Ciputra World" to "Pakuwon mall" reaches every phone within 2 seconds

  Scenario: Members see the rerouting notice
    When the leader's phone is calculating a new route
    Then "Agus" sees "Rerouting…" on the turn card
    When the new route arrives
    Then "Budi" and "Citra" see "New route · Following Agus" with the new time for 5 seconds
    And the map shows the new route line without any tap
    And no sound plays

  Scenario: Leader edits the route
    When "Agus" opens Edit Route, changes the destination to "Pakuwon city mall" and saves
    Then every phone shows "Route updated by Agus" and "To Pakuwon city mall" within 2 seconds

  Scenario: Leader offline, then back
    When "Agus" sends no location for 2 minutes
    Then "Budi" and "Citra" see "Agus is offline" and keep navigating
    When "Agus" is back after 3 minutes
    Then the banner disappears and "Agus" is still the leader

  Scenario: Leader stays offline
    When "Agus" sends no location for 5 minutes
    And "Budi" picks "Citra" in "Pick Your New Leader" and confirms
    Then "Citra" is the leader on every phone within 2 seconds
    And when "Agus" comes back he is a member
```

### Data

| Element | Entity | Fields |
| --- | --- | --- |
| Route | `Route`, `Trip` | `polyline`, `version`, `routeVersion` |
| Progress | `Trip` | `currentWaypointIndex` (written by the leader only) |
| Cars | `Participant` | `latitude`, `longitude`, `speedKmh`, `motionState`, `alert`, `lastSeenAt` |
| Street and ETA | Derived | reverse geocode (at most every 30 s per car), MapKit travel time |
| Way back | Device only | MapKit directions; never saved to the server |

---

<a id="us-07"></a>
## US-07 — As a leader or member, I want to arrive, continue, leave or end the trip clearly so that nobody is ever stuck in a trip.

**Lo-fi:** `FOCUS ON ONE OF CAR 2`, `FOCUS ON ONE OF CAR 3`, `FOCUS ON ONE OF CAR 4`, `FOCUS ON ONE OF CAR 6`, `END ROUTE (LEADER)`, `END ROUTE POP UP ALERT CONFIRM (LEADER)`, `EXIT ROUTE (JOINER)`, `EXIT ROUTE POP UP ALERT CONFIRM (JOINER)`, `TRIP ROOM POP UP CONFIRM ALERT(JOINER)`, `LEADER EXIT POP UP ALERT CONFIRM`

### Rules

**Arrive**
- Arrived = within 20 m of the destination. Offline members count as not arrived; members who exited are not counted.

| Who | Not everyone arrived | Everyone arrived |
| --- | --- | --- |
| Member who arrived | "You have arrived" · "Waiting for everyone to arrive" | "Everyone has arrived!" |
| Leader who arrived | "You have arrived" · "Waiting for everyone to arrive" + "New Destination" + "End Trip" | "Everyone has arrived!" · "Continue your trip?" + "New Destination" + "End Trip" |

- The leader is never blocked by late cars.

**New Destination**
- Opens the planner (US-01) with the start point locked to the current destination.
- Saving keeps the same trip, room code and members, sets the trip back to `LOBBY` with the new route, and moves every phone to the Trip Room; ready status then uses the new start point.
- Going back without saving returns to the map.

**Leave and end**

| Who | Where | Button | Confirmation | Result |
| --- | --- | --- | --- | --- |
| Member | Trip Room | Exit (top left) | "Exit the room?" | I leave; Home opens |
| Member | On the road | "Exit Trip" | "Exit trip?" | I leave; my car disappears from every map |
| Leader | Trip Room | Exit (top left) | "Exit and end the trip for everyone? All members will leave this trip." | Trip `CANCELLED` for everyone |
| Leader | On the road | "End Trip" | "End trip?" — or, if not everyone arrived, "End trip? Not everyone has arrived yet." | Trip `ENDED` for everyone |
| Leader | Draft card | "New Trip" (US-03) | "Create a new trip? Your current trip will end for everyone." | Old trip ends for everyone |

- Every confirmation has "Cancel" and "Confirm"; the leader's warnings use the destructive style.
- When the trip ends, every member sees "The leader ended the trip." and returns to Home within 2 seconds. Members who are offline get it when they reconnect.
- Leaving or ending stops location sharing and removes the trip from the device.
- If the last member leaves, the leader stays in the trip and can still exit or end it.
- There is no recap screen.

**Needs lo-fi**
- `LEADER EXIT POP UP ALERT CONFIRM` ("Exit the room and set a new leader?") must change to the end-for-everyone warning above.
- Copy check for "End trip? Not everyone has arrived yet."
- Lo-fi grammar is corrected: "Everyone has arrived!", "Waiting for everyone to arrive".

### Acceptance criteria

```gherkin
Feature: Arrive, continue, leave and end

  Background:
    Given trip "897654" is IN_TRIP with leader "Agus" and members "Budi" and "Citra"
    And the destination is "Ciputra World Surabaya"

  Scenario: Member arrives first
    When "Budi" comes within 20 m of the destination
    Then "Budi" sees "You have arrived" and "Waiting for everyone to arrive"

  Scenario: Leader arrives before everyone
    Given "Citra" is 500 m behind
    When "Agus" arrives
    Then "Agus" sees "Waiting for everyone to arrive" with "New Destination" and "End Trip"

  Scenario: Everyone arrives
    When "Agus", "Budi" and "Citra" have all arrived
    Then "Agus" sees "Everyone has arrived!", "Continue your trip?", "New Destination" and "End Trip"
    And "Budi" and "Citra" see "Everyone has arrived!"

  Scenario: Continue to a new destination
    When "Agus" taps "New Destination"
    Then the planner opens with the start point "Ciputra World Surabaya" locked
    When "Agus" picks "Pakuwon mall" and saves
    Then the trip is in LOBBY with the same room code and members
    And every phone shows the Trip Room with the new route within 2 seconds

  Scenario: End after everyone arrived
    Given everyone has arrived
    When "Agus" taps "End Trip" and confirms "End trip?"
    Then the trip is ENDED
    And "Budi" and "Citra" see "The leader ended the trip." and return to Home within 2 seconds

  Scenario: End before everyone arrived
    Given "Citra" has not arrived
    When "Agus" taps "End Trip"
    Then "Agus" sees "End trip? Not everyone has arrived yet."
    When "Agus" taps "Confirm"
    Then the trip is ENDED

  Scenario: Member exits on the road
    When "Budi" taps "Exit Trip" and confirms "Exit trip?"
    Then "Budi" is on Home and stops sharing location
    And the car of "Budi" disappears from every map within 2 seconds
    And the trip continues for "Agus" and "Citra"

  Scenario: Member exits the Trip Room
    Given the trip is in LOBBY
    When "Budi" taps Exit and confirms "Exit the room?"
    Then "Budi" is on Home and the others no longer see him

  Scenario: Leader exits the Trip Room
    Given the trip is in LOBBY
    When "Agus" taps Exit
    Then "Agus" sees "Exit and end the trip for everyone? All members will leave this trip."
    When "Agus" taps "Confirm"
    Then the trip is CANCELLED and every phone returns to Home

  Scenario: Leader leaves without ending
    Given the trip is in LOBBY and "Agus" handed the lead to "Budi"
    When "Agus" taps Exit and confirms "Exit the room?"
    Then the trip continues with "Budi" as leader

  Scenario: Cancel
    When anyone taps "Cancel" on a confirmation
    Then nothing changes
```

### Data

| Action | Entity | Effect |
| --- | --- | --- |
| Arrived | Derived | distance to destination ≤ 20 m |
| New Destination | `Waypoint`, `Route`, `Trip` | replace waypoints (new start = old destination); new route version; `status: LOBBY`, `currentWaypointIndex: 0` |
| Member exits | `Participant` | delete own record |
| Leader exits or ends | `Trip` | `status: CANCELLED` (LOBBY) or `ENDED` (IN_TRIP), `endedAt: now` |
| Every phone | Device | stop location updates, clear `activeTripID` |
