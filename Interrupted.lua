-- Some of this addon is from another similar addon that I can't remember the name of,
-- specifically the getDistribution and getDistributionSetting methods are from somewhere
-- else, although I repurposed them and their implementation (I needed a touch of inspiration,
-- first time Lua writer and all that).

-- Addon written by Ivona, Terenas, EU.
-- detonator316@gmail.com

function Interrupted_OnLoad(self)
   self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

-- Array of raid marker symbols
local symbols = {"(triangle)", "(star)", "(circle)", "(diamond)", "(triangle)", "(moon)", "(square)", "(cross)", "(skull)"}

-- Spell ID's and text names of spell interrupts
local interrupts = {
	[1766] = "Kick",
	[6552] = "Pummel",
	[72] = "Shield Bash",
	[2139] = "Counterspell",
	[8042] = "Earth Shock",
	[32748] = "Deadly Throw Interrupt",
	[80964] = "Skull Bash (Bear)",
	[80965] = "Skull Bash (Cat)"
}

-- Guid and Time flags used for the throwing specialisation fix
local lastGUID, lastTime
-- Alias' for global methods
local GetTime = _G.GetTime
local UnitGUID = _G.UnitGUID
local UnitExists = _G.UnitExists

-- Skip flag for event parser, just so we don't have to reallocate it constantly
local skip = false
-- Current target icon ID
local currentTargetIcon

-- Determines where to send message depending upon player context
local function getDistributionSetting()
	local inInstance, instanceType = IsInInstance()
	if instanceType == "arena" then
		return "say"
	elseif instanceType == "pvp" then	
		return "say"
	elseif GetNumRaidMembers() > 0 then
		return "say"
	elseif GetNumPartyMembers() > 0 then
		return "say"
	else
		return "test"
	end
end

-- Performs a little additional logic on player location dependant 
-- text output
local function getDistribution(p)
	if p:lower() == "party" then
		return "SAY"
	elseif p:lower() == "raid" then
		return "SAY" 
	elseif p:lower() == "raidwarn" then
		return "SAY"
	elseif p:lower() == "group" then
		if GetNumRaidMembers() > 0 then 
			return "SAY" 
		end
		if GetNumPartyMembers() > 0 then 
			return "SAY" 
		end
	elseif p:lower() == "say" then
		return "SAY"
	elseif p:lower() == "yell" then
		return "SAY"
	else
		return "TEST"
	end
end

-- Wrapper function for sending text output
local function sendMessage(msg)
	-- Get the chat channel we're writing to
	local destination = getDistribution(getDistributionSetting())
	-- Don't output to say, as it's silly talking to yourself
	if destination ~= "TEST" then
		SendChatMessage(msg, destination)
	end
end

function Interrupted_OnEvent(self, event, ... )
	-- Variadic function spaff.
	local timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellID, spellName, _, missType = ...
	local bit_band, strsub, tonumber = bit.band, strsub, tonumber
	
	-- If this was a spell interrupt from the current player
	if srcGUID == UnitGUID("player") and eventtype == "SPELL_INTERRUPT" then
		-- yay more variadic function variable spam, jesus christ.
		local srcSpellId, srcSpellName, srcSpellSchool, dstSpellId, dstSpellName, dstSpellSchool = select(9, ...);

		-- Check whether we've had another interrupt from this player reported in the last
		-- half second, throwing spec generates a lot of spaff.
		skip = dstGUID == lastGUID and GetTime() - lastTime < 0.5
		-- Update the last target Guid and event time to the one we just parsed
		-- so we can have accurate data for the next event 
		lastGUID = dstGUID
		lastTime = GetTime()
		
		-- Only continue if neccesary
		if not skip then
			-- Get the current raid target icon if applicable
			if dstGUID == UnitGUID("target") then
				currentTargetIcon = GetRaidTargetIndex("target")
			elseif dstGUID == UnitGUID("focus") then
				currentTargetIcon = GetRaidTargetIndex("focus")
			elseif dstGUID == UnitGUID("mouseover") then
				currentTargetIcon = GetRaidTargetIndex("mouseover")
			else 
				currentTargetIcon = 0
			end
			
			-- If no icon is set on the current target, default to the "blank" entry at the start of the array
			if(currentTargetIcon == nil) then  
				currentTargetIcon = 0
			elseif currentTargetIcon > 0 then
				currentTargetIcon = currentTargetIcon + 1
			end
			symbol = symbols[currentTargetIcon]
			
			if symbol == nil then
				symbol = "-"
			end
			-- Write message to client
			sendMessage(string.format("Interrupted %s's %s %s", dstName, GetSpellLink(dstSpellId), symbol))
		end	
	elseif srcGUID == UnitGUID("player") and interrupts[spellID] and eventtype == "SPELL_MISSED" then
		-- Allocate miss message
		local reason
		-- Text formatting
		if missType == "IMMUNE" then
			reason = "Immune"
		elseif missType == "MISS" then
			reason = "Miss"
		end
		-- Write message to client
		sendMessage(string.format("%s failed on %s (%s)", spellName, dstName, reason))
	end

	if srcGUID == UnitGUID("player") and eventtype == "SPELL_DAMAGE" then
		if bit_band(dstFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 and tonumber(strsub(dstGUID, 6, 10), 16) == 5925 then
			local spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...
			sendMessage(string.format("Grounded %s", GetSpellLink(spellID)))
		end
		return
	end
end