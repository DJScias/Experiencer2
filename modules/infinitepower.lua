------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("infinitepower", {
	label       = "Infinite Power",
	order       = 7,
	active      = true,
	savedvars   = {
		char = {
			session = {
				Exists = false,
				Time = 0,
				TotalInfinitePower = 0,
			},
			persist = {
				CurrentInfinitePower = 0,
			}
		},
		global = {
			ShowRemaining  		= true,
			ShowedGainedInfinitePower = true,
			ShowInfinitePowerLevel 		= true,
			KeepSessionData     = true
		},
	},
});

module.session = {
	LoginTime       = time(),
	GainedInfinitePower   = 0,
};

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

module.isLERemix = false;
module.ready = false;

local GATHERED_INFINITE_POWER = 0;
local CLOAK_OF_INFINITE_POTENTIAL_ITEM_ID = 210333;
local LAST_CONFIG_ID = nil;

function module:Initialize()
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	self:RegisterEvent("PLAYER_LOGIN");

	module:RestoreSession();
end

function module:IsDisabled()
	if not module.isLERemix then
		return true;
	end
	return false;
end

function module:PLAYER_LOGIN()
	module.isLERemix = (PlayerGetTimerunningSeasonID() == 2);

	if module.isLERemix then
		module:GetPowerInfo(true);
		module:Refresh();
	end
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
        charSession.TotalInfinitePower = session.GainedInfinitePower;
    end;

	local charPersist = self.db.char.persist;
	charPersist.CurrentInfinitePower = GATHERED_INFINITE_POWER;
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

    local currentIP, level, nextLevel, levelText = module:GetPowerInfo(false);

    local remaining, progress, progressColor;

	remaining = nextLevel - currentIP;
	progress = currentIP / nextLevel;

	progressColor = Addon:GetProgressColor(progress);

    if level == 12 then
        progressColor = Addon:FinishedProgressColor();
    end

	local globalDB = self.db.global;
    if globalDB.ShowInfinitePowerLevel then
        tinsert(primaryText,
            ("|cffffd200Unlimited Power Level|r %s"):format(levelText)
        );
    end

	if globalDB.ShowRemaining then
		tinsert(primaryText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(currentIP), BreakUpLargeNumbers(nextLevel), progressColor, progress * 100)
		);
	end

    if module.session.GainedInfinitePower > 0 then
        if globalDB.ShowedGainedInfinitePower then
            tinsert(secondaryText,
                string.format("+%s |cffffcc00Infinite Power|r", BreakUpLargeNumbers(module.session.GainedInfinitePower))
            );
        end
    end

	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return true, "Derp.";
end

function module:GetChatMessage()
    local threads, _, nextLevvel, levelText = module:GetPowerInfo(false);
    local remaining = nextLevvel - threads;

    local progress = threads / nextLevvel;
    local leveltext = ("Currently Unlimited Power level %s"):format(levelText);

    return ("%s at %s/%s (%d%%) with %s to go"):format(
        leveltext,
        BreakUpLargeNumbers(threads),
        BreakUpLargeNumbers(nextLevvel),
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
		local currentIP, level, nextLevel = module:GetPowerInfo(false);
		data.current = currentIP;
		data.level = level;
		data.max = nextLevel;
    end

    return data;
end

function module:GetOptionsMenu(currentMenu)
    local globalDB = self.db.global;  -- Cache self.db.global to globalDB

    currentMenu:CreateTitle("Infinite Power Options");

    currentMenu:CreateRadio("Show remaining Infinite Power",
        function() return globalDB.ShowRemaining == true; end,
        function()
            globalDB.ShowRemaining = true;
            module:RefreshText();
        end
    ):SetResponse(MenuResponse.Refresh);

    currentMenu:CreateRadio("Show current and max Infinite Power",
        function() return globalDB.ShowRemaining == false; end,
        function()
            globalDB.ShowRemaining = false;
            module:RefreshText();
        end
    ):SetResponse(MenuResponse.Refresh);

    currentMenu:CreateDivider();

    currentMenu:CreateCheckbox("Show gained Infinite Power",
        function() return globalDB.ShowedGainedInfinitePower; end,
        function()
            globalDB.ShowedGainedInfinitePower = not globalDB.ShowedGainedInfinitePower;
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

	currentMenu:CreateCheckbox("Show Unlimited Power level",
		function() return globalDB.ShowInfinitePowerLevel; end,
		function()
			globalDB.ShowInfinitePowerLevel = not globalDB.ShowInfinitePowerLevel;
			module:RefreshText();
		end
	);
end

------------------------------------------

function module:CURRENCY_DISPLAY_UPDATE(_, currencyType, _, quantityChange)
    if not module.ready or not currencyType then return; end

    if currencyType == 3268 then
        C_Timer.After(0.5, function()
            module.session.GainedInfinitePower = module.session.GainedInfinitePower + quantityChange;
            module:Refresh();
        end);
    end
end

function module:RestoreSession()
    if not self.db.char.session.Exists or not self.db.global.KeepSessionData then return end;

    local data = self.db.char.session;

    module.session.LoginTime 		= module.session.LoginTime - data.Time;
    module.session.GainedInfinitePower 	= data.TotalInfinitePower;
end

function module:ResetSession()
	module.session = {
		LoginTime		 = time(),
		GainedInfinitePower    = 0,
	};

	self.db.char.session = {
		Exists             = false,
		Time               = 0,
		TotalInfinitePower = 0,
	};

	module:RefreshText();
end

function module:GetPowerInfo(isInitialLogin)
    local level = 0;
    local levelText = "0";
    local nextLevel = 10000;

	local levels = {
		{threshold = 5000000, text = "XII", level = 12},
		{threshold = 3000000, text = "XI", level = 11},
		{threshold = 2000000, text = "X", level = 10},
		{threshold = 1500000, text = "IX", level = 9},
		{threshold = 1250000, text = "VIII", level = 8},
		{threshold = 1000000, text = "VII", level = 7},
		{threshold = 750000, text = "VI", level = 6},
		{threshold = 500000, text = "V", level = 5},
		{threshold = 250000, text = "IV", level = 4},
		{threshold = 100000, text = "III", level = 3},
		{threshold = 50000, text = "II", level = 2},
		{threshold = 10000, text = "I", level = 1},
	};

	local traitTreeID = C_RemixArtifactUI.GetCurrTraitTreeID() or 1161;
	local configID = traitTreeID and C_Traits.GetConfigIDByTreeID(traitTreeID);
	if configID then
		if not LAST_CONFIG_ID or configID ~= LAST_CONFIG_ID then
			LAST_CONFIG_ID = configID;
		end
	elseif not configID and LAST_CONFIG_ID then
		configID = LAST_CONFIG_ID;
	end
	local configInfo = C_Traits.GetConfigInfo(configID);
	local treeID = configInfo and configInfo.treeIDs[1] or 1161;
	local treeCurrencyInfo = C_Traits.GetTreeCurrencyInfo(configID, treeID, false);

	if treeCurrencyInfo and treeCurrencyInfo[1] then
		local maxQuantity = treeCurrencyInfo[1].maxQuantity;
		local charPersist = self.db.char.persist;
		if not maxQuantity and charPersist.CurrentInfinitePower and charPersist.CurrentInfinitePower > 0 then
			maxQuantity = charPersist.CurrentInfinitePower;
		end

		GATHERED_INFINITE_POWER = maxQuantity;

		for i, v in ipairs(levels) do
			if GATHERED_INFINITE_POWER > v.threshold then
				levelText = v.text;
				level = v.level;
				nextLevel = levels[i - 1] and levels[i - 1].threshold or GATHERED_INFINITE_POWER;
				break;
			end
		end
	end


    if isInitialLogin then
        module.ready = true;
    end

	return GATHERED_INFINITE_POWER, level, nextLevel, levelText;
end
