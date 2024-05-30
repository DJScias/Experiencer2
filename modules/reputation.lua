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
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowGainedRep = true,
			
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

function module:Initialize()
	module:RegisterEvent("UPDATE_FACTION");
	module:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE");
	
	local name = GetWatchedFactionInfo();
	module.Tracked = name;
	
	if(name) then
		module.recentReputations[name] = {
			amount = 0;
		};
	end
	
	module.AutoWatchRecent = {};
	module.AutoWatchUpdate = 0;
	module.AutoWatchRecentTimeout = 0;
end

function module:IsDisabled()
	return false;
end

function module:GetSortedRecentList()
	local sortedList = {};
	for name, data in pairs(module.recentReputations) do
		tinsert(sortedList, {name = name, data = data});
	end
	table.sort(sortedList, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return a.name < b.name;
	end);
	for index, data in ipairs(sortedList) do
		module.recentReputations[data.name].sortedIndex = index;
	end
	return sortedList;
end

function module:OnMouseWheel(delta)
	if(IsShiftKeyDown()) then
		local recentRepsList = module:GetSortedRecentList();
		if(not recentRepsList or #recentRepsList == 0) then return end
		
		local currentIndex = nil;
		local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
		if(name) then
			currentIndex = module.recentReputations[name].sortedIndex;
		else
			currentIndex = 1;
		end
		
		currentIndex = currentIndex - delta;
		if(currentIndex > #recentRepsList) then currentIndex = 1 end
		if(currentIndex < 1) then currentIndex = #recentRepsList end
		
		if(recentRepsList[currentIndex]) then
			local factionIndex = module:GetReputationID(recentRepsList[currentIndex].name);
			SetWatchedFactionIndex(factionIndex);
		end
	end
end

function module:CanLevelUp()
	local _, _, _, _, _, factionID = GetWatchedFactionInfo();
	if(factionID and C_Reputation.IsFactionParagon(factionID)) then
		local _, _, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		return hasRewardPending;
	end
	return false;
end

function module:SetStanding(factionID, standing)
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);
	
	local standingText = "";
	local standingColor = {};
	local isCapped = false;

	if(majorFactionData) then
		local renownLevel = majorFactionData.renownLevel;

		local renownLevelThreshold = majorFactionData.renownLevelThreshold;
		if(not renownLevelThreshold) then
			isCapped = true; -- This will never trigger for now, Renowns don't get capped.
		end
		
		standingText = string.format("|cff00ccffRenown %s|r", renownLevel);
		standingColor = {r=0.00, g=0.80, b=1.00};
	elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
		local friendLevel = reputationInfo.reaction;

		local nextFriendThreshold = reputationInfo.nextThreshold;

		if(not nextFriendThreshold) then
			isCapped = true;
		end

		standingText, standingColor = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, friendLevel);
	else
		if(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end

		standingText, standingColor = module:GetStandingColorText(standing);
	end

	if((isCapped and C_Reputation.IsFactionParagon(factionID)) or C_Reputation.IsFactionParagon(factionID)) then
		local currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;

		local paragonLevel = math.floor(currentReputation / maxReputation);
	
		if(paragonLevel > 1) then
			standingText, standingColor = string.format("%dx %s", paragonLevel, module:GetStandingColorText(9));
		else
			standingText, standingColor = module:GetStandingColorText(9);
		end
	end

	Addon:SetReputationColor(standingColor);
	return standingText;
end

function module:GetText()
	if(not module:HasWatchedReputation()) then
		return "No active watched reputation";
	end
		
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local isCapped = false;
	local standingText = module:SetStanding(factionID, standing);

	if(majorFactionData) then
		local renownLevelThreshold = majorFactionData.renownLevelThreshold;
		if(not renownLevelThreshold) then
			isCapped = true; -- This will never trigger for now, Renowns don't get capped.
		end
	elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
		local nextFriendThreshold = reputationInfo.nextThreshold;

		if(not nextFriendThreshold) then
			isCapped = true;
		end
	else
		if(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end
	end

	local remainingReputation = 0;
	local realCurrentReputation = 0;
	local realMaxReputation = 0;
	
	local hasRewardPending = false;
	local isParagon = false;
	local paragonLevel = 0;
	
	if((isCapped and C_Reputation.IsFactionParagon(factionID)) or C_Reputation.IsFactionParagon(factionID)) then
		currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		minReputation = 0;
		isCapped = false;
		isParagon = true;
		
		paragonLevel = math.floor(currentReputation / maxReputation);
		currentReputation = currentReputation % maxReputation;

		remainingReputation = maxReputation - currentReputation;
	elseif(not isCapped) then
		remainingReputation = maxReputation - currentReputation;
		realCurrentReputation = currentReputation - minReputation;
		realMaxReputation = maxReputation - minReputation;
		if(majorFactionData) then
			local renownReputationEarned = majorFactionData.renownReputationEarned;
			local renownLevelThreshold = majorFactionData.renownLevelThreshold;

			remainingReputation = renownLevelThreshold - renownReputationEarned;
			realCurrentReputation = renownReputationEarned;
			realMaxReputation = renownLevelThreshold;
		elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
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

	local progress = currentReputation / maxReputation;
	local color = Addon:GetProgressColor(progress);

	local primaryText = {};
	
	if(not isCapped) then
		if(self.db.global.ShowRemaining) then
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100)
			);
		else
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r / %s (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(currentReputation), BreakUpLargeNumbers(maxReputation), color, progress * 100)
			);
		end
	end
	
	if (isCapped) then
		tinsert(primaryText,
			string.format("%s (%s)", name, standingText)
		);
	end
	
	local secondaryText = {};

	if(hasRewardPending) then
		tinsert(secondaryText, "|cff00ff00Paragon reward earned!|r");
	end
	
	if(self.db.global.ShowGainedRep and module.recentReputations[name]) then
		if(module.recentReputations[name].amount > 0) then
			tinsert(secondaryText, string.format("+%s |cffffcc00rep|r", BreakUpLargeNumbers(module.recentReputations[name].amount)));
		end
	end

	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return GetWatchedFactionInfo() ~= nil, "No watched reputation.";
end

function module:GetChatMessage()

	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local standingText = "";
	local isCapped = false;
	
	if(majorFactionData) then
		local renownLevel = majorFactionData.renownLevel;
		local renownLevelThreshold = majorFactionData.renownLevelThreshold;
		standingText = string.format("|cff00ccffRenown %s|r", renownLevel);
		if(not renownLevelThreshold) then
			isCapped = true; -- This will never trigger for now, Renowns don't get capped.
		end
	elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
		local friendLevel = reputationInfo.reaction;
		local nextFriendThreshold = reputationInfo.nextThreshold;

		standingText = friendLevel;
		if(not nextFriendThreshold) then
			isCapped = true;
		end
	else
		standingText = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
		if(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end
	end

	local paragonLevel = 0;
	
	if((isCapped and C_Reputation.IsFactionParagon(factionID)) or C_Reputation.IsFactionParagon(factionID)) then
		currentReputation, maxReputation, _, _ = C_Reputation.GetFactionParagonInfo(factionID);
		minReputation = 0;
		isCapped = false;
		
		paragonLevel = math.floor(currentReputation / maxReputation);
		if (paragonLevel < 1) then
			paragonLevel = 1;
		end
		currentReputation = currentReputation % maxReputation;
	end
	
	if(not isCapped) then
		local remaining_rep = maxReputation - currentReputation;
		if(majorFactionData) then
			local renownLevelThreshold = majorFactionData.renownLevelThreshold;
			local renownReputationEarned = majorFactionData.renownReputationEarned;

			remaining_rep = renownLevelThreshold - renownReputationEarned;
		elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
			local friendStanding = reputationInfo.standing;
			local nextFriendThreshold = reputationInfo.nextThreshold;

			remaining_rep = nextFriendThreshold - friendStanding;
		end
		local progress = (currentReputation - minReputation) / (maxReputation - minReputation);

		local paragonText = "";
		if(paragonLevel > 0) then
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
	local data    = {};
	data.id       = nil;
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;
	
	if(module:HasWatchedReputation()) then
		local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
		data.id = factionID;

		local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
		local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);
				
		local isCapped = false;
		local isParagon = false;

		if (majorFactionData) then
			minReputation = 0;
			if (not majorFactionData.renownLevelThreshold) then
				isCapped = true; -- This will never trigger for now, Renowns don't get capped.
			end
		elseif(reputationInfo and reputationInfo.friendshipFactionID > 0 and not reputationInfo.nextThreshold) then
			isCapped = true;
		elseif(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end
		
		if((isCapped and C_Reputation.IsFactionParagon(factionID)) or C_Reputation.IsFactionParagon(factionID)) then
			currentReputation, maxReputation, _, _ = C_Reputation.GetFactionParagonInfo(factionID);
			isCapped = false;
			isParagon = true;
			minReputation = 0;
			
			currentReputation = currentReputation % maxReputation;
		end
		
		data.level       = standing;
		
		if(not isCapped) then
			data.min  	 = minReputation;
			data.max  	 = maxReputation;
			data.current = currentReputation;
			if(majorFactionData and not isParagon) then
				data.max = majorFactionData.renownLevelThreshold;
			elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
				data.min = reputationInfo.reactionThreshold;
				data.max = reputationInfo.nextThreshold;
			end
		else
			data.min     = 0;
			data.max     = 1;
			data.current = 1;
		end
	end
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Reputation Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining reputation",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max reputation",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show gained reputation",
			func = function() self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep; module:Refresh(); end,
			checked = function() return self.db.global.ShowGainedRep; end,
			isNotRadio = true,
		},
		{
			text = "Auto watch most recent reputation",
			func = function() self.db.global.AutoWatch.Enabled = not self.db.global.AutoWatch.Enabled; end,
			checked = function() return self.db.global.AutoWatch.Enabled; end,
			hasArrow = true,
			isNotRadio = true,
			menuList = {
				{
					text = "Ignore guild reputation",
					func = function() self.db.global.AutoWatch.IgnoreGuild = not self.db.global.AutoWatch.IgnoreGuild; end,
					checked = function() return self.db.global.AutoWatch.IgnoreGuild; end,
					isNotRadio = true,
				},
				{
					text = "Ignore bodyguard reputations",
					func = function() self.db.global.AutoWatch.IgnoreBodyguard = not self.db.global.AutoWatch.IgnoreBodyguard; end,
					checked = function() return self.db.global.AutoWatch.IgnoreBodyguard; end,
					isNotRadio = true,
				},
				{
					text = "Ignore inactive reputations",
					func = function() self.db.global.AutoWatch.IgnoreInactive = not self.db.global.AutoWatch.IgnoreInactive; end,
					checked = function() return self.db.global.AutoWatch.IgnoreInactive; end,
					isNotRadio = true,
				},
			},
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Set Watched Faction",
			isTitle = true,
			notCheckable = true,
		},
	};
	
	local reputationsMenu = module:GetReputationsMenu();
	for _, data in ipairs(reputationsMenu) do
		tinsert(menudata, data);
	end
	
	tinsert(menudata, { text = "", isTitle = true, notCheckable = true, });
	tinsert(menudata, {
		text = "Open reputations panel",
		func = function() ToggleCharacter("ReputationFrame"); end,
		notCheckable = true,
	});
	
	return menudata;
end

------------------------------------------

function module:GetReputationID(faction_name)
	if(faction_name == GUILD) then
		return 2;
	end
	
	local numFactions = GetNumFactions();
	local index = 1;
	while index <= numFactions do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed, _, _, _, factionID = GetFactionInfo(index);
		
		if(isHeader and isCollapsed) then
			ExpandFactionHeader(index);
			numFactions = GetNumFactions();
		end
		
		if(name == faction_name) then
			return index, factionID;
		end
			
		index = index + 1;
	end
	
	return nil
end

function module:MenuSetWatchedFactionIndex(factionIndex)
	SetWatchedFactionIndex(factionIndex);
	CloseMenus();
end

function module:GetRecentReputationsMenu()
	local factions = {
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Recent Reputations", isTitle = true, notCheckable = true,
		},
	};
	
	local recentRepsList = module:GetSortedRecentList();
	for _, rep in ipairs(recentRepsList) do
		local name = rep.name;
		local data = rep.data;
		
		local factionIndex = module:GetReputationID(name);
		local _, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(factionIndex);

		local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
		local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

		local standing_text = "";
		
		if(not isHeader or hasRep) then
			if (majorFactionData) then
				standing_text = string.format("|cff00ccffRenown %s|r", majorFactionData.renownLevel);
			elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
				standing_text, _ = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
			else
				standing_text, _ = module:GetStandingColorText(standing)
			end
		end
		
		tinsert(factions, {
			text = string.format("%s (%s)  +%s rep this session", name, standing_text, BreakUpLargeNumbers(data.amount)),
			func = function()
				module:MenuSetWatchedFactionIndex(factionIndex);
			end,
			checked = function() return isWatched end,
		})
	end
	
	if(#recentRepsList == 0) then
		return false;
	end
	
	return factions;
end

function module:GetReputationProgressByFactionID(factionID)
	if(not factionID) then return nil end
	
	local name, _, standing, minReputation, maxReputation, currentReputation = GetFactionInfoByID(factionID);
	if(not name or not minReputation or not maxReputation) then return nil end
	
	-- Friendships
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);

	-- Renown
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local isCapped = false;
	local isParagon = false;

	if(majorFactionData) then
		minReputation = 0;
		if(not majorFactionData.renownLevelThreshold) then
			isCapped = true; -- This will never trigger for now, Renown does not get capped.
		elseif(C_Reputation.IsFactionParagon(factionID)) then
			currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
			isParagon = true;
			currentReputation = currentReputation % maxReputation;
		else
			currentReputation = majorFactionData.renownReputationEarned;
			maxReputation = majorFactionData.renownLevelThreshold;
		end
	elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
		local friendStanding = reputationInfo.standing;
		local friendThreshold = reputationInfo.reactionThreshold;
		local nextFriendThreshold = reputationInfo.nextThreshold;
		if(not nextFriendThreshold) then
			isCapped = true;
		else
			minReputation = friendThreshold;
			currentReputation = friendStanding;
			maxReputation = nextFriendThreshold;
		end
	else
		if(standing == MAX_REPUTATION_REACTION) then
			if(C_Reputation.IsFactionParagon(factionID)) then
				currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
				isParagon = true;
				minReputation = 0;
				currentReputation = currentReputation % maxReputation;
			else
				isCapped = true;
			end
		end
	end

	return currentReputation - minReputation, maxReputation - minReputation, isCapped, isParagon;
end

function module:GetReputationsMenu()
	local factions = {};
	
	local previous, current = nil, nil;
	local depth = 0;
	
	local factionIndex = 1;
	local numFactions = GetNumFactions();
	while factionIndex <= numFactions do
		local name, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(factionIndex);
		if(name) then
			local progressText = "";
			if(factionID) then
				local currentRep, nextThreshold, isCapped, isParagon = module:GetReputationProgressByFactionID(factionID);
				if(isParagon) then
					standing = 9;
				end
				
				if(currentRep and not isCapped) then
					progressText = string.format("  (|cfffff2ab%s|r / %s)", BreakUpLargeNumbers(currentRep), BreakUpLargeNumbers(nextThreshold));
				end
			end

			local standingText = "";

			if(not isHeader or hasRep) then
				local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
				local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);
				if(majorFactionData and standing ~= 9) then
					standingText = string.format("|cff00ccffRenown %s|r", majorFactionData.renownLevel);
				elseif(reputationInfo and reputationInfo.friendshipFactionID > 0) then
					standingText, _ = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
				else
					standingText, _ = module:GetStandingColorText(standing);
				end
			end
			
			if(isHeader and isCollapsed) then
				ExpandFactionHeader(factionIndex);
				numFactions = GetNumFactions();
			end
			
			if(isHeader and isChild and current) then -- Second tier header
				if(depth == 2) then
					current = previous;
					previous = nil;
				end
				
				if(not hasRep) then
					tinsert(current, {
						text = name,
						hasArrow = true,
						notCheckable = true,
						menuList = {},
					})
				else
					local index = factionIndex;
					tinsert(current, {
						text = string.format("%s (%s)%s", name, standingText, progressText),
						hasArrow = true,
						func = function()
							module:MenuSetWatchedFactionIndex(index);
						end,
						checked = function() return isWatched; end,
						menuList = {},
					})
				end
				
				previous = current;
				current = current[#current].menuList;
				tinsert(current, {
					text = name,
					isTitle = true,
					notCheckable = true,
				})
				
				depth = 2
				
			elseif(isHeader) then -- First tier header
				tinsert(factions, {
					text = name,
					hasArrow = true,
					notCheckable = true,
					menuList = {},
				})
				
				current = factions[#factions].menuList;
				tinsert(current, {
					text = name,
					isTitle = true,
					notCheckable = true,
				})
				
				depth = 1
			elseif(not isHeader) then -- First and second tier faction
				local index = factionIndex;
				tinsert(current, {
					text = string.format("%s (%s)%s", name, standingText, progressText),
					func = function()
						module:MenuSetWatchedFactionIndex(index);
					end,
					checked = function() return isWatched end,
				})
			end
		end
		
		factionIndex = factionIndex + 1;
	end
	
	local recent = module:GetRecentReputationsMenu();
	if(recent ~= false) then
		for _, data in ipairs(recent) do tinsert(factions, data) end
	end
	
	return factions;
end

------------------------------------------

function module:HasWatchedReputation()
	return GetWatchedFactionInfo() ~= nil;
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
	
	local label;
	if(standing < 9) then
		label = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
	else
		label = "Paragon";
	end
	
	return string.format('|cff%02x%02x%02x%s|r',
		colors[standing].r * 255,
		colors[standing].g * 255,
		colors[standing].b * 255,
		label
	), colors[standing];
end

function module:GetFriendShipColorText(friendshipFactionID, standing)
	local standingLevel = C_GossipInfo.GetFriendshipReputationRanks(friendshipFactionID).currentLevel;
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
		[9] = colors[9], -- Paragon
	}

	if (friendshipFactionID == 1374 or friendshipFactionID == 1419 or friendshipFactionID == 1690 or friendshipFactionID == 1691 or friendshipFactionID == 2010 or friendshipFactionID == 2011) then -- Brawlers S1-S3
		friendshipColors = {
			[1] = colors[5], -- Rank 1
			[2] = colors[5], -- Rank 2
			[3] = colors[5], -- Rank 3
			[4] = colors[5], -- Rank 4
			[5] = colors[5], -- Rank 5
			[6] = colors[5], -- Rank 6
			[7] = colors[5], -- Rank 7
			[8] = colors[5], -- Rank 8
			[9] = colors[5], -- Rank 9
			[10] = colors[5], -- Rank 10
		}
	elseif (friendshipFactionID == 2371 or friendshipFactionID == 2372) then -- Brawlers S4/Current
		friendshipColors = {
			[1] = colors[5], -- Rank 1
			[2] = colors[5], -- Rank 2
			[3] = colors[5], -- Rank 3
			[4] = colors[5], -- Rank 4
			[5] = colors[5], -- Rank 5
			[6] = colors[5], -- Rank 6
			[7] = colors[5], -- Rank 7
			[8] = colors[5], -- Rank 8
		}
	elseif (friendshipFactionID == 2135) then -- Chromie
		friendshipColors = {
			[1] = colors[4], -- Whelpling
			[2] = colors[4], -- Temporal Trainee
			[3] = colors[5], -- Timehopper
			[4] = colors[5], -- Chrono-Friend
			[5] = colors[6], -- Bronze Ally
			[6] = colors[7], -- Epoch-Mender
			[7] = colors[8], -- Timelord
		}
	elseif (friendshipFactionID == 1357) then -- Nomi
		friendshipColors = {
			[1] = colors[4], -- Apprentice
			[2] = colors[4], -- Apprentice
			[3] = colors[5], -- Journeyman
			[4] = colors[6], -- Journeyman
			[5] = colors[7], -- Journeyman
			[6] = colors[8], -- Expert
		}
	elseif (friendshipFactionID == 2517 or friendshipFactionID == 2518) then -- Wrathion/Sabellian TO-DO: Confirm colors
		friendshipColors = {
			[1] = colors[4], -- Acquaintance
			[2] = colors[4], -- Cohort
			[3] = colors[5], -- Ally
			[4] = colors[6], -- Fang
			[5] = colors[7], -- Friend
			[6] = colors[8], -- True Friend
			[9] = colors[9], -- Paragon
		}
	elseif (friendshipFactionID == 2544 or friendshipFactionID == 2568 or friendshipFactionID == 2553 or friendshipFactionID == 2550 or friendshipFactionID == 2615) then -- Artisan's Consortium - Dragon Isles Branch / Glimmerogg Racer / Soridormi / Cobalt Assembly / Azerothian Archives
		friendshipColors = {
			[1] = colors[4], -- Neutral    -- Aspirational  -- Anomaly                   -- Empty    -- Junior
			[2] = colors[5], -- Preferred  -- Amateur       -- Future Friend             -- Low      -- Capable
			[3] = colors[6], -- Respected  -- Competent     -- Rift Mender               -- Medium   -- Learned
			[4] = colors[7], -- Valued     -- Skilled       -- Timewalker                -- High     -- Resident
			[5] = colors[8], -- Esteemed   -- Professional  -- Legend of the Multiverse  -- Maximum  -- Tenured
		}
	end

	if (friendshipColors[standingLevel] == nil) then
		return string.format('|cff%02x%02x%02x%s|r',
		colors[5].r * 255,
		colors[5].g * 255,
		colors[5].b * 255,
		standing
		), colors[5];
	end

	return string.format('|cff%02x%02x%02x%s|r',
		friendshipColors[standingLevel].r * 255,
		friendshipColors[standingLevel].g * 255,
		friendshipColors[standingLevel].b * 255,
		standing
	), friendshipColors[standingLevel];
end

function module:UPDATE_FACTION(event, ...)
	local name, standing, _, _, _, factionID = GetWatchedFactionInfo();
	module.levelUpRequiresAction = (factionID and C_Reputation.IsFactionParagon(factionID));
	
	local instant = false;
	if(name ~= module.Tracked or not name) then
		instant = true;
		module.AutoWatchUpdate = 0;
	end
	module.Tracked = name;
	
	module:SetStanding(factionID, standing);
	module:Refresh(instant);
end

local reputationPattern = FACTION_STANDING_INCREASED:gsub("%%s", "(.-)"):gsub("%%d", "(%%d*)%%");

function module:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match(reputationPattern);
	amount = tonumber(amount) or 0;
	
	if(not reputation or not module.recentReputations) then return end
	
	local isGuild = false;
	if(reputation == GUILD) then
		isGuild = true;
		
		local guildName = GetGuildInfo("player");
		if(guildName) then
			reputation = guildName;
		end
	end
	
	if(not module.recentReputations[reputation]) then
		module.recentReputations[reputation] = {
			amount = 0,
		};
	end
	
	module.recentReputations[reputation].amount = module.recentReputations[reputation].amount + amount;
	
	if(self.db.global.AutoWatch.Enabled and module.AutoWatchUpdate ~= 2) then
		local factionListIndex, factionID = module:GetReputationID(reputation);
		if(not factionListIndex) then return end
		
		if(self.db.global.AutoWatch.IgnoreInactive and IsFactionInactive(factionListIndex)) then return end
		if(self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[factionID] ~= nil) then return end
		if(self.db.global.AutoWatch.IgnoreGuild and isGuild) then return end
		
		module.AutoWatchUpdate = 1;
		module.AutoWatchRecentTimeout = 0.1;
		
		if(not module.AutoWatchRecent[reputation]) then
			module.AutoWatchRecent[reputation] = 0;
		end
		module.AutoWatchRecent[reputation] = module.AutoWatchRecent[reputation] + amount;
	end
end

function module:AllowedToBufferUpdate()
	return module.AutoWatchUpdate == 0;
end

function module:Update(elapsed)
	if (module.AutoWatchUpdate == 1) then
		if (module.AutoWatchRecentTimeout > 0.0) then
			module.AutoWatchRecentTimeout = module.AutoWatchRecentTimeout - elapsed;
		end
		
		if (module.AutoWatchRecentTimeout <= 0.0) then
			local selectedFaction = nil;
			local largestGain = 0;
			for faction, gain in pairs(module.AutoWatchRecent) do
				if (gain > largestGain) then
					selectedFaction = faction;
					largestGain = gain;
				end
			end
			
			local name = GetWatchedFactionInfo();
			if (selectedFaction ~= name) then
				local factionListIndex, factionID = module:GetReputationID(selectedFaction);
				if(factionListIndex) then
					SetWatchedFactionIndex(factionListIndex);
				end
				module.AutoWatchUpdate = 2;
			else
				module.AutoWatchUpdate = 0;
			end
			
			module.AutoWatchRecentTimeout = 0;
			wipe(module.AutoWatchRecent);
		end
	end
end
