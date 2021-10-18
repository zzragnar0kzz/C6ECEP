# Enhanced Combat Experience and Promotions for Civilization VI
![ECEP Ingame](/IMAGES/ECEP_Ingame.png)

# Overview
A mod that allows a unit to continue to receive experience from combat after it has earned enough for its next promotion. Any such experience will be banked. Combat experience banked in this manner is persistent between sessions, and will be earned at an approximation of the usual rate. This approximation includes any applicable bonuses for an attacking unit, melee or ranged combat, and/or a kill, but excludes any experience modifiers the unit may possess.

Upon receiving a promotion, any banked experience will be applied to the unit, up to the amount needed for its next promotion. As it is possible to bank enough experience for multiple promotions, any banked experience beyond this amount will remain banked for the following promotion.

Ingame world-view text indicating the amount of experience banked from a particular combat will appear alongside or instead of the usual world-view text indicating the total amount of experience earned from that combat. Additionally, any units with banked experience will reflect the total amount banked alongside other stats in the XP area tooltip of the Unit panel when they are selected.

Experience earned from sources other than actual combat will be ignored by this mod.

# Localization
When obtained via any of the official channels referenced in the #Installation section below, releases contain new Frontend and Ingame text fully localized in the following language(s):
- English (en_US)
- Spanish (es_ES)
- French (fr_FR)

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
- UnitPanel

If your mod employs custom versions of any of these UI context files, conflicts __WILL__ arise.

# Special Thanks
To the greater community.
