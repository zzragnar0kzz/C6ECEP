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

--[[ =========================================================================
	event listener function OnCombat( tCombatResult )
        parses combat results and banks any applicable experience earned
	should be defined prior to Initialize()
=========================================================================== ]]
function OnCombat( tCombatResult )
	-- attacker and defender combat result parameters
	local pAttacker, pDefender = tCombatResult[CombatResultParameters.ATTACKER], tCombatResult[CombatResultParameters.DEFENDER];
	-- map (x, y) coordinates of the combat location
	local iX, iY = tCombatResult[CombatResultParameters.LOCATION].x, tCombatResult[CombatResultParameters.LOCATION].y;
	-- true when the attacker or defender, respectively, is a unit
	pAttacker.IsUnit, pDefender.IsUnit = pAttacker[CombatResultParameters.ID].type == ComponentType.UNIT, pDefender[CombatResultParameters.ID].type == ComponentType.UNIT;
	-- minimum experience from combat, and debugging header
	local iMinXP, sF = 2, "OnCombat";
	-- true when attacker is a unit
	if pAttacker.IsUnit then 
		-- true when the attacking unit has sustained more damage than it has hit points
		pAttacker.IsDead = pAttacker[CombatResultParameters.FINAL_DAMAGE_TO] > pAttacker[CombatResultParameters.MAX_HIT_POINTS];
		-- true when the attacking unit is dead
		if not pAttacker.IsDead then 
			-- player and unit IDs, and XP change for the attacker
			local iPlayerID, iUnitID = pAttacker[CombatResultParameters.ID].player, pAttacker[CombatResultParameters.ID].id;
			local iXP = (pAttacker[CombatResultParameters.EXPERIENCE_CHANGE] > 0) and pAttacker[CombatResultParameters.EXPERIENCE_CHANGE] or iMinXP;
			-- attacking unit data
			local pUnit = Players[iPlayerID]:GetUnits():FindID(iUnitID);
			-- true when attacking unit data exists
			if (pUnit ~= nil) then 
                -- attacking unit XP data
		    	local pUnitExperience = pUnit:GetExperience();
                -- true when attacking unit XP data exists
                if (pUnitExperience ~= nil) then 
	    	    	-- attacking unit's current XP and XPFNL
    	    		local iCurrentXP, iXPFNL = pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
	    		    -- attacking unit's current XP balance and last known current XP total
    		    	local iBalanceXP = (pUnit:GetProperty("XP_BALANCE") ~= nil) and pUnit:GetProperty("XP_BALANCE") or 0;
	    		    local iLastCurrentXP = (pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
                    -- attacking unit's new XP balance and amount of XP to be banked
                    local iNewBalanceXP = ((iLastCurrentXP + iXP) > iXPFNL) and iBalanceXP + ((iLastCurrentXP + iXP) - iXPFNL) or iBalanceXP;
                    local iBankXP = (iNewBalanceXP ~= iBalanceXP) and iNewBalanceXP - iBalanceXP or 0;
	    	    	-- reset the attacking unit's XP balance and last known current XP total properties to the new values
    	    		pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
    			    pUnit:SetProperty("LAST_CURRENT_XP", iCurrentXP);
			        -- debugging output
		        	local sPriAttMsg = "Player " .. iPlayerID .. ": Attacking Unit " .. iUnitID .. " survived, earning " .. iXP .. " combat experience";
	        		local sSecAttMsg = " (" .. iLastCurrentXP .. " --> " .. iCurrentXP .. " XP / " .. iXPFNL .. " FNL, balance " .. iBalanceXP .. " --> " .. iNewBalanceXP .. " XP)";
        			Dprint(sF, sPriAttMsg .. sSecAttMsg);
                    -- popup text to indicate how much, if any, experience was banked
                    if iBankXP > 0 and Players[iPlayerID]:IsHuman() then 
                        Game.AddWorldViewText(iPlayerID, Locale.Lookup("[COLOR_LIGHTBLUE] + {1_XP} XP stored pending promotion [ENDCOLOR]", iBankXP), iX, iY, 0);
                    end
                end
            end
		end
	end
	-- true when defender is a unit
	if pDefender.IsUnit then 
		-- true when the defending unit has sustained more damage than it has hit points
		pDefender.IsDead = pDefender[CombatResultParameters.FINAL_DAMAGE_TO] > pDefender[CombatResultParameters.MAX_HIT_POINTS];
		-- true when the defending unit is dead
		if not pDefender.IsDead then 
			-- player and unit IDs, and XP change for the defender
			local iPlayerID, iUnitID = pDefender[CombatResultParameters.ID].player, pDefender[CombatResultParameters.ID].id;
			local iXP = (pDefender[CombatResultParameters.EXPERIENCE_CHANGE] > 0) and pDefender[CombatResultParameters.EXPERIENCE_CHANGE] or iMinXP;
			-- defending unit data
			local pUnit = Players[iPlayerID]:GetUnits():FindID(iUnitID);
			-- true when defending unit data exists
            if (pUnit ~= nil) then 
                -- defending unit XP data
		    	local pUnitExperience = pUnit:GetExperience();
                -- true when defending unit XP data exists
                if (pUnitExperience ~= nil) then 
	    	    	-- defending unit's current XP and XPFNL
    	    		local iCurrentXP, iXPFNL = pUnitExperience:GetExperiencePoints(), pUnitExperience:GetExperienceForNextLevel();
	    		    -- defending unit's current XP balance and last known current XP total
    		    	local iBalanceXP = (pUnit:GetProperty("XP_BALANCE") ~= nil) and pUnit:GetProperty("XP_BALANCE") or 0;
	    		    local iLastCurrentXP = (pUnit:GetProperty("LAST_CURRENT_XP") ~= nil) and pUnit:GetProperty("LAST_CURRENT_XP") or 0;
                    -- defending unit's new XP balance and amount of XP to be banked
                    local iNewBalanceXP = ((iLastCurrentXP + iXP) > iXPFNL) and iBalanceXP + ((iLastCurrentXP + iXP) - iXPFNL) or iBalanceXP;
                    local iBankXP = (iNewBalanceXP ~= iBalanceXP) and iNewBalanceXP - iBalanceXP or 0;
	    	    	-- reset the defending unit's XP balance and last known current XP total properties to the new values
    	    		pUnit:SetProperty("XP_BALANCE", iNewBalanceXP);
    			    pUnit:SetProperty("LAST_CURRENT_XP", iCurrentXP);
			        -- debugging output
		        	local sPriAttMsg = "Player " .. iPlayerID .. ": Defending Unit " .. iUnitID .. " survived, earning " .. iXP .. " combat experience";
	        		local sSecAttMsg = " (" .. iLastCurrentXP .. " --> " .. iCurrentXP .. " XP / " .. iXPFNL .. " FNL, balance " .. iBalanceXP .. " --> " .. iNewBalanceXP .. " XP)";
        			Dprint(sF, sPriAttMsg .. sSecAttMsg);
                    -- popup text to indicate how much, if any, experience was banked
                    if iBankXP > 0 and Players[iPlayerID]:IsHuman() then 
                        Game.AddWorldViewText(iPlayerID, Locale.Lookup("[COLOR_LIGHTBLUE] + {1_XP} XP stored pending promotion [ENDCOLOR]", iBankXP), iX, iY, 0);
                    end
                end
            end
		end
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
        	-- true when unit has banked XP
    	    if iBalanceXP > 0 then 
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
	        	Dprint(sF, sPriInfoMsg .. sSecInfoMsg .. iNewCurrentXP .. " XP . . . PASS!");
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
    should be defined prior to AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnCombatHook() Events.Combat.Add(OnCombat); end

--[[ =========================================================================
	hook function OnUnitAddedToMapHook()
        hooks OnUnitAddedToMap() to Events.UnitAddedToMap
    should be defined prior to AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitAddedToMapHook() Events.UnitAddedToMap.Add(OnUnitAddedToMap); end

--[[ =========================================================================
	hook function OnUnitRemovedFromMapHook()
        hooks OnUnitRemovedFromMap() to Events.UnitRemovedFromMap
    should be defined prior to AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
-- function OnUnitRemovedFromMapHook() Events.UnitRemovedFromMap.Add(OnUnitRemovedFromMap); end

--[[ =========================================================================
	hook function OnUnitPromotedHook()
        hooks OnUnitPromoted() to Events.UnitPromoted
    should be defined prior to AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitPromotedHook() Events.UnitPromoted.Add(OnUnitPromoted); end

--[[ =========================================================================
	hook function OnUnitUpgradedHook()
        hooks OnUnitUpgraded() to Events.UnitUpgraded
    should be defined prior to AddEventHooks()
	should be defined prior to Initialize()
=========================================================================== ]]
function OnUnitUpgradedHook() Events.UnitUpgraded.Add(OnUnitUpgraded); end

--[[ =========================================================================
	hook function AddEventHooks( sFunction )
        attaches any defined hooks to Events.LoadScreenClose
        prints debugging output to the log file
	should be defined prior to Initialize()
=========================================================================== ]]
function AddEventHooks( sFunction )
    -- debugging header
    sFunction = sFunction .. "():AddEventHooks";
    -- attach listener functions to the appropriate Events with debugging output
    Events.LoadScreenClose.Add(OnUnitAddedToMapHook);
	Dprint(sFunction, "OnUnitAddedToMap() successfully hooked to Events.UnitAddedToMap");
	-- Events.LoadScreenClose.Add(OnUnitRemovedFromMapHook);
	-- Dprint(sFunction, "OnUnitRemovedFromMap() successfully hooked to Events.UnitRemovedFromMap");
	Events.LoadScreenClose.Add(OnUnitPromotedHook);
	Dprint(sFunction, "OnUnitPromoted() successfully hooked to Events.UnitPromoted");
	Events.LoadScreenClose.Add(OnUnitUpgradedHook);
	Dprint(sFunction, "OnUnitUpgraded() successfully hooked to Events.UnitUpgraded");
	Events.LoadScreenClose.Add(OnCombatHook);
	Dprint(sFunction, "OnCombat() successfully hooked to Events.Combat");
end

--[[ =========================================================================
	function Initialize()
        prepare ECEP components
    should be the penultimate definition
=========================================================================== ]]
function Initialize()
    -- debugging header
    local sF = "Initialize";
    -- attach listener functions to the appropriate Events
    AddEventHooks(sF);
end

-- load ECEP
Initialize();

--[[ =========================================================================
	end ECEP.lua gameplay script
=========================================================================== ]]
