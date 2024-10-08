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
	active      = false,
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
	return not PlayerGetTimerunningSeasonID() or not module.hasCloak or not module.ready;
end

function module:PLAYER_LOGIN()
	-- Necessary for first time to wait with querying Threads until API is ready.
	-- This function ensures we receive a valid thread count at login.

	module:GetCloakInfo(true)
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
end


function module:OnMouseDown(_)

end

function module:CanLevelUp()
	return false;
end

function module:GetText()
    if module:IsDisabled() then
        return "No cloak";
    end

    local primaryText = {};
    local secondaryText = {};

    local threads, cloakLevel, cloakNext, cloakLevelText = module:GetCloakInfo(false);

    local remaining = cloakNext - threads;
    local progress = threads / cloakNext;
    local progressColor = Addon:GetProgressColor(progress);

    if cloakLevel == 12 then
        progressColor = Addon:FinishedProgressColor();
    end

	local globalDB = self.db.global;
    if globalDB.ShowCloakLevel then
        tinsert(primaryText,
            ("|cffffd200Cloak Level|r %s"):format(cloakLevelText)
        );
    end

    if cloakLevel == 12 then
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
    local threads, _, cloakNext, cloakLevelText = module:GetCloakInfo(false);
    local remaining = cloakNext - threads;

    local progress = threads / cloakNext;
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
        data.current, data.level, data.max = module:GetCloakInfo(false);
    end

    return data;
end

function module:GetOptionsMenu(currentMenu)
    local globalDB = self.db.global;  -- Cache self.db.global to globalDB

    currentMenu:CreateTitle("Cloak Thread Options");

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

    currentMenu:CreateDivider();

    currentMenu:CreateCheckbox("Show cloak level",
        function() return globalDB.ShowCloakLevel; end,
        function()
            globalDB.ShowCloakLevel = not globalDB.ShowCloakLevel;
            module:RefreshText();
        end
    );
end

------------------------------------------

function module:CURRENCY_DISPLAY_UPDATE(_, currencyType, _, quantityChange)
    if not currencyType then return; end

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

function module:GetCloakInfo(isInitialLogin)
    local c = {0, 1, 2, 3, 4, 5, 6, 7, 148};
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
    };

    for i, v in ipairs(levels) do
        if GATHERED_THREADS > v.threshold then
            cloakLevelText = v.text;
            cloakLevel = v.level;
            cloakNext = levels[i - 1] and levels[i - 1].threshold or GATHERED_THREADS;
            break;
        end
    end

    if isInitialLogin then
        module.ready = true;
    end

    return GATHERED_THREADS, cloakLevel, cloakNext, cloakLevelText;
end
