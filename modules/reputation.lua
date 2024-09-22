------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = Addon:RegisterModule("reputation", {
	label 	    = "Reputation",
	order       = 2,
	active      = true,
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowGainedRep = true,
			SwitchTo = false,
			DeferCombat = false,

			AutoWatch = {
				Enabled = false,
				IgnoreGuild = true,
				IgnoreInactive = true,
				IgnoreBodyguard = true,
			},
		},
	},
});

module.tooltipText = "You can quickly scroll through recently gained reputations by scrolling the mouse wheel while holding down shift key."

module.recentReputations = {};
module.hasCustomMouseCallback = true;

local BODYGUARD_FACTIONS = {
	[1738] = "Defender Illona",
	[1740] = "Aeda Brightdawn",
	[1733] = "Delvar Ironfist",
	[1739] = "Vivianne",
	[1737] = "Talonpriest Ishaal",
	[1741] = "Leorajh",
	[1736] = "Tormmok",
};

local inactiveReps = {};

function module:Initialize()
	module:RegisterEvent("UPDATE_FACTION");
	module:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE");
	module:RegisterEvent("PLAYER_REGEN_ENABLED");
	local globalDB = self.db.global;

	local factionData = C_Reputation.GetWatchedFactionData();
	module.Tracked = factionData and factionData.name;

	if factionData and factionData.name then
		module.recentReputations[factionData.name] = {
			factionID = factionData.factionID,
			amount = 0,
		};
	end

	-- Update SwitchTo to live as a global and not under AutoWatch.
	if globalDB.AutoWatch.SwitchTo then
		globalDB.SwitchTo = globalDB.AutoWatch.SwitchTo;
		globalDB.AutoWatch.SwitchTo = nil;
	end

	module.AutoWatchRecent = {};
	module.AutoWatchUpdate = 0;
	module.AutoWatchRecentTimeout = 0;
end

function module:IsDisabled()
	return false;
end

function module:GetSortedRecentList()
	local recentReputations = module.recentReputations;
	local sortedList = {};

	for name, data in pairs(recentReputations) do
		tinsert(sortedList, {name = name, data = data});
	end

	table.sort(sortedList, function(a, b)
		if a == nil or b == nil then
			return a ~= nil -- Non-nil comes first
		end
		return a.name < b.name
	end)

	for index, data in ipairs(sortedList) do
		recentReputations[data.name].sortedIndex = index;
	end

	return sortedList;
end

function module:OnMouseWheel(delta)
	if IsShiftKeyDown() then
		local recentRepsList = module:GetSortedRecentList();
		if not recentRepsList or #recentRepsList == 0 then return end

		local currentIndex = 1;
		local factionData = C_Reputation.GetWatchedFactionData();
		local name = factionData and factionData.name or nil;

		if name then
			currentIndex = module.recentReputations[name].sortedIndex;
		end

		currentIndex = currentIndex - delta;
		if currentIndex > #recentRepsList then currentIndex = 1 end
		if currentIndex < 1 then currentIndex = #recentRepsList end

		if recentRepsList[currentIndex] then
			local data = recentRepsList[currentIndex].data;
			module:MenuSetWatchedFactionID(data.factionID);
		end
	end
end

function module:CanLevelUp()
	local factionData = C_Reputation.GetWatchedFactionData();
	if factionData and C_Reputation.IsFactionParagon(factionData.factionID) then
		local hasRewardPending = select(4, C_Reputation.GetFactionParagonInfo(factionData.factionID));
		return hasRewardPending;
	end
	return false;
end

function module:SetStanding(factionID)
	local standing = C_Reputation.GetFactionDataByID(factionID).reaction;
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local standingText = "";
	local standingColor = {};
	local isCapped = false;

	if majorFactionData then
		isCapped = not majorFactionData.renownLevelThreshold;

		standingText = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
		standingColor = {r = 0.00, g = 0.80, b = 1.00};
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		isCapped = not reputationInfo.nextThreshold;

		standingText, standingColor = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
	elseif standing then
		isCapped = standing == MAX_REPUTATION_REACTION;

		standingText, standingColor = module:GetStandingColorText(standing);
	end

	local IsFactionParagon = C_Reputation.IsFactionParagon(factionID);
	if isCapped and IsFactionParagon or IsFactionParagon then
		local currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;

		local paragonLevel = math.floor(currentReputation / maxReputation);

		if paragonLevel > 1 then
			standingText, standingColor = string.format("%dx %s", paragonLevel, module:GetStandingColorText(9));
		else
			standingText, standingColor = module:GetStandingColorText(9);
		end
	end

	Addon:SetReputationColor(standingColor);
	return standingText;
end

function module:GetText()
	if not module:HasWatchedReputation() then
		return "No active watched reputation";
	end

	local factionData = C_Reputation.GetWatchedFactionData();
	local factionID = factionData.factionID;
	local name = factionData.name;
	local standing = factionData.reaction;
	local minReputation = factionData.currentReactionThreshold;
	local maxReputation = factionData.nextReactionThreshold;
	local currentReputation = factionData.currentStanding;

	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local isCapped = false;
	local standingText = module:SetStanding(factionID);

	-- Determine if reputation is capped
	if majorFactionData then
		isCapped = not majorFactionData.renownLevelThreshold; -- Renowns don't get capped currently
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		isCapped = not reputationInfo.nextThreshold;
	elseif standing then
		isCapped = standing == MAX_REPUTATION_REACTION;
	end

	local remainingReputation = 0;
	local realCurrentReputation = 0;
	local realMaxReputation = 0;

	local hasRewardPending = false;
	local isParagon = false;
	local paragonLevel = 0;

	local IsFactionParagon = C_Reputation.IsFactionParagon(factionID);
	if isCapped and IsFactionParagon or IsFactionParagon then
		currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;
		isParagon = true;

		paragonLevel = math.floor(currentReputation / maxReputation);
		currentReputation = currentReputation % maxReputation;

		remainingReputation = maxReputation - currentReputation;
	elseif not isCapped then
		remainingReputation = maxReputation - currentReputation;
		realCurrentReputation = currentReputation - minReputation;
		realMaxReputation = maxReputation - minReputation;

		if majorFactionData then
			local renownReputationEarned = majorFactionData.renownReputationEarned;
			local renownLevelThreshold = majorFactionData.renownLevelThreshold;

			remainingReputation = renownLevelThreshold - renownReputationEarned;
			realCurrentReputation = renownReputationEarned;
			realMaxReputation = renownLevelThreshold;
		elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
			local friendStanding = reputationInfo.standing;
			local friendThreshold = reputationInfo.reactionThreshold;
			local nextFriendThreshold = reputationInfo.nextThreshold;

			remainingReputation = nextFriendThreshold - friendStanding;
			realCurrentReputation = friendStanding - friendThreshold;
			realMaxReputation = nextFriendThreshold - friendThreshold;
		end

		currentReputation = realCurrentReputation;
		maxReputation = realMaxReputation;
	end

	local globalDB = self.db.global;

	local progress = currentReputation / maxReputation;
	local color = Addon:GetProgressColor(progress);

	local primaryText = {};

	if not isCapped then
		if globalDB.ShowRemaining then
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100)
			);
		else
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r / %s (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(currentReputation), BreakUpLargeNumbers(maxReputation), color, progress * 100)
			);
		end
	end

	if isCapped then
		tinsert(primaryText,
			string.format("%s (%s)", name, standingText)
		);
	end

	local secondaryText = {};

	if hasRewardPending then
		tinsert(secondaryText, "|cnGREEN_FONT_COLOR:Paragon reward earned!|r");
	end

	local recentReputations = module.recentReputations;

	if globalDB.ShowGainedRep and recentReputations[name] then
		if recentReputations[name].amount > 0 then
			tinsert(secondaryText, string.format("+%s |cnNORMAL_FONT_COLOR:rep|r", BreakUpLargeNumbers(recentReputations[name].amount)));
		end
	end

	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return C_Reputation.GetWatchedFactionData() ~= nil, "No watched reputation.";
end

function module:GetChatMessage()
	local factionData = C_Reputation.GetWatchedFactionData();

	local factionID = factionData.factionID;
	local name = factionData.name;
	local standing = factionData.reaction;
	local minReputation = factionData.currentReactionThreshold;
	local maxReputation = factionData.nextReactionThreshold;
	local currentReputation = factionData.currentStanding;

	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local standingText = "";
	local isCapped = false;

	if majorFactionData then
		standingText = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
		isCapped = not majorFactionData.renownLevelThreshold; -- This will never trigger for now, Renowns don't get capped.
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		standingText = reputationInfo.reaction;
		isCapped = not reputationInfo.nextThreshold;
	elseif standing then
		standingText = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
		isCapped = standing == MAX_REPUTATION_REACTION;
	end

	local paragonLevel = 0;

	local IsFactionParagon = C_Reputation.IsFactionParagon(factionID);
	if isCapped and IsFactionParagon or IsFactionParagon then
		currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
		minReputation = 0;
		isCapped = false;

		paragonLevel = math.floor(currentReputation / maxReputation);
		if paragonLevel < 1 then
			paragonLevel = 1;
		end
		currentReputation = currentReputation % maxReputation;
	end

	if not isCapped then
		local remaining_rep = maxReputation - currentReputation;
		if majorFactionData then
			local renownLevelThreshold = majorFactionData.renownLevelThreshold;
			local renownReputationEarned = majorFactionData.renownReputationEarned;

			remaining_rep = renownLevelThreshold - renownReputationEarned;
		elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
			local friendStanding = reputationInfo.standing;
			local nextFriendThreshold = reputationInfo.nextThreshold;

			remaining_rep = nextFriendThreshold - friendStanding;
		end
		local progress = (currentReputation - minReputation) / (maxReputation - minReputation);

		local paragonText = "";
		if paragonLevel > 0 then
			paragonText = string.format(" (%dx paragon)", paragonLevel);
		end

		return string.format("%s%s with %s: %s/%s (%d%%) with %s to go",
			standingText,
			paragonText,
			name,
			BreakUpLargeNumbers(currentReputation - minReputation),
			BreakUpLargeNumbers(maxReputation - minReputation),
			progress * 100,
			BreakUpLargeNumbers(remaining_rep)
		);
	else
		return string.format("%s with %s",
			standingText,
			name
		);
	end
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

	if module:HasWatchedReputation() then
		local factionData = C_Reputation.GetWatchedFactionData();
		local factionID = factionData.factionID;
		local standing = factionData.reaction;
		local minReputation = factionData.currentReactionThreshold;
		local maxReputation = factionData.nextReactionThreshold;
		local currentReputation = factionData.currentStanding;
		data.id = factionID;

		local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
		local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

		local isCapped = false;
		local isParagon = false;

		if majorFactionData then
			minReputation = 0;
			isCapped = not majorFactionData.renownLevelThreshold; -- This will never trigger for now, Renowns don't get capped.
		else
			if reputationInfo and reputationInfo.friendshipFactionID > 0 and not reputationInfo.nextThreshold then
				isCapped = true;
			elseif standing == MAX_REPUTATION_REACTION then
				isCapped = true;
			end
		end

		local IsFactionParagon = C_Reputation.IsFactionParagon(factionID);
		if isCapped and IsFactionParagon or IsFactionParagon then
			currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
			isCapped = false;
			isParagon = true;
			minReputation = 0;

			currentReputation = currentReputation % maxReputation;
		end

		data.level = standing;

		if not isCapped then
			data.min = minReputation;
			data.max = maxReputation;
			data.current = currentReputation;
			if majorFactionData and not isParagon then
				data.max = majorFactionData.renownLevelThreshold;
			elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
				data.min = reputationInfo.reactionThreshold;
				data.max = reputationInfo.nextThreshold;
			end
		else
			data.min = 0;
			data.max = 1;
			data.current = 1;
		end
	end

	return data;
end

function module:GetOptionsMenu(currentMenu)
	currentMenu:CreateTitle("Reputation Options");
	currentMenu:CreateRadio("Show remaining reputation", function() return self.db.global.ShowRemaining == true; end, function()
		self.db.global.ShowRemaining = true;
		module:RefreshText();
	end):SetResponse(MenuResponse.Refresh);
	currentMenu:CreateRadio("Show current and max reputation", function() return self.db.global.ShowRemaining == false; end, function()
		self.db.global.ShowRemaining = false;
		module:RefreshText();
	end):SetResponse(MenuResponse.Refresh);

	currentMenu:CreateDivider();

	local reputationSortType = currentMenu:CreateButton("Reputation Filter");
	reputationSortType:CreateTitle("Reputation Filter");
	reputationSortType:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "Filters your reputation list by chosen type.|n|n|cnWARNING_FONT_COLOR:Note: This option can also be found in the reputations panel in the upper right corner.|r");
	end);
	local sortTypeAll = reputationSortType:CreateRadio("All", function() return C_Reputation.GetReputationSortType() == 0; end, function()
		C_Reputation.SetReputationSortType(0)
	end);

	local sortTypeWarband = reputationSortType:CreateRadio("Warband", function() return C_Reputation.GetReputationSortType() == 1; end, function()
		C_Reputation.SetReputationSortType(1)
	end);

	local sortTypeChar = reputationSortType:CreateRadio(UnitName("PLAYER"), function() return C_Reputation.GetReputationSortType() == 2; end, function()
		C_Reputation.SetReputationSortType(2)
	end);

	local legacyOption = currentMenu:CreateCheckbox("Show Legacy Reputations", function() return C_Reputation.AreLegacyReputationsShown(); end, function()
		C_Reputation.SetLegacyReputationsShown(not C_Reputation.AreLegacyReputationsShown());
		module:RefreshText();
	end);
	legacyOption:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "This option will toggle all reputations prior to |cnWHITE_FONT_COLOR:The War Within|r.|n|n|cnWARNING_FONT_COLOR:Note: This option can also be found in the reputations panel in the upper right corner.|r");
	end);
	legacyOption:SetResponse(MenuResponse.CloseAll);

	currentMenu:CreateDivider();

	currentMenu:CreateCheckbox("Show gained reputation", function() return self.db.global.ShowGainedRep; end, function()
		self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep;
		module:RefreshText();
	end);
	local autoWatchedOption = currentMenu:CreateCheckbox("Auto add to Recent Reputations list", function() return self.db.global.AutoWatch.Enabled; end, function()
		self.db.global.AutoWatch.Enabled = not self.db.global.AutoWatch.Enabled;
	end);
	autoWatchedOption:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "Increased reputations are automatically added to the Recent Reputations list.");
	end);
	autoWatchedOption:CreateCheckbox("Ignore guild reputation", function() return self.db.global.AutoWatch.IgnoreGuild; end, function() self.db.global.AutoWatch.IgnoreGuild = not self.db.global.AutoWatch.IgnoreGuild; end);
	autoWatchedOption:CreateCheckbox("Ignore bodyguard reputation", function() return self.db.global.AutoWatch.IgnoreBodyguard; end, function() self.db.global.AutoWatch.IgnoreBodyguard = not self.db.global.AutoWatch.IgnoreBodyguard; end);
	autoWatchedOption:CreateCheckbox("Ignore inactive reputation", function() return self.db.global.AutoWatch.IgnoreInactive; end, function() self.db.global.AutoWatch.IgnoreInactive = not self.db.global.AutoWatch.IgnoreInactive; end);
	local switchToOption = currentMenu:CreateCheckbox("Auto switch bar to last gained reputation", function() return self.db.global.SwitchTo; end, function()
		self.db.global.SwitchTo = not self.db.global.SwitchTo;
	end);
	switchToOption:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "Automatically switch the Reputation bar to track latest gained reputation.|n|n|cnWARNING_FONT_COLOR:Note: Regardless of your \"auto add\" settings, it will be added to your Recent Reputations list.|r");
	end);

	local deferOption = currentMenu:CreateCheckbox("Wait for end of combat", function() return self.db.global.DeferCombat; end, function()
		self.db.global.DeferCombat = not self.db.global.DeferCombat;
		module:RefreshText();
	end);
	deferOption:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "Delay all reputation calculations until the end of combat. This option is off by default.|n|n|cnWARNING_FONT_COLOR:Note: This can potentially avoid lag or freezing by waiting to do all reputation calculations until combat is over.|r");
	end);

	currentMenu:CreateDivider();
	currentMenu:CreateTitle("Set Watched Faction");

	module:GetReputationsMenu(currentMenu);
end

------------------------------------------

function module:SaveCollapsedHeaders()
	local numFactions = C_Reputation.GetNumFactions();
	local collapsedHeaders = {};

	for factionIndex = 1, numFactions do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		if factionData and factionData.isCollapsed then
			tinsert(collapsedHeaders, factionData.factionID);
		end
	end

	return collapsedHeaders;
end

function module:CloseCollapsedHeaders(collapsedHeaders)
	local numFactions = C_Reputation.GetNumFactions();

	for factionIndex = numFactions, 1, -1 do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		if factionData then
			for index = #collapsedHeaders, 1, -1 do
				if factionData.factionID == collapsedHeaders[index] then
					C_Reputation.CollapseFactionHeader(factionIndex);
					tremove(collapsedHeaders, index);
					break;
				end
			end
		end
	end
end

function module:GetFactionActive(givenFactionID)
	-- If no inactive reps, all factions are active.
	if not next(inactiveReps) then
		return true;
	end

	-- If the faction exists within, it means it is inactive.
	if inactiveReps[givenFactionID] ~= nil then
		return false;
	end

	return true;
end

function module:GetFactionInfoByName(factionName)
	local requestedFactionID = 0;
	local collapsedHeaders = {};

	local numFactions = C_Reputation.GetNumFactions();
	local factionIndex = 1;

	while factionIndex <= numFactions do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		if factionData then
			local factionID, name, isHeader, isCollapsed = factionData.factionID, factionData.name, factionData.isHeader, factionData.isCollapsed;

			-- If the faction has a name and it matches the requested factionName
			if name == factionName then
				requestedFactionID = factionID;
				break;
			end

			-- If the faction is a header and collapsed, expand it and update numFactions
			if isHeader and isCollapsed then
				C_Reputation.ExpandFactionHeader(factionIndex);
				tinsert(collapsedHeaders, factionID);
				numFactions = C_Reputation.GetNumFactions(); -- Update after expansion
			end
		end

		factionIndex = factionIndex + 1;
	end

	module:CloseCollapsedHeaders(collapsedHeaders);
	return requestedFactionID, factionIndex, C_Reputation.IsFactionActive(factionIndex);
end

function module:MenuSetWatchedFactionID(factionID)
	C_Reputation.SetWatchedFactionByID(factionID);
end

function module:MenuSetWatchedFactionIndex(factionIndex)
	C_Reputation.SetWatchedFactionByIndex(factionIndex);
end

function module:GetRecentReputationsMenu()
	local factions = {
		{ name = "Recent Reputations", isRecentTitle = true },
	};

	local recentRepsList = module:GetSortedRecentList();
	for _, rep in ipairs(recentRepsList) do
		local name = rep.name;
		local data = rep.data;
		local factionID = data.factionID;

		if name then
			local factionData = C_Reputation.GetFactionDataByID(factionID);
			local standing, isHeader, hasRep, isWatched = factionData.reaction, factionData.isHeader, factionData.isHeaderWithRep, factionData.isWatched;

			if not isHeader or hasRep then
				local standing_text = "";
				local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);
				local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);

				if majorFactionData then
					standing_text = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
				elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
					standing_text = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
				else
					standing_text = module:GetStandingColorText(standing);
				end

				tinsert(factions, {
					name = string.format("%s (%s)  +%s rep this session", name, standing_text, BreakUpLargeNumbers(data.amount)),
					isRecentFaction = true,
					factionID = factionID,
					isWatched = isWatched,
				});
			end
		end
	end

	if #recentRepsList == 0 then
		return false;
	end

	return factions;
end

function module:GetReputationProgressByFactionID(factionID)
	if not factionID then return nil end

	local factionData = C_Reputation.GetFactionDataByID(factionID);
	local name, standing, minReputation, maxReputation, currentReputation = factionData.name, factionData.reaction, factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding;
	if not name or not minReputation or not maxReputation then return nil end

	-- Friendships
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);

	-- Renown
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local isCapped = false;
	local isParagon = false;

	-- Handle Major Faction (Renown) and Paragon
	if majorFactionData then
		minReputation = 0;
		if not majorFactionData.renownLevelThreshold then
			isCapped = true;  -- Renown does not get capped currently
		elseif C_Reputation.IsFactionParagon(factionID) then
			currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
			isParagon = true;
			currentReputation = currentReputation % maxReputation;
		else
			currentReputation = majorFactionData.renownReputationEarned;
			maxReputation = majorFactionData.renownLevelThreshold;
		end
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		-- Handle Friendship factions
		local nextFriendThreshold = reputationInfo.nextThreshold;
		if not nextFriendThreshold then
			isCapped = true;
		else
			minReputation = reputationInfo.reactionThreshold;
			currentReputation = reputationInfo.standing;
			maxReputation = nextFriendThreshold;
		end
	elseif standing == MAX_REPUTATION_REACTION then
		if C_Reputation.IsFactionParagon(factionID) then
			currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
			isParagon = true;
			minReputation = 0;
			currentReputation = currentReputation % maxReputation;
		else
			isCapped = true;
		end
	end

	-- Return the progress (current, max), and status flags
	return currentReputation - minReputation, maxReputation - minReputation, isCapped, isParagon;
end

function module:CreateRecentReputationsMenu(currentMenu, recents)
	for _, recentsInfo in ipairs(recents) do
		if recentsInfo.isRecentTitle then
			currentMenu:CreateTitle(recentsInfo.name);
		elseif recentsInfo.isRecentFaction then
			currentMenu:CreateRadio(recentsInfo.name,
				function() return recentsInfo.isWatched; end,
				function()
					-- Set the watched faction when selected
					module:MenuSetWatchedFactionID(recentsInfo.factionID);
				end
			);
		end
	end

	currentMenu:CreateButton("Clear recent reputations", function()
		wipe(module.recentReputations); -- Clears the cached recent reputations
	end);
end

function module:CreateWatchedFactionSubMenu(subMenu, factionInfo)
	subMenu:CreateTitle(factionInfo.menuList[1].name);
	tremove(factionInfo.menuList, 1);
	for _, faction in ipairs(factionInfo.menuList) do
		local factionOption;

		if faction.isHeader then
			factionOption = subMenu:CreateButton(faction.name);
			module:CreateWatchedFactionSubMenu(factionOption, faction);
		else
			factionOption = subMenu:CreateRadio(faction.name, function()
				return faction.isWatched;
			end, function()
				module:MenuSetWatchedFactionID(faction.factionID);
			end);
		end

		if faction.isHeaderWithRep then
			factionOption:SetShouldRespondIfSubmenu(true);
			factionOption:SetResponse(MenuResponse.CloseAll);
			module:CreateWatchedFactionSubMenu(factionOption, faction);
		end
	end
end

function module:CreateWatchedFactionsMenu(currentMenu, factions)
	for _, faction in ipairs(factions) do
		if faction.isMajorHeader then
			local majorHeader = currentMenu:CreateButton(faction.name);
			module:CreateWatchedFactionSubMenu(majorHeader, faction);
		end
	end
end

function module:GetReputationsMenu(currentMenu)
	local factions = {};

	local previous, current = nil, nil;
	local tier = 0;

	local collapsedHeaders = {};
	local inactiveHeader = false;
	inactiveReps = {};

	local numFactions = C_Reputation.GetNumFactions();
	local factionIndex = 1;
	while factionIndex <= numFactions do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		-- TWW introduced potential empty headers, only handle below if factionData exists.
		if factionData then
			local factionID, name, standing, isHeader, isCollapsed, hasRep, isWatched, isChild, isAccountWide = factionData.factionID, factionData.name, factionData.reaction, factionData.isHeader, factionData.isCollapsed, factionData.isHeaderWithRep, factionData.isWatched, factionData.isChild, factionData.isAccountWide;
			-- If inactive reps, open that header and save them for later.
			if factionID == 0 then
				inactiveHeader = true;

				if isHeader and isCollapsed then
					C_Reputation.ExpandFactionHeader(factionIndex);
					tinsert(collapsedHeaders, factionData.factionID);
					numFactions = C_Reputation.GetNumFactions();
				end
			end
			if not C_Reputation.IsFactionActive(factionIndex) then
				inactiveReps[factionData.factionID] = true;
			end
			if name and not inactiveHeader then
				local progressText = "";
				if factionID then
					local currentRep, nextThreshold, isCapped, isParagon = module:GetReputationProgressByFactionID(factionID);
					if (isParagon) then
						standing = 9;
					end

					if (currentRep and not isCapped) then
						progressText = string.format("  (|cfffff2ab%s|r / %s)", BreakUpLargeNumbers(currentRep), BreakUpLargeNumbers(nextThreshold));
					end
				end

				local standingText = "";

				if not isHeader or hasRep then
					local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
					local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);
					if (majorFactionData and standing ~= 9) then
						standingText = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
					elseif (reputationInfo and reputationInfo.friendshipFactionID > 0) then
						standingText = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
					else
						standingText = module:GetStandingColorText(standing);
					end
				end

				-- Open up collapsed headers temporarily
				if isHeader and isCollapsed then
					C_Reputation.ExpandFactionHeader(factionIndex);
					tinsert(collapsedHeaders, factionData.factionID);
					numFactions = C_Reputation.GetNumFactions();
				end

				-- 2nd tier has some quirks which we fix here:
				-- If 2nd but not a child, it's 1st tier.
				-- If 2nd tier but a child, but also a header (with or without rep), it's 1st tier.
				if tier == 2 then
					if not isChild or (isChild and (isHeader or hasRep)) then
						current = previous;
						tier = 1;
					end
				end

				if isHeader and not hasRep and not isChild then -- Expansion 1st tier header
					tinsert(factions, {
						name = name,
						isMajorHeader = true;
						menuList = {},
					});

					current = factions[#factions].menuList;
					tinsert(current, {
						name = name,
						isMajorHeaderTitle = true,
					});

					tier = 1;
				elseif tier == 1 then -- 2nd tier header/expansions
					if not isHeader then -- Simple faction, no header business.
						tinsert(current, {
							name = string.format("%s (%s)%s", name, standingText, progressText),
							isFaction = true,
							factionID = factionID,
							isWatched = isWatched,
						});
					else
						if not hasRep then
							tinsert(current, {
								name = name,
								isHeader = true,
								menuList = {},
							});
						else
							tinsert(current, {
								name = string.format("%s (%s)%s", name, standingText, progressText),
								isHeaderWithRep = true,
								factionID = factionID,
								isWatched = isWatched,
								menuList = {},
							});
						end

						previous = current;
						current = current[#current].menuList;
						tinsert(current, {
							name = name,
							isSubMenuTitle = true,
						});

						tier = 2;
					end
				elseif tier == 2 then -- 3rd tier header
					tinsert(current, {
						name = string.format("%s (%s)%s", name, standingText, progressText),
						isFaction = true,
						factionID = factionID,
						isWatched = isWatched,
					});
				end
			end
		end

		factionIndex = factionIndex + 1;
	end

	module:CloseCollapsedHeaders(collapsedHeaders);
	module:CreateWatchedFactionsMenu(currentMenu, factions);

	local recent = module:GetRecentReputationsMenu();
	if recent ~= false then
		currentMenu:CreateDivider();
		module:CreateRecentReputationsMenu(currentMenu, recent);
	end

	currentMenu:CreateDivider();

	currentMenu:CreateButton("Open reputations panel", function() ToggleCharacter("ReputationFrame"); end);
end

------------------------------------------

function module:HasWatchedReputation()
	return C_Reputation.GetWatchedFactionData() ~= nil;
end

function module:GetStandingColorText(standing)
	local colors = {
		[1] = {r=0.80, g=0.13, b=0.13}, -- hated
		[2] = {r=1.00, g=0.25, b=0.00}, -- hostile
		[3] = {r=0.93, g=0.40, b=0.13}, -- unfriendly
		[4] = {r=1.00, g=1.00, b=0.00}, -- neutral
		[5] = {r=0.00, g=0.70, b=0.00}, -- friendly
		[6] = {r=0.00, g=1.00, b=0.00}, -- honored
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
		[9] = {r=0.00, g=1.00, b=1.00}, -- paragon
	}

	local color = colors[standing];
	local label = standing < 9 and GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player")) or "Paragon";

	return string.format('|cff%02x%02x%02x%s|r',
		color.r * 255, color.g * 255, color.b * 255, label
	), color;
end

function module:GetFriendShipColorText(friendshipFactionID, standing)
	local friendshipInfo = C_GossipInfo.GetFriendshipReputationRanks(friendshipFactionID);
	local maxLevel = friendshipInfo.maxLevel;
	local standingLevel = friendshipInfo.standingLevel;

	local colors = {
		[1] = {r=0.80, g=0.13, b=0.13}, -- hated
		[2] = {r=1.00, g=0.25, b=0.00}, -- hostile
		[3] = {r=0.93, g=0.40, b=0.13}, -- unfriendly
		[4] = {r=1.00, g=1.00, b=0.00}, -- neutral
		[5] = {r=0.00, g=0.70, b=0.00}, -- friendly
		[6] = {r=0.00, g=1.00, b=0.00}, -- honored
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
		[9] = {r=0.00, g=1.00, b=1.00}, -- paragon
	}

	local friendshipColors = {
		[1] = colors[4], -- Stranger
		[2] = colors[5], -- Acquaintance/Pal
		[3] = colors[6], -- Buddy
		[4] = colors[6], -- Friend
		[5] = colors[7], -- Good Friend
		[6] = colors[8], -- Best Friend
		[7] = colors[9], -- Paragon
	}

	-- Customize colors based on friendshipFactionID
	local customFriendshipColors = {
		[1374] = true, [1419] = true, [1690] = true, [1691] = true, -- Brawlers S1-S3
		[2010] = true, [2011] = true, -- Brawlers S1-S3
		[2371] = true, [2372] = true, -- Brawlers S4/Current
		[2135] = true, -- Chromie
		[1357] = true, -- Nomi
		[2640] = true, [2605] = true, [2607] = true, [2601] = true,
		[2517] = true, [2518] = true, [2544] = true, [2568] = true,
		[2553] = true, [2550] = true, [2615] = true, -- Always friendly green
	}

	if customFriendshipColors[friendshipFactionID] then
		if friendshipFactionID == 2135 then -- Chromie
			friendshipColors = {
				[1] = colors[4], -- Whelpling
				[2] = colors[4], -- Temporal Trainee
				[3] = colors[5], -- Timehopper
				[4] = colors[5], -- Chrono-Friend
				[5] = colors[6], -- Bronze Ally
				[6] = colors[7], -- Epoch-Mender
				[7] = colors[8], -- Timelord
			}
		elseif friendshipFactionID == 1357 then -- Nomi
			friendshipColors = {
				[1] = colors[4], -- Apprentice
				[2] = colors[4], -- Apprentice
				[3] = colors[5], -- Journeyman
				[4] = colors[6], -- Journeyman
				[5] = colors[7], -- Journeyman
				[6] = colors[8], -- Expert
			}
		else -- For Brawlers and other special reputations
			friendshipColors = {};
			for i = 1, maxLevel do
				friendshipColors[i] = colors[5]; -- Rank 1 to Rank N - Always friendly green
			end
		end
	end

	-- Fallback to friendly color if no specific color is set
	local friendshipColor = friendshipColors[standingLevel] or colors[5];

	return string.format('|cff%02x%02x%02x%s|r',
		friendshipColor.r * 255,
		friendshipColor.g * 255,
		friendshipColor.b * 255,
		standing
	), friendshipColor;
end

function module:HandleUpdateFaction()
	local factionData = C_Reputation.GetWatchedFactionData();
	if not factionData then return end;

	module.levelUpRequiresAction = C_Reputation.IsFactionParagon(factionData.factionID);

	local instant = factionData.name ~= module.Tracked or not factionData.name;
	module.Tracked = factionData.name;

	if instant then
		module.AutoWatchUpdate = 0;
	end

	module:SetStanding(factionData.factionID);
	module:Refresh(instant);
end

local reputationsToUpdate = {};
local updateFactionRequired = false;

function module:HandleReputationUpdates()
	for reputation, amount in pairs(reputationsToUpdate) do
		updateFactionRequired = true;
        reputationsToUpdate[reputation] = nil;

        local factionID, _, isActive = module:GetFactionInfoByName(reputation);

        if isActive then
            inactiveReps[factionID] = nil;
        else
            inactiveReps[factionID] = true;
        end

		local isGuild = (reputation == GUILD) and true or false;
        if isGuild then
            local guildName = GetGuildInfo("player")
            if guildName then
                reputation = guildName;
            end
        end

		-- Proceed only if recentReputations exists
		if module.recentReputations then
			-- Cache globalDB, recentReputations, and watchedFactionData
			local globalDB = self.db.global;
			local recentReputations = module.recentReputations;
			local watchedFactionData = C_Reputation.GetWatchedFactionData();

			-- Check if the recent reputation exists.
            local reputationEntry = recentReputations[reputation];
            if not reputationEntry then
                -- If auto-watch enabled or switchTo, create it regardless.
				-- Otherwise check if your current watched == current given and then add it.
                if globalDB.AutoWatch.Enabled or globalDB.SwitchTo or
                   (watchedFactionData and watchedFactionData.factionID == factionID) then
                    recentReputations[reputation] = { amount = 0, factionID = factionID };
					reputationEntry = recentReputations[reputation];
				else -- If neither auto-watch is on, or you're not currently tracking it, we stop.
					return;
				end
            end

			-- If auto-switch, let's do that.
			if globalDB.SwitchTo then
                module:MenuSetWatchedFactionID(factionID);
            end

			-- Increment the amount
            if reputationEntry then
                reputationEntry.amount = reputationEntry.amount + amount;
            end

			if globalDB.AutoWatch.Enabled and module.AutoWatchUpdate ~= 2 then
                local shouldIgnore = globalDB.AutoWatch.IgnoreInactive and not module:GetFactionActive(reputationEntry.factionID);
                local isBodyguard = globalDB.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[reputationEntry.factionID];
                local isGuildIgnored = globalDB.AutoWatch.IgnoreGuild and isGuild;

                if not (shouldIgnore or isBodyguard or isGuildIgnored) then
                    module.AutoWatchUpdate = 1;
                    module.AutoWatchRecentTimeout = 0.1;

                    module.AutoWatchRecent[reputation] = (module.AutoWatchRecent[reputation] or 0) + amount;
                end
            end

			-- If reputation changes have happened to watched, we probably want to run faction updates.
            if watchedFactionData and watchedFactionData.name == reputation then
                updateFactionRequired = false;
                RunNextFrame(function()
                    module:HandleUpdateFaction();
                end);
            end
		end
	end
end

function module:UPDATE_FACTION()
	-- If in combat, hold the update.
	if self.db.global.DeferCombat and InCombatLockdown() then
		updateFactionRequired = true;
		return;
	end

	module:HandleUpdateFaction();
end

function module:PLAYER_REGEN_ENABLED()
	RunNextFrame(function()
		-- If we have reputation updates to process, do that.
		if next(reputationsToUpdate) then
			module:HandleReputationUpdates();
		elseif updateFactionRequired then
			updateFactionRequired = false;
			module:HandleUpdateFaction();
		end
	end);
end

local reputationPattern = FACTION_STANDING_INCREASED:gsub("%%s", "(.-)"):gsub("%%d", "(%%d*)%%");
local warbandReputationPattern = FACTION_STANDING_INCREASED_ACCOUNT_WIDE:gsub("%%s", "(.-)"):gsub("%%d", "(%%d*)%%");

function module:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match(reputationPattern);

	-- If no reputation is found, check for warband (account-wide).
	if not reputation then
		reputation, amount = message:match(warbandReputationPattern);
	end

	-- If not char-specific or warband reputation, we end here.
	if not reputation then return end

	reputationsToUpdate[reputation] = (reputationsToUpdate[reputation] or 0) + tonumber(amount) or 0;

	-- If in combat, we don't process the reputation updates yet.
	if self.db.global.DeferCombat and InCombatLockdown() then
		return;
	end

	RunNextFrame(function()
		module:HandleReputationUpdates();
	end);
end

function module:AllowedToBufferUpdate()
	return module.AutoWatchUpdate == 0;
end

function module:Update(elapsed)
    if module.AutoWatchUpdate == 1 then
        if module.AutoWatchRecentTimeout > 0.0 then
            module.AutoWatchRecentTimeout = module.AutoWatchRecentTimeout - elapsed;
        end

        if module.AutoWatchRecentTimeout <= 0.0 then
            local selectedFaction = nil;
            local largestGain = 0;

            for faction, gain in pairs(module.AutoWatchRecent) do
                if gain > largestGain then
                    selectedFaction = faction;
                    largestGain = gain;
                end
            end

            local factionData = C_Reputation.GetWatchedFactionData();
            if factionData and selectedFaction ~= factionData.name then
                module:MenuSetWatchedFactionID(factionData.factionID);
                module.AutoWatchUpdate = 2;
            else
                module.AutoWatchUpdate = 0;
            end

            module.AutoWatchRecentTimeout = 0;
            wipe(module.AutoWatchRecent);
        end
    end
end
