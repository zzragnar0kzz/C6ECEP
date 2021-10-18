--[[ =========================================================================
	ECEP : Enhanced Combat Experience and Promotions for Civilization VI
	Copyright (C) 2021 zzragnar0kzz
	All rights reserved
=========================================================================== ]]

--[[ =========================================================================
	begin UnitPanel_ECEP_Expansion2.lua UI script
=========================================================================== ]]

--[[ =========================================================================
	include ECEP XP1 file
=========================================================================== ]]
include("UnitPanel_ECEP_Expansion1");

--[[ =========================================================================
	store base functions to add to base tables
=========================================================================== ]]
local BASE_InitSubjectData = InitSubjectData;
local BASE_GetBuildImprovementParameters = GetBuildImprovementParameters;
local BASE_ReadCustomUnitStats = ReadCustomUnitStats;
local Base_RealizeSpecializedViews = RealizeSpecializedViews;
local BASE_FilterUnitStatsFromUnitData = FilterUnitStatsFromUnitData;
local BASE_LateCheckOperationBeforeAdd = LateCheckOperationBeforeAdd;

--[[ =========================================================================
	OVERRIDE: call base to get values, then XP2 and ECEP specific custom fields
=========================================================================== ]]
function InitSubjectData()
	local kSubjectData:table = BASE_InitSubjectData();
	kSubjectData.RockBandLevel	= -1;
	kSubjectData.AlbumSales		= 0;	
	kSubjectData.IsRockbandUnit	= false;
	kSubjectData.ExperienceBalance = 0;
	return kSubjectData;	
end

--[[ =========================================================================
	OVERRIDE: call base to get values, then XP2 and ECEP specific custom fields
=========================================================================== ]]
function ReadCustomUnitStats( pUnit:table, kSubjectData:table )	
	kSubjectData = BASE_ReadCustomUnitStats(pUnit, kSubjectData );
	local iXPBalance = pUnit:GetProperty("XP_BALANCE");
	if iXPBalance == nil then 
		iXPBalance = 0;
		-- pUnit:SetProperty("XP_BALANCE", iXPBalance);
	end
	kSubjectData.ExperienceBalance = iXPBalance;
	if GameInfo.Units[kSubjectData.UnitType].UnitType == "UNIT_ROCK_BAND" then 
		kSubjectData.IsRockbandUnit = true;
		kSubjectData.RockBandLevel	= pUnit:GetRockBand():GetRockBandLevel();
		kSubjectData.AlbumSales		= pUnit:GetRockBand():GetAlbumSales();
	end
	return kSubjectData;
end

-- remainder of script is ganked wholesale from UnitPanel_Expansion2.lua, and is unmodified from the source

-- ===========================================================================
--	OVERRIDE
--	Is this hash representing an improvement to be built?
-- ===========================================================================
function IsBuildingImprovement( actionHash:number )
	return (actionHash == UnitOperationTypes.BUILD_IMPROVEMENT 
	  	or actionHash == UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT);
end

-- ===========================================================================
--	OVERRIDE
--	Obtain the parameters for a building improvement.
--	actionHash, the hash of the type of the operation type
--	pUnit, the unit doing the operation
-- ===========================================================================
function GetBuildImprovementParameters(actionHash, pUnit)
	if actionHash == UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT then
		return {};	-- no parameters
	end
	return BASE_GetBuildImprovementParameters(actionHash, pUnit);
end

-- ===========================================================================
--	OVERRIDE
--	Returns: Callback function, Disabled state
-- ===========================================================================
function GetBuildImprovementCallback( actionHash :number, isDisabledIn:boolean )
	local callbackFn	:ifunction = OnUnitActionClicked_BuildImprovement;
	local isDisabled	:boolean = isDisabledIn;
	if (actionHash == UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT) then
		callbackFn = OnUnitActionClicked_BuildImprovementAdjacent;
		isDisabledModified = false;
	else
		callbackFn = OnUnitActionClicked_BuildImprovement;
		isDisabledModified = isDisabled;
	end
	return callbackFn, isDisabledModified;
end

-- ===========================================================================
function AddUpgradeResourceCost( pUnit:table )
	local toolTipString:string = "";
	if (GameInfo.Units_XP2~= nil) then
		local upgradeResource, upgradeResourceCost = pUnit:GetUpgradeResourceCost();
		if (upgradeResource ~= nil and upgradeResource >= 0) then
			local resourceName:string = Locale.Lookup(GameInfo.Resources[upgradeResource].Name);
			local resourceIcon = "[ICON_" .. GameInfo.Resources[upgradeResource].ResourceType .. "]";
			toolTipString = "[NEWLINE]" .. Locale.Lookup("LOC_UNITOPERATION_UPGRADE_RESOURCE_INFO", upgradeResourceCost, resourceIcon, resourceName)
		end
	end
	return toolTipString;
end

-- ===========================================================================
-- UnitAction<BuildImprovementAdjacent> was clicked.
-- ===========================================================================
function OnUnitActionClicked_BuildImprovementAdjacent( improvementHash, dummy )
	if (g_isOkayToProcess) then
		local pSelectedUnit = UI.GetHeadSelectedUnit();
		if (pSelectedUnit ~= nil) then
			local tParameters = {};
			tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash;
			tParameters[UnitOperationTypes.PARAM_OPERATION_TYPE] = UnitOperationTypes.BUILD_IMPROVEMENT_ADJACENT;
			UI.SetInterfaceMode(InterfaceModeTypes.BUILD_IMPROVEMENT_ADJACENT, tParameters);
		end
		ContextPtr:RequestRefresh();
	end
end

-- ===========================================================================
function RockbandView( kData:table )
	if kData.IsRockbandUnit == false then return; end
	-- TODO: populate with rock band information if using a custom view (may want to remove stats data entries)
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function FilterUnitStatsFromUnitData( kUnitData:table, ignoreStatType:number )
	local kData:table= BASE_FilterUnitStatsFromUnitData( kUnitData, ignoreStatType );

	if kUnitData.IsRockbandUnit then 
		table.insert(kData, {Value = kUnitData.AlbumSales,		Type = "ActionCharges",	Label = "LOC_HUD_UNIT_PANEL_ROCK_BAND_ALBUM_SALES",	FontIcon="[ICON_Charges_Large]",		IconName="ICON_STAT_RECORD_SALES"});
		table.insert(kData, {Value = kUnitData.RockBandLevel,	Type = "SpreadCharges", Label = "LOC_HUD_UNIT_PANEL_ROCK_BAND_LEVEL",		FontIcon="[ICON_ReligionStat_Large]",	IconName="ICON_STAT_ROCKBAND_LEVEL"});
	end

	local pPlayer : table = Players[kUnitData.Owner];
	if (pPlayer ~= nil) then
		local pUnit : table = pPlayer:GetUnits():FindID(kUnitData.UnitID);
		if(GameInfo.Units[pUnit:GetUnitType()].ParkCharges > 0)then
			table.insert(kData, {Value = pUnit:GetParkCharges(), Type = "ParkCharges", Label = "LOC_HUD_UNIT_PANEL_PARK_CHARGES", FontIcon = "[ICON_Charges_Large]", IconName = "ICON_BUILD_CHARGES"});
		end
	end

	return kData;
end

-- ===========================================================================
function RealizeSpecializedViews( kData:table )
	Base_RealizeSpecializedViews(kData);
	RockbandView(kData);
end

-- ===========================================================================
-- Override the unit operation icon for XP2 railroads.
-- ===========================================================================
function LateCheckOperationBeforeAdd( tResults: table, kActionsTable: table, actionHash:number, isDisabled:boolean, tooltipString:string, overrideIcon:string )
	if (tResults[UnitOperationResults.ROUTE_TYPE] ~= nil and tResults[UnitOperationResults.ROUTE_TYPE] == "ROUTE_RAILROAD") then
		overrideIcon = "ICON_ROUTE_RAILROAD";
		return isDisabled, tooltipString, overrideIcon;
	end

	-- Not a railroad, fall through to the base version.
	return BASE_LateCheckOperationBeforeAdd( tResults, kActionsTable, actionHash, isDisabled, tooltipString, overrideIcon );
end

--[[ =========================================================================
    end UnitPanel_ECEP_Expansion2.lua UI script
=========================================================================== ]]
