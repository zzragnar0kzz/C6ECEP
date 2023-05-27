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
function EM.DebugPrint( sFunction, sMessage ) if EM.IsDebugEnabled then print("[DEBUG] " .. sFunction .. "(): " .. tostring(sMessage)); end end
-- the global Debug flag; DebugPrint() successfully outputs if this is true
EM.IsDebugEnabled = true;
-- shortcut for DebugPrint()
Dprint = EM.DebugPrint;
-- exactly what it says on the tin
EM.RowOfDashes = (EM.RowOfDashes) and EM.RowOfDashes or "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -";
EM.Turn = Game.GetCurrentGameTurn();
-- table of minimum and maximum XP amounts per level, with valid ranges
EM.PromotionLevels = (EM.PromotionLevels) and EM.PromotionLevels or { 
	{ Min = 0, Max = 15, Range = 15 }, { Min = 15, Max = 45, Range = 30 }, { Min = 45, Max = 90, Range = 45 }, { Min = 90, Max = 150, Range = 60 }, 
	{ Min = 150, Max = 225, Range = 75 }, { Min = 225, Max = 315, Range = 90 }, { Min = 315, Max = 420, Range = 105 }, { Min = 420, Max = 540, Range = 120 }
};
-- table of current government indices by Player
EM.PlayerGovernments = (EM.PlayerGovernments) and EM.PlayerGovernments or {};
-- relevant global parameters related to combat experience
EM.XPMaxOneCombat = tonumber(GameInfo.GlobalParameters["EXPERIENCE_MAXIMUM_ONE_COMBAT"].Value);
EM.XPBarbSoftCap = tonumber(GameInfo.GlobalParameters["EXPERIENCE_BARB_SOFT_CAP"].Value);
EM.XPMaxBarbLevel = tonumber(GameInfo.GlobalParameters["EXPERIENCE_MAX_BARB_LEVEL"].Value);
EM.XPCityCaptured = tonumber(GameInfo.GlobalParameters["EXPERIENCE_CITY_CAPTURED"].Value);
EM.XPCombatAttackerBonus = tonumber(GameInfo.GlobalParameters["EXPERIENCE_COMBAT_ATTACKER_BONUS"].Value);
EM.XPCombatRanged = tonumber(GameInfo.GlobalParameters["EXPERIENCE_COMBAT_RANGED"].Value);
EM.XPDistrictVsUnit = tonumber(GameInfo.GlobalParameters["EXPERIENCE_DISTRICT_VS_UNIT"].Value);
EM.XPKillBonus = tonumber(GameInfo.GlobalParameters["EXPERIENCE_KILL_BONUS"].Value);
EM.XPNotCombatRanged = tonumber(GameInfo.GlobalParameters["EXPERIENCE_NOT_COMBAT_RANGED"].Value);
EM.XPUnitVsDistrictNotCityCaptured = tonumber(GameInfo.GlobalParameters["EXPERIENCE_UNIT_VS_DISTRICT_NOT_CITY_CAPTURED"].Value);
-- table of bonuses for combat type
EM.CombatBonusXP = { AIR = 0, ["AIR-TO-AIR"] = EM.XPNotCombatRanged, ["AIR-TO-GROUND"] = EM.XPCombatRanged, BOMBARD = EM.XPCombatRanged, ICBM = 0, MELEE = EM.XPNotCombatRanged, RANGED = EM.XPCombatRanged, RELIGIOUS = 0, };
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
EM.CombatTypeByHash = { [1184946373] = "AIR", [1338578493] = "BOMBARD", [1640240290] = "ICBM", [748940753] = "MELEE", [784649805] = "RANGED", [1580168296] = "RELIGIOUS" };
-- difficulty level types by hash
EM.DifficultyLevels, EM.NumDifficultyLevels = {}, 0;
-- init default difficulty type and level, and high- and low-difficulty XP modifiers
EM.DefaultDifficultyType, EM.DefaultDifficultyLevel, EM.HighDifficultyXPModifier, EM.LowDifficultyXPModifier = "DIFFICULTY_PRINCE", 4, 10, -15;
for row in GameInfo.Difficulties() do 
    EM.NumDifficultyLevels = EM.NumDifficultyLevels + 1;
    EM.DifficultyLevels[DB.MakeHash(row.DifficultyType)] = { Type = row.DifficultyType, Level = EM.NumDifficultyLevels }; 
end
-- other combat experience modifiers
EM.XPModifiers = {};
for modifier in GameInfo.ModifierArguments() do 
    if modifier.ModifierId == "MINOR_CIV_KABUL_UNIT_EXPERIENCE_BONUS" then EM.XPModifiers[modifier.ModifierId] = modifier.Value; 
    elseif modifier.ModifierId == "HIGH_DIFFICULTY_UNIT_XP_SCALING" then 
        EM.HighDifficultyXPModifier = modifier.Extra;
    elseif modifier.ModifierId == "LOW_DIFFICULTY_UNIT_XP_SCALING" then 
        EM.DefaultDifficultyType = modifier.SecondExtra;
        EM.DefaultDifficultyLevel = EM.DifficultyLevels[DB.MakeHash(EM.DefaultDifficultyType)].Level;
        EM.LowDifficultyXPModifier = modifier.Extra;
    end
end
-- combat experience modifiers for major AI players on non-default difficulty levels
EM.DifficultyXPModifiers = {};
for p = 0, 63 do 
    local pPlayer, pPlayerConfig = Players[p], PlayerConfigurations[p];
    if pPlayer ~= nil and pPlayerConfig ~= nil and pPlayer:IsMajor() and not pPlayer:IsHuman() then 
        local hDifficulty = pPlayerConfig:GetHandicapTypeID();
        local sDifficultyType = (hDifficulty ~= nil) and EM.DifficultyLevels[hDifficulty].Type or nil;
        local iDifficultyLevel = (hDifficulty ~= nil) and EM.DifficultyLevels[hDifficulty].Level or nil;
        local iXPModifier = 0;
        if iDifficultyLevel < EM.DefaultDifficultyLevel then iXPModifier = (EM.DefaultDifficultyLevel - iDifficultyLevel) * EM.LowDifficultyXPModifier;
        elseif iDifficultyLevel > EM.DefaultDifficultyLevel then iXPModifier = (iDifficultyLevel - EM.DefaultDifficultyLevel) * EM.HighDifficultyXPModifier;
        end
        EM.DifficultyXPModifiers[p] = (100 + iXPModifier) / 100;
    end
end

--[[ =========================================================================
	member function InitializeUnitProperty( pUnit, sPropertyName, iValue )
	    set sPropertyName to iValue for pUnit
	should be defined prior to Initialize()
=========================================================================== ]]
-- function EM.InitializeUnitProperty( pUnit, sPropertyName, iValue ) pUnit:SetProperty(sPropertyName, iValue); end

--[[ =========================================================================
	member function GetCombatParameters(  )
	    fetch and return minimum relevant values from target combatant's most recent combat
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.GetCombatParameters( sCombat, tTarget, bIsAttacker )
    -- debugging header
    local sF = "GetCombatParameters";
    -- initialize result table
    local t = { Combat = sCombat, IsAttacker = bIsAttacker, Action = bIsAttacker and "Attacking" or "Defending" };
    -- target (x, y) location
    t.Location = { x = tTarget[CombatResultParameters.LOCATION].x, y = tTarget[CombatResultParameters.LOCATION].y };
    -- target player ID, combatant ID, and numeric component type
    t.PID, t.CID, t.CT = tTarget[CombatResultParameters.ID].player, tTarget[CombatResultParameters.ID].id, tTarget[CombatResultParameters.ID].type;
    -- true when target component type is a city, district, or unit
    t.IsCity, t.IsDistrict, t.IsUnit = t.CT == ComponentType.CITY, t.CT == ComponentType.DISTRICT, t.CT == ComponentType.UNIT;
    -- target combatant's maximum health, damage sustained this combat, and total damage sustained
    t.MaxHP, t.Damage, t.FinalDamage = tTarget[CombatResultParameters.MAX_HIT_POINTS], tTarget[CombatResultParameters.DAMAGE_TO], tTarget[CombatResultParameters.FINAL_DAMAGE_TO];
    -- true when target combatant is dead
    t.IsDead = t.FinalDamage > t.MaxHP;
    -- target combatant's strength, strength modifier, and experience earned from this combat
    t.CS, t.SM, t.XP = tTarget[CombatResultParameters.COMBAT_STRENGTH], tTarget[CombatResultParameters.STRENGTH_MODIFIER], tTarget[CombatResultParameters.EXPERIENCE_CHANGE];
    -- target's type and promotion class if it's a unit, or type if it's NOT a unit
    local pPlayer = Players[t.PID];
    if t.IsUnit then 
        local pUnit = (pPlayer ~= nil) and pPlayer:GetUnits():FindID(t.CID) or nil;
        local pUnitData = (pUnit ~= nil) and GameInfo.Units[pUnit:GetType()] or nil;
        local pUnitExperience = (pUnit ~= nil) and pUnit:GetExperience() or nil;
        -- unit is eligible for combat experience if its unit, unit data, and unit experience tables are all NOT nil
        t.IsEligible = pUnit ~= nil and pUnitData ~= nil and pUnitExperience ~= nil;
        if t.IsEligible then 
            -- target unit's promotion class, formation class, and type
            t.PromotionClass, t.FormationClass, t.Type = pUnitData.PromotionClass, pUnitData.FormationClass, pUnitData.UnitType;
            -- target unit's current XP, and XPFNL
            t.CurrentXP, t.XPFNL = pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
            -- target unit's current level, current XP balance, and last known current XP total
            t.Level = pUnit:GetProperty("CURRENT_LEVEL") ~= nil and pUnit:GetProperty("CURRENT_LEVEL") or 1;
            t.BalanceXP = pUnit:GetProperty("XP_BALANCE") ~= nil and pUnit:GetProperty("XP_BALANCE") or 0;
            t.LastCurrentXP = pUnit:GetProperty("LAST_CURRENT_XP") ~= nil and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
            -- 
            t.OldTotalXP = t.LastCurrentXP + t.BalanceXP;
            print("Old total XP: " .. t.OldTotalXP);
            t.CurrentTotalXP = t.CurrentXP + t.BalanceXP;
            print("Current total XP: " .. t.CurrentTotalXP);
            print("Current level: " .. t.Level);
        end
        -- local pUnitAbility = (pUnit ~= nil) and pUnit:GetAbility() or nil;
        -- -- target unit's promotion class, type, and eligibility for combat experience
        -- t.PromotionClass = (pUnitData ~= nil) and pUnitData.PromotionClass or "'UNSPECIFIED'";
        -- t.FormationClass = (pUnitData ~= nil) and pUnitData.FormationClass or "'UNSPECIFIED";
        -- t.Type = (pUnitData ~= nil) and pUnitData.UnitType or "'UNSPECIFIED'";
        
        -- -- target unit's current XP, and XPFNL
        -- t.CurrentXP, t.XPFNL = t.IsEligible and pUnitExperience:GetExperiencePoints() or nil, t.IsEligible and pUnitExperience:GetExperienceForNextLevel() or nil;
        -- -- target unit's current XP balance and last known current XP total
        -- t.Level = (t.IsEligible and pUnit:GetProperty("CURRENT_LEVEL") ~= nil) and pUnit:GetProperty("CURRENT_LEVEL") or 1;
        -- t.BalanceXP = (t.IsEligible and pUnit:GetProperty("XP_BALANCE") ~= nil) and pUnit:GetProperty("XP_BALANCE") or 0;
        -- t.LastCurrentXP = (t.IsEligible and pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
        -- t.OldTotalXP = t.LastCurrentXP + t.BalanceXP;
        -- print("Old total XP: " .. t.OldTotalXP);
        -- t.CurrentTotalXP = t.CurrentXP + t.BalanceXP;
        -- print("Current total XP: " .. t.CurrentTotalXP);
        -- -- reset target unit's level if its last current XP is within the specified range
        -- -- for i, v in ipairs(EM.PromotionLevels) do if (t.CurrentTotalXP >= v.Min and t.CurrentTotalXP < v.Max) then t.Level = i; end end
        -- print("Current level: " .. t.Level);
    elseif not t.IsUnit then 
        local pDistrict = (pPlayer ~= nil) and pPlayer:GetDistricts():FindID(t.CID) or nil;
        local pDistrictData = (pDistrict ~= nil) and GameInfo.Districts[pDistrict:GetType()] or nil;
        -- target district/city type
        t.Type = (pDistrictData ~= nil) and pDistrictData.DistrictType or "'UNSPECIFIED'";
        -- reset IsCity flag when necessary
        if t.Type == "DISTRICT_CITY_CENTER" then t.IsCity = true; end
    end
    return t;
end

--[[ =========================================================================
	member function GetCombatXP(  )
	    approximate experience earned by target unit from its most recent combat
        return this value
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.GetCombatXP( tT, tE )
    -- 
    local sF, iXP = "GetCombatXP", 1;
    local sKilled = tE.IsDead and " 'KILLED' " or " ";
    local iKilled = (tT.IsAttacker and tE.IsDead) and EM.XPKillBonus or 1;
    local iBonusXP, iXPModifier, iDifficultyXPModifier = 0, 1, EM.DifficultyXPModifiers[tT.PID] ~= nil and EM.DifficultyXPModifiers[tT.PID] or 1;
    local sCombatMsg = "Calculated combat experience with applicable ";
    if tE.IsDistrict or tE.IsCity then 
        iXP = tT.IsAttacker and EM.XPUnitVsDistrictNotCityCaptured or EM.XPDistrictVsUnit;
        local sDistrictMsg = tT.Action .. " unit vs city/district base experience";
        if not tT.IsAttacker then 
            Dprint(sF, sDistrictMsg .. ": " .. iXP);
            sCombatMsg = "No applicable combat experience modifiers; calculated value is unchanged"
        elseif tT.IsAttacker then 
            if tT.Combat ~= "MELEE" and tE.MaxHP == 0 then 
                iXP = 0;
                sDistrictMsg = sDistrictMsg .. " (district HP ≤ 0)";
            elseif tT.Combat == "MELEE" and tE.IsDead then 
                iXP = EM.XPCityCaptured;
                sDistrictMsg = sDistrictMsg .. " (district captured)";
            end
            Dprint(sF, sDistrictMsg .. ": " .. iXP);
            iXPModifier = (tT.IsAttacker and iXP > 0) and EM.GetXPModifiers(tT) or iXPModifier;
            sCombatMsg = sCombatMsg .. "modifiers: " .. iXP .. " * " .. iXPModifier .. " = ";
            iXP = iXP * iXPModifier;
            sCombatMsg = sCombatMsg .. iXP;
            iXP = math.floor(iXP);
        end
    elseif tE.IsUnit then 
        iXP = (tE.CS / tT.CS) * iKilled;
        Dprint(sF, tT.Action .. " unit vs" .. sKilled .. "unit base experience: (" .. tE.CS .. " / " .. tT.CS .. ") * " .. iKilled .. " = " .. iXP);
        iBonusXP = EM.GetXPBonuses(tT, tE);
        iXPModifier = EM.GetXPModifiers(tT);
        sCombatMsg = sCombatMsg .. "bonuses and modifiers: (" .. iXP .. " + " .. iBonusXP .. ") * " .. iXPModifier .. " = ";
        iXP = (iXP + iBonusXP) * iXPModifier;
        sCombatMsg = sCombatMsg .. iXP;
        iXP = math.ceil(iXP);
    end
    -- iXP = math.ceil(iXP);
    Dprint(sF, sCombatMsg .. "  (" .. iXP .. ")");
    if ((tE.IsCity or tE.IsDistrict) and iXP == EM.XPDistrictVsUnit and not tT.IsAttacker) or iXP == 0 or iDifficultyXPModifier == 1 then 
        sCombatMsg = "Major AI difficulty modifier is not applicable; calculated value is unchanged";
    elseif iDifficultyXPModifier ~= 1 and iXP > 0 then 
        sCombatMsg = "Applying major AI difficulty modifier: " .. iXP .. " * " .. iDifficultyXPModifier .. " = ";
        iXP = iXP * iDifficultyXPModifier;
        sCombatMsg = sCombatMsg .. iXP;
        iXP = math.ceil(iXP);
    end
    Dprint(sF, sCombatMsg .. "  (" .. iXP .. ")");
    if Players[tE.PID]:IsBarbarian() and iXP > EM.XPBarbSoftCap and tT.Level > EM.XPMaxBarbLevel then 
        iXP = EM.XPBarbSoftCap;
        Dprint(sF, "Enforcing Barbarian soft cap");
    elseif tE.IsUnit and iXP > EM.XPMaxOneCombat then 
        iXP = EM.XPMaxOneCombat;
        Dprint(sF, "Enforcing maximum per-combat cap");
    end
    Dprint(sF, "Final combat experience earned: " .. iXP);
    -- popup text for human players to indicate how much, if any, experience was earned
    if iXP > 0 and Players[tT.PID]:IsHuman() then 
        Game.AddWorldViewText(tT.PID, Locale.Lookup("[COLOR_LIGHTBLUE] +{1_XP}XP [ENDCOLOR]", iXP), tT.Location.x, tT.Location.y, 0);
    end
    return iXP;
end

--[[ =========================================================================
	member function GetXPBonuses(  )
	    identify valid combat experience bonuses for target unit
        return the sum of these bonuses
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.GetXPBonuses(tT, tE)
    -- 
    local sF, iB, tB = "GetXPBonuses", 0, {};
    -- add the attacker XP bonus to the XP bonuses table when this is the attacking player
    if tT.IsAttacker then tB["ATTACKER"] = EM.XPCombatAttackerBonus; end
    -- combat type bonus
    tB[tT.Combat] = (EM.CombatBonusXP[tT.Combat] ~= nil) and EM.CombatBonusXP[tT.Combat] or 0;
    -- reset potential air combat bonus
    if tT.Combat == "AIR" then 
        tB["AIR"] = nil;
        local bIsTargetAircraft = (tT.PromotionClass == "PROMOTION_CLASS_AIR_BOMBER" or tT.PromotionClass == "PROMOTION_CLASS_AIR_FIGHTER");
        local bIsEnemyAircraft = (tE.PromotionClass == "PROMOTION_CLASS_AIR_BOMBER" or tE.PromotionClass == "PROMOTION_CLASS_AIR_FIGHTER");
        if bIsTargetAircraft and bIsEnemyAircraft then tB["AIR-TO-AIR"] = EM.CombatBonusXP["AIR-TO-AIR"];
        else tB["AIR-TO-GROUND"] = EM.CombatBonusXP["AIR-TO-GROUND"];
        end
    end
    -- debugging
    local sSecBonusMsg = "";
    -- increment the total bonus value for each bonus in the table
    for k, v in pairs(tB) do 
        iB = iB + v;
        sSecBonusMsg = sSecBonusMsg .. " [" .. k .. " (+" .. v .. ")]"; 
    end
    -- logging
    local sPriBonusMsg = tT.Action .. " unit combat experience bonuses total +" .. iB;
    if iB > 0 then sPriBonusMsg = sPriBonusMsg .. ":"; end
    Dprint(sF, sPriBonusMsg .. sSecBonusMsg);
    return iB;
end

--[[ =========================================================================
	member function GetXPModifiers(  )
	    identify valid combat experience modifiers for target unit
        return the sum of these modifiers as a decimal value
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.GetXPModifiers(tT)
    -- 
    local sF, iM, tM, iBase = "GetXPModifiers", 0, {}, 100;
    -- 
    local pPlayer, pPlayerConfig = Players[tT.PID], PlayerConfigurations[tT.PID];
    local pPlayerCulture = (pPlayer ~= nil) and pPlayer:GetCulture() or nil;
    local pUnit = (pPlayer ~= nil) and pPlayer:GetUnits():FindID(tT.CID) or nil;
    local pUnitAbility = (pUnit ~= nil) and pUnit:GetAbility() or nil;
    -- adjust the XP modifier for each valid ability attached to this unit
    for k, v in pairs(EM.AbilityXPModifiers) do if (pUnitAbility ~= nil and pUnitAbility:GetAbilityCount(k) ~= nil and pUnitAbility:GetAbilityCount(k) > 0) then tM[k] = v; end end
    -- adjust the XP modifier for any valid policy card that is slotted
    for i = 0, pPlayerCulture:GetNumPolicySlots() - 1 do 
        -- database index of the policy in slot i
        local iPolicy = pPlayerCulture:GetSlotPolicy(i);
        -- adjust the XP modifier
        if (iPolicy == EM.PolicyXPModifiers.POLICY_SURVEY and tT.PromotionClass == "PROMOTION_CLASS_RECON") then tM[EM.PolicyXPModifiers[iPolicy].Policy] = EM.PolicyXPModifiers[iPolicy].Modifier;
        elseif (iPolicy ~= EM.PolicyXPModifiers.POLICY_SURVEY and EM.PolicyXPModifiers[iPolicy] ~= nil) then tM[EM.PolicyXPModifiers[iPolicy].Policy] = EM.PolicyXPModifiers[iPolicy].Modifier;
        end
    end
    -- last known government refresh
    local iGovernment = pPlayer:GetProperty("CURRENT_GOVERNMENT_INDEX");
    if iGovernment == nil or iGovernment == -1 then iGovernment = (EM.PlayerGovernments[tT.PID] ~= nil) and EM.PlayerGovernments[tT.PID] or -1; end
    pPlayer:SetProperty("CURRENT_GOVERNMENT_INDEX", iGovernment);
    -- adjust the XP modifier when a valid government is in use
    if EM.GovernmentXPModifiers[iGovernment] ~= nil then tM[EM.GovernmentXPModifiers[iGovernment].Government] = EM.GovernmentXPModifiers[iGovernment].Modifier; end
    -- XP modifiers for major players
    if pPlayer:IsMajor() then 
        -- adjust the XP modifier when this major player is suzerain of Kabul
        for i, pMinor in ipairs(PlayerManager.GetAliveMinors()) do 
            local bIsMinorKabul = (PlayerConfigurations[pMinor:GetID()] ~= nil and PlayerConfigurations[pMinor:GetID()]:GetCivilizationTypeName() == "CIVILIZATION_KABUL");
            local bIsTargetSuzerain = (pMinor:GetInfluence() ~= nil and pMinor:GetInfluence():GetSuzerain() == tT.PID);
            if tT.IsAttacker and bIsMinorKabul and bIsTargetSuzerain then tM["MINOR_CIV_KABUL_UNIT_EXPERIENCE_BONUS"] = EM.XPModifiers["MINOR_CIV_KABUL_UNIT_EXPERIENCE_BONUS"]; end
        end
    end
    -- debugging
    local sSecModifierMsg = "";
    -- increment the total modifier value for each modifier in the table
    for k, v in pairs(tM) do 
        iM = iM + v;
        sSecModifierMsg = sSecModifierMsg .. " [" .. k .. " (+" .. v .. "%%)]"; 
    end
    -- logging
    local sPriModifierMsg = tT.Action .. " unit combat experience modifiers total +" .. iM .. "%%";
    if iM > 0 then sPriModifierMsg = sPriModifierMsg .. ":"; end
    Dprint(sF, sPriModifierMsg .. sSecModifierMsg);
    -- add the modifier total to the base value, and divide this sum by the base value to obtain the decimal modifier value; return this value
    iM = (iBase + iM) / iBase;
    return iM;
end

--[[ =========================================================================
	member function RefreshXPBalance(  )
	    update target unit's experience balance as necessary
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.RefreshXPBalance( tT, sAction )
    -- debugging
    local sF = "RefreshXPBalance";
    local pUnit = Players[tT.PID]:GetUnits():FindID(tT.CID);
    -- abort here if pUnit is nil
    if pUnit == nil then 
        Dprint(sF, "Unit data for " .. string.lower(sAction) .. " ID " .. tT.CID .. " is nil here; this unit was likely killed in a subsequent combat, doing nothing");
        return;
    end
    local pUnitExperience = pUnit:GetExperience();
    -- abort here if pUnitExperience is nil
    if pUnitExperience == nil then 
        Dprint(sF, "UnitExperience data for " .. string.lower(sAction) .. " ID " .. tT.CID .. " is nil here; this unit was likely killed in a subsequent combat, doing nothing");
        return;
    end
    -- target unit's level, current XP, and XPFNL
    local iLevel, iNewLevel, iCurrentXP, iXPFNL = pUnit:GetProperty("CURRENT_LEVEL"), pUnit:GetProperty("CURRENT_LEVEL"), pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
    -- target unit's current XP balance and last known current XP total
    local iBalanceXP = pUnit:GetProperty("XP_BALANCE") ~= nil and pUnit:GetProperty("XP_BALANCE") or 0;
    local iLastCurrentXP = pUnit:GetProperty("LAST_CURRENT_XP") ~= nil and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
    if iLastCurrentXP > iXPFNL and iLastCurrentXP ~= (iCurrentXP + iBalanceXP) then iCurrentXP = iLastCurrentXP - iBalanceXP; 
    elseif iLastCurrentXP > 0 and iLastCurrentXP <= iXPFNL and iLastCurrentXP ~= iCurrentXP then iCurrentXP = iLastCurrentXP;
    end
    -- local iOldTotalXP = iCurrentXP + iBalanceXP;
    
    -- target unit's new XP balance and amount of XP to be banked
    local iBankXP = ((iCurrentXP + tT.XP) > iXPFNL) and ((iCurrentXP + tT.XP) - iXPFNL) or 0;
    local iNewBalanceXP = iBalanceXP + iBankXP;
    local iNewTotalXP = iLastCurrentXP + tT.XP;
    -- reset target unit's level when its new total XP is in the specified range
    for i, v in ipairs(EM.PromotionLevels) do if (iNewTotalXP >= v.Min and iNewTotalXP < v.Max) then iNewLevel = i; end end
    Dprint(sF, "Banked experience from this combat (new banked balance): " .. iBankXP .. " (" .. iNewBalanceXP .. ")");
    -- reset the target unit's XP balance and last known current XP total properties to the new values
    pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
    pUnit:SetProperty("LAST_CURRENT_XP", iNewTotalXP);
    -- pUnit:SetProperty("CURRENT_LEVEL", iNewLevel);
    -- logging
    local sInfoMsg = "Player " .. tT.PID .. ": " .. sAction .. " " .. tT.Type .. " " .. tT.CID .. " survived, earning " .. tT.XP .. " combat experience ";
    sInfoMsg = sInfoMsg .. "[ Level " .. tostring(iLevel) .. " (" .. tostring(iNewLevel) .. "), " .. tostring(iLastCurrentXP) .. " --> " .. tostring(iNewTotalXP) .. " XP / " .. tostring(iXPFNL); 
    sInfoMsg = sInfoMsg .. " FNL, stored " .. tostring(iBalanceXP) .. " --> " .. tostring(iNewBalanceXP) .. " XP ]";
    print(sInfoMsg);
    -- print(sInfoMsg .. "[ Level " .. iLevel .. " (" .. iNewLevel .. "), " .. iLastCurrentXP .. " --> " .. iNewTotalXP .. " XP / " .. iXPFNL .. " FNL, stored " .. iBalanceXP .. " --> " .. iNewBalanceXP .. " XP ]");
end

--[[ =========================================================================
	member function ValidateCombatant(  )
	    validate target combat parameters
        calculate and/or store combat experience as necessary
	should be defined prior to Initialize()
=========================================================================== ]]
function EM.ValidateCombatant( tT, tE, sAction )
    -- 
    local sF, sValidateMsg = "ValidateCombatant", "Player " .. tostring(tT.PID);
    if tT.PID == -1 or tT.PID == nil then 
        Dprint(sF, sValidateMsg .. " is 'NOT' a valid player; doing nothing");
    elseif tE.PID == -1 or tE.PID == nil then 
        Dprint(sF, sValidateMsg .. ": Enemy Player ID " .. tostring(tE.PID) .. " is 'NOT' valid; strange things are afoot at the Circle K [XP from gamecore: " .. tostring(tT.XP) .. "]");
    elseif tT.CID == -1 or tT.CID == nil then 
        Dprint(sF, sValidateMsg .. ": Combatant ID " .. tostring(tT.CID) .. " is 'NOT' valid; doing nothing");
    elseif Players[tT.PID]:IsBarbarian() then 
        Dprint(sF, sValidateMsg .. ": " .. sAction .. " Barbarian horde; ignoring this combatant");
    -- elseif tT.IsCity or tT.IsDistrict or (tT.IsUnit and (tT.FormationClass == "FORMATION_CLASS_CIVILIAN" or tT.FormationClass == "FORMATION_CLASS_SUPPORT" or tT.Type == "UNIT_GIANT_DEATH_ROBOT")) then 
    elseif tT.IsCity or tT.IsDistrict then 
        Dprint(sF, sValidateMsg .. ": " .. sAction .. " city/district " .. tT.Type .. " " .. tT.CID .. " is 'NOT' eligible for combat experience; ignoring this combatant");
    elseif tE.IsUnit and (tE.FormationClass == "FORMATION_CLASS_CIVILIAN" or tE.FormationClass == "FORMATION_CLASS_SUPPORT") then 
        Dprint(sF, sValidateMsg .. ": " .. sAction .. " " .. tT.Type .. " " .. tT.CID .. " earns zero combat experience from combat against civilian and support units; ignoring this combatant");
    elseif tT.IsUnit then 
        if not tT.IsEligible then 
            Dprint(sF, sValidateMsg .. ": " .. sAction .. " unit ID " .. tT.CID .. " is 'NOT' valid or eligible for combat experience here; doing nothing");
            -- Dprint(sF, sValidateMsg .. ": Unit(Experience) data for " .. string.lower(sAction) .. " ID " .. tT.CID .. " is nil; this unit is no longer valid or eligible for combat experience");
        elseif tT.IsDead then 
            Dprint(sF, sValidateMsg .. ": " .. sAction .. " unit " .. tT.Type .. " " .. tT.CID .. " was 'KILLED'; no combat experience awarded");
        elseif tT.FormationClass == "FORMATION_CLASS_CIVILIAN" or tT.FormationClass == "FORMATION_CLASS_SUPPORT" then 
            Dprint(sF, sValidateMsg .. ": " .. sAction .. " unit " .. tT.Type .. " " .. tT.CID .. " is a civilian or support unit and is 'NOT' eligible for combat experience; ignoring this combatant");
        elseif tT.Type == "UNIT_GIANT_DEATH_ROBOT" then 
            Dprint(sF, sValidateMsg .. ": " .. sAction .. " unit " .. tT.Type .. " " .. tT.CID .. " is 'NOT' eligible for combat experience; ignoring this combatant");
        else 
            sValidateMsg = sValidateMsg .. ": " .. sAction .. " " .. tT.Type .. " " .. tT.CID .. " survived and received " .. tostring(tT.XP) .. " combat experience from gamecore";
            -- Dprint(sF, sValidateMsg);
            -- local iGameCoreXP = tT.XP;
            -- tT.XP = EM.GetCombatXP(tT, tE);
            -- if tT.XP ~= iGameCoreXP then tT.XP = iGameCoreXP; end
            if tT.XP < 1 then 
                Dprint(sF, sValidateMsg .. "; determining actual value, if any . . .");
                tT.XP = EM.GetCombatXP(tT, tE); 
            else
                Dprint(sF, sValidateMsg);
            end
            EM.RefreshXPBalance(tT, sAction);
        end
    end
end

--[[ =========================================================================
	event listener function OnCombat( tCombatResult )
        parses combat results and banks any applicable experience earned
	should be defined prior to Initialize()
=========================================================================== ]]
function OnCombat( tCombatResult )
    -- debugging header
    local sF = "OnCombat";
    -- increment global combat tracker
    local iCombat = (Game:GetProperty("GLOBAL_COMBAT") ~= nil) and Game:GetProperty("GLOBAL_COMBAT") + 1 or 1;
    Game:SetProperty("GLOBAL_COMBAT", iCombat);
    -- combat type hash and string values
    local hCombat = tCombatResult[CombatResultParameters.COMBAT_TYPE];
    local sCombat = (EM.CombatTypeByHash[hCombat] ~= nil) and EM.CombatTypeByHash[hCombat] or tostring(hCombat);
    -- map (x, y) coordinates of the combat location
	local iX, iY = tCombatResult[CombatResultParameters.LOCATION].x, tCombatResult[CombatResultParameters.LOCATION].y;
    -- attacker and defender data
    local tA, tD = EM.GetCombatParameters(sCombat, tCombatResult[CombatResultParameters.ATTACKER], true), EM.GetCombatParameters(sCombat, tCombatResult[CombatResultParameters.DEFENDER], false);
    -- logging
    local sPriCombatMsg = "Turn " .. EM.Turn .. ": Global combat " .. iCombat .. ": Type " .. sCombat .. " at plot (x " .. iX .. ", y " .. iY .. "): ";
    local sSecCombatMsg = tA.Action .. " Player " .. tA.PID .. " (" .. tostring(tA.Type) .. " " .. tA.CID .. ") vs " .. tD.Action .. " Player " .. tD.PID .. " (" .. tostring(tD.Type) .. " " .. tD.CID .. ")";
    print(sPriCombatMsg .. sSecCombatMsg);
    -- abort here if combat type is ICBM or RELIGIOUS
    if sCombat == "ICBM" or sCombat == "RELIGIOUS" then 
        Dprint(sF, "Combat type " .. sCombat .. " does 'NOT' provide combat experience; ignoring this combat");
        return;
    end
    -- validate attacker and defender, banking combat experience where appropriate
    EM.ValidateCombatant(tA, tD, tA.Action);
    EM.ValidateCombatant(tD, tA, tD.Action);
end

--[[]]
-- function OnUnitExperienceChanged( input1 )
--     local sF = "OnUnitExperienceChanged";
--     Dprint(sF, tostring(input1));
-- end

--[[ =========================================================================
	event listener function OnTurnBegin( iTurn )
	    track the current global game turn; primarily for debugging
	should be defined prior to Initialize()
=========================================================================== ]]
function OnTurnBegin( iTurn ) EM.Turn = iTurn; end

--[[ =========================================================================
	event listener function OnPlayerTurnActivated( iPlayerID, bIsFirstTime )
	    does stuff at the beginning of each player's turn
	should be defined prior to Initialize()
=========================================================================== ]]
function OnPlayerTurnActivated( iPlayerID, bIsFirstTime )
    if bIsFirstTime then 
        local pPlayer = Players[iPlayerID];
        if pPlayer ~= nil and not pPlayer:IsBarbarian() then 
            for i, pUnit in pPlayer:GetUnits():Members() do 
                if (pUnit:GetProperty("XP_BALANCE") == nil or pUnit:GetProperty("LAST_CURRENT_XP") == nil) then 
                    local iUnitID = pUnit:GetID();
                    print("Player " .. iPlayerID .. ": Resetting ECEP properties for Unit " .. iUnitID);
                    OnUnitAddedToMap(iPlayerID, iUnitID);
                end
            end
        end
    end
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
            pUnit:SetProperty("CURRENT_LEVEL", 1);
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
            --
            local sF = "OnUnitPromoted";
    	    -- unit's banked XP, and debugging header
	        local iLevel, iBalanceXP = pUnit:GetProperty("CURRENT_LEVEL") ~= nil and pUnit:GetProperty("CURRENT_LEVEL") or 1, pUnit:GetProperty("XP_BALANCE") ~= nil and pUnit:GetProperty("XP_BALANCE") or 0;
            -- init XP_BALANCE for this unit if it has not yet been set
            -- if iBalanceXP == nil then pUnit:SetProperty("XP_BALANCE", 0);
        	-- true when unit has banked XP
            if iBalanceXP ~= nil and iBalanceXP > 0 then 
    		    -- unit's level, current XP total, XPFNL, and XP grant after promotion
                iLevel = iLevel + 1;
		        local iCurrentXP, iXPFNL = pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
	        	-- for i, v in ipairs(EM.PromotionLevels) do if (iCurrentXP >= v.Min and iCurrentXP < v.Max) then iLevel = i; end end
        		local iGrantXP = (iBalanceXP > EM.PromotionLevels[iLevel].Range) and EM.PromotionLevels[iLevel].Range or iBalanceXP;
                -- add XP grant after promotion to unit, and get new current XP total
	    	    pUnitExperience:ChangeExperience(iGrantXP);
                local iNewCurrentXP = pUnitExperience:GetExperiencePoints();
                local iNewBalanceXP = iBalanceXP - iGrantXP
                -- reset unit's XP balance and last known current XP total property values
                pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
                pUnit:SetProperty("LAST_CURRENT_XP", iNewCurrentXP + iNewBalanceXP);
                pUnit:SetProperty("CURRENT_LEVEL", iLevel);
                -- debugging
                local sPriInfoMsg = "Player " .. iPlayerID .. ": Restoring experience to Unit " .. iUnitID .. " from its balance following promotion to Level " .. iLevel .. " (";
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

--[[]]
-- function OnUnitExperienceChangedHook() Events.UnitExperienceChanged.Add(OnUnitExperienceChanged); end

--[[ =========================================================================
	hook function OnTurnBeginHook()
        hooks OnTurnBegin() to Events.TurnBegin
	should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnTurnBeginHook() Events.TurnBegin.Add(OnTurnBegin); end

--[[ =========================================================================
	hook function OnPlayerTurnActivatedHook()
        hooks OnPlayerTurnActivated() to Events.PlayerTurnActivated
	should be defined prior to and executed in AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnPlayerTurnActivatedHook() Events.PlayerTurnActivated.Add(OnPlayerTurnActivated); end

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
    -- Events.LoadScreenClose.Add(OnUnitExperienceChangedHook);
    -- Dprint(sF, "OnUnitExperienceChanged() successfully hooked to Events.UnitExperienceChanged");
    Events.LoadScreenClose.Add(OnTurnBeginHook);
	Dprint(sF, "OnTurnBegin() successfully hooked to Events.TurnBegin");
    Events.LoadScreenClose.Add(OnPlayerTurnActivatedHook);
    Dprint(sF, "OnPlayerTurnActivated() successfully hooked to Events.PlayerTurnActivated");
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
    print("Fetching relevant game setup option(s) . . .");
    print("Unit experience soft cap vs Barbarians: " .. EM.XPBarbSoftCap .. "; this is enforced beginning at Level " .. EM.XPMaxBarbLevel);
    print("Base Unit combat experience, City/District vs Unit: " .. EM.XPDistrictVsUnit);
    print("Base Unit combat experience, Unit vs City/District: " .. EM.XPUnitVsDistrictNotCityCaptured .. "; this is instead " .. EM.XPCityCaptured .. " for a captured city");
    print("Unit vs Unit Attacker bonus experience: " .. EM.XPCombatAttackerBonus);
    print("Unit vs Unit Ranged / Air-to-Ground combat bonus experience: " .. EM.XPCombatRanged);
    print("Unit vs Unit Non-Ranged / Air-to-Air combat bonus experience: " .. EM.XPNotCombatRanged);
    print("Unit vs Unit base experience kill modifier: " .. EM.XPKillBonus);
    print("Other Unit vs Unit per-combat experience cap: " .. EM.XPMaxOneCombat);
    print(EM.RowOfDashes);
    print("Current game turn at session start: " .. EM.Turn);
    local iCombat = (Game:GetProperty("GLOBAL_COMBAT") ~= nil) and Game:GetProperty("GLOBAL_COMBAT") or 0;
    print("Global combat counter at session start: " .. iCombat);
    print(EM.RowOfDashes);
    print("Configuring Policy Card modifiers for experience banking system . . .");
    for k, v in pairs(EM.PolicyXPModifiers) do if type(v) == "table" then Dprint(sF, "[" .. v.Policy .. "]: +" .. v.Modifier .. "%%"); end end
    print("Configuring Government modifiers for experience banking system . . .");
    for k, v in pairs(EM.GovernmentXPModifiers) do if type(v) == "table" then Dprint(sF, "[" .. v.Government .. "]: +" .. v.Modifier .. "%%"); end end
    print("Configuring Unit Ability modifiers for experience banking system . . .");
    for k, v in pairs(EM.AbilityXPModifiers) do Dprint(sF, "[" .. k .. "]: +" .. v .. "%%"); end
    print("Configuring other modifiers for experience banking system . . .");
    for k, v in pairs(EM.XPModifiers) do Dprint(sF, "[" .. k .. "]: +" .. v .. "%%"); end
    print("Configuring major AI difficulty modifiers for experience banking system . . .")
    for k, v in pairs(EM.DifficultyXPModifiers) do Dprint(sF, "Player " .. k .. ": " .. v * 100 .. "%% of awarded combat experience"); end
    -- attach listener functions to the appropriate Events; extra output when debugging
    print(EM.RowOfDashes);
    print("Configuring required hook(s) for ingame Event(s) . . .");
    AddEventHooks("Initialize():AddEventHooks");
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
