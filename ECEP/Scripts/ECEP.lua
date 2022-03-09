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
-- global combat tracker; this should increment with each combat
EM.CombatCounter = (EM.CombatCounter) and EM.CombatCounter or 0;
-- difficulty level types by hash
EM.DifficultyLevels, EM.NumDifficultyLevels = {}, 0;
-- init default difficulty type and level, and high- and low-difficulty XP modifiers
EM.DefaultDifficultyType, EM.DefaultDifficultyLevel, EM.HighDifficultyXPModifier, EM.LowDifficultyXPModifier = "DIFFICULTY_PRINCE", 4, 10, -15;
for row in GameInfo.Difficulties() do 
    EM.NumDifficultyLevels = EM.NumDifficultyLevels + 1;
    EM.DifficultyLevels[DB.MakeHash(row.DifficultyType)] = { Type = row.DifficultyType, Level = EM.NumDifficultyLevels }; 
end
-- other combat experience modifiers
-- EM.KabulXPModifier = 0;
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
-- difficulty level xp modifiers by type
-- EM.DifficultyXPModifiers = { 
--     ["DIFFICULTY_SETTLER"] = 45, ["DIFFICULTY_CHIEFTAIN"] = 30, ["DIFFICULTY_WARLORD"] = 15, ["DIFFICULTY_PRINCE"] = 0, 
--     ["DIFFICULTY_KING"] = 15, ["DIFFICULTY_EMPEROR"] = 30, ["DIFFICULTY_IMMORTAL"] = 45, ["DIFFICULTY_DEITY"] = 60
-- };

--[[]]
function EM.InitializeUnitProperty( pUnit, sPropertyName, iValue )
    pUnit:SetProperty(sPropertyName, iValue);
    -- Dprint("InitializeUnitProperty", "Player " .. iPlayerID .. ": Property " .. sPropertyName .. " for Unit " .. );
end

--[[]]
function EM.GetCombatParameters( sCombatType, tCombatant, bIsAttacker )
    -- debugging header
    local sF = "GetCombatParameters";
    -- initialize result table and action adverb
    local t, sAction = { Combat = sCombatType, IsAttacker = bIsAttacker, BonusXP = 0, XPBonuses = {}, ModifierXP = 0, XPModifiers = {} }, bIsAttacker and "Attacking" or "Defending";
     -- target player ID
    t.PlayerID = tCombatant[CombatResultParameters.ID].player;
    -- true when this is a valid player; abort when not true
    t.IsValid = (Players[t.PlayerID] ~= nil);
    -- true when this is the Barbarian player; abort when true
    t.IsBarbarian = t.IsValid and Players[t.PlayerID]:IsBarbarian() or false;
    -- true when this player is human
    t.IsHuman = t.IsValid and Players[t.PlayerID]:IsHuman() or false;
    -- true when this is a major player
    t.IsMajor = t.IsValid and Players[t.PlayerID]:IsMajor() or false;
    -- combatant ID corresponds to a city, district, or unit in the appropriate table; combatant type is an integer representing same
    t.CombatantID, t.CombatantType = tCombatant[CombatResultParameters.ID].id, tCombatant[CombatResultParameters.ID].type;
    -- identify combatant as city/district/unit using provided type
    t.IsCity = t.CombatantType == ComponentType.CITY;
    t.IsDistrict = t.CombatantType == ComponentType.DISTRICT;
    t.IsUnit = t.CombatantType == ComponentType.UNIT;
    -- 
    t.MaxHP, t.Damage, t.FinalDamage = tCombatant[CombatResultParameters.MAX_HIT_POINTS], tCombatant[CombatResultParameters.DAMAGE_TO], tCombatant[CombatResultParameters.FINAL_DAMAGE_TO];
    -- true when this combatant has sustained more damage than it has hit points
    t.IsDead = t.FinalDamage > t.MaxHP;
    -- combatant combat strength, applicable strength modifiers, and XP earned from this combat
    t.CombatStrength = tCombatant[CombatResultParameters.COMBAT_STRENGTH];
    t.StrengthModifier = tCombatant[CombatResultParameters.STRENGTH_MODIFIER];
    t.XP = tCombatant[CombatResultParameters.EXPERIENCE_CHANGE];
    -- 
    local pPlayer = t.IsValid and Players[t.PlayerID] or nil;
    if t.IsCity then 
        -- 
        local pCity = (pPlayer ~= nil) and pPlayer:GetCities():FindID(t.CombatantID) or nil;
    elseif t.IsDistrict then 
        -- 
        local pDistrict = (pPlayer ~= nil) and pPlayer:GetDistricts():FindID(t.CombatantID) or nil;
        local pDistrictData = (pDistrict ~= nil) and GameInfo.Districts[pDistrict:GetType()] or nil;
        t.DistrictType = (pDistrictData ~= nil) and pDistrictData.DistrictType or nil;
    elseif t.IsUnit then 
        -- 
        local pPlayerConfig = (PlayerConfigurations[t.PlayerID] ~= nil) and PlayerConfigurations[t.PlayerID] or nil;
        local pPlayerCulture = (pPlayer ~= nil) and pPlayer:GetCulture() or nil;
        local pUnit = (pPlayer ~= nil) and pPlayer:GetUnits():FindID(t.CombatantID) or nil;
        local pUnitData = (pUnit ~= nil) and GameInfo.Units[pUnit:GetType()] or nil;
        local pUnitExperience = (pUnit ~= nil) and pUnit:GetExperience() or nil;
        local pUnitAbility = (pUnit ~= nil) and pUnit:GetAbility() or nil;
        t.DifficultyHash = (pPlayerConfig ~= nil) and pPlayerConfig:GetHandicapTypeID() or nil;
        t.DifficultyType = (t.DifficultyHash ~= nil) and EM.DifficultyLevels[t.DifficultyHash].Type or nil;
        t.DifficultyLevel = (t.DifficultyHash ~= nil) and EM.DifficultyLevels[t.DifficultyHash].Level or nil;
        t.DifficultyXPModifier = 0;
        t.PromotionClass = (pUnitData ~= nil) and pUnitData.PromotionClass or "'UNSPECIFIED'";
        t.UnitType = (pUnitData ~= nil) and pUnitData.UnitType or "'UNSPECIFIED'";
        t.IsEligible = pUnit ~= nil and pUnitExperience ~= nil;
        -- target unit's level, current XP, and XPFNL
        t.Level, t.CurrentXP, t.XPFNL = 1, t.IsEligible and pUnitExperience:GetExperiencePoints() or nil, t.IsEligible and pUnitExperience:GetExperienceForNextLevel() or nil;
        -- target unit's current XP balance and last known current XP total
        t.BalanceXP = (t.IsEligible and pUnit:GetProperty("XP_BALANCE") ~= nil) and pUnit:GetProperty("XP_BALANCE") or 0;
        t.LastCurrentXP = (t.IsEligible and pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
        -- when unit has enough XP for its next promotion, and that promotion would cross the barbarian soft XP cap threshold, begin enforcing the cap on any new XP banked prior to applying that promotion
        for i, v in ipairs(EM.PromotionLevels) do if (t.LastCurrentXP >= v.Min and t.LastCurrentXP <= v.Max) then t.Level = i; end end
        -- add the attacker XP bonus to the XP bonuses table when this is the attacking player
        if t.IsAttacker then t.XPBonuses["ATTACKER"] = EM.XPCombatAttackerBonus; end
        -- combat type bonus
        t.XPBonuses[sCombatType] = (EM.CombatBonusXP[sCombatType] ~= nil) and EM.CombatBonusXP[sCombatType] or 0;
        -- adjust the XP modifier for each valid ability attached to this unit
        for k, v in pairs(EM.AbilityXPModifiers) do if (pUnitAbility ~= nil and pUnitAbility:GetAbilityCount(k) ~= nil and pUnitAbility:GetAbilityCount(k) > 0) then t.XPModifiers[k] = v; end end
        -- adjust the XP modifier for any valid policy card that is slotted
        for i = 0, pPlayerCulture:GetNumPolicySlots() - 1 do 
            -- database index of the policy in slot i
            t.Policy = pPlayerCulture:GetSlotPolicy(i);
            -- adjust the XP modifier
            if (t.Policy == EM.PolicyXPModifiers.POLICY_SURVEY and t.PromotionClass == "PROMOTION_CLASS_RECON") then t.XPModifiers[EM.PolicyXPModifiers[t.Policy].Policy] = EM.PolicyXPModifiers[t.Policy].Modifier;
            elseif (t.Policy ~= EM.PolicyXPModifiers.POLICY_SURVEY and EM.PolicyXPModifiers[t.Policy] ~= nil) then t.XPModifiers[EM.PolicyXPModifiers[t.Policy].Policy] = EM.PolicyXPModifiers[t.Policy].Modifier;
            end
        end
        -- XP modifiers for major players
        if t.IsMajor then 
            -- difficulty XP modifier
            if not t.IsHuman then 
                if t.DifficultyLevel < EM.DefaultDifficultyLevel then t.DifficultyXPModifier = (EM.DefaultDifficultyLevel - t.DifficultyLevel) * EM.LowDifficultyXPModifier;
                elseif t.DifficultyLevel > EM.DefaultDifficultyLevel then t.DifficultyXPModifier = (t.DifficultyLevel - EM.DefaultDifficultyLevel) * EM.HighDifficultyXPModifier;
                end
            end
            -- if (t.IsHuman and t.DifficultyLevel < 4) or (not t.IsHuman and t.DifficultyLevel > 4) then t.XPModifiers[t.DifficultyType] = EM.DifficultyXPModifiers[t.DifficultyType]; end
            -- last known government refresh
            t.Government = pPlayer:GetProperty("CURRENT_GOVERNMENT_INDEX");
            if t.Government == nil or t.Government == -1 then t.Government = (EM.PlayerGovernments[t.PlayerID] ~= nil) and EM.PlayerGovernments[t.PlayerID] or -1; end
            pPlayer:SetProperty("CURRENT_GOVERNMENT_INDEX", t.Government);
            -- adjust the XP modifier for major players when a valid government is in use
            if EM.GovernmentXPModifiers[t.Government] ~= nil then t.XPModifiers[EM.GovernmentXPModifiers[t.Government].Government] = EM.GovernmentXPModifiers[t.Government].Modifier; end
            -- adjust the XP modifier when this major player is suzerain of Kabul
            for i, pMinor in ipairs(PlayerManager.GetAliveMinors()) do 
                local bIsMinorKabul = (PlayerConfigurations[pMinor:GetID()] ~= nil and PlayerConfigurations[pMinor:GetID()]:GetCivilizationTypeName() == "CIVILIZATION_KABUL");
                local bIsTargetSuzerain = (pMinor:GetInfluence() ~= nil and pMinor:GetInfluence():GetSuzerain() == t.PlayerID);
                if bIsMinorKabul and bIsTargetSuzerain then t.XPModifiers["MINOR_CIV_KABUL_UNIT_EXPERIENCE_BONUS"] = EM.XPModifiers["MINOR_CIV_KABUL_UNIT_EXPERIENCE_BONUS"]; end
            end
        end
        -- 
        for k, v in pairs(t.XPBonuses) do t.BonusXP = t.BonusXP + v; end
        for k, v in pairs(t.XPModifiers) do t.ModifierXP = t.ModifierXP + v; end
    else 
    end
    return t;
end

--[[]]
function EM.GetCombatXP( tTarget, tEnemy, sAction, iX, iY )
    -- debugging message headers
    local sF, sTargetInfoMsg = "GetCombatXP", "Player " .. tostring(tTarget.PlayerID) .. ": ";
    -- abort and return nil here when necessary, or return the provided XP value; otherwise calculate an XP value and return that
    if not tTarget.IsValid then 
        Dprint(sF, "Player " .. tostring(tTarget.PlayerID) .. " is 'NOT' a valid player; doing nothing");
        return nil;
    elseif tTarget.Combat == "ICBM" or tTarget.Combat == "RELIGIOUS" then 
        Dprint(sF, sTargetInfoMsg .. "No combat experience awarded for '" .. tTarget.Combat .. "' combat; doing nothing");
        return nil;
    elseif tTarget.IsBarbarian then 
        Dprint(sF, sTargetInfoMsg .. sAction .. " Barbarian horde; ignoring this combatant");
        return nil;
    elseif tTarget.IsCity or tTarget.IsDistrict or (tTarget.IsUnit and tTarget.UnitType == "UNIT_GIANT_DEATH_ROBOT") then 
        local sTarget = tTarget.IsCity and " 'CITY'" or tTarget.IsDistrict and " " .. tostring(tTarget.DistrictType) or " " .. tostring(tTarget.UnitType);
        Dprint(sF, sTargetInfoMsg .. sAction .. sTarget .. " is 'NOT' eligible for combat experience; ignoring this combatant");
        return nil;
    elseif tTarget.IsUnit and tTarget.IsDead then 
        Dprint(sF, sTargetInfoMsg .. sAction .. " unit " .. tostring(tTarget.UnitType) .. " was 'KILLED'; no combat experience awarded");
        return nil;
    -- elseif tTarget.IsUnit and tTarget.XP > 0 then 
    --     Dprint(sF, sTargetInfoMsg .. sAction .. " unit " .. tostring(tTarget.UnitType) .. " survived and received " .. tTarget.XP .. " combat experience from gamecore; proceeding with this value . . .");
    --     return tTarget.XP;
    elseif tTarget.IsUnit then 
        if not tTarget.IsEligible then 
            Dprint(sF, sTargetInfoMsg .. sAction .. " unit " .. tostring(tTarget.UnitType)  .. " has no current Unit or UnitExperience data; skipping this combatant");
            return nil;
        end
        Dprint(sF, sTargetInfoMsg .. sAction .. " unit " .. tostring(tTarget.UnitType) .. " survived and is eligible for combat experience, but none was provided by gamecore; calculating experience earned . . .");
        Dprint(sF, sAction .. " unit combat experience from gamecore: " .. tTarget.XP);
        Dprint(sF, "Enemy HP: -" .. tEnemy.Damage .. " (" .. (tEnemy.MaxHP - tEnemy.FinalDamage) .. " / " .. tEnemy.MaxHP .. ")");
        -- initialize base XP and base modifier values
        local iBaseXP, iBaseXPModifier, iCalcXP = 1, 100, 1;
        -- base XP is multiplied by this when enemy unit is killed
        local iKillXPModifier, iXPModifier = tEnemy.IsDead and EM.XPKillBonus or 1, (iBaseXPModifier + tTarget.ModifierXP) / iBaseXPModifier;
        -- 
        local iDifficultyXPModifier = (iBaseXPModifier + tTarget.DifficultyXPModifier) / iBaseXPModifier;
        -- reset potential air combat bonus
        if tTarget.Combat == "AIR" then 
            tTarget.BonusXP = tTarget.BonusXP - tTarget.XPBonuses["AIR"];
            tTarget.XPBonuses["AIR"] = nil;
            local bIsTargetAircraft = (tTarget.PromotionClass == "PROMOTION_CLASS_AIR_BOMBER" or tTarget.PromotionClass == "PROMOTION_CLASS_AIR_FIGHTER");
            local bIsEnemyAircraft = (tEnemy.PromotionClass == "PROMOTION_CLASS_AIR_BOMBER" or tEnemy.PromotionClass == "PROMOTION_CLASS_AIR_FIGHTER");
            if bIsTargetAircraft and bIsEnemyAircraft then 
                tTarget.XPBonuses["AIR-TO-AIR"] = EM.CombatBonusXP["AIR-TO-AIR"];
                tTarget.BonusXP = tTarget.BonusXP + tTarget.XPBonuses["AIR-TO-AIR"];
            else
                tTarget.XPBonuses["AIR-TO-GROUND"] = EM.CombatBonusXP["AIR-TO-GROUND"];
                tTarget.BonusXP = tTarget.BonusXP + tTarget.XPBonuses["AIR-TO-GROUND"];
            end
        end
        -- 
        local sKilledFlag = tEnemy.IsDead and " 'KILLED' " or " ";
        local sCalcMsg = sAction .. " unit vs" .. sKilledFlag;
        -- 
        if tEnemy.IsDistrict or tEnemy.IsCity then 
            tTarget.BonusXP, tTarget.XPBonuses = 0, {};
            if not tTarget.IsAttacker then 
                iBaseXP = EM.XPDistrictVsUnit;
                iCalcXP = iBaseXP;
            elseif tTarget.IsAttacker then 
                iBaseXP = EM.XPUnitVsDistrictNotCityCaptured;
                if tTarget.Combat ~= "MELEE" and tEnemy.MaxHP == 0 then iBaseXP = 0;
                elseif tTarget.Combat == "MELEE" and tEnemy.IsDead then iBaseXP = EM.XPCityCaptured;
                end
                iCalcXP = iBaseXP * iXPModifier;
            end
            sCalcMsg = sCalcMsg .. "city/district base combat experience: " .. iBaseXP;
        elseif tEnemy.IsUnit then 
            -- 
            iBaseXP = (tEnemy.CombatStrength / tTarget.CombatStrength);
            sCalcMsg = sCalcMsg .. "unit base combat experience: (" .. tEnemy.CombatStrength .. " / " .. tTarget.CombatStrength .. ") ";
            if tTarget.IsAttacker and tEnemy.IsDead then 
                iBaseXP = iBaseXP * EM.XPKillBonus; 
                sCalcMsg = sCalcMsg .. "* " .. EM.XPKillBonus .. " = " .. iBaseXP;
            else
                sCalcMsg = sCalcMsg .. "= " .. iBaseXP;
            end
            iCalcXP = (iBaseXP + tTarget.BonusXP) * iXPModifier;
        end
        if iDifficultyXPModifier ~= 1 then iCalcXP = math.ceil(math.ceil(iCalcXP) * iDifficultyXPModifier);
        else iCalcXP = math.ceil(iCalcXP);
        end
        -- 
        Dprint(sF, sCalcMsg);
        local sTargetBonusMsg = sAction .. " unit combat experience bonuses (+" .. tTarget.BonusXP .. " total):";
        for k, v in pairs(tTarget.XPBonuses) do sTargetBonusMsg = sTargetBonusMsg .. " [" .. k .. " (+" .. v .. ")]"; end
        Dprint(sF, sTargetBonusMsg);
        local sTargetModifierMsg = sAction .. " unit combat experience modifiers (+" .. tTarget.ModifierXP .. "%% total):";
        for k, v in pairs(tTarget.XPModifiers) do sTargetModifierMsg = sTargetModifierMsg .. " [" .. k .. " (+" .. v .. "%%)]"; end
        Dprint(sF, sTargetModifierMsg);
        if tTarget.DifficultyXPModifier ~= 0 then Dprint(sF, sAction .. " unit AI difficulty modifier: " .. tTarget.DifficultyXPModifier .. "%% [" .. tTarget.DifficultyType .. "]"); end
        local sFinalCalcMsg = sAction .. " unit final calculated combat experience";
        local sBarbCapEnforced = ": ";
        if (tTarget.Level >= EM.XPMaxBarbLevel and tEnemy.IsValid and tEnemy.IsBarbarian) then 
            sBarbCapEnforced = "(Barbarian soft XP cap enforced): ";
            sFinalCalcMsg = sFinalCalcMsg .. sBarbCapEnforced .. iCalcXP .. " (";
            iCalcXP = EM.XPBarbSoftCap;
            sFinalCalcMsg = sFinalCalcMsg .. iCalcXP .. ")";
        else
            sFinalCalcMsg = sFinalCalcMsg .. sBarbCapEnforced .. iCalcXP;
        end
        Dprint(sF, sFinalCalcMsg);
        EM.RefreshXPBalance(tTarget, iCalcXP, iX, iY);
        return iCalcXP;
    end
end

--[[]]
function EM.RefreshXPBalance( tTarget, iXP, iX, iY )
    -- 
    local sF, sAction = "RefreshXPBalance", tTarget.IsAttacker and "Attacking " or "Defending ";
    local pUnit = Players[tTarget.PlayerID]:GetUnits():FindID(tTarget.CombatantID);
    local pUnitExperience = pUnit:GetExperience();
    -- target unit's new XP balance and amount of XP to be banked
    local iBankXP = ((tTarget.LastCurrentXP + iXP) > tTarget.XPFNL) and ((tTarget.LastCurrentXP + iXP) - tTarget.XPFNL) or 0;
    local iNewBalanceXP = tTarget.BalanceXP + iBankXP;
    Dprint(sF, "Banked combat experience: " .. iBankXP); -- .. " (New balance: " .. iNewBalanceXP .. ")");
    -- reset the target unit's XP balance and last known current XP total properties to the new values
    pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
    pUnit:SetProperty("LAST_CURRENT_XP", tTarget.CurrentXP);
    -- popup text to indicate how much, if any, experience was banked
    if iBankXP > 0 and tTarget.IsHuman then 
        Game.AddWorldViewText(tTarget.PlayerID, Locale.Lookup("[COLOR_LIGHTBLUE] +{1_XP}XP stored pending promotion [ENDCOLOR]", iBankXP), iX, iY, 0);
    end
    local sInfoMsg = "Player " .. tTarget.PlayerID .. ": " .. sAction .. tTarget.UnitType .. " (ID " .. tTarget.CombatantID .. ") survived, earning " .. iXP .. " combat experience ";
    print(sInfoMsg .. "(Level " .. tTarget.Level .. ", " .. tTarget.LastCurrentXP .. " --> " .. tTarget.CurrentXP .. " XP / " .. tTarget.XPFNL .. " FNL, balance " .. tTarget.BalanceXP .. " --> " .. iNewBalanceXP .. " XP)");
end

--[[ =========================================================================
	listener function OnTurnBegin( iTurn )
	for Expansion1 ruleset and beyond; global Era for all Players
	pre-init: this should be defined prior to Initialize()
=========================================================================== ]]
function OnTurnBegin( iTurn )
	EM.CurrentTurn = iTurn;			-- update the global current turn
	-- local iPreviousEra = GUE.CurrentEra;
	-- local iEraThisTurn = Game.GetEras():GetCurrentEra();		-- fetch the current era
	-- -- local Dprint = GUE.DebugPrint;
	-- if (iPreviousEra ~= iEraThisTurn) then			-- true when the current era differs from the stored global era
	-- 	GUE.CurrentEra = iEraThisTurn;			-- update the global era
	-- 	Dprint("Turn " .. tostring(iTurn) .. ": The current global game Era has changed from " .. tostring(GUE.Eras[iPreviousEra]) .. " to " .. tostring(GUE.Eras[iEraThisTurn]));
	-- 	if (GUE.HostilesAfterReward > 2) then Dprint("Hostility > 2: Hostile villagers will now appear with increased intensity following most goody hut rewards");
	-- 	elseif (GUE.HostilesAfterReward > 1) then Dprint("Hostility > 1: Hostile villagers will now appear with increased frequency and intensity following most goody hut rewards");
	-- 	end
	-- else
	-- 	Dprint("Turn " .. tostring(iTurn) .. ": The current global game Era is " .. tostring(GUE.Eras[iEraThisTurn]));
	-- end
end

--[[ =========================================================================
	event listener function OnCombat( tCombatResult )
        parses combat results and banks any applicable experience earned
	should be defined prior to Initialize()
=========================================================================== ]]
function OnCombat( tCombatResult )
    -- increment global combat tracker
    EM.CombatCounter = EM.CombatCounter + 1;
    -- combat type hash
    local hCombatType = tCombatResult[CombatResultParameters.COMBAT_TYPE];
    -- combat type string
    local sCombatType = (EM.CombatTypeByHash[hCombatType] ~= nil) and EM.CombatTypeByHash[hCombatType] or "'UNKNOWN'";
    -- debugging header
    local sF = "OnCombat";
	-- fetch combat result parameters and initialize local result tables for attacker and defender
    local tAttacker, tDefender = EM.GetCombatParameters(sCombatType, tCombatResult[CombatResultParameters.ATTACKER], true), EM.GetCombatParameters(sCombatType, tCombatResult[CombatResultParameters.DEFENDER], false);
    -- map (x, y) coordinates of the combat location
	local iX, iY = tCombatResult[CombatResultParameters.LOCATION].x, tCombatResult[CombatResultParameters.LOCATION].y;
    -- 
    local bDefenderCaptured = tCombatResult[CombatResultParameters.DEFENDER_CAPTURED];
	
    -- debugging output
    local sAttacker = tAttacker.IsUnit and tAttacker.UnitType or tAttacker.IsDistrict and tAttacker.DistrictType or tAttacker.IsCity and "'CITY'" or "'UNKNOWN'";
    local sDefender = tDefender.IsUnit and tDefender.UnitType or tDefender.IsDistrict and tDefender.DistrictType or tDefender.IsCity and "'CITY'" or "'UNKNOWN'";
    local sPriDebugMsg = "Turn " .. EM.CurrentTurn .. ": Global combat " .. EM.CombatCounter .. ": " .. sCombatType .. " (Hash " .. hCombatType .. ") at plot (x " .. iX .. ", y " .. iY .. "), ";
    local sSecDebugMsg = "Attacking Player " .. tostring(tAttacker.PlayerID) .. " (" .. sAttacker .. ", ID " .. tostring(tAttacker.CombatantID) .. ") vs Defending Player " .. tostring(tDefender.PlayerID) .. " (" .. sDefender .. ", ID " .. tostring(tDefender.CombatantID) .. ") [ DEFENDER_CAPTURED = " .. tostring(bDefenderCaptured) .. " ]";
    print(sPriDebugMsg .. sSecDebugMsg);
	
    -- 
    local iAttackerXP, iDefenderXP = EM.GetCombatXP(tAttacker, tDefender, "Attacking", iX, iY), EM.GetCombatXP(tDefender, tAttacker, "Defending", iX, iY);
    
end

--[[]]
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
	hook function OnTurnBeginHook()
	actions related to a global game Era change
	init: this should be hooked to Events.LoadScreenClose in Initialize()
=========================================================================== ]]
function OnTurnBeginHook() Events.TurnBegin.Add(OnTurnBegin); end

-- 
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
    print("Retrieving relevant game setup option(s) . . .");
    print("Barbarian experience soft cap: " .. EM.XPBarbSoftCap .. "; this is enforced beginning at Level " .. EM.XPMaxBarbLevel);
    print("Other Unit-vs-Unit per-combat experience cap: " .. EM.XPMaxOneCombat);
    -- print("Kabul suzerain combat experience modifier: +" .. EM.KabulXPModifier .. "%%");
    print("Configuring Policy Card modifiers for experience banking system . . .");
    for k, v in pairs(EM.PolicyXPModifiers) do if type(v) == "table" then Dprint(sF, "[" .. v.Policy .. "]: +" .. v.Modifier .. "%%"); end end
    print("Configuring Government modifiers for experience banking system . . .");
    for k, v in pairs(EM.GovernmentXPModifiers) do if type(v) == "table" then Dprint(sF, "[" .. v.Government .. "]: +" .. v.Modifier .. "%%"); end end
    print("Configuring Unit Ability modifiers for experience banking system . . .");
    for k, v in pairs(EM.AbilityXPModifiers) do Dprint(sF, "[" .. k .. "]: +" .. v .. "%%"); end
    print("Configuring other modifiers for experience banking system . . .");
    for k, v in pairs(EM.XPModifiers) do Dprint(sF, "[" .. k .. "]: +" .. v .. "%%"); end
    
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

--[[ =========================================================================
	exposed member function SetXPBalance( sCombatType, iX, iY, pTarget, iTargetPlayerID, iTargetUnitID, pEnemy, iEnemyPlayerID, iEnemyUnitID, bIsAttacker, bDefenderCaptured )
        (re)sets XP balance data for pTarget
        displays world-view text at (iX, iY) reflecting XP banked from a combat
	should be defined prior to Initialize()
=========================================================================== ]]
-- function EM.SetXPBalance( sCombatType, iX, iY, pTarget, iTargetPlayerID, iTargetUnitID, pEnemy, iEnemyPlayerID, iEnemyUnitID, bIsAttacker, bDefenderCaptured )
--     -- logging details
--     local sF, sAction, sCombatant = "SetXPBalance", bIsAttacker and "Attacking" or "Defending", " Unit ";
--     -- result message; this will be assembled below when XP is calculated, and returned for logging
--     local sInfoMsg = "Player " .. tostring(iTargetPlayerID) .. ": ";
--     -- abort if the target player or ID is nil or invalid
--     if iTargetPlayerID == nil or iTargetPlayerID < 0 or Players[iTargetPlayerID] == nil then return sAction .. " player ID " .. tostring(iTargetPlayerID) .. " is nil or otherwise invalid; ignoring"; end
--     -- abort if the combat type is ICBM
--     if sCombatType == "ICBM" then return sInfoMsg .. "No experience awarded for ICBM strike; ignoring"; end
--     -- abort if the enemy player or ID is nil or invalid
--     if iEnemyPlayerID == nil or iEnemyPlayerID < 0 or Players[iEnemyPlayerID] == nil then return sInfoMsg .. "Enemy player ID " .. tostring(iEnemyPlayerID) .. " is nil or otherwise invalid; ignoring"; end
--     -- fetch Players table for target player; abort if this player is the Barbarian player 
--     local pPlayer = Players[iTargetPlayerID];
--     if pPlayer:IsBarbarian() then return sInfoMsg .. sAction .. " Barbarian horde; ignoring provided ID " .. iTargetUnitID; end
--     -- identify target and enemy combatants as city/district/unit using provided types
--     local bIsTargetCity, bIsEnemyCity = pTarget[CombatResultParameters.ID].type == ComponentType.CITY, pEnemy[CombatResultParameters.ID].type == ComponentType.CITY;
--     local bIsTargetDistrict, bIsEnemyDistrict = pTarget[CombatResultParameters.ID].type == ComponentType.DISTRICT, pEnemy[CombatResultParameters.ID].type == ComponentType.DISTRICT;
--     local bIsTargetUnit, bIsEnemyUnit = pTarget[CombatResultParameters.ID].type == ComponentType.UNIT, pEnemy[CombatResultParameters.ID].type == ComponentType.UNIT;
--     -- these are true when the target or enemy, respectively, has sustained more damage than it has hit points
--     local bIsTargetDead = pTarget[CombatResultParameters.FINAL_DAMAGE_TO] > pTarget[CombatResultParameters.MAX_HIT_POINTS];
--     local bIsEnemyDead = pEnemy[CombatResultParameters.FINAL_DAMAGE_TO] > pEnemy[CombatResultParameters.MAX_HIT_POINTS];
--     -- abort if target combatant is a city or district
--     if bIsTargetCity or bIsTargetDistrict then 
--         sCombatant = bIsTargetCity and " City " or " District ";
--         return sInfoMsg .. sAction .. sCombatant .. "(ID " .. iTargetUnitID .. "); no experience awarded";
--     elseif bIsTargetUnit then 
--         -- abort if target combatant unit is dead
--         if bIsTargetDead then 
--             return sInfoMsg .. sAction .. sCombatant .. "(ID " .. iTargetUnitID .. ") was killed; no experience awarded";
--         else
--             -- fetch PlayerConfigurations table for target player; abort if this returns nil
--             local pPlayerConfig = PlayerConfigurations[iTargetPlayerID];
--             if pPlayerConfig == nil then return "PlayerConfigurations returned nil for target player " .. iTargetPlayerID .. "; ignoring"; end
--             -- fetch target player culture data; abort if this returns nil
--             local pPlayerCulture = pPlayer:GetCulture();
--             if pPlayerCulture == nil then return "Players:GetCulture() returned nil for target player " .. iTargetPlayerID .. "; ignoring"; end
--             -- fetch target player units data; abort if this returns nil
--             local pUnit = pPlayer:GetUnits():FindID(iTargetUnitID);
--             if pUnit == nil then return sInfoMsg .. "Players:GetUnits():FindID() returned nil for provided ID " .. iTargetUnitID .. "; ignoring"; end
--             -- fetch target unit experience data; abort if this returns nil
--             local pUnitExperience = (pUnit ~= nil) and pUnit:GetExperience() or nil;
--             if pUnitExperience == nil then return sInfoMsg .. "Units:GetExperience() returned nil for provided ID " .. iTargetUnitID .. "; ignoring"; end
--             -- fetch target unit ability data; abort if this returns nil
--             local pUnitAbility = (pUnit ~= nil) and pUnit:GetAbility() or nil;
--             if pUnitAbility == nil then return sInfoMsg .. "Units:GetAbility() returned nil for provided ID " .. iTargetUnitID .. "; ignoring"; end
--             -- fetch general data for target unit; abort if this returns nil
--             local pUnitData = (pUnit ~= nil) and GameInfo.Units[pUnit:GetType()] or nil;
--             if pUnitData == nil then return sInfoMsg .. "GameInfo.Units[Units:GetType()] returned nil for provided ID " .. iTargetUnitID .. "; ignoring"; end
--             -- fetch target unit's promotion class; abort if this returns nil
--             local sTargetPromotionClass = (pUnitData.PromotionClass ~= nil) and pUnitData.PromotionClass or nil;
--             if sTargetPromotionClass == nil then return sInfoMsg .. "GameInfo.Units[Units:GetType()].PromotionClass returned nil for provided ID " .. iTargetUnitID .. "; ignoring"; end
--             -- 
--             local sTargetUnitType = (pUnitData.UnitType ~= nil) and pUnitData.UnitType or nil;
--             print(sTargetUnitType .. ", " .. sTargetPromotionClass);
--             -- 
--             local sEnemyPromotionClass = tostring(GameInfo.Units[Players[iEnemyPlayerID]:GetUnits():FindID(iEnemyUnitID):GetType()].PromotionClass);
--             local sEnemyUnitType = tostring(GameInfo.Units[Players[iEnemyPlayerID]:GetUnits():FindID(iEnemyUnitID):GetType()].UnitType);
--             print(sEnemyUnitType .. ", " .. sEnemyPromotionClass);
--             -- target and enemy combat strength, applicable strength modifiers, and XP earned from this combat
--             local iTargetCombatStr, iEnemyCombatStr = pTarget[CombatResultParameters.COMBAT_STRENGTH], pEnemy[CombatResultParameters.COMBAT_STRENGTH];
--             local iTargetStrModifier, iEnemyStrModifier = pTarget[CombatResultParameters.STRENGTH_MODIFIER], pEnemy[CombatResultParameters.STRENGTH_MODIFIER];
--             local iTargetXP, iEnemyXP = pTarget[CombatResultParameters.EXPERIENCE_CHANGE], pEnemy[CombatResultParameters.EXPERIENCE_CHANGE];
--             -- target unit's level, current XP, and XPFNL
--             local iLevel, iCurrentXP, iXPFNL = 1, pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
--             -- target unit's current XP balance and last known current XP total
--             local iBalanceXP = (pUnit:GetProperty("XP_BALANCE") ~= nil) and pUnit:GetProperty("XP_BALANCE") or 0;
--             local iLastCurrentXP = (pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
--             -- when unit has enough XP for its next promotion, and that promotion would cross the barbarian soft XP cap threshold, begin enforcing the cap on any new XP banked prior to applying that promotion
--             for i, v in ipairs(EM.PromotionLevels) do if (iLastCurrentXP >= v.Min and iLastCurrentXP <= v.Max) then iLevel = i; end end
--             -- initialize experience bonuses and modifiers tables
--             local tBonuses, tModifiers = { ATTACKER = bIsAttacker, KILL = bIsEnemyDead }, {};
--             -- add valid combat type bonuses to the bonuses table
--             for k, v in pairs(EM.CombatBonusXP) do tBonuses[k] = (k == sCombatType); end
--             -- initialize base XP to the barbarian soft XP cap value
--             local iBaseXP = EM.XPBarbSoftCap;
--             -- added when target unit is the attacker
--             local iAttackerBonusXP = bIsAttacker and EM.XPCombatAttackerBonus or 0;
--             -- combat type bonus
--             local iCombatBonusXP = (EM.CombatBonusXP[sCombatType] ~= nil) and EM.CombatBonusXP[sCombatType] or 0;
--             -- base XP is multiplied by this when enemy is killed
--             local iKillXPModifier = bIsEnemyDead and EM.XPKillBonus or 1;
--             -- base XP modifier, Kabul suzerain XP modifier, and difficulty type hash
--             local iBaseXPModifier, iKabulXPModifier, hDifficulty = 100, 100, pPlayerConfig:GetHandicapTypeID();
--             -- default additional XP modifier
--             local iXPModifier = 0;
--             -- difficulty type and level from type hash
--             local sDifficulty, iDifficultyLevel = EM.DifficultyLevels[hDifficulty].Type, EM.DifficultyLevels[hDifficulty].Level;
--             -- difficulty level XP modifier
--             local iDifficultyXPModifier = iBaseXPModifier;
--             -- calculate base combat XP
--             if bIsEnemyCity or bIsEnemyDistrict then 
--                 if bIsAttacker then 
--                     if bDefenderCaptured then iBaseXP = EM.XPCityCaptured;
--                     else iBaseXP = EM.XPUnitVsDistrictNotCityCaptured;
--                     end
--                 elseif not bIsAttacker then iBaseXP = EM.XPDistrictVsUnit;
--                 end
--             elseif bIsEnemyUnit then iBaseXP = iEnemyCombatStr / iTargetCombatStr;
--             end
--             -- adjust the XP modifier for each valid ability attached to this unit
--             for k, v in pairs(EM.AbilityXPModifiers) do 
--                 -- number of times this ability has been attached to this unit
--                 local iAbilityCount = (pUnitAbility ~= nil) and pUnitAbility:GetAbilityCount(k) or -1;
--                 -- adjust the XP modifier when the unit has this ability
--                 if iAbilityCount ~= nil and iAbilityCount > 0 then 
--                     iXPModifier = iXPModifier + v;
--                     tModifiers[k] = true;
--                 end
--             end
--             -- adjust the XP modifier for any valid policy card that is slotted
--             for i = 0, pPlayerCulture:GetNumPolicySlots() - 1 do 
--                 -- database index of the policy in slot i
--                 local iPolicyIndex = pPlayerCulture:GetSlotPolicy(i);
--                 -- adjust the XP modifier when policy Survey is slotted and the target unit is a recon unit
--                 if iPolicyIndex == EM.PolicyXPModifiers.POLICY_SURVEY and sTargetPromotionClass == "PROMOTION_CLASS_RECON" then 
--                     iXPModifier = iXPModifier + EM.PolicyXPModifiers[iPolicyIndex].Modifier;
--                     tModifiers[EM.PolicyXPModifiers[iPolicyIndex].Policy] = true;
--                 -- catch for any other valid policy; adjust the XP modifier by the indicated amount
--                 elseif iPolicyIndex ~= EM.PolicyXPModifiers.POLICY_SURVEY and EM.PolicyXPModifiers[iPolicyIndex] ~= nil then 
--                     iXPModifier = iXPModifier + EM.PolicyXPModifiers[iPolicyIndex].Modifier;
--                     tModifiers[EM.PolicyXPModifiers[iPolicyIndex].Policy] = true;
--                 end
--             end
--             -- major player XP modifiers
--             if pPlayer:IsMajor() then 
--                 -- last known government refresh
--                 local iGovernmentIndex = pPlayer:GetProperty("CURRENT_GOVERNMENT_INDEX");
--                 if iGovernmentIndex == nil or iGovernmentIndex == -1 then 
--                     iGovernmentIndex = (EM.PlayerGovernments[iTargetPlayerID] ~= nil) and EM.PlayerGovernments[iTargetPlayerID] or -1; 
--                 end
--                 pPlayer:SetProperty("CURRENT_GOVERNMENT_INDEX", iGovernmentIndex);
--                 -- adjust the XP modifier for major players when a valid government is in use
--                 if EM.GovernmentXPModifiers[iGovernmentIndex] ~= nil then 
--                     iXPModifier = iXPModifier + EM.GovernmentXPModifiers[iGovernmentIndex].Modifier;
--                     tModifiers[EM.GovernmentXPModifiers[iGovernmentIndex].Government] = true;
--                 end
--                 -- adjust the XP modifier when this major player is suzerain of Kabul
--                 for i, pMinor in ipairs(PlayerManager.GetAliveMinors()) do 
--                     -- this minor player's ID
--                     local iMinorID = pMinor:GetID();
--                     -- this minor's config and influence
--                     local pMinorConfig, pMinorInfluence = PlayerConfigurations[iMinorID], pMinor:GetInfluence();
--                     -- true when this minor is Kabul, target player is its suzerain, and target player is attacker
--                     if pMinorConfig ~= nil and pMinorConfig:GetCivilizationTypeName() == "CIVILIZATION_KABUL" and pMinorInfluence ~= nil and pMinorInfluence:GetSuzerain() == iTargetPlayerID and bIsAttacker then 
--                         -- adjust the XP modifier
--                         iXPModifier = iXPModifier + iKabulXPModifier;
--                         tModifiers.KABUL_SUZERAIN = true;
--                     end
--                 end
--                 -- adjust the XP modifier for human Major players below and AI Major players above the indicated difficulty level
--                 if ((pPlayer:IsHuman() and iDifficultyLevel < 4) or (not pPlayer:IsHuman() and iDifficultyLevel > 4)) then 
--                     iDifficultyXPModifier = iDifficultyXPModifier + EM.DifficultyXPModifiers[sDifficulty];
--                     local sPlayer = pPlayer:IsHuman() and "HUMAN_" or "AI_";
--                     tModifiers[sPlayer .. sDifficulty] = true;
--                 end
--             end
--             -- calculate total XP earned from this combat
--             local iTotalBonusXP, iFinalXPModifier = (iCombatBonusXP + iAttackerBonusXP), ((iDifficultyXPModifier + iXPModifier) / iBaseXPModifier);
--             local iCalcXP = ((iBaseXP * iKillXPModifier) + iTotalBonusXP) * iFinalXPModifier;
--             -- reset calculated XP if necessary
--             if bIsEnemyCity or bIsEnemyDistrict then
--                 -- no bonuses or modifiers when defending against city/district attacks
--                 if not bIsAttacker then iCalcXP = iBaseXP;
--                 -- no bonuses when attacking city/district defenses
--                 elseif bIsAttacker then iCalcXP = iBaseXP * iFinalXPModifier;
--                 end
--             elseif sCombatType == "AIR" then 
--                 -- no attacker bonus for air combat
--                 iCalcXP = ((iBaseXP * iKillXPModifier) + iCombatBonusXP) * iFinalXPModifier;
--             elseif sCombatType == "BOMBARD" then 
--                 -- no bonuses for bombard attacks
--                 iCalcXP = iBaseXP * iFinalXPModifier;
--             end
--             -- use the rounded calculated value if it does not exceed the defined per-combat cap, otherwise use the cap value
--             local iXP = (math.ceil(iCalcXP) > EM.XPMaxOneCombat and bIsEnemyUnit) and EM.XPMaxOneCombat or math.ceil(iCalcXP);
--             -- enforce barbarian XP soft cap
--             iXP = (iLevel >= EM.XPMaxBarbLevel and Players[iEnemyPlayerID] ~= nil and Players[iEnemyPlayerID]:IsBarbarian()) and EM.XPBarbSoftCap or iXP;
--             -- logging
--             local sPriCalcXPMsg = "Calculated [rounded/capped] 'vs' actual ingame combat experience value: ";
--             local sSecCalcMsg = "((" .. iBaseXP .. " * " .. iKillXPModifier .. ") + " .. iTotalBonusXP .. ") * " .. iFinalXPModifier .. " = " .. iCalcXP .. " [ " .. iXP .. " ] 'vs' " .. iTargetXP;
--             -- reset logging messages as necessary
--             if bIsEnemyCity or bIsEnemyDistrict then
--                 if not bIsAttacker then sSecCalcMsg = iBaseXP .. " = " .. iCalcXP .. " [ " .. iXP .. " ] 'vs' " .. iTargetXP;
--                 elseif bIsAttacker then sSecCalcMsg = iBaseXP .. " * " .. iFinalXPModifier .. " = " .. iCalcXP .. " [ " .. iXP .. " ] 'vs' " .. iTargetXP;
--                 end
--             elseif sCombatType == "AIR" then sSecCalcMsg = "((" .. iBaseXP .. " * " .. iKillXPModifier .. ") + " .. iCombatBonusXP .. ") * " .. iFinalXPModifier .. " = " .. iCalcXP .. " [ " .. iXP .. " ] 'vs' " .. iTargetXP;
--             elseif sCombatType == "BOMBARD" then sSecCalcMsg = iBaseXP .. " * " .. iFinalXPModifier .. " = " .. iCalcXP .. " [ " .. iXP .. " ] 'vs' " .. iTargetXP;
--             end
--             -- logging
--             local sPriInfoMsg = sAction .. " unit combat experience bonuses:";
--             for k, v in pairs(tBonuses) do if v then sPriInfoMsg = sPriInfoMsg .. " [" .. tostring(k) .. "]"; end end
--             Dprint(sF, sPriInfoMsg);
--             local sSecInfoMsg = sAction .. " unit combat experience modifiers:";
--             for k, v in pairs(tModifiers) do if v then sSecInfoMsg = sSecInfoMsg .. " [" .. tostring(k) .. "]"; end end
--             Dprint(sF, sSecInfoMsg);
--             Dprint(sF, sPriCalcXPMsg .. sSecCalcMsg);
--             -- use the game-provided value if it exists, otherwise continue using the calculated/capped value
--             iXP = (iTargetXP > 0) and iTargetXP or iXP;
--             -- target unit's new XP balance and amount of XP to be banked
--             local iBankXP = ((iLastCurrentXP + iXP) > iXPFNL) and ((iLastCurrentXP + iXP) - iXPFNL) or 0;
--             local iNewBalanceXP = iBalanceXP + iBankXP;
--             Dprint(sF, "Banked combat experience: " .. iBankXP); -- .. " (New balance: " .. iNewBalanceXP .. ")");
--             -- reset the target unit's XP balance and last known current XP total properties to the new values
--             pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
--             pUnit:SetProperty("LAST_CURRENT_XP", iCurrentXP);
--             -- popup text to indicate how much, if any, experience was banked
--             if iBankXP > 0 and Players[iTargetPlayerID]:IsHuman() then 
--                 Game.AddWorldViewText(iTargetPlayerID, Locale.Lookup("[COLOR_LIGHTBLUE] +{1_XP}XP stored pending promotion [ENDCOLOR]", iBankXP), iX, iY, 0);
--             end
--             sInfoMsg = sInfoMsg .. sAction .. sCombatant .. "(ID " .. iTargetUnitID .. ") survived, earning " .. iXP .. " combat experience";
--             return sInfoMsg .. " (Level " .. iLevel .. ", " .. iLastCurrentXP .. " --> " .. iCurrentXP .. " XP / " .. iXPFNL .. " FNL, balance " .. iBalanceXP .. " --> " .. iNewBalanceXP .. " XP)";
--         end
--     end
-- end
