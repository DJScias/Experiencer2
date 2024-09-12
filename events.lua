------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

function Addon:PLAYER_REGEN_DISABLED()

end

function Addon:UNIT_AURA()
	Addon:RefreshBar();
end

local hiddenForPetBattle = false;

function Addon:PET_BATTLE_OPENING_START()
	if ExperiencerFrameBars:IsVisible() then
		hiddenForPetBattle = true;
		Addon:HideBar();
	end
end

function Addon:PET_BATTLE_CLOSE()
	if hiddenForPetBattle then
		Addon:ShowBar();
		hiddenForPetBattle = false;
	end
end
