--[[ =========================================================================
	ECEP : Enhanced Combat Experience and Promotions for Civilization VI
	Copyright (C) 2021 zzragnar0kzz
	All rights reserved
=========================================================================== ]]

--[[ =========================================================================
	begin ECEP.lua gameplay script
=========================================================================== ]]

--[[ =========================================================================
	pre-pre-init context sharing
        simplifies accessing any later exposed globals
        provides access to exposed members from other scripts
	should be defined prior to any exposed globals
=========================================================================== ]]
-- shortcut for global exposed members
EM = ExposedMembers;

--[[ =========================================================================
	pre-init exposed globals
        objects here are used by multiple functions in this and other scripts
	should be defined prior to Initialize()
=========================================================================== ]]
-- exposed member function DebugPrint( sFunction, sMessage ) prints a debug entry with sFunction and sMessage to the log file if IsDebugEnabled is true
function EM.DebugPrint( sFunction, sMessage ) if EM.IsDebugEnabled then print("[DEBUG] " .. sFunction .. "(): " .. sMessage); end end
-- the global Debug flag; DebugPrint() successfully outputs if this is true
EM.IsDebugEnabled = true;
-- shortcut for DebugPrint()
Dprint = EM.DebugPrint;
-- exactly what it says on the tin
EM.RowOfDashes = (EM.RowOfDashes) and EM.RowOfDashes or "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -";
-- table of minimum and maximum XP amounts per level, with valid ranges
EM.PromotionLevels = (EM.PromotionLevels) and EM.PromotionLevels or { 
	{ Min = 0, Max = 15, Range = 15 }, { Min = 15, Max = 45, Range = 30 }, { Min = 45, Max = 90, Range = 45 }, { Min = 90, Max = 150, Range = 60 }, 
	{ Min = 150, Max = 225, Range = 75 }, { Min = 225, Max = 315, Range = 90 }, { Min = 315, Max = 420, Range = 105 }, { Min = 420, Max = 540, Range = 120 }
};
-- table of current government indices by Player
EM.PlayerGovernments = (EM.PlayerGovernments) and EM.PlayerGovernments or {};
-- global experience max-per-combat, barbarian soft cap, and max barbarian level values
EM.MaxExperiencePerCombat = tonumber(GameInfo.GlobalParameters["EXPERIENCE_MAXIMUM_ONE_COMBAT"].Value);
EM.ExperienceBarbSoftCap = tonumber(GameInfo.GlobalParameters["EXPERIENCE_BARB_SOFT_CAP"].Value);
EM.ExperienceMaxBarbLevel = tonumber(GameInfo.GlobalParameters["EXPERIENCE_MAX_BARB_LEVEL"].Value);
-- table of policy cards with combat experience modifiers, keyed by both policy type and database index
EM.PolicyXPModifiers = {};
for policy in GameInfo.PolicyModifiers() do 
    if (string.find(policy.ModifierId, "EXPERIENCE") ~= nil) then 
        for modifier in GameInfo.ModifierArguments() do 
            if modifier.ModifierId == policy.ModifierId and modifier.Name == "Amount" then 
                local iPolicyIndex = GameInfo.Policies[policy.PolicyType].Index;
                EM.PolicyXPModifiers[iPolicyIndex] = { Policy = policy.PolicyType, Modifier = modifier.Value };
                EM.PolicyXPModifiers[policy.PolicyType] = iPolicyIndex;
            end
        end
    end
end
-- table of governments with combat experience modifiers, keyed by both government type and database index
EM.GovernmentXPModifiers = {};
for government in GameInfo.GovernmentModifiers() do 
    if (string.find(government.ModifierId, "EXPERIENCE") ~= nil) then 
        for modifier in GameInfo.ModifierArguments() do 
            if modifier.ModifierId == government.ModifierId and modifier.Name == "Amount" then 
                local iGovernmentIndex = GameInfo.Governments[government.GovernmentType].Index;
                EM.GovernmentXPModifiers[iGovernmentIndex] = { Government = government.GovernmentType, Modifier = modifier.Value };
                EM.GovernmentXPModifiers[government.GovernmentType] = iGovernmentIndex;
            end
        end
    end
end
-- table of unit abilities with combat experience modifiers
EM.AbilityXPModifiers = {};
for ability in GameInfo.UnitAbilityModifiers() do 
    if (string.find(ability.UnitAbilityType, "EXPERIENCE") ~= nil) or (string.find(ability.UnitAbilityType, "TRAINED_UNIT_XP") ~= nil) or (string.find(ability.UnitAbilityType, "TRAINED_AIRCRAFT_XP") ~= nil) or (string.find(ability.UnitAbilityType, "TOQUI_XP") ~= nil) or (ability.UnitAbilityType == "ABILITY_MUSTANG" and ability.ModifierId == "MUSTANG_MORE_EXPERIENCE") or (ability.UnitAbilityType == "ABILITY_ZULU_IMPI") then 
        for modifier in GameInfo.ModifierArguments() do 
            if modifier.ModifierId == ability.ModifierId and modifier.Name == "Amount" then 
                EM.AbilityXPModifiers[ability.UnitAbilityType] = modifier.Value;
            end
        end
    end
end
-- CombatTypes does not appear to be available in this context, so define a makeshift version; (unknown hashes?: 1184946373, 1640240290)
EM.CombatTypeByHash = { [1184946373] = "AIR", [1338578493] = "BOMBARD", [1640240290] = "ICBM", [748940753] = "MELEE", [784649805] = "RANGED", ["-3"] = "RELIGIOUS" };
-- global combat tracker; this should increment with each combat
EM.CombatCounter = (EM.CombatCounter) and EM.CombatCounter or 0;
-- difficulty data
EM.DifficultyLevels, EM.NumDifficultyLevels = {}, 0;
for row in GameInfo.Difficulties() do
	EM.NumDifficultyLevels = EM.NumDifficultyLevels + 1;
	EM.DifficultyLevels[DB.MakeHash(row.DifficultyType)] = { DifficultyType = row.DifficultyType, Modifier = EM.NumDifficultyLevels };
end

--[[ =========================================================================
	exposed member function GetCombatXP( pPlayer, pPlayerConfig, pPlayerCulture, pTarget, pEnemy, bIsAttacker, sCombatType, pUnit )
        manually calculates combat experience for pTarget, for when the game fails to provide a value, like when the unit has any pending promotion(s)
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.GetCombatXP( pPlayer, pPlayerConfig, pPlayerCulture, pTarget, pEnemy, bIsAttacker, sCombatType, pUnit )
    -- debugging header, bonus for attacking unit, and this player's ID
    local sF, iAttackerBonusXP, iPlayerID = "GetCombatXP", (bIsAttacker) and 1 or 0, pPlayer:GetID();
    -- nil checks; return nil and a message if these fail
    if pUnit == nil then return nil, "Player " .. tostring(iPlayerID) .. ": Players:GetUnits():FindID() returned nil for Unit " .. tostring(iUnitID) .. "; skipping this Unit"; end
    if pUnit:GetExperience() == nil then return nil, "Player " .. tostring(iPlayerID) .. ": Unit:GetExperience() returned nil for Unit " .. tostring(iUnitID) .. "; skipping this Unit"; end
    -- table of bonuses for combat type, and table of active combat bonuses
    local tCombatBonusXP, tBonuses = { AIR = 2, BOMBARD = 1, ICBM = 0, MELEE = 2, RANGED = 1, RELIGIOUS = 0 }, { ATTACKER = (bIsAttacker) };
    local iCombatBonusXP = (tCombatBonusXP[sCombatType] ~= nil) and tCombatBonusXP[sCombatType] or 0;
    for k, v in pairs(tCombatBonusXP) do tBonuses[k] = (k == sCombatType); end
    -- total bonus to be added to the base amount prior to modifiers
    local iTotalBonusXP = iAttackerBonusXP + iCombatBonusXP;
    -- this unit's GetAbility() method, unit data, and promotion class
    local pUnitAbility = (pUnit ~= nil) and pUnit:GetAbility() or nil;
    local pUnitData = (pUnit ~= nil) and GameInfo.Units[pUnit:GetType()] or nil;
    local sPromotionClass = (pUnitData ~= nil and pUnitData.PromotionClass ~= nil) and pUnitData.PromotionClass or nil;
    -- target and enemy combat strengths
    local iTargetStr, iEnemyStr = pTarget[CombatResultParameters.COMBAT_STRENGTH], pEnemy[CombatResultParameters.COMBAT_STRENGTH];
    -- default XP modifier, Kabul suzerain XP modifier, difficulty type hash, and active modifiers table
    local iXPModifier, iKabulXPModifier, hDifficulty, tModifiers = 100, 100, pPlayerConfig:GetHandicapTypeID(), {};
    -- difficulty level from type and modifier
    local sDifficulty, iDifficulty = EM.DifficultyLevels[hDifficulty].DifficultyType, EM.DifficultyLevels[hDifficulty].Modifier;
    -- instantly double the base XP when the enemy is destroyed
    local bIsEnemyDead = (pEnemy[CombatResultParameters.FINAL_DAMAGE_TO] > pEnemy[CombatResultParameters.MAX_HIT_POINTS]);
    local iKillModifier = (bIsAttacker and bIsEnemyDead and sCombatType ~= "AIR" and sCombatType ~= "ICBM" and sCombatType ~= "RELIGIOUS") and 2 or 1;
    tModifiers.KILL = (iKillModifier > 1);
    -- adjust the XP modifier for each valid ability attached to this unit
    for k, v in pairs(EM.AbilityXPModifiers) do 
        -- number of times this ability has been attached to this unit
		local iAbilityCount = (pUnitAbility ~= nil) and pUnitAbility:GetAbilityCount(k) or -1;
		-- adjust the XP modifier when the unit has this ability
		if iAbilityCount ~= nil and iAbilityCount > 0 then 
            iXPModifier = iXPModifier + v;
            tModifiers[k] = true;
        end
    end
    -- adjust the XP modifier for any valid policy card that is slotted
    for i = 0, pPlayerCulture:GetNumPolicySlots() - 1 do 
        -- database index of the policy in slot i
        local iPolicyIndex = pPlayerCulture:GetSlotPolicy(i);
        -- adjust the XP modifier when policy Survey is slotted and the target unit is a recon unit
        if iPolicyIndex == EM.PolicyXPModifiers.POLICY_SURVEY and sPromotionClass == "PROMOTION_CLASS_RECON" then 
            iXPModifier = iXPModifier + EM.PolicyXPModifiers[iPolicyIndex].Modifier;
            tModifiers[EM.PolicyXPModifiers[iPolicyIndex].Policy] = true;
        -- catch for any other valid policy; adjust the XP modifier by the indicated amount
        elseif iPolicyIndex ~= EM.PolicyXPModifiers.POLICY_SURVEY and EM.PolicyXPModifiers[iPolicyIndex] ~= nil then 
            iXPModifier = iXPModifier + EM.PolicyXPModifiers[iPolicyIndex].Modifier;
            tModifiers[EM.PolicyXPModifiers[iPolicyIndex].Policy] = true;
        end
	end
    -- major player XP modifiers
    if pPlayer:IsMajor() then 
        local iGovernmentIndex = pPlayer:GetProperty("CURRENT_GOVERNMENT_INDEX");
        if iGovernmentIndex == nil or iGovernmentIndex == -1 then iGovernmentIndex = (EM.PlayerGovernments[iPlayerID] ~= nil) and EM.PlayerGovernments[iPlayerID] or -1; end
        pPlayer:SetProperty("CURRENT_GOVERNMENT_INDEX", iGovernmentIndex);
        Dprint(sF, "Player " .. iPlayerID .. ": CURRENT_GOVERNMENT_INDEX property is set to " .. iGovernmentIndex);
        -- adjust the XP modifier for major players when a valid government is in use
        if EM.GovernmentXPModifiers[iGovernmentIndex] ~= nil then 
            iXPModifier = iXPModifier + EM.GovernmentXPModifiers[iGovernmentIndex].Modifier;
            tModifiers[EM.GovernmentXPModifiers[iGovernmentIndex].Government] = true;
        end
        -- adjust the XP modifier when this major player is suzerain of Kabul
        for i, pMinor in ipairs(PlayerManager.GetAliveMinors()) do 
            -- this minor player's ID
            local iMinorID = pMinor:GetID();
            -- this minor's config and influence
	    	local pMinorConfig, pMinorInfluence = PlayerConfigurations[iMinorID], pMinor:GetInfluence();
            -- true when this minor is Kabul, target player is its suzerain, and target player is attacker
    		if pMinorConfig ~= nil and pMinorConfig:GetCivilizationTypeName() == "CIVILIZATION_KABUL" and pMinorInfluence ~= nil and pMinorInfluence:GetSuzerain() == iPlayerID and bIsAttacker then 
                -- adjust the XP modifier
                iXPModifier = iXPModifier + iKabulXPModifier;
                tModifiers.KABUL_SUZERAIN = true;
    		end
	    end
        -- adjust the XP modifier for the indicated difficulty level when this is the human player
        if pPlayer:IsHuman() and iDifficulty < 4 then 
            if sDifficulty == "DIFFICULTY_SETTLER" then iXPModifier = iXPModifier + 45;
            elseif sDifficulty == "DIFFICULTY_CHIEFTAIN" then iXPModifier = iXPModifier + 30;
            elseif sDifficulty == "DIFFICULTY_WARLORD" then iXPModifier = iXPModifier + 15;
            end
            tModifiers["HUMAN_" .. sDifficulty] = true;
        -- adjust the XP modifier for the indicated difficulty level when this is a major AI player
        elseif not pPlayer:IsHuman() and iDifficulty > 4 then 
            if sDifficulty == "DIFFICULTY_KING" then iXPModifier = iXPModifier + 10;
            elseif sDifficulty == "DIFFICULTY_EMPEROR" then iXPModifier = iXPModifier + 20;
            elseif sDifficulty == "DIFFICULTY_IMMORTAL" then iXPModifier = iXPModifier + 30;
            elseif sDifficulty == "DIFFICULTY_DEITY" then iXPModifier = iXPModifier + 40;
            end
            tModifiers["AI_" .. sDifficulty] = true;
        end
    end
    -- calculate the XP amount for this combat and round up the result
    local iXP = math.ceil(((iKillModifier * (iEnemyStr / iTargetStr)) + iTotalBonusXP) * (iXPModifier / 100));
    -- debugging 
    local sPriInfoMsg = "Valid combat experience bonuses: ";
    for k, v in pairs(tBonuses) do if v then sPriInfoMsg = sPriInfoMsg .. "[" .. k .. "] "; end end
    Dprint(sF, sPriInfoMsg);
    local sSecInfoMsg = "Valid combat experience modifiers: ";
    for k, v in pairs(tModifiers) do if v then sSecInfoMsg = sSecInfoMsg .. "[" .. k .. "] "; end end
    Dprint(sF, sSecInfoMsg);
    local sDebugMsg = "ECEP calculated combat experience: ceiling(((" .. iKillModifier .. " * (" .. iEnemyStr .. " / " .. iTargetStr .. ")) + " .. iTotalBonusXP .. ") * (" .. iXPModifier .. " / 100)) = " .. iXP;
    Dprint(sF, sDebugMsg);
    -- reset the calculated XP amount when it exceeds the global max-per-combat value
    if iXP > EM.MaxExperiencePerCombat then iXP = EM.MaxExperiencePerCombat; end
    -- return the final determined XP amount and a nil message
    return iXP, nil;
end

--[[ =========================================================================
	exposed member function SetXPBalance( pTarget, pEnemy, bIsAttacker, sCombatType, iX, iY )
        (re)sets XP balance data for pTarget
        displays world-view text at (iX, iY) reflecting XP banked from a combat
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.SetXPBalance( pTarget, pEnemy, bIsAttacker, sCombatType, iX, iY )
    -- debugging header, target player and unit IDs, and target player data
	local sF, iPlayerID, iUnitID = "SetXPBalance", pTarget[CombatResultParameters.ID].player, pTarget[CombatResultParameters.ID].id;
    local pPlayer = Players[iPlayerID];
    -- barbarian units do not appear to accrue combat experience, so abort here if target player is the barbarian player
    if pPlayer:IsBarbarian() then 
        Dprint(sF, "Player " .. iPlayerID .. ": Skipping Barbarian Unit " .. iUnitID);
        return;
    end
    -- target player configuration data and culture data, and target unit data
    local pPlayerConfig, pPlayerCulture, pUnit = PlayerConfigurations[iPlayerID], pPlayer:GetCulture(), pPlayer:GetUnits():FindID(iUnitID);
    -- manually calculated XP value, and game-provided or manually calculated XP value
    local iTargetXP, sResult = EM.GetCombatXP(pPlayer, pPlayerConfig, pPlayerCulture, pTarget, pEnemy, bIsAttacker, sCombatType, pUnit);
    if iTargetXP == nil then 
        Dprint(sF, sResult);
        return;
    end
    Dprint(sF, "ECEP final determined combat experience: " .. iTargetXP);
	local iXP = (pTarget[CombatResultParameters.EXPERIENCE_CHANGE] > 0) and pTarget[CombatResultParameters.EXPERIENCE_CHANGE] or iTargetXP;
    Dprint(sF, "Actual combat experience: " .. iXP);
	-- true when target unit data exists
	if (pUnit ~= nil) then 
        -- target unit XP data
		local pUnitExperience = pUnit:GetExperience();
        -- true when target unit XP data exists
        if (pUnitExperience ~= nil) then 
	    	-- target unit's level, current XP, and XPFNL
    	    local iLevel, iCurrentXP, iXPFNL = 1, pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
            -- local iXPTNL = iXPFNL - iCurrentXP;
            for i, v in ipairs(EM.PromotionLevels) do if (iCurrentXP >= v.Min and iCurrentXP <= v.Max) then iLevel = i; end end
            -- enforce barbarian XP soft cap
            local iEnemyID = pEnemy[CombatResultParameters.ID].player;
            if iLevel >= EM.ExperienceMaxBarbLevel and Players[iEnemyID] ~= nil and Players[iEnemyID]:IsBarbarian() then iXP = EM.ExperienceBarbSoftCap; end
	    	-- target unit's current XP balance and last known current XP total
        	local iBalanceXP = (pUnit:GetProperty("XP_BALANCE") ~= nil) and pUnit:GetProperty("XP_BALANCE") or 0;
	    	local iLastCurrentXP = (pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
            -- target unit's new XP balance and amount of XP to be banked
            local iBankXP = ((iLastCurrentXP + iXP) > iXPFNL) and ((iLastCurrentXP + iXP) - iXPFNL) or 0;
            Dprint(sF, "Combat experience banked from this combat for this unit: " .. iBankXP);
            local iNewBalanceXP = iBalanceXP + iBankXP;
            Dprint(sF, "New banked experience balance for this unit: " .. iNewBalanceXP);
	    	-- reset the target unit's XP balance and last known current XP total properties to the new values
    		pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
    		pUnit:SetProperty("LAST_CURRENT_XP", iCurrentXP);
	        -- debugging output
            local sAction = bIsAttacker and "Attacking" or "Defending";
		    local sPriAttMsg = "Player " .. iPlayerID .. ": " .. sAction .. " Unit " .. iUnitID .. " survived, earning " .. iXP .. " combat experience";
			local sSecAttMsg = " (" .. iLastCurrentXP .. " --> " .. iCurrentXP .. " XP / " .. iXPFNL .. " FNL, balance " .. iBalanceXP .. " --> " .. iNewBalanceXP .. " XP)";
        	Dprint(sF, sPriAttMsg .. sSecAttMsg);
            -- popup text to indicate how much, if any, experience was banked
            if iBankXP > 0 and Players[iPlayerID]:IsHuman() then 
                Game.AddWorldViewText(iPlayerID, Locale.Lookup("[COLOR_LIGHTBLUE] +{1_XP}XP stored pending promotion [ENDCOLOR]", iBankXP), iX, iY, 0);
            end
        end
    end
end

--[[ =========================================================================
	event listener function OnCombat( tCombatResult )
        parses combat results and banks any applicable experience earned
	should be defined prior to Initialize()
=========================================================================== ]]
function OnCombat( tCombatResult )
	-- debugging header, and attacker and defender combat result parameters
	local sF, pAttacker, pDefender = "OnCombat", tCombatResult[CombatResultParameters.ATTACKER], tCombatResult[CombatResultParameters.DEFENDER];
	-- map (x, y) coordinates of the combat location
	local iX, iY = tCombatResult[CombatResultParameters.LOCATION].x, tCombatResult[CombatResultParameters.LOCATION].y;
    -- increment global combat tracker, and get combat type values
    EM.CombatCounter = EM.CombatCounter + 1;
    local hCombatType = tCombatResult[CombatResultParameters.COMBAT_TYPE];
    local sCombatType = (EM.CombatTypeByHash[hCombatType] ~= nil) and EM.CombatTypeByHash[hCombatType] or "undefined";
    local bDefenderCaptured = tCombatResult[CombatResultParameters.DEFENDER_CAPTURED];
    local sPriDebugMsg = tostring("Tracked global combat " .. EM.CombatCounter .. ": " .. sCombatType .. " (Hash " .. hCombatType .. ")");
    if bDefenderCaptured then sPriDebugMsg = sPriDebugMsg .. " plus captured defender"; end
    Dprint(sF, sPriDebugMsg);
	-- these are true when the attacker or defender, respectively, is a unit
	pAttacker.IsUnit, pDefender.IsUnit = pAttacker[CombatResultParameters.ID].type == ComponentType.UNIT, pDefender[CombatResultParameters.ID].type == ComponentType.UNIT;
    -- these are true when the attacker or defender, respectively, has sustained more damage than it has hit points
    pAttacker.IsDead = pAttacker[CombatResultParameters.FINAL_DAMAGE_TO] > pAttacker[CombatResultParameters.MAX_HIT_POINTS];
    pDefender.IsDead = pDefender[CombatResultParameters.FINAL_DAMAGE_TO] > pDefender[CombatResultParameters.MAX_HIT_POINTS];
    -- set attacker XP balance info when it is a unit and it is not dead
    if pAttacker.IsUnit and not pAttacker.IsDead then EM.SetXPBalance(pAttacker, pDefender, true, sCombatType, iX, iY); end
    -- set defender XP balance info when it is a unit and it is not dead
    if pDefender.IsUnit and not pDefender.IsDead then EM.SetXPBalance(pDefender, pAttacker, false, sCombatType, iX, iY); end
end

--[[ =========================================================================
	event listener function OnPlayerTurnDeactivated( iPlayerID )
        uses context sharing to (re)set CURRENT_GOVERNMENT_INDEX for Player iPlayerID
	should be defined prior to Initialize()
=========================================================================== ]]
function OnPlayerTurnDeactivated( iPlayerID )
    if EM.PlayerGovernments[iPlayerID] ~= nil then 
        local sF, pPlayer = "OnPlayerTurnDeactivated", Players[iPlayerID];
        local iCurrentGovernmentIndex = pPlayer:GetProperty("CURRENT_GOVERNMENT_INDEX");
        if iCurrentGovernmentIndex ~= EM.PlayerGovernments[iPlayerID] then 
            pPlayer:SetProperty("CURRENT_GOVERNMENT_INDEX", EM.PlayerGovernments[iPlayerID]);
            Dprint(sF, "Player " .. iPlayerID .. ": CURRENT_GOVERNMENT_INDEX property reset to " .. EM.PlayerGovernments[iPlayerID]);
            EM.PlayerGovernments[iPlayerID] = nil;
        end
    end
end

--[[ =========================================================================
	event listener function OnUnitAbilityGained( iPlayerID, iUnitID, eAbilityType )
        if applicable, updates a unit's last current XP when it gains a new ability
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitAbilityGained( iPlayerID, iUnitID, eAbilityType )
    local sF, pUnit = "OnUnitAbilityGained", Players[iPlayerID]:GetUnits():FindID(iUnitID);
    local pUnitExperience, sDebugMsg = (pUnit ~= nil) and pUnit:GetExperience() or nil, "Player " .. iPlayerID .. ": Unit " .. iUnitID .. " gained Ability " .. tostring(eAbilityType);
    if (pUnitExperience ~= nil) then 
        -- current experience, and last known current experience
        local iCurrentXP = pUnitExperience:GetExperiencePoints();
	    local iLastCurrentXP = (pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
        -- reset last known current experience when this is true
        if iCurrentXP ~= iLastCurrentXP then 
            pUnit:SetProperty("LAST_CURRENT_XP", iCurrentXP);
            sDebugMsg = sDebugMsg .. "; resetting last current experience value for this unit to " .. iCurrentXP .. " XP";
        end
        -- debugging
        Dprint(sF, sDebugMsg);
    end
end

--[[ =========================================================================
	event listener function OnUnitAddedToMap( iPlayerID, iUnitID )
        adds ECEP properties to units when they are created
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitAddedToMap( iPlayerID, iUnitID )
	-- unit data
	local pUnit = Players[iPlayerID]:GetUnits():FindID(iUnitID);
    -- true when unit data exists
    if (pUnit ~= nil) then 
        -- unit XP data
        local pUnitExperience = pUnit:GetExperience();
        -- true when unit XP data exists
        if (pUnitExperience ~= nil) then 
            -- unit's current XP total, and debugging header
            local iCurrentXP, sF = pUnitExperience:GetExperiencePoints(), "OnUnitAddedToMap";
	        -- initialize XP balance and last known XP total properties
	        pUnit:SetProperty("XP_BALANCE", 0);
	        pUnit:SetProperty("LAST_CURRENT_XP", iCurrentXP);
            -- debugging output
            Dprint(sF, "Player " .. iPlayerID .. ": New Unit " .. iUnitID .. " has " .. iCurrentXP .. " XP");
        end
    end
end

--[[ =========================================================================
	event listener function OnUnitRemovedFromMap( iPlayerID, iUnitID )
        actions to perform around units when they are destroyed or otherwise removed
	should be defined prior to Initialize()
=========================================================================== ]]
-- function OnUnitRemovedFromMap( iPlayerID, iUnitID )
-- end

--[[ =========================================================================
	event listener function OnUnitPromoted( iPlayerID, iUnitID )
        applies any banked experience to a unit following a promotion, up to the amount required for its next promotion
        any experience beyond this amount will remain banked
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitPromoted( iPlayerID, iUnitID )
	-- unit data
	local pUnit = Players[iPlayerID]:GetUnits():FindID(iUnitID);
    -- true when unit data exists
    if (pUnit ~= nil) then 
        -- unit XP data
        local pUnitExperience = pUnit:GetExperience();
        -- true when unit XP data exists
        if (pUnitExperience ~= nil) then 
    	    -- unit's banked XP, and debugging header
	        local iBalanceXP, sF = pUnit:GetProperty("XP_BALANCE"), "OnUnitPromoted";
            -- init XP_BALANCE for this unit if it has not yet been set
            if iBalanceXP == nil then pUnit:SetProperty("XP_BALANCE", 0);
        	-- true when unit has banked XP
            elseif iBalanceXP ~= nil and iBalanceXP > 0 then 
    		    -- unit's level, current XP total, XPFNL, and XP grant after promotion
		        local iLevel, iCurrentXP, iXPFNL = 1, pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
	        	for i, v in ipairs(EM.PromotionLevels) do if (iCurrentXP >= v.Min and iCurrentXP <= v.Max) then iLevel = i; end end
        		local iGrantXP = (iBalanceXP > EM.PromotionLevels[iLevel].Range) and EM.PromotionLevels[iLevel].Range or iBalanceXP;
                -- add XP grant after promotion to unit, and get new current XP total
	    	    pUnitExperience:ChangeExperience(iGrantXP);
                local iNewCurrentXP = pUnitExperience:GetExperiencePoints();
                -- reset unit's XP balance and last known current XP total property values
                pUnit:SetProperty("XP_BALANCE", (iBalanceXP - iGrantXP));
                pUnit:SetProperty("LAST_CURRENT_XP", iNewCurrentXP);
                -- debugging
                local sPriInfoMsg = "Player " .. iPlayerID .. ": Restoring experience to Unit " .. iUnitID .. " from its balance following promotion (";
        		local sSecInfoMsg = iGrantXP .. " XP, with " .. pUnit:GetProperty("XP_BALANCE") .. " remaining), and resetting last current experience value for this unit to ";
	        	Dprint(sF, sPriInfoMsg .. sSecInfoMsg .. iNewCurrentXP .. " XP");
            end
    	end
    end
end

--[[ =========================================================================
	event listener function OnUnitUpgraded( iPlayerID, iUnitID )
        actions to perform around units when they are upgraded
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitUpgraded( iPlayerID, iUnitID )
    -- unit data
	local pUnit = Players[iPlayerID]:GetUnits():FindID(iUnitID);
    -- true when unit data exists
    if (pUnit ~= nil) then 
        -- unit XP data
        local pUnitExperience = pUnit:GetExperience();
        -- true when unit XP data exists
        if (pUnitExperience ~= nil) then 
            -- unit's banked XP, and debugging header
            local iBalanceXP, sF = pUnit:GetProperty("XP_BALANCE"), "OnUnitUpgraded";
            -- debugging
            Dprint(sF, "Player " .. iPlayerID .. ": Upgraded Unit " .. iUnitID .. " has a balance of " .. iBalanceXP .. " XP");
        end
    end
end

--[[ =========================================================================
	hook function OnCombatHook()
        hooks OnCombat() to Events.Combat
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnCombatHook() Events.Combat.Add(OnCombat); end

--[[ =========================================================================
	hook function OnPlayerTurnDeactivatedHook()
        hooks OnPlayerTurnDeactivated() to Events.PlayerTurnDeactivated
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnPlayerTurnDeactivatedHook() Events.PlayerTurnDeactivated.Add(OnPlayerTurnDeactivated); end

--[[ =========================================================================
	hook function OnUnitAbilityGainedHook()
        hooks OnUnitAbilityGained() to Events.UnitAbilityGained
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitAbilityGainedHook() Events.UnitAbilityGained.Add(OnUnitAbilityGained); end

--[[ =========================================================================
	hook function OnUnitAddedToMapHook()
        hooks OnUnitAddedToMap() to Events.UnitAddedToMap
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitAddedToMapHook() Events.UnitAddedToMap.Add(OnUnitAddedToMap); end

--[[ =========================================================================
	hook function OnUnitRemovedFromMapHook()
        hooks OnUnitRemovedFromMap() to Events.UnitRemovedFromMap
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
-- function OnUnitRemovedFromMapHook() Events.UnitRemovedFromMap.Add(OnUnitRemovedFromMap); end

--[[ =========================================================================
	hook function OnUnitPromotedHook()
        hooks OnUnitPromoted() to Events.UnitPromoted
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitPromotedHook() Events.UnitPromoted.Add(OnUnitPromoted); end

--[[ =========================================================================
	hook function OnUnitUpgradedHook()
        hooks OnUnitUpgraded() to Events.UnitUpgraded
    should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitUpgradedHook() Events.UnitUpgraded.Add(OnUnitUpgraded); end

--[[ =========================================================================
	hook function AddEventHooks()
        attaches any defined hooks to Events.LoadScreenClose
        prints debugging output to the log file
	should be defined prior to Initialize()
=========================================================================== ]]
function AddEventHooks( sF )
    -- attach listener functions to the appropriate Events with debugging output
    Events.LoadScreenClose.Add(OnCombatHook);
	Dprint(sF, "OnCombat() successfully hooked to Events.Combat");
    Events.LoadScreenClose.Add(OnPlayerTurnDeactivatedHook);
    Dprint(sF, "OnPlayerTurnDeactivated() successfully hooked to Events.PlayerTurnDeactivated");
    Events.LoadScreenClose.Add(OnUnitAbilityGainedHook);
	Dprint(sF, "OnUnitAbilityGained() successfully hooked to Events.UnitAbilityGained");
    Events.LoadScreenClose.Add(OnUnitAddedToMapHook);
	Dprint(sF, "OnUnitAddedToMap() successfully hooked to Events.UnitAddedToMap");
	Events.LoadScreenClose.Add(OnUnitPromotedHook);
	Dprint(sF, "OnUnitPromoted() successfully hooked to Events.UnitPromoted");
    -- Events.LoadScreenClose.Add(OnUnitRemovedFromMapHook);
	-- Dprint(sF, "OnUnitRemovedFromMap() successfully hooked to Events.UnitRemovedFromMap");
	Events.LoadScreenClose.Add(OnUnitUpgradedHook);
	Dprint(sF, "OnUnitUpgraded() successfully hooked to Events.UnitUpgraded");
end

--[[ =========================================================================
	function Initialize()
        prepare ECEP components
    should be the penultimate definition
=========================================================================== ]]
function Initialize()
    -- debugging header
    local sF = "Initialize";
    print(EM.RowOfDashes);
    print("Loading ECEP gameplay script ECEP.lua . . .");
    -- combat experience modifiers; extra output when debugging
    print(EM.RowOfDashes);
    print("Configuring Policy Card experience modifiers for experience banking system . . .");
    for k, v in pairs(EM.PolicyXPModifiers) do if type(v) == "table" then Dprint(sF, "[" .. v.Policy .. "]: +" .. v.Modifier .. "%%"); end end
    print("Configuring Government experience modifiers for experience banking system . . .");
    for k, v in pairs(EM.GovernmentXPModifiers) do if type(v) == "table" then Dprint(sF, "[" .. v.Government .. "]: +" .. v.Modifier .. "%%"); end end
    print("Configuring Unit Ability experience modifiers for experience banking system . . .");
    for k, v in pairs(EM.AbilityXPModifiers) do Dprint(sF, "[" .. k .. "]: +" .. v .. "%%"); end
    -- attach listener functions to the appropriate Events; extra output when debugging
    print(EM.RowOfDashes);
    print("Configuring required hook(s) for ingame Event(s) . . .");
    AddEventHooks("Initialize:AddEventHooks");
    print(EM.RowOfDashes);
	print("ECEP configuration complete. Proceeding . . .");
end

-- load ECEP
Initialize();

--[[ =========================================================================
	references
==============================================================================

=========================================================================== ]]

--[[ =========================================================================
	end ECEP.lua gameplay script
=========================================================================== ]]
