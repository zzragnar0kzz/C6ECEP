# Enhanced Combat Experience and Promotions for Civilization VI
![ECEP Ingame](/IMAGES/ECEP_Ingame.png)

# Overview
A mod that allows a unit to continue to receive combat experience when it has a promotion pending.

# Features
ECEP utilizes custom ingame Player and Unit properties. Together, these properties allow any valid unit to receive combat experience in some situations where it otherwise would not. Specifically:

- Any combat experience earned by a unit which exceeds the amount needed for its next promotion will now be banked instead of lost
- A unit that engages in combat when it has a promotion pending will, if it survives and is eligible, receive experience approximately equal to the amount it would have received if it did not have a pending promotion. All such experience earned will be banked

Combat experience banked in this manner is persistent between sessions. Banked experience will be applied to a unit following promotion, up to the amount required for its next promotion; it is therefore possible for a unit to bank enough experience for multiple promotions.

When the game does not provide an experience value and ECEP must calculate one, if the result of the calculation is greater than zero, ingame world-view text indicating the amount of experience earned will appear like it would when the game does provide a value. Additionally, when a unit with banked experience is selected, the banked amount will be added to the unit's current total for display in the UI, as shown above.

# Limitations
ECEP DOES NOT OPERATE IN REAL TIME! It cannot operate until it has been provided combat results by the gamecore. If multiple combats involving the same unit occur in rapid succession, it is possible that several of them will have concluded __BEFORE__ ECEP has received the results of the first. If that unit dies, it is possible that it will have been removed from the game __BEFORE__ ECEP gets a chance to act on it. ECEP will attempt to anticipate this and act accordingly.

ECEP's combat experience formula is close, but it is still only an approximation. The practical effect of this is that amounts calculated by ECEP may be slightly greater than or less than any amounts that would have been provided by the game in a similar circumstance.

ECEP does not provide combat experience in cases where the game never does.

Notwithstanding the above, ECEP enforces any caps on earned experience which may be present, such as the maximum amount from one combat and maximum amount from barbarian combat.

Ingame effects that instantly provide a unit its "next" promotion provide a variable amount of experience depending on the amount required for that unit's next promotion. Due to the way the game handles these effects, no experience will be provided if the unit has a promotion pending. ECEP currently does not affect any such experience in any way.

# Localization
ECEP's changes to ingame text involve little beyond altering the Unit Panel to reflect any banked experience in addition to the actual value, which should be accurately reflected regardless of the language in use.

# Compatibility
## SP / MP
Compatible with Single- and Multi-Player game setups.

## Rulesets
Compatible with the following rulesets:

* Standard
* Rise and Fall
* Gathering Storm

## Game Modes
Compatible with the following game modes:

* Apocalypse
* Barbarian Clans
* Dramatic Ages
* Heroes & Legends
* Monopolies and Corporations
* Secret Societies

Has not been tested with the following game modes:

* Tech and Civic Shuffle
* Zombie Defense

# Installation
## Automatic

## Manual
Download the [latest release](https://github.com/zzragnar0kzz/C6ECEP/releases/latest) and extract it into the game's local mods folder. Alternately, clone the repository into the game's local mods folder using your preferred tools. The local mods folder varies by OS:
- Windows : `$userprofile\Documents\My Games\Sid Meier's Civilization VI\Mods`
- Linux : 
- MacOS : 

To update to a newer release, clone or download the latest release as described above, overwriting any existing items in the destination folder.

# Conflicts
## Ingame
### Gameplay Scripts
ECEP employs the following new custom gameplay scripts:
- ECEP.lua

If your mod employs any gameplay scripts with similar names, conflicts __WILL__ arise.

### UI Context
ECEP employs customized versions of the following ingame UI context files for all rulesets:
- GovernmentScreen
- UnitPanel

If your mod employs custom versions of any of these UI context files, conflicts __WILL__ arise.

# Special Thanks
ECEP generally relies on knowledge gleaned from the following

* The [Civilization Fanatics](https://www.civfanatics.com/) community, particularly the [Civ VI Experience](https://forums.civfanatics.com/resources/civ-vi-experience.26777/) reference
* The [Civilization Fandom](https://civilization.fandom.com/) wiki, particularly the [Promotion (Civ6)](https://civilization.fandom.com/wiki/Promotion_(Civ6)/) article
* [Lua Objects](https://docs.google.com/spreadsheets/d/1HQSUOmw_pI8dNSr1kmun4qAHj6SsOVfa1vGTbk5mVvs/edit#gid=1768114376), a spreadsheet that breaks down some of the combat parameters

Extra special thanks to these contributors, and to the greater community.
