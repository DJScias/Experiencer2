------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("threads", {
	label       = "Cloak Threads",
	order       = 6,
	savedvars   = {
		char = {
			session = {
				Exists = false,
				Time = 0,
				TotalThreads = 0,
			},
		},
		global = {
			ShowRemaining  		= true,
			ShowedGainedThreads = true,
			ShowCloakLevel 		= true,
			KeepSessionData     = true
		},
	},
});

module.session = {
	LoginTime       = time(),
	GainedThreads   = 0,
};

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

module.hasCloak = true;
module.ready = false;

local GATHERED_THREADS = 0;
local CLOAK_OF_INFINITE_POTENTIAL_ITEM_ID = 210333;

function module:Initialize()
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	self:RegisterEvent("PLAYER_LOGIN");

	C_Timer.After(4, function()
		self:RegisterEvent("UNIT_INVENTORY_CHANGED");
		module:UpdateHasCloak();
	end);

	module:RestoreSession();
end

function module:IsDisabled()
	return not module.hasCloak or not module.ready;
end

function module:PLAYER_LOGIN(event)
	-- Necessary for first time to wait with querying Threads until API is ready.
	-- This function ensures we receive a valid thread count at login.

	module:GetCloakInfo(true)
end

function module:UNIT_INVENTORY_CHANGED(event, unit)
	if (unit ~= "player") then return end;

	module:UpdateHasCloak();
end

function module:UpdateHasCloak()
    local itemId = GetInventoryItemID("player", 15);

    module.hasCloak = (itemId == CLOAK_OF_INFINITE_POTENTIAL_ITEM_ID);
    module:Refresh(true);
end


function module:AllowedToBufferUpdate()
	return true;
end

function module:Update(elapsed)
    if not self.db then return end;

    if self.db.global.KeepSessionData then
        local session = self.db.char.session;
        session.Exists = true;
        session.Time = time() - self.session.LoginTime;
        session.TotalThreads = self.session.GainedThreads;
    end;
end


function module:OnMouseDown(button)
	
end

function module:CanLevelUp()
	return false;
end

function module:GetText()
	if (module:IsDisabled()) then
		return "No cloak";
	end

	local primaryText 										= {};
	local secondaryText 									= {};

	local threads, cloakLevel, cloakLevelText, cloakNext	= module:GetCloakInfo(false);

	local remaining         								= cloakNext - threads;
			
	local progress          								= threads / cloakNext;
	local progressColor     								= Addon:GetProgressColor(progress);
	if cloakLevel == 12 then
		progressColor = Addon:FinishedProgressColor();
	end

	if(self.db.global.ShowCloakLevel) then
		tinsert(primaryText, 
			("|cffffd200Cloak Level|r %s"):format(cloakLevelText)
		);
	end

	if cloakLevel == 12 then
		tinsert(primaryText,
			("%s%s|r"):format(progressColor, BreakUpLargeNumbers(threads))
		);
	else
		if(self.db.global.ShowRemaining) then
			tinsert(primaryText,
				("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
			);
		else
			tinsert(primaryText,
				("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(threads), BreakUpLargeNumbers(cloakNext), progressColor, progress * 100)
			);
		end
	end
	
	if (module.session.GainedThreads > 0) then
		if (self.db.global.ShowedGainedThreads) then
			tinsert(secondaryText,
				string.format("+%s |cffffcc00threads|r", BreakUpLargeNumbers(module.session.GainedThreads))
			);
		end
	end
	
	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return true, "Derp.";
end

function module:GetChatMessage()
	local threads, _, cloakLevelText, cloakNext	= module:GetCloakInfo(false);
	local remaining         					= cloakNext - threads;
					
	local progress          					= threads / cloakNext;

	local leveltext = ("Currently cloak level %s"):format(cloakLevelText);
		
	return ("%s at %s/%s (%d%%) with %s to go"):format(
		leveltext,
		BreakUpLargeNumbers(threads),
		BreakUpLargeNumbers(cloakNext),
		math.ceil(progress * 100),
		BreakUpLargeNumbers(remaining)
	);
end

function module:GetBarData()
	local data    = {};
	data.id       = nil;
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;

	if (not module:IsDisabled()) then
		data.current, data.level, _, data.max = module:GetCloakInfo(false);
	end
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Cloak Thread Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining threads",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max threads",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show gained threads",
			func = function() self.db.global.ShowedGainedThreads = not self.db.global.ShowedGainedThreads; module:RefreshText(); end,
			checked = function() return self.db.global.ShowedGainedThreads; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Remember session data",
			func = function() self.db.global.KeepSessionData = not self.db.global.KeepSessionData; end,
			checked = function() return self.db.global.KeepSessionData; end,
			isNotRadio = true,
		},
		{
			text = "Reset session",
			func = function()
				module:ResetSession();
			end,
			notCheckable = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show cloak level",
			func = function() self.db.global.ShowCloakLevel = not self.db.global.ShowCloakLevel; module:RefreshText(); end,
			checked = function() return self.db.global.ShowCloakLevel; end,
			isNotRadio = true,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:CURRENCY_DISPLAY_UPDATE(event, currencyType, _, quantityChange)
	if not currencyType then return end;

	if currencyType == 3001 or (currencyType >= 2853 and currencyType <= 2860) then
		-- We set a 0.5 timer as the cloak needs a small bit of time to update its values.
		C_Timer.After(0.5, function()
			module.session.GainedThreads = module.session.GainedThreads + quantityChange;
			module:Refresh();
		end)
	end
end

function module:RestoreSession()
    if not self.db.char.session.Exists or not self.db.global.KeepSessionData then return end;

    local data = self.db.char.session;
    
    module.session.LoginTime 		= module.session.LoginTime - data.Time;
    module.session.GainedThreads 	= data.TotalThreads;
end


function module:ResetSession()
	module.session = {
		LoginTime		 = time(),
		GainedThreads    = 0,
	};
	
	self.db.char.session = {
		Exists           = false,
		Time             = 0,
		TotalThreads     = 0,
	};
	
	module:RefreshText();
end

function module:GetCloakInfo(isInitialLogin)
	local c = {0,1,2,3,4,5,6,7,148};
	local threads = 0;
	local cloakLevel = 0;
	local cloakLevelText = "0";
	local cloakNext = 40;

	for i = 1, #c do
		threads = threads + C_CurrencyInfo.GetCurrencyInfo(2853 + c[i]).quantity;
	end
	GATHERED_THREADS = threads;
	
	local levels = {
		{threshold = 4200, text = "XII", level = 12},
		{threshold = 2200, text = "XI", level = 11},
		{threshold = 700, text = "X", level = 10},
		{threshold = 600, text = "IX", level = 9},
		{threshold = 500, text = "VIII", level = 8},
		{threshold = 400, text = "VII", level = 7},
		{threshold = 300, text = "VI", level = 6},
		{threshold = 250, text = "V", level = 5},
		{threshold = 200, text = "IV", level = 4},
		{threshold = 150, text = "III", level = 3},
		{threshold = 100, text = "II", level = 2},
		{threshold = 40, text = "I", level = 1},
	}
	
	for i, v in ipairs(levels) do
		if GATHERED_THREADS > v.threshold then
			cloakLevelText = v.text
			cloakLevel = v.level
			cloakNext = levels[i - 1] and levels[i - 1].threshold or GATHERED_THREADS
			break
		end
	end

	if isInitialLogin then
		module.ready = true;
	end

	return GATHERED_THREADS, cloakLevel, cloakLevelText, cloakNext;
end
