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
| Invite link | `https://lezgo-trip.netlify.app/join?code=897654`, a universal link that opens Lezgo ([ADR 0020](../docs/adr/0020-UniversalInviteLinkOnNetlify.md)). The older `lezgo://join?code=897654` still opens it. |
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
| `Participant` | `id`, `tripID`, `userRecordID`, `displayName` (unique in the trip, ignoring upper/lower case and spaces at the ends), `carDescription`, `avatar` (`Yellow`, `Blue`, `Green`, `Pink`, `Purple`), `latitude`, `longitude`, `speedKmh`, `motionState` (`driving`, `stopped`), `alert` (`none`, `offRoute`, `passedCheckpoint`, `aheadOfLeader`), `lastSeenAt`, `course` (degrees clockwise from north, empty when unknown) | One record per person (= per car). `id` is the CloudKit record name; `userRecordID` is the iCloud user, unique per trip. Leader when `id == Trip.leaderParticipantID`, otherwise member. |
| `Route` | `id`, `tripID`, `version`, `polyline` | The road path. A new version replaces the old one. |

### Sync and timing

- Each phone sends its location **every 1 second** while the trip is open, moving or stopped. Sharing starts in the Trip Room and runs in the background during the trip ("Always" location permission, asked with a clear reason).
- Every phone shows another car's new position and any status change (join, leave, remove, start, end, new route, new leader) **within 2 seconds**. Start Trip reaches every phone **within 1 second**. Phones listen to a CloudKit subscription and also fetch every 1 second while the app is open; silent pushes alone are not enough because iOS delays and drops them.
- Arrival and checkpoints use a **20 m radius**, checked on every 1-second location update instead of an iOS region geofence (region geofences fire late or not at all for a radius this small). At highway speed a car moves about 28 m per second, so a car also counts as arriving when the line between two updates passes within 20 m of the point.
- A person is **offline** when `lastSeenAt` is older than **2 minutes**.
- Alerts on the road are visual only. No sound, no vibration.
- Every destructive action asks for confirmation, and every flow has a way out.

### CarPlay

While the trip map is open on the iPhone, CarPlay shows the same trip (#257, [ADR 0023](../docs/adr/0023-CarPlayMirrorsTheTripMap.md)). The map shows the route, the stops and the cars as on the phone; everything else uses Apple's CarPlay templates with the phone's copy:

| Phone | CarPlay |
| --- | --- |
| Turn card, time left | Guidance panel and trip estimates |
| Alert and notice banners | Navigation alert, silent, with "OK" |
| Car status card | "Cars" button, then a panel with the car's status |
| "You have arrived!" card | Panel with the title, subtitle and "2/3 arrived" |
| End Trip / Exit Trip | Navigation bar button, then the same question with "Cancel" and "Confirm" |

Without a trip map on the phone, CarPlay shows the map and "No trip yet · Start or join a trip on your iPhone, and it shows here." New Destination and Edit Route stay on the phone.

### Not in scope (no lo-fi, not in the app statement)

Trip recap, trip history, SOS button, prolonged-stop alerts, sound notifications, "Cancel Trip" menu item.

---

<a id="us-01"></a>
## US-01 — As a leader, I want to plan a route with a start point, checkpoints and a destination so that the group knows where we are going.

**Lo-fi:** `HOME`, `SEARCH ROUTE`, `ADD CHECKPOINT`, `PREVIEW ROUTE Copy`, `PREVIEW ROUTE CHECKPOINT Copy`, `EDIT ROUTE`

### Rules

- Whoever creates the trip becomes its leader.
- The planner opens from the search bar on Home ("Where do you want to travel?").
- The start point is the current location by default and can be changed by search. The planner says "Current Location", but the trip saves the real place (a street or place name from the map), because "Current Location" means nothing to a member in the Trip Room. A place the map has no name for is saved as "Leader's starting point".
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
- An invite link opens the same dialog with the code filled in. A link with no valid 6-digit code is ignored.
- No form, and the app never asks for a name. iOS does not tell apps the iCloud account's name, so a car whose driver typed no name is called "Leader" (the leader) or "Car 2", "Car 3", … (members, in the order they joined; the leader counts as car 1). A name typed in "Edit my name and car" (US-04) is shown instead and saved on the phone for every later trip I create or join.
- `LOBBY` → I join as a member and the Trip Room opens. `IN_TRIP` → I join as a late member and the map opens.
- `ENDED` or `CANCELLED` → join is rejected.
- Joining the same trip again with the same iCloud account returns to my existing record; it never adds a second car.
- If my saved name is already used by another car in the trip, I still join: my name is left empty, so I am shown as "Car 2", "Car 3", …, and my car and avatar are kept. I can then change my name in Edit Profile (US-04), where the name is checked as usual.

### Acceptance criteria

```gherkin
Feature: Join a trip

  Scenario: Join a trip in the Trip Room
    Given trip "897654" is in LOBBY
    When I enter "897654" and tap "Enter"
    Then I am a member of the trip and the Trip Room opens

  Scenario: Join with an invite link
    When I open "https://lezgo-trip.netlify.app/join?code=897654"
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

  Scenario: Name already used
    Given trip "897654" has a member called "Budi"
    And my saved name is "budi "
    When I enter "897654" and tap "Enter"
    Then I am added to the trip and the Trip Room opens
    And my car is shown as "Car 2" with my car and avatar kept
    And I can change my name in Edit Profile

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

**Hi-fi:** Trip Room, Add Participants, Edit Profile, Start Trip confirmation, hold menu on an avatar (#166). The hi-fi wins where it differs from the lo-fi.

### Rules

**Room**
- Always dark: the Trip Room and its sheets never show in light mode.
- At the top, a map preview shows the start point, the destination and the road route only: no checkpoints, no other routes, no cars.
- The title is "Lez Get Ready !".
- "Overview" shows STARTING POINT, DESTINATION and "# OF STOPS" (the number of checkpoints, without the start point and the destination).
- "Participants" shows everyone's avatar, name and car description; the leader has a crown. Under the list a hint says "Hold to manage participants" to the leader and "Hold to edit your profile" to a member.
- The list updates within 2 seconds when someone joins, leaves, is removed, edits their profile, or the leader changes.
- The leader sees "Start Trip". Members see "Waiting for others ...".
- Under the participants: the leader has "End Trip", a member has "Exit Trip" (US-07). Text buttons, no icon. When the trip starts, every phone moves to the map.

**Invite**
- "Add" next to "Participants" opens "Add Participants": the room code in large text and "Share Link" (iOS share sheet with the invite link). Leader and members can both invite.
- Tapping the room code copies the 6 digits and shows "Copied" in the box for 2 seconds. Touching and holding it shows "Copy Code". The lo-fi has no copy button, so copying lives on the code itself.
- "Share Link" sends "Join my Lezgo trip with code 897654" together with the invite link.
- Copying and "Share Link" stay disabled until the room code has loaded.

**Manage participants** (hold an avatar)
- Tapping an avatar does nothing. Holding it lifts the avatar to the centre of the screen with its name and car; the background turns dark and blurred, and a menu appears under it.
- The leader holding a member: "Set as Trip Leader", "Edit Details", "Remove from Trip" (US-05).
- The leader or a member holding their own avatar: "Edit Details" only.
- A member holding someone else's avatar: nothing opens.
- "Edit Details" opens Edit Profile. Not available during the trip (safety).

**Edit Profile**
- A member can only edit their own profile; the leader can edit everyone's. Avatar: one of the five. Name: 1–30 characters, required. Car details: optional, up to 40 characters ("White Avanza"). Spaces at the start and the end are removed.
- Avatars scroll sideways; the one in the middle is chosen at once and grows to the size of the avatars in the Trip Room, the others are smaller. There is no select button. Tapping an avatar scrolls it to the middle.
- Names are unique in the trip, ignoring upper/lower case and spaces at the ends. The name is checked twice: when I leave the field, and when I tap "Save". A name already used by another car turns the field's border red with "Name already used in this trip" under it, and "Save" is disabled and grey. Tapping the field again clears the red. If "Save" is tapped before the first check ran, the second check shows the same red field and an alert with "Name already used in this trip". Keeping my own name is never a clash.
- My own details are saved on my device and reused next time I create or join a trip; details the leader changes for a member are not saved on either device. Not editable during the trip (safety).

**Confirmations**
- Every confirmation in the Trip Room is the same dialog: a title (and optional message), "Cancel" in red text and one main button in yellow (the LEZGO logo for "Start Trip?"). It is one shared component, so its text colours, background and button content can be set per use, and other screens use it too. A message with only "OK" uses the same dialog with one button.

**Avatar**
- Five avatars: Yellow, Blue, Green, Pink, Purple. Each is a set of finished mascot images told apart by asset name (`MainSelectedBlue`, `MainUnselectedBlue`, …); the trip stores only the key (`Blue`).
- Several cars may have the same avatar.
- Someone who never picked one gets Yellow when they create a trip and a random other avatar when they join.
- Records without a known avatar show Yellow.

**Ready**
- Detected automatically; nobody taps a button.
- Ready = within 100 m of the start point. Unknown location (no permission or offline) = not ready.
- Each avatar shows it: the selected image (with the burst behind the mascot) when ready, the unselected image when not. The two differ in shape, not only colour, and VoiceOver reads "Ready at start point" or "Not ready at start point".
- Not ready never blocks the start; it only adds a warning (US-05).

### Acceptance criteria

```gherkin
Feature: Trip Room

  Background:
    Given trip "897654" is in LOBBY with start point "Universitas Ciputra"
    And leader "Agus" and member "Budi" are in the Trip Room

  Scenario: See the shared plan
    When "Budi" opens the Trip Room
    Then "Budi" sees the map preview, the overview, "Agus" with a crown and "Budi"
    And "Budi" sees "Waiting for others ..." and "Exit Trip"
    And "Agus" sees "Start Trip" and "End Trip"

  Scenario: Count the stops
    Given the route has 2 checkpoints
    Then the overview shows "2" under "# OF STOPS"

  Scenario: Someone joins
    When "Citra" joins with the room code
    Then "Agus" and "Budi" see "Citra" within 2 seconds

  Scenario: Invite friends
    When "Budi" taps "Add"
    Then "Budi" sees "897654" in large text
    When "Budi" taps "Share Link"
    Then the share sheet opens with "Join my Lezgo trip with code 897654" and "https://lezgo-trip.netlify.app/join?code=897654"

  Scenario: Copy the room code
    When "Budi" taps "Add" and then the room code
    Then "897654" is on the pasteboard
    And "Budi" sees "Copied"

  Scenario: Edit my profile
    When "Budi" holds his own avatar and taps "Edit Details"
    And scrolls to the Pink avatar and sets "Budi" and "White Avanza"
    Then everyone sees the Pink avatar and "White Avanza" for "Budi" within 2 seconds
    And next time "Budi" joins a trip he joins as "Budi" with "White Avanza" and the Pink avatar

  Scenario: Default avatars
    Given "Citra" never picked an avatar
    When "Citra" joins
    Then "Citra" has an avatar that is not Yellow

  Scenario: Tapping an avatar does nothing
    When "Agus" taps the avatar of "Budi"
    Then nothing opens

  Scenario: Hold menu of a member for the leader
    When "Agus" holds the avatar of "Budi"
    Then the avatar of "Budi" moves to the centre and the background turns dark and blurred
    And "Agus" sees "Set as Trip Leader", "Edit Details" and "Remove from Trip"

  Scenario: Hold menu of my own avatar
    When "Budi" holds his own avatar
    Then "Budi" sees only "Edit Details"

  Scenario: A member cannot edit someone else
    When "Budi" holds the avatar of "Agus"
    Then no menu opens

  Scenario: Choose an avatar by scrolling
    Given "Budi" is in Edit Profile
    When "Budi" scrolls the Green avatar to the middle
    Then Green is chosen and bigger than the others

  Scenario: Name already used, checked when leaving the field
    Given "Agus" is in the trip
    When "Budi" types "agus " and leaves the name field
    Then the field has a red border with "Name already used in this trip"
    And "Save" is disabled
    When "Budi" taps the name field
    Then the red border and the text are gone

  Scenario: Name already used, checked on Save
    When "Budi" types "Agus" and taps "Save" at once
    Then "Budi" sees an alert "Name already used in this trip"
    And the name field has a red border with the same text

  Scenario: Keep my own name
    When "Budi" changes only his car details and taps "Save"
    Then it is saved

  Scenario: The leader edits a member
    When "Agus" holds the avatar of "Budi", taps "Edit Details" and sets "Budi Santoso"
    Then everyone sees "Budi Santoso" within 2 seconds
    And next time "Agus" joins a trip he still joins as "Agus"

  Scenario: Empty name
    When "Budi" clears his name
    Then saving is disabled

  Scenario: Arrive at the start point
    Given "Budi" is 2 km away and his avatar shows not ready
    When "Budi" comes within 100 m of "Universitas Ciputra"
    Then "Agus" sees the avatar of "Budi" as ready within 2 seconds

  Scenario: No location permission
    Given "Budi" denied location permission
    Then the avatar of "Budi" shows not ready
    And "Budi" sees how to turn on location in Settings
```

### Data

| Element | Entity | Fields |
| --- | --- | --- |
| Route | `Waypoint` | `name`, `kind`, `orderIndex` |
| Map preview | `Waypoint`, `Route` | start point, destination, `polyline` |
| Participants | `Participant` | `displayName`, `carDescription`, `avatar`, `latitude`, `longitude`, `lastSeenAt` |
| Crown | `Trip` | `leaderParticipantID` |
| Saved profile | Device | `displayName`, `carDescription`, `avatar` |

---

<a id="us-05"></a>
## US-05 — As a leader, I want to manage the group and start the trip for everyone so that the right cars leave together.

**Hi-fi:** the hold menu on an avatar, Start Trip confirmation (#166). It replaces the swipe, Select and picker lo-fi below.

**Lo-fi:** `TRIP ROOM (EDIT)`, `SLIDE DELETE IF NOT LEADER`, `SLIDE DELETE IF LEADER`, `REMOVE PERSON POP UP ALERT CONFIRM VIA SLIDER`, `SELECT MEMBERS`, `MORE THAN 3 REMOVAL POP UP ALERT CONFIRM`, `SET LEAD IF NOT LEADER VIA SLIDER`, `SET LEAD IF LEADERS IS SELECTED VIA SLIDER`, `POP UP ALERT CONFIRM SET LEADER`, `PICK LEADER`, `LEADER POP UP ALERT CONFIRM`, `LEADER BECOMES JOINER`, `CONFIRM START TRIP`, `CONFIRM START TRIP WHEN NOT ALL MEMBER READY`

### Rules

Only the leader sees these actions, and only in the Trip Room. The hi-fi has no swipe actions, `...` menu or Select mode: removing and handing over happen one car at a time from the menu that opens when the leader holds an avatar (US-04).

**Remove members**
- Hold a member's avatar → "Remove from Trip" (red).
- The leader's own avatar has no "Remove from Trip" and no "Set as Trip Leader", so the leader cannot remove or hand over to themselves.
- Confirm: "Remove XX from the trip?" → "Cancel" / "Remove".
- A removed member sees "You were removed from the trip." and returns to Home. They can join again with the code.

**Hand over the lead**
- Hold a member's avatar → "Set as Trip Leader".
- Confirm: "Set XX as Trip Leader?" → "Cancel" / "Confirm".
- The crown moves; the new leader gets "Start Trip" and "End Trip"; the old leader becomes a member ("Waiting for others ..." and "Exit Trip"). Saved with a conditional write so two leaders can never exist.
- Handing over is how a leader leaves without ending the trip: hand over, then "Exit Trip" as a member.

**Start the trip**
- "Start Trip" needs at least one member besides the leader; otherwise it is disabled with "Invite at least one friend to start."
- Everyone ready → "Start Trip?". Someone not ready → "Some participants are not yet ready, are you sure you want to start the trip?". Both → "Cancel" / the LEZGO logo button (VoiceOver: "Start").
- Start sets the trip to `IN_TRIP` and moves every phone to the map within 1 second.

### Acceptance criteria

```gherkin
Feature: Manage the group and start

  Background:
    Given trip "897654" is in LOBBY with leader "Agus" and members "Budi", "Citra", "Doni", "Eka", "Fajar"

  Scenario: Remove a member
    When "Agus" holds the avatar of "Doni", taps "Remove from Trip" and confirms "Remove Doni from the trip?"
    Then "Doni" is no longer in Participants
    And "Doni" sees "You were removed from the trip." and returns to Home

  Scenario: Cancel a removal
    When "Agus" holds the avatar of "Doni", taps "Remove from Trip" and then "Cancel"
    Then "Doni" stays

  Scenario: Leader cannot remove or hand over to himself
    When "Agus" holds his own avatar
    Then the menu shows only "Edit Details"

  Scenario: Members cannot manage the group
    When "Budi" holds his own avatar
    Then the menu shows only "Edit Details"

  Scenario: Hand over the lead
    When "Agus" holds the avatar of "Budi", taps "Set as Trip Leader" and confirms "Set Budi as Trip Leader?"
    Then "Budi" has the crown and sees "Start Trip"
    And "Agus" sees "Waiting for others ..."

  Scenario: Start with everyone ready
    Given everyone is "ready at startpoint"
    When "Agus" taps "Start Trip" and confirms "Start Trip?"
    Then the trip is IN_TRIP
    And every phone shows the map within 1 second

  Scenario: Start with someone not ready
    Given "Budi" is "not ready at startpoint"
    When "Agus" taps "Start Trip"
    Then "Agus" sees "Some participants are not yet ready, are you sure you want to start the trip?"
    When "Agus" taps the LEZGO button
    Then the trip is IN_TRIP

  Scenario: Leader alone
    Given every member left
    Then "Start Trip" is disabled with "Invite at least one friend to start."
```

### Data

| Action | Entity | Effect |
| --- | --- | --- |
| Remove | `Participant` | delete the member's record |
| Hand over | `Trip` | `leaderParticipantID` (conditional save) |
| Start | `Trip` | `status: IN_TRIP`, `startedAt: now`, `currentWaypointIndex: 1` |

---

<a id="us-06"></a>
## US-06 — As a leader or member, I want to see the shared route, every car and silent alerts on one map so that we stay together on the road.

**Lo-fi:** `TRIP COORDINATE`, `TRIP COORDINATE 2`, `MEMBER`, `MEMBER FOCUS`, `FOCUS ON ONE OF CAR`, `FOCUS ON ONE OF CAR 5`, `MEMBER WRONG ROUTE`, `MEMBER WRONG ROUTE FOCUS`, `MEBER PASS CHECKPOINT`, `MEBER PASS CHECKPOINT FOCUS`, `MEBER PRECEDE LEADER`, `MEBER PRECEDE LEADER FOCUS`, `EDGE CASE - OUT OF THE WAY`, `EDGE CASE - OUT OF THE WAY Copy`, `EDIT ROUTE`

### Rules

**Map**
- Shows the route still ahead of my car, the checkpoints not visited yet, the destination and every car. As in Apple Maps, the part already driven, the start point and visited checkpoints are not drawn.
- Top card: next turn ("200 m, Turn right"). Bottom card: "To [destination]" and time left ("50 min").
- Members are measured against the group's road: the leader's footprint, then the leader, then the route ahead of the leader. A member behind the leader on the footprint is not off route, even after the leader was rerouted and the route now starts at the leader.
- The bottom card is a sheet. Pulled up, it adds only End Trip (leader) or Exit Trip (member), and Edit Route for the leader. The cars are on the map, and the room code is in the Trip Room, so the sheet lists neither.
- Map buttons: show the whole route, and follow my car.
- Checkpoints follow the leader: when the leader's car is within 20 m of the next checkpoint, it is visited for everyone. The app does not wait for members.

**Footprint**
- The leader's phone records the road the leader drives (a point every 20 m, the last 1,500 points, about 30 km) and saves it every 5 seconds; the other phones read it every 3 seconds.
- A member's map draws the road ahead along the footprint to the leader, then the route ahead of the leader. Its turn card follows that line ("Turn right", "Follow the leader's route"); the time and distance left stay MapKit's.
- A member more than 50 m off the group's road for 5 seconds gets a way back to it, drawn and guided like the rest of the line. It joins the road at its closest point at least 50 m beyond where the member left it, so it leads on towards the leader instead of back to the junction behind them. It is asked again after 10 seconds if they leave that way too, and it goes away once they are back on the road.
- The leader's map shows the footprint behind the leader as a faint dotted line, so the leader sees the road the members follow and the cars on it.
- A member's phone shares their way back (`Participant.wayBack`). The leader's map shows what is left of it as a dashed line in the alert colour, so the leader sees how a car that took another road will catch up. Offline cars' way backs are not shown, and members do not see each other's.
- Location runs in the background (screen locked, another app in front) only on the trip map. Home, Set Route and the Trip Room stop using it when the app leaves the screen, and closing the app stops it.

**Car status**
- Tap a car → card with name, status and street ("Driving at Ahmad Yani Street"), and ETA to the destination ("50 min").
- The camera moves to the tapped car and follows it while its card is open. Closing the card takes the camera back to where it was (following this car or showing the whole route); a map moved by hand meanwhile stays where it is.
- "Driving" while moving; "Stopped" after speed 0 for 30 seconds, shown on the pin by colour **and** icon, without sound.
- Offline cars are faded at their last position and show "Last seen 3 min ago".
- Tap elsewhere or swipe down to close.
- Cars so close that their robots would overlap on screen are drawn side by side on one dark card, each with the driver's name under the robot. A car with an alert stays on its own.
- The leader's car has a crown beside it, on its own or on a card, where the leader always comes first.
- A card shows at most 4 cars and counts the rest ("+6"), for example 10 cars at the start point. Tapping the count opens the card to show every car; tapping a car on the card opens its status, and the car glows in its place.
- An offline car's card shows no ETA, because its last position is out of date.
- Until the street and ETA are known (or without network), the card shows the status alone ("Driving").

**Formation alerts (members only)**

| Alert | When | Banner | Map |
| --- | --- | --- | --- |
| Off route | More than 50 m from the group's road for 5 s | "You're out of the way" | Way back to the road, towards the leader |
| Passed checkpoint | Past the next unvisited checkpoint by more than 200 m | "You pass a checkpoint" | Guides back to that checkpoint |
| Passed destination | More than 100 m past the end of the route, every checkpoint visited, for 5 s | "You passed the destination" | Nothing; only that car sees it |
| Ahead of leader | More than 100 m ahead of the leader for 5 s | "You Precede The Leader" | Nothing; slow down or wait |

- Visual only, under the turn card. One banner at a time (passed destination > off route > passed checkpoint > ahead of leader). It disappears when the condition ends; ⓧ hides it until it happens again.
- Everyone else sees "[name] has gone out of route" / "[name] - Precede The Leader" ("Car 3 has gone out of route", "Budi has gone out of route") and the car highlighted. The lo-fi's "Car X" put "Car" before the name; with automatic names that read "Car Car 3".
- **Stopped car:** another online car that was driving and has been at speed 0 for 30 seconds, before it has arrived (US-07), shows "[name] has stopped" on a red banner, after every formation alert. It hides until that car has driven again. A car still waiting at the start does not count.
- A tap on the banner hides it (the hi-fi has no ⓧ). Banners are yellow, and red for a stopped car.
- The time and distance limits stop flicker from GPS noise. They were 100 m and 15 s at first; on the road a wrong turn then showed far too late, so they match the leader's reroute now (50 m, 5 s).

**Route changes (leader only)**
- Automatic: the leader more than 50 m off the route for 5 s → new route from the leader through the unvisited checkpoints to the destination. These limits are tighter than a member's off-route alert so the group is rerouted within seconds, as in Apple Maps; 5 s still ignores short GPS jumps. A failed reroute is tried again after 10 s.
- Manual: Edit Route opens the planner (US-01) with the leader's position as start point. The button that opens it on the map **needs lo-fi**.
- Each new route has `routeVersion + 1`; members switch within 2 seconds and never go back to an older version.
- **Rerouting notice** (like Apple Maps and Google Maps), visual only. Lo-fi: `B6 Rerouting (leader)`.
  - From 2 seconds off the road until the new route arrives, the turn card shows "Rerouting…" in its place: "Finding a new route for everyone" on the leader's phone, "Finding the way back to your group" on a member's phone looking for a way back. It replaces the turn card, so nothing is added on top of the map.
  - When the new route arrives, every phone shows a yellow banner under the turn card for 5 seconds, then it hides on its own:
    - The same stops: "New route · Following Agus · 52 min" ("New route · 52 min" on the leader's phone).
    - Changed stops: "Route updated by Agus · 58 min" ("Route updated · 58 min" on the leader's phone). The bottom card shows the new destination.
  - The map animates to the new route line and the old line disappears; guidance continues without any tap.
  - A formation alert (off route, passed checkpoint, ahead of leader) has priority and stays on top; the rerouting notice waits until it is gone.
  - Several reroutes in a row show only the latest one.
- No network → the old route stays, the leader sees a red banner "Couldn't update the route. Trying again." and the app retries. It hides once a new route is saved or the leader is back on the route.

**Leader offline**
- Covers a leader who disappears without leaving (dead phone, no signal, app deleted). A leader who leaves on purpose ends the trip (US-07).
- Offline 2 min → everyone sees a red banner "Agus is offline". It goes when the leader is back; a tap hides it until then.
- Everyone keeps navigating on the same current route. Checkpoint progress and "ahead of leader" pause, because the leader's phone drives them.
- The leader never changes on the road, however long the leader is offline: nobody picks a new one and nobody takes over. The lead is handed over only in the Trip Room (US-05).
- Why: the driver must not be distracted, and the group already has the route it needs.

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
    And the map moves to the car of "Budi" and follows it

  Scenario: Close a car's card
    Given "Agus" is following his own car and has tapped the car of "Budi"
    When "Agus" closes the card
    Then the map follows the car of "Agus" again

  Scenario: A car stops
    Given "Budi" has had speed 0 for 30 seconds
    Then the pin of "Budi" shows the stopped style and no sound plays

  Scenario: Member leaves the route
    When "Budi" is more than 50 m off the route for 5 seconds
    Then "Budi" sees "You're out of the way" and the way back
    And "Agus" sees "Budi has gone out of route"
    When "Budi" is back on the route
    Then the banner disappears

  Scenario: Member passes a checkpoint
    When "Budi" passes unvisited "Ciputra World" by more than 200 m
    Then "Budi" sees "You pass a checkpoint" and is guided back to it

  Scenario: Member drives ahead of the leader
    When "Budi" is 150 m ahead of "Agus" for 5 seconds
    Then "Budi" sees "You Precede The Leader"

  Scenario: GPS jump
    When "Budi" appears 150 m off the route for 3 seconds
    Then no alert appears

  Scenario: Leader takes another road
    When "Agus" is more than 50 m off the route for 5 seconds
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
    Then "Budi" and "Citra" still see "Agus is offline" and keep navigating on the same route
    And "Agus" is still the leader
    And nobody is asked to pick a new leader
```

### Data

| Element | Entity | Fields |
| --- | --- | --- |
| Route | `Route`, `Trip` | `polyline`, `version`, `routeVersion` |
| Progress | `Trip` | `currentWaypointIndex` (written by the leader only) |
| Cars | `Participant` | `latitude`, `longitude`, `speedKmh`, `motionState`, `alert`, `lastSeenAt`, `course` |
| Street and ETA | Derived | reverse geocode (at most every 30 s per car), MapKit travel time |
| Way back | Device only | MapKit directions; never saved to the server |

---

<a id="us-07"></a>
## US-07 — As a leader or member, I want to arrive, continue, leave or end the trip clearly so that nobody is ever stuck in a trip.

**Lo-fi:** `FOCUS ON ONE OF CAR 2`, `FOCUS ON ONE OF CAR 3`, `FOCUS ON ONE OF CAR 4`, `FOCUS ON ONE OF CAR 6`, `END ROUTE (LEADER)`, `END ROUTE POP UP ALERT CONFIRM (LEADER)`, `EXIT ROUTE (JOINER)`, `EXIT ROUTE POP UP ALERT CONFIRM (JOINER)`, `TRIP ROOM POP UP CONFIRM ALERT(JOINER)`, `LEADER EXIT POP UP ALERT CONFIRM`

### Rules

**Arrive**
- Arrived = within 20 m of the destination, or "I've Arrived" (below). Offline members count as not arrived; members who exited are not counted.
- **I've Arrived:** a destination's point is not always where the group parks; in a big mall a car can stop 200 m away and never come within 20 m. Within 1 km of the point, the pulled-up card shows "I've Arrived" (leader and members), between Edit Route and End Trip or Exit Trip. It hides once the car has arrived.
  - Tapping it asks first: "Arrived at Tunjungan Plaza?" · "You are 200 m from the destination point. Are you sure you have arrived?" with "Cancel" and "I've Arrived". The distance is rounded to 10 m.
  - Confirming counts the car as arrived on every phone, as if it were within 20 m. It counts for that destination only: a New Destination starts afresh. A reroute or Edit Route that keeps the destination in the same place keeps it.
  - A car that has arrived this way is not "stopped": it gets no "[name] has stopped" banner.
  - If saving fails (no network), a message says why and the button stays, so the driver can try again.

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
| Member | Trip Room | "Exit Trip" (under the participants) | "Exit the room?" | I leave; Home opens |
| Member | On the road | "Exit Trip" | "Exit trip?" · "Your car disappears from every map." | I leave; my car disappears from every map |
| Leader | Trip Room | "End Trip" (under the participants) | "Exit and end the trip for everyone? All members will leave this trip." | Trip `CANCELLED` for everyone |
| Leader | On the road | "End Trip" | "End trip?" — or, if not everyone arrived, "End trip?" · "Not everyone has arrived yet." | Trip `ENDED` for everyone |
| Leader | Draft card | "New Trip" (US-03) | "Create a new trip? Your current trip will end for everyone." | Old trip ends for everyone |

- Every confirmation is the shared dialog (US-04, "Confirmations") with "Cancel" and "Confirm".
- When the trip ends, every member sees "The leader ended the trip." and returns to Home within 2 seconds. Members who are offline get it when they reconnect.
- Leaving or ending stops location sharing and removes the trip from the device.
- If the last member leaves, the leader stays in the trip and can still exit or end it.
- There is no recap screen.

**Needs lo-fi**
- `LEADER EXIT POP UP ALERT CONFIRM` ("Exit the room and set a new leader?") must change to the end-for-everyone warning above.
- Copy check for "End trip?" · "Not everyone has arrived yet."
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

  Scenario: Member says they arrived in a big mall
    Given "Budi" is parked 200 m from the destination's point
    When "Budi" taps "I've Arrived"
    Then "Budi" sees "Arrived at Ciputra World Surabaya?" and "You are 200 m from the destination point. Are you sure you have arrived?"
    When "Budi" taps "I've Arrived" again
    Then every phone counts "Budi" as arrived
    And "Budi" sees "You have arrived" and "Waiting for everyone to arrive"

  Scenario: Arrival survives a reroute
    Given "Budi" said "I've Arrived" 200 m from the destination's point
    When the route is recalculated with the same destination
    Then every phone still counts "Budi" as arrived
    And no phone shows "Budi has stopped"

  Scenario: Far from the destination
    Given "Budi" is 5 km from the destination
    Then the card has no "I've Arrived"

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
    Then "Agus" sees "End trip?" and "Not everyone has arrived yet."
    When "Agus" taps "Confirm"
    Then the trip is ENDED

  Scenario: Member exits on the road
    When "Budi" taps "Exit Trip" and confirms "Exit trip?"
    Then "Budi" is on Home and stops sharing location
    And the car of "Budi" disappears from every map within 2 seconds
    And the trip continues for "Agus" and "Citra"

  Scenario: Member exits the Trip Room
    Given the trip is in LOBBY
    When "Budi" taps "Exit Trip" and confirms "Exit the room?"
    Then "Budi" is on Home and the others no longer see him

  Scenario: Leader exits the Trip Room
    Given the trip is in LOBBY
    When "Agus" taps "End Trip"
    Then "Agus" sees "Exit and end the trip for everyone? All members will leave this trip."
    When "Agus" taps "Confirm"
    Then the trip is CANCELLED and every phone returns to Home

  Scenario: Leader leaves without ending
    Given the trip is in LOBBY and "Agus" handed the lead to "Budi"
    When "Agus" taps "Exit Trip" and confirms "Exit the room?"
    Then the trip continues with "Budi" as leader

  Scenario: Cancel
    When anyone taps "Cancel" on a confirmation
    Then nothing changes
```

### Data

| Action | Entity | Effect |
| --- | --- | --- |
| Arrived | Derived | distance to destination ≤ 20 m, or `arrivedAtWaypointID` = the destination |
| I've Arrived | `Participant` | `arrivedAtWaypointID: destination.id` |
| New Destination | `Waypoint`, `Route`, `Trip` | replace waypoints (new start = old destination); new route version; `status: LOBBY`, `currentWaypointIndex: 0` |
| Member exits | `Participant` | delete own record |
| Leader exits or ends | `Trip` | `status: CANCELLED` (LOBBY) or `ENDED` (IN_TRIP), `endedAt: now` |
| Every phone | Device | stop location updates, clear `activeTripID` |
