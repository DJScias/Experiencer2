------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("threads", {
	label       = "Threads",
	order       = 6,
	active      = true,
	savedvars   = {
		char = {
			session = {
				Exists = false,
				Time = 0,
				TotalThreads = 0,
			},
			persist = {
				CurrentThreads = 0,
			}
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

module.isMoPRemix = false;
module.isLERemix = false;
module.hasCloak = true;
module.ready = false;

local GATHERED_THREADS = 0;
local CLOAK_OF_INFINITE_POTENTIAL_ITEM_ID = 210333;

function module:Initialize()
	self:RegisterEvent("UNIT_AURA");
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	self:RegisterEvent("PLAYER_LOGIN");

	self.label = module:GetLabel();

	if module.isMoPRemix then
		C_Timer.After(4, function()
			self:RegisterEvent("UNIT_INVENTORY_CHANGED");
			module:UpdateHasCloak();
		end);
	end

	module:RestoreSession();
end

function module:IsDisabled()
	if not module.isLERemix or (module.isMoPRemix and not module.hasCloak) then
		return true;
	end

	return false;
end

function module:GetLabel()
	if module.isMoPRemix then
		return "Cloak Threads";
	elseif module.isLERemix then
		return self.label;
	end
end

function module:GetLevelSource()
	if module.isMoPRemix then
		return "Cloak";
	elseif module.isLERemix then
		return "Infinite Power";
	end
end

function module:PLAYER_LOGIN()
	-- Necessary for first time to wait with querying Threads until API is ready.
	-- This function ensures we receive a valid thread count at login.

	module.isMoPRemix = (PlayerGetTimerunningSeasonID() == 1);
	module.isLERemix = (PlayerGetTimerunningSeasonID() == 2);

	if module.isMoPRemix or module.isLERemix then
		module:GetThreadInfo(true);
		module:Refresh();
	end
end

function module:UNIT_INVENTORY_CHANGED(_, unit)
	if unit ~= "player" then
		return;
	end

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

function module:Update(_)
    local globalDB = self.db and self.db.global;

    if not globalDB then return end;

	if globalDB.KeepSessionData then
        local charSession = self.db.char.session;
		local session = self.session;
        charSession.Exists = true;
        charSession.Time = time() - session.LoginTime;
        charSession.TotalThreads = session.GainedThreads;
    end;

	local charPersist = self.db.char.persist;
	charPersist.CurrentThreads = GATHERED_THREADS;
end

function module:OnMouseDown(_)

end

function module:CanLevelUp()
	return false;
end

function module:GetText()
    if module:IsDisabled() then
        return "No Remix";
    end

    local primaryText = {};
    local secondaryText = {};

    local threads, cloakLevel, cloakNext, cloakLevelText = module:GetThreadInfo(false);

    local remaining, progress, progressColor;

	remaining = cloakNext - threads;
	progress = threads / cloakNext;
	progressColor = Addon:GetProgressColor(progress);

    if module.isLERemix or cloakLevel == 12 then
        progressColor = Addon:FinishedProgressColor();
    end

	local globalDB = self.db.global;
    if globalDB.ShowCloakLevel and module.isMoPRemix then
        tinsert(primaryText,
            ("|cffffd200Cloak Level|r %s"):format(cloakLevelText)
        );
    end

    if module.isLERemix or cloakLevel == 12 then
        tinsert(primaryText,
            ("%s%s|r"):format(progressColor, BreakUpLargeNumbers(threads))
        );
    else
        if globalDB.ShowRemaining then
            tinsert(primaryText,
                ("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
            );
        else
            tinsert(primaryText,
                ("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(threads), BreakUpLargeNumbers(cloakNext), progressColor, progress * 100)
            );
        end
    end

    if module.session.GainedThreads > 0 then
        if globalDB.ShowedGainedThreads then
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
    local threads, _, cloakNext, cloakLevelText = module:GetThreadInfo(false);
    local remaining = cloakNext - threads;

    local progress = threads / cloakNext;
    local leveltext = ("Currently %s level %s"):format(module:GetLevelSource(), cloakLevelText);

    return ("%s at %s/%s (%d%%) with %s to go"):format(
        leveltext,
        BreakUpLargeNumbers(threads),
        BreakUpLargeNumbers(cloakNext),
        math.ceil(progress * 100),
        BreakUpLargeNumbers(remaining)
    );
end

function module:GetBarData()
    local data = {
        id = nil,
        level = 0,
        min = 0,
        max = 1,
        current = 0,
        rested = nil,
        visual = nil
    };

    if not module:IsDisabled() then
		data.current, data.level, data.max = module:GetThreadInfo(false);
    end

    return data;
end

function module:GetOptionsMenu(currentMenu)
    local globalDB = self.db.global;  -- Cache self.db.global to globalDB

    currentMenu:CreateTitle(module:GetLabel() .. " Options");

    currentMenu:CreateRadio("Show remaining threads",
        function() return globalDB.ShowRemaining == true; end,
        function()
            globalDB.ShowRemaining = true;
            module:RefreshText();
        end
    ):SetResponse(MenuResponse.Refresh);

    currentMenu:CreateRadio("Show current and max threads",
        function() return globalDB.ShowRemaining == false; end,
        function()
            globalDB.ShowRemaining = false;
            module:RefreshText();
        end
    ):SetResponse(MenuResponse.Refresh);

    currentMenu:CreateDivider();

    currentMenu:CreateCheckbox("Show gained threads",
        function() return globalDB.ShowedGainedThreads; end,
        function()
            globalDB.ShowedGainedThreads = not globalDB.ShowedGainedThreads;
            module:RefreshText();
        end
    );

    currentMenu:CreateDivider();

    currentMenu:CreateCheckbox("Remember session data",
        function() return globalDB.KeepSessionData; end,
        function()
            globalDB.KeepSessionData = not globalDB.KeepSessionData;
        end
    );

    currentMenu:CreateButton("Reset session",
        function()
            module:ResetSession();
        end
    ):SetResponse(MenuResponse.Refresh);

	if module.isMoPRemix then
		currentMenu:CreateDivider();

		currentMenu:CreateCheckbox("Show cloak level",
			function() return globalDB.ShowCloakLevel; end,
			function()
				globalDB.ShowCloakLevel = not globalDB.ShowCloakLevel;
				module:RefreshText();
			end
		);
	end
end

------------------------------------------

local firstRun = true;

function module:UNIT_AURA(_, unitTarget, updateInfo)
	if unitTarget ~= "player" or not module.isLERemix then
		return;
	end

	if updateInfo.updatedAuraInstanceIDs then
		for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
			local auraInfo = C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID);

			if auraInfo and auraInfo.spellId == 1232454 then
				local threads = 0;
				for i = 1,16 do
					local stat = auraInfo.points[i];
					threads = threads + stat;
				end
				local threadsChange = threads - GATHERED_THREADS;
				GATHERED_THREADS = threads;
				if not firstRun then
					module.session.GainedThreads = module.session.GainedThreads + threadsChange;
				end
				firstRun = false;
				module:Refresh();
				return;
			end
		end
	end
end

function module:CURRENCY_DISPLAY_UPDATE(_, currencyType, _, quantityChange)
    if not module.ready or not currencyType or module.isLERemix then return; end

    if currencyType == 3001 or (currencyType >= 2853 and currencyType <= 2860) then
        -- We set a 0.5 timer as the cloak needs a small bit of time to update its values.
        C_Timer.After(0.5, function()
            module.session.GainedThreads = module.session.GainedThreads + quantityChange;
            module:Refresh();
        end);
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

function module:GetThreadInfo(isInitialLogin)
    local level = 0;
    local levelText = "0";
    local nextLevel = 40;

	if module.isLERemix then
		level = 1;
		nextLevel = 1;
	end

	local threads = 0;
	local aura, maxPoints;
	if module.isMoPRemix then
		aura = C_UnitAuras.GetPlayerAuraBySpellID(440393) -- MoP Remix
		maxPoints = 9;
	elseif module.isLERemix then
		aura = C_UnitAuras.GetPlayerAuraBySpellID(1232454) -- Legion Remix
		maxPoints = 16;
	end

	if aura then
		for i = 1, maxPoints do
			threads = threads + aura.points[i];
		end
	end

	local charPersist = self.db.char.persist;
	if charPersist.CurrentThreads and charPersist.CurrentThreads > 0 and threads == 0 then
		threads = charPersist.CurrentThreads;
	end

    GATHERED_THREADS = threads;

	if module.isMoPRemix then
		local cloakLevels = {
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
		};

		for i, v in ipairs(cloakLevels) do
			if GATHERED_THREADS > v.threshold then
				levelText = v.text;
				level = v.level;
				nextLevel = cloakLevels[i - 1] and cloakLevels[i - 1].threshold or GATHERED_THREADS;
				break;
			end
		end
	end

    if isInitialLogin then
        module.ready = true;
    end

	return GATHERED_THREADS, level, nextLevel, levelText;
end
