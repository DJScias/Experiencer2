------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("honor", {
	label       = "Honor",
	order       = 4,
	active      = true,
	savedvars   = {
		global = {
			ShowHonorLevel  = true,
			ShowPrestige    = true,
			ShowRemaining   = true
		},
	},
});

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

function module:Initialize()
	self:RegisterEvent("HONOR_XP_UPDATE");
	self:RegisterEvent("HONOR_LEVEL_UPDATE");
end

function module:IsDisabled()
	return not C_PvP.CanDisplayHonorableKills();
end

function module:AllowedToBufferUpdate()
	return true;
end

function module:Update(elapsed)
	
end

function module:OnMouseDown(button)
	
end

function module:CanLevelUp()
	return false;
end

function module:GetText()
	local primaryText = {};

	local honorlevel 	    = UnitHonorLevel("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;

	local progress          = honor / (honormax > 0 and honormax or 1);
	local progressColor     = Addon:GetProgressColor(progress);

	local globalDB = self.db.global;
	if(globalDB.ShowHonorLevel) then
		tinsert(primaryText, 
			("|cffffd200Honor Level|r %d"):format(honorlevel)
		);
	end

	if(globalDB.ShowRemaining) then
		tinsert(primaryText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(honor), BreakUpLargeNumbers(honormax), progressColor, progress * 100)
		);
	end

	return table.concat(primaryText, "  "), nil;
end

function module:HasChatMessage()
	return true, "Derp.";
end

function module:GetChatMessage()
	local level 	        = UnitHonorLevel("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;

	local progress    = honor / (honormax > 0 and honormax or 1);
	local levelText   = ("Currently honor level %d"):format(level);

	return ("%s at %s/%s (%d%%) with %s to go"):format(
		levelText,
		BreakUpLargeNumbers(honor),
		BreakUpLargeNumbers(honormax),
		math.ceil(progress * 100),
		BreakUpLargeNumbers(remaining)
	);
end

function module:GetBarData()
	local level 	        = UnitHonorLevel("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;

	local progress  = honor / (honormax > 0 and honormax or 1);
	local progressColor = Addon:GetProgressColor(progress);

	local data = {
		id      = nil,
		level   = level,
		min     = 0,
		max     = honormax,
		current = honor,
		visual  = nil
	};

	return data;
end

function module:GetOptionsMenu(currentMenu)
	local globalDB = self.db.global;

	currentMenu:CreateTitle("Honor Options");
	currentMenu:CreateRadio("Show remaining honor", 
		function() return globalDB.ShowRemaining == true end,
		function()
			globalDB.ShowRemaining = true;
			module:RefreshText();
		end
	):SetResponse(MenuResponse.Refresh);

	currentMenu:CreateRadio("Show current and max honor",
		function() return globalDB.ShowRemaining == false end,
		function()
			globalDB.ShowRemaining = false;
			module:RefreshText();
		end
	):SetResponse(MenuResponse.Refresh);

	currentMenu:CreateDivider();

	currentMenu:CreateCheckbox("Show honor level",
		function() return globalDB.ShowHonorLevel end,
		function()
			globalDB.ShowHonorLevel = not globalDB.ShowHonorLevel;
			module:RefreshText();
		end
	);
end

------------------------------------------

function module:HONOR_XP_UPDATE()
	module:Refresh();
end

function module:HONOR_LEVEL_UPDATE()
	module:Refresh();
end
