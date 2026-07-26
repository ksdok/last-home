# LH-MP-5 (M) - House picker before the role picker

## Context

Today, Last Home supports two house-selection paths:

1. **Solo Challenge mode**: the player effectively chooses the house by
   selecting one of the 4 challenge entries (Hospital, Villa, Prison,
   Elementary School) before the game starts.
2. **MP sandbox / Host mode**: the house is selected by the server bootstrap
   (`LastHomeBootstrap.lua`) from `Zomboid/Server/LastHomeHouse.cfg`, then the
   normal role picker opens.

This means the multiplayer Host flow has **no in-game UI** allowing a player to
choose the house before choosing a role. The current config-driven bootstrap is
useful for headless / repeatable hosting, but it is less practical for a Host
session where the group wants to decide the building interactively at runtime.

The server-side foundation already exists:

- `LastHomeServer.setSelectedHouse(houseId, source, actorUsername)` already
  validates and applies a pre-wave house selection.
- `LastHomeClient` / `LastHomeServer` already use client/server commands to open
  the role picker.
- The server already re-teleports assigned players if the house changes before
  waves start.

This ticket adds an explicit **house picker UI shown before the role picker** in
multiplayer sandbox mode.

## Goal

Allow an eligible player in MP sandbox / Host mode to choose the Last Home
location **before** the role picker opens, using an in-game picker listing the 4
houses.

## Non-goals

- Replacing the solo Challenges menu flow.
- Allowing house changes after waves have started.
- Reworking role definitions or role picker visuals beyond the minimum needed to
  chain house picker -> role picker.
- Removing `LastHomeHouse.cfg` support for dedicated / non-interactive hosting.

## Architecture

### 1. Activation mode: explicit `picker` config value

`LastHomeShared.getScenarioHouseId()` should accept a new config value:

- `hospital`
- `villa`
- `prison`
- `elementary_school`
- `random`
- **`picker`** (new)

Behavior:

- If the cfg contains one of the 4 house ids, behavior stays unchanged.
- If the cfg contains `random`, behavior stays unchanged.
- If the cfg contains `picker`, the bootstrap does **not** auto-select a house
  on startup. Instead, the server enters a **pending house selection** state and
  waits for an interactive player choice.

This preserves headless/dedicated compatibility while enabling Host sessions to
opt into an in-game picker.

### 2. New pre-role flow in MP sandbox mode

When the scenario is in `source == "scenario"` mode and no house is selected
because the server is in `picker` mode:

1. the client sends `RolePickerReady` as today;
2. the server **does not** open the role picker yet;
3. the server opens a new **house picker** for one eligible chooser;
4. once the server accepts `ChooseHouse(houseId)`, it calls
   `LastHomeServer.setSelectedHouse(houseId, "scenario-picker", username)`;
5. the server then opens the normal role picker.

Result: **house picker first, role picker second**.

### 3. Authority and race handling

The server must remain authoritative.

Suggested rules:

- Only one player at a time can be the **active house chooser**.
- The first eligible player who reaches the pending selection flow becomes the
  chooser.
- `ChooseHouse` commands from any other player are rejected while the chooser is
  active.
- Once a valid house is accepted, the selection is locked by the existing
  `setSelectedHouse(...)` logic and the normal role-assignment flow resumes.

Other connected players should receive a waiting message such as:

- `Choix du lieu en cours...`
- then, once selected: `Lieu choisi : Hopital`.

### 4. Eligible chooser

The minimal rule for this ticket:

- the **first non-spectator player without an assigned role** who triggers the
  pending flow becomes the chooser.

No admin permission system is required in this ticket.

If desired later, a follow-up can restrict the chooser to the Host/admin only.

### 5. House picker UI

Add a lightweight client UI similar in spirit to the role picker, but much
smaller:

- title: `Choisissez le lieu`
- 4 entries:
  - Hopital
  - Villa
  - Prison
  - Ecole elementaire
- optional short subtitle per entry with the expected atmosphere or difficulty
  if useful, but not required for this ticket.

The UI only needs to support:

- open from a server command,
- send `ChooseHouse` to the server,
- close on success,
- avoid duplicate submissions.

### 6. Integration with the existing role picker flow

Required behavior:

- If the house is already known, the current role picker flow stays unchanged.
- If the house is pending (`picker` mode), `RolePickerReady` must route to the
  house picker instead.
- After `ChooseHouse` is accepted, the server must open the role picker for:
  - the chooser,
  - and any other waiting unassigned players.

### 7. Reconnects / late joiners

- If a player joins **before** the house is selected, they should either:
  - wait while another player is choosing, or
  - become the chooser if nobody has claimed the picker yet.
- If a player joins **after** the house is selected, they should follow the
  existing flow directly (role picker or role restore).

### 8. Solo Challenge behavior remains unchanged

The 4 `media/lua/client/LastStand/LastHome*.lua` challenge files continue to
force their house as they do today.

No house picker is shown in solo Challenges mode.

## Server / client command changes

### New client -> server command

- `ChooseHouse`
  - payload:
    - `houseId`

### New server -> client commands

- `OpenHousePicker`
  - payload:
    - optional `availableHouses` list (if we want the client UI to be data-driven)
- `HouseChosen`
  - payload:
    - `houseId`
    - `houseName`
- optional `HouseSelectionWaiting`
  - payload:
    - `chooserUsername`

The exact naming may be adjusted during implementation, but the flow must stay
server-authoritative.

## Suggested implementation notes

### Client

Possible new file:

- `media/lua/client/LastHomeHousePicker.lua`

Likely touched client files:

- `media/lua/client/LastHomeClient.lua`

Responsibilities:

- open/close the house picker,
- debounce submission,
- react to `OpenHousePicker` / `HouseChosen`,
- request the normal role picker once the house has been accepted if needed.

### Server

Likely touched server files:

- `media/lua/server/LastHomeServer.lua`
- `media/lua/server/LastHomeBootstrap.lua`

Responsibilities:

- represent the pending-picker bootstrap state,
- claim/release the current chooser,
- validate `ChooseHouse`,
- fan out waiting/accepted notifications,
- route waiting players back into the normal role picker flow.

### Shared

Likely touched shared files:

- `media/lua/shared/LastHomeShared.lua`

Responsibilities:

- accept `picker` in `getScenarioHouseId()`,
- optionally expose a shared ordered house list for the new picker UI.

## Files impacted

- `media/lua/client/LastHomeClient.lua`
- `media/lua/client/LastHomeHousePicker.lua` **(new)**
- `media/lua/server/LastHomeServer.lua`
- `media/lua/server/LastHomeBootstrap.lua`
- `media/lua/shared/LastHomeShared.lua`
- `specs/LH-MP-5-house-picker-before-role-picker.md` **(new)**
- `README.md`
- `project-state.md`

## Acceptance criteria

1. In MP sandbox / Host mode, if `LastHomeHouse.cfg` contains `picker`, the
   server does **not** auto-select a house on startup.
2. In that mode, the first eligible player sees the **house picker before the
   role picker**.
3. Choosing `Hopital`, `Villa`, `Prison`, or `Ecole elementaire` applies the
   selected house through the server-authoritative path.
4. After the house choice is accepted, the role picker opens normally.
5. Other connected players cannot override the house while selection is in
   progress.
6. Once the house is chosen, reconnects / late joiners use the normal existing
   flow.
7. If `LastHomeHouse.cfg` contains `hospital`, `villa`, `prison`,
   `elementary_school`, or `random`, current behavior is unchanged.
8. Solo Challenges mode remains unchanged.

## Pitfalls

- Do not regress the existing challenge house-selection guard
  (`getChallengeID() == self.id`).
- Do not auto-open both pickers at once.
- Do not let `RolePickerReady` bypass the house picker when the server is in
  pending `picker` mode.
- Do not let the picker path break dedicated/non-interactive hosting via cfg.
- Do not allow `ChooseHouse` after waves have started.

## Dependencies

- `LH-MP-1` — reusable `LastHomeServer.setSelectedHouse(...)`
- `LH-MP-2` — MP bootstrap / `LastHomeHouse.cfg`
- Existing role picker flow in `LastHomeClient.lua` / `LastHomeServer.lua`

## Open questions

1. Should the chooser always be the **first player**, or specifically the
   **Host/admin** when that information is available?
2. Should `picker` become the recommended default for Host sessions, or remain
   optional?
3. Should the UI show preview text / difficulty hints per house, or keep the
   first version text-only?

## Size estimate

**M** — touches bootstrap state, server command routing, a new client picker,
and the handoff into the existing role picker flow.
