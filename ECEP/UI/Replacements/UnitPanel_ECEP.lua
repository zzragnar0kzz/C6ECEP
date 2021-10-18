--[[ =========================================================================
	ECEP : Enhanced Combat Experience and Promotions for Civilization VI
	Copyright (C) 2021 zzragnar0kzz
	All rights reserved
=========================================================================== ]]

--[[ =========================================================================
	begin UnitPanel_ECEP.lua UI script
=========================================================================== ]]

--[[ =========================================================================
	include base game file
=========================================================================== ]]
include("UnitPanel");

--[[ =========================================================================
	store base functions to add to base tables
=========================================================================== ]]
local BASE_InitSubjectData = InitSubjectData;
local BASE_ReadCustomUnitStats = ReadCustomUnitStats;
local BASE_View = View;

--[[ =========================================================================
	OVERRIDE: call base to get values, then ECEP specific custom fields
=========================================================================== ]]
function InitSubjectData()
	local kSubjectData:table = BASE_InitSubjectData();
	kSubjectData.ExperienceBalance = 0;
	return kSubjectData;	
end

--[[ =========================================================================
	OVERRIDE: call base to get values, then ECEP specific custom fields
=========================================================================== ]]
function ReadCustomUnitStats( pUnit:table, kSubjectData:table )	
	kSubjectData = BASE_ReadCustomUnitStats(pUnit, kSubjectData );
	local iXPBalance = pUnit:GetProperty("XP_BALANCE");
	if iXPBalance == nil then 
		iXPBalance = 0;
		-- pUnit:SetProperty("XP_BALANCE", iXPBalance);
	end
	kSubjectData.ExperienceBalance = iXPBalance;
	return kSubjectData;
end

--[[ =========================================================================
	OVERRIDE: call base to set values, then ECEP specific custom fields
=========================================================================== ]]
function View( data )
	BASE_View(data);
	-- populate Earned Promotions UI, including any banked experience
	if (not UILens.IsLensActive("Religion") and data.Combat > 0 and data.MaxExperience > 0) then
		local sTooltip = Locale.Lookup("LOC_HUD_UNIT_PANEL_XP_TT", data.UnitExperience, data.MaxExperience, data.UnitLevel + 1);
		if data.ExperienceBalance > 0 then sTooltip = sTooltip .. ", with " .. data.ExperienceBalance .. " stored pending promotion"; end
		Controls.XPArea:SetHide(false);
		Controls.XPBar:SetPercent( data.UnitExperience / data.MaxExperience );
		Controls.XPArea:SetToolTipString(sTooltip);
    else
		Controls.XPArea:SetHide(true);
	end
end

--[[ =========================================================================
    end UnitPanel_ECEP.lua UI script
=========================================================================== ]]
