# Enhanced Combat Experience and Promotions for Civilization VI
![ECEP Ingame](/IMAGES/ECEP_Ingame.png)

# Overview
A mod that allows a unit to continue to receive experience when it has a promotion pending.

# Features
ECEP utilizes custom ingame Player and Unit properties which allow any valid unit to continue to receive combat experience even after it has earned enough for its next promotion. Any experience earned which exceeds this amount will now be banked instead of lost. Combat experience banked in this manner is persistent between sessions.

Game-provided values for experience earned from a combat will be used when they are available, and will be applied to a unit's actual experience and/or stored balance as appropriate. When the game does not provide combat experience values, ECEP will attempt to approximate these values itself, and the approximated amount will be entirely applied to a unit's stored balance. This approximation is calculated based on the combat strengths of the attacking and defending units, the type of combat, and any applicable bonuses and/or modifiers, including but not limited to the following:
- Securing a kill doubles the base calculated experience amount, before any other bonuses or modifiers are applied, for the attacking unit only
- A flat bonus for Melee, Ranged, or Bombard combat types
- Modifiers from Civilization Traits, such as Nubia's +50% for Ranged units
- The Oligarchy government provides a +20% experience modifier when it is active
- Policy cards that provide an experience modifier for one or more unit types
- Modifiers from District buildings, such as +25% to trained units from a Barracks, Stable, or Lighthouse
- Great Generals, Great Admirals, and other Great People that provide an experience modifier to a unit when retired
- Modifiers for Human Players on Difficulty settings below Prince
- Modifiers for AI (Major) Players on Difficulty settings above Prince

Upon receiving a promotion, any banked experience will be applied to a unit, up to the amount needed for its next promotion. As it is possible to bank enough experience for multiple promotions, any banked experience beyond this amount will remain banked for the following promotion.

Ingame world-view text indicating the amount of experience banked from a particular combat will appear alongside or instead of the usual world-view text indicating the total amount of experience earned from that combat. Additionally, any units with banked experience will reflect the total amount banked alongside other stats in the XP area tooltip of the Unit panel when they are selected.

# Limitations
ECEP's combat experience formula is close, but there are still some unaccounted-for variables that cause its result to occassionally not match that provided by the game, when one is provided at all. The practical effect of this is that used amounts calculated by ECEP may currently be slightly greater than or less than any amounts that would have been provided by the game.

Notwithstanding the above, ECEP also enforces any caps on earned experience which may be present, such as the maximum amount from one combat and maximum amount from barbarian combat.

ECEP currently does not recognize a City siege attack separately from any other attack. If values calculated by ECEP are used for such combat, they will currently adhere to the rules and caps for unit-to-unit combat.

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
- GovernmentScreen
- UnitPanel

If your mod employs custom versions of any of these UI context files, conflicts __WILL__ arise.

# Special Thanks
To the greater community.
