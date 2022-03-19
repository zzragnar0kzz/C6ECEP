# Enhanced Combat Experience and Promotions for Civilization VI
![ECEP Ingame](/IMAGES/ECEP_Ingame.png)

# Overview
A mod that allows a unit to continue to receive combat experience when it has a promotion pending.

# Features
ECEP utilizes custom ingame Player and Unit properties. Together, these properties allow any valid unit to receive (more) combat experience in some situations where it otherwise would receive less or none at all. Specifically:

- When a unit DOES NOT have a promotion pending: If a unit earns more experience from combat than is required for its next promotion, any experience overflow will now be banked instead of lost
- When a unit DOES have a promotion pending: If a unit would otherwise be eligible for combat experience, but receives none due to being at its current level cap, ECEP will attempt to calculate the amount of experience owed. All such experience will be banked

Combat experience banked in this manner is persistent between sessions. Banked experience will be applied to a unit following promotion, up to the amount required for its next promotion; it is therefore possible for a unit to bank enough experience for multiple promotions.

When the game does not provide an experience value and ECEP must calculate one, if the result of the calculation is greater than zero, ingame world-view text indicating the amount of experience earned will appear like it would when the game does provide a value. Additionally, when a unit with banked experience is selected, the banked amount will be added to the unit's current total for display in the UI, as shown above.

## How It Works
The game is inconsistent with how it internally handles combat experience awards. If a unit survives, is eligible for combat experience, and was below its current level cap prior to combat, the game will provide a combat experience value for that unit. It does this even if the unit belongs to the Barbarian player, whose units never promote (testing shows that most Barbarian units DO in fact have an experience total, but it never changes). This is annoying, but simple enough to account for and work around.

This changes if the unit was at its current level cap prior to combat. Rather than providing a value and simply disregarding it, as it seems to do with Barbarian units, the game will instead provide a value of zero experience. When this happens, ECEP will attempt to calculate the amount of experience that should have been provided to the unit. The manner in which it does this varies depending on the other combatant.

### Unit
ECEP will consider the following when the other combatant is a unit: 

- The combat strength of the target unit (t)
- The combat strength of the enemy unit (e)
- An immediate base XP multiplier (k) equal to 1; if the target is the attacker and the enemy is dead, then instead k = a game-defined value (default 2)
- An amount of bonus XP (b) equal to the sum of any applicable flat bonus amounts, such as those for the attacking unit and for specific combat types
- A modifier (m) equal to 1.M, where M is the sum of any applicable non-difficulty percentage modifiers, including but not necessarily limited to those from 
    - civilization traits
    - unit abilities
    - active governments
    - slotted policy cards
    - city-state suzerainty
- A modifier (d) for major AI players for the selected difficulty level; on the default difficulty level, d = 1
    - If the selected level is higher than the default level, add a game-defined value (default 10%) for each level above (d > 1)
    - If the selected level is lower than the default level, subtract a game-defined value (default 15%) for each level below (d < 1)

Given the above, then `xp = ceiling((((e / t) * k) + b) * m)`.

For human and minor AI players, there are no further calculations. For major AI players, take the previous calculated value (p), and `xp = ceiling(p * d)`.

Finally, if the calculated value exceeds any defined experience caps, it will be reset as appropriate.

### City/District
If the other combatant is a city or district, most of the factors identified above will be disregarded. Base experience (e) provided varies:

- For City/District vs Unit (defending), e = a game-defined value (default 2)
- For Unit (attacking) vs City/District, e = a game-defined value (default 3). If the attack results in a captured city, then instead e = a different game-defined value (default 10)

Given the above, then `xp = ceiling(e * m)`. 

For human and minor AI players, there are no further calculations. For major AI players, take the previous calculated value (p), and `xp = ceiling(p * d)`.

Caps are NOT enforced when a city or district is involved in the combat, so every XP calculated is an XP awarded.

# Limitations
ECEP __DOES NOT__ OPERATE IN REAL TIME! It cannot operate until it has been provided combat results by the gamecore. If multiple combats involving the same unit occur in rapid succession, it is possible that several of them will have concluded __BEFORE__ ECEP has received the results of the first. If that unit dies, it is possible that it will have been removed from the game __BEFORE__ ECEP gets a chance to act on it. ECEP will attempt to anticipate this and act accordingly.

ECEP's combat experience formula is close, but it is still only an approximation. The practical effect of this is that amounts calculated by ECEP may be slightly greater than or less than any amounts that would have been provided by the game in a similar circumstance.

Sometimes, when the game provides zero experience, it actually means zero experience. ECEP does not provide combat experience in cases where the game never does.

Ingame effects that instantly provide a unit its "next" promotion provide a variable amount of experience depending on the amount required for that unit's next promotion. Due to the way the game handles these effects, no experience will be provided if the unit has a promotion pending. ECEP currently does not affect any such experience in any way.

# Misconceptions and Quirks
Regarding difficulty modifiers, the relevant database value for low difficulty is negative. ECEP does not alter this value in any way. This means that on lower difficulties, the (major) AI players are actually earning less experience, rather than the human player earning more. Since the difficulty modifier only applies to major AI players, this also means that on lower difficulties, major AI players earn less experience than city-states.

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
