# DanZ-AIO Cassiopeia V1
<p align="center">
  <img src="https://raw.communitydragon.org/14.1/game/assets/characters/cassiopeia/hud/cassiopeia_circle_0.png" width="120" title="Cassiopeia Icon">
</p>


---

## Key Features

*   **Intelligent Combo:** Utilizes Q, W, E, and R in combination based on customizable logic and prediction.
*   **Advanced Farming Modes:** Multiple configurable farming modes to suit different lane situations:
    *   Q Only (Prioritizes hitting multiple minions)
    *   Q Clear + E Last Hit
    *   E Last Hit Only (Default)
    *   Q Clear + E Clear (Aggressive E usage)
    *   Cycle through modes using a dedicated keybind (Default: `MMB`).
*   **Jungle Clear:** Efficiently clears jungle camps using Q and E based on mana limits.
*   **Harass/Hybrid Mode:** Uses Q, W, and E for poking, with optional E last hitting.
*   **Killsteal:** Automatically attempts to secure kills with Q, E, W, or R when targets are low enough.
*   **Auto Abilities:**
    *   **Auto Q:** Harasses enemies automatically (toggleable, with turret safety option).
    *   **Auto R:** Uses ultimate automatically on CC'd targets, to interrupt specific spells, or when multiple enemies are facing you.
    *   **Auto W:** Casts Miasma on CC'd targets or to counter enemy dashes.
    *   **Auto CC:** Uses Q and W on CC'd targets.
*   **Semi-Cast Keys:** Hold dedicated keys (Default: `Q`, `W`, `E`, `R`) to manually aim and cast spells.
*   **Flash + R Combo:** Execute a Flash + R combo with a dedicated keybind (Default: `T`).
*   **AA Blocking:** Smartly blocks auto-attacks during farming to prioritize E last hits and during combo based on spell availability.
*   **Customizable Drawings:** Visualize spell ranges, predicted damage on health bars, poisoned targets, and script status (Farm Mode, Auto Q).
*   **Permashow Indicators:** Clear visual feedback for the currently selected Farm Mode and Auto Q status.
*   **Detailed Menu:** Extensive configuration options with tooltips for every setting in both English and Chinese.

---

## Changelog (V4.3)

*   **Integrated multi-mode farming:** Added Q Only, Q+E Last Hit, E Last Hit Only, and Q Clear + E Clear modes.
*   **Cycle farm mode:** Implemented keybind (Default: `MMB`) to cycle through farm modes.
*   **Updated Permashow:** Added status indicators for the current farm mode.
*   **Refined AA blocking:** Improved logic for blocking auto-attacks to prioritize E last hitting.
*   **Added Jungle Clear:** Implemented Q/E usage for jungle camps with corrected mob selection.
*   **Added Auto Q Safety:** Option to disable Auto Q harass while under enemy turrets.
*   **Reworked Combo AA Blocking:** Option to only allow AAs in combo when Q or E is on cooldown.
*   **Reworked R Combo Logic:** Added modes: Never, Always (if stunnable), Below X% HP.
*   **Improved Q Farm Logic:** Enhanced Q aiming in farm modes (1, 2, 4) to prioritize hitting multiple minions.
*   **Added Q Clear + E Clear Mode:** New aggressive farming option.
*   **Code Structure:** General improvements and minor bug fixes.

---

## Configuration Options


### Combo Settings
*   **Only AA in Combo if Q/E Down:** Prevents auto-attacking during combo if both Q and E are ready to be cast.

### Q - Noxious Blast
*   **Toggle Auto Q:** Keybind (`G`) to enable/disable automatic Q harass.
*   **Use Q in Combo:** Enable/Disable Q usage during Combo mode.
*   **Use Q in Harass:** Enable/Disable Q usage during Harass/Hybrid mode.
*   **Use Q in Flee:** Enable/Disable Q usage while fleeing.
*   **Use Q to Killsteal:** Allow Q for securing kills.
*   **Auto Q on CC'd:** Automatically Q enemies under hard crowd control.
*   **Don't Auto Q Under Enemy Turret:** Prevents Auto Q harass if you are under an enemy turret.
*   **Q Harass Mana Limit %:** Minimum mana required for Auto Q/Harass Q.
*   **Q Semi-Cast Key:** Keybind (`Q`) for manual Q casting.
*   **Q Range:** Adjust the maximum cast range for Q.

### W - Miasma
*   **Use W in Combo:** Enable/Disable W usage during Combo mode.
*   **Use W in Harass:** Enable/Disable W usage during Harass/Hybrid mode.
*   **W Anti-Dash:** Automatically use W to block enemy dashes.
*   **Auto W on CC'd:** Automatically W enemies under hard crowd control.
*   **Use W in Flee:** Cast W behind you while fleeing.
*   **W Harass Mana Limit %:** Minimum mana required for Harass W.
*   **W Semi-Cast Key:** Keybind (`W`) for manual W casting.
*   **W AoE Priority (Teamfight):** Prioritize hitting multiple enemies with W in Combo mode.
*   **Max Range:** Adjust the maximum cast range for W.

### E - Twin Fang
*   **Use E in Combo:** Enable/Disable E usage during Combo mode.
*   **Use E in Harass:** Enable/Disable E usage during Harass/Hybrid mode.
*   **Use E Last Hit in Harass:** Prioritize using E to last hit minions during Harass mode.
*   **Use E to Killsteal:** Allow E for securing kills.
*   **E Only on Poisoned:** Only cast E on targets currently poisoned by Q or W.
*   **E Semi-Cast Key:** Keybind (`E`) for manual E casting.

### R - Petrifying Gaze
*   **R Combo Usage Mode:**
    *   `[1] Never`: Don't use R in combo.
    *   `[2] Always (If Stunnable)`: Use R if the target is facing you.
    *   `[3] Below X% HP`: Use R if the target is facing you and below a certain health threshold.
*   **R HP Limit % (Mode 3):** Health threshold for R usage in Mode 3.
*   **Auto R on CC'd:** Automatically R CC'd enemies (if facing).
*   **Auto R Interrupt Spells:** Automatically R to interrupt specific enemy channels (if facing).
*   **R Interrupt Spell List:** (Sub-menu) Enable/Disable interruption for specific champion abilities.
*   **Flash R Keybind:** Keybind (`T`) to execute Flash + R.
*   **R Semi-Cast Key:** Keybind (`R`) for manual R casting.
*   **Auto R Min Facing Enemies:** Minimum number of facing enemies required to trigger Auto R.

### Killsteal Settings
*   **Enable Killsteal:** Master toggle for all KS features.
*   **Q/W/E/R Toggles:** Enable/Disable specific spells for killstealing.

### Farm Settings
*   **Farm Mode:** Select the current farming logic (Q Only, Q+E Last Hit, E Last Hit Only, Q+E Clear).
*   **Cycle Farm Mode:** Keybind (`MMB`) to switch between farm modes.
*   **Farm Mana Limit %:** Minimum mana required for using spells in lane farm.
*   **Q Clear Min Hit (Modes 1, 2, 4):** Minimum minions Q must hit to be used for clearing.
*   **Use Q/E in Jungle Clear:** Enable/Disable spells for jungle farming.
*   **Jungle Mana Limit %:** Minimum mana required for using spells in jungle clear.

### Draw Settings
*   **Enable Drawings:** Master toggle for all script visuals.
*   **Draw Q/W/E/R Range:** Display spell ranges.
*   **Draw Damage Indicator:** Show potential combo damage on enemy health bars.
*   **Draw Poisoned Targets:** Circle poisoned enemies.
*   **Draw Farm Mode:** Display current farm mode above player.
*   **Draw Auto Q Status:** Display Auto Q status (ON/OFF) above player.

### Debug Settings
*   **Print Buffs:** Continuously print target buffs to console (for debugging).
*   **Print Buffs Key:** Keybind (`B`) to print target buffs once.

---

## Usage

*   **Combo:** Hold the Orbwalker's Combo key (Default: `Space`).
*   **Harass/Hybrid:** Hold the Orbwalker's Harass/Hybrid key (Default: `C`).
*   **Lane Clear:** Hold the Orbwalker's Lane Clear key (Default: `V`).
*   **Last Hit:** Hold the Orbwalker's Last Hit key (Default: `X`).
*   **Flee:** Hold the Orbwalker's Flee key (Default: `Z`).
*   **Farm Mode Cycle:** Press the assigned key (Default: `MMB`) to switch between `Q Only` -> `Q+E Last Hit` -> `E Last Hit Only` -> `Q+E Clear` -> `Q Only`. The current mode is shown via Permashow/Drawings.
*   **Auto Q Toggle:** Press the assigned key (Default: `G`) to toggle Auto Q harass ON/OFF. Status is shown via Permashow/Drawings.
*   **Semi-Cast:** Hold the respective spell key (Default: `Q`, `W`, `E`, `R`) to aim and cast manually.
*   **Flash R:** Hold the assigned key (Default: `T`) to attempt a Flash + R combo on a suitable target.

---
