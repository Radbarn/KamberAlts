-- Set to current version
local KAversion = "KamberAlts v1.2.1"
local KAname = "KamberAlts"

-- Set Currency IDs
local CONQUEST_CURRENCY_ID = 1602
local HONOR_CURRENCY_ID = 1792
local GEAR_CURRENCY_ID = 3008 --valorstones
local GEAR_CURRENCY_NAME = "VStones"

--Tooltip Texts
local headerTooltips = {
    ["Name"] = "The character's name\nClick to Sort by this column",
    ["2v2"] = "Your 2v2 rating\nClick to Sort by this column",
    ["3v3"] = "Your 3v3 rating\nClick to Sort by this column",
    ["SS"] = "Your Solo Shuffle rating\nClick to Sort by this column",
    ["SBG"] = "Your Solo RBG rating\nClick to Sort by this column",
    ["ThisWeek"] = "Your wins and games played this week\nClick to Sort by this column",
    ["PvP iLvl"] = "Your PvP item level\nClick to Sort by this column",
    ["PvE iLvl"] = "Your PvE item level\nClick to Sort by this column",
    ["Vaults"] = "Number of Vault rewards available\nSecond value is your highest ilvl reward achieved\nYes! means you have a vault to open\nClick to Sort by this column",
    ["Conquest"] = "Your current Conquest points\nClick to Sort by this column",
    ["Honor"] = "Your current Honor points\nClick to Sort by this column",
    [GEAR_CURRENCY_NAME] = "Your current Flightstones\nClick to Sort by this column",
    ["Server"] = "The server this character is on\nClick to Sort by this column",
}

--Define the KamberAltFrame so it can be referenced in various functions.  Frame settings are handled farther down
---@class KamberAltFrame:Frame
---@field title FontString
---@field TitleBg Texture
---@field InsetBg Texture
local KamberAltFrame = CreateFrame("Frame", "KamberAltFrame", UIParent, "BasicFrameTemplateWithInset")


--function to reset the weekly data to zero if the weekly reset has happened
local function ResetWeeklyData()
    for characterName, charInfo in pairs(KamberAltsDB) do
        if charInfo.weeklyPlayed2v2 then charInfo.weeklyPlayed2v2 = 0 end
        if charInfo.weeklyPlayed3v3 then charInfo.weeklyPlayed3v3 = 0 end
        if charInfo.weeklyPlayedSS then charInfo.weeklyPlayedSS = 0 end
        if charInfo.weeklyPlayedSBG then charInfo.weeklyPlayedSBG = 0 end
        if charInfo.weeklyPlayed then charInfo.weeklyPlayed = 0 end
        if charInfo.weeklyWon2v2 then charInfo.weeklyWon2v2 = 0 end
        if charInfo.weeklyWon3v3 then charInfo.weeklyWon3v3 = 0 end
        if charInfo.weeklyWonSS then charInfo.weeklyWonSS = 0 end
        if charInfo.weeklyWonSBG then charInfo.weeklyWonSBG = 0 end
        if charInfo.weeklyWon then charInfo.weeklyWon = 0 end
        if charInfo.vaults then
            charInfo.rewardsAvailable = charInfo.vaults > 0
            charInfo.vaults = 0
            charInfo.vaultilvl = 0
        end
    end
end

--weekly reset checking
local function CheckForWeeklyReset()
	--record the next weekly reset
	if KamberAltsSettings.NextReset == nil then
		KamberAltsSettings.NextReset = time() + C_DateAndTime.GetSecondsUntilWeeklyReset()
	end

	--perform maintenance if the weekly reset has past since last login
	if KamberAltsSettings.NextReset < time() then
		ResetWeeklyData()
		KamberAltsSettings.NextReset = time() + C_DateAndTime.GetSecondsUntilWeeklyReset()
        print("Weekly Reset has triggered!")
	end
end

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- Function to delete a character from history/saved data
-- must be given full charactername+realmname as its parameter
function DeleteCharacter(charName)
    StaticPopupDialogs["CONFIRM_DELETE_CHARACTER"] = {
        text = "Are you sure you want to delete\n" .. charName .. "?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function(self)
            local nameToDelete = charName
            local indexToDelete = nil
            for i, charData in pairs(KamberAltsDB) do
                if i == nameToDelete then
                    KamberAltsDB[i] = nil
                    print("Character " .. nameToDelete .. " deleted from KamberAlts.")
                    break
                end
            end
            UpdateKamberAltFrame() -- Refresh the UI
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("CONFIRM_DELETE_CHARACTER")
end


local function UpdateHighestVaultItemLevel(activities)
    local highestItemLevel = 0

    for _, activity in ipairs(activities) do
        if activity.progress >= activity.threshold then
            local ilvl = C_Item.GetDetailedItemLevelInfo(C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)) or 0
            if ilvl > highestItemLevel then
                    highestItemLevel = ilvl
            end
        end
    end

    return highestItemLevel
end

local function UpdateGreatVaultRewards()
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    local characterName = playerName .. "-" .. realmName
    local activities = C_WeeklyRewards.GetActivities()
    local unlockedRewards = 0

    for i, activityInfo in ipairs(activities) do
        if activityInfo.progress >= activityInfo.threshold then
            unlockedRewards = unlockedRewards + 1
        end
    end
    
    KamberAltsDB[characterName] = KamberAltsDB[characterName] or {}
    local charInfo = KamberAltsDB[characterName]
    
    charInfo.characterName = playerName
    charInfo.realmName = realmName
    
    charInfo.vaults = unlockedRewards
    charInfo.vaultilvl = UpdateHighestVaultItemLevel(activities)

    --check if the vault has rewards to pick up
    charInfo.rewardsAvailable = C_WeeklyRewards.HasAvailableRewards()
        
end

local function UpdateGearInfo()
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    local characterName = playerName .. "-" .. realmName
    local avgItemLevel, avgItemLevelEquipped, avgItemLevelPvp = GetAverageItemLevel()
    
    KamberAltsDB[characterName] = KamberAltsDB[characterName] or {}
    local charInfo = KamberAltsDB[characterName]
    
    charInfo.characterName = playerName
    charInfo.realmName = realmName
    
    charInfo.avgItemLevel = round(avgItemLevel, 1)
    charInfo.avgItemLevelEquipped = round(avgItemLevelEquipped, 1)
    charInfo.avgItemLevelPvp = round(avgItemLevelPvp, 1)
end

local function UpdatePvPInfo()
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    local characterName = playerName .. "-" .. realmName
    local rating2v2, seasonBest2v2, weeklyBest2v2, seasonPlayed2v2, seasonWon2v2, weeklyPlayed2v2, weeklyWon2v2, lastWeeksBest2v2, hasWon2v2, pvpTier2v2, ranking2v2, roundsSeasonPlayed2v2, roundsSeasonWon2v2, roundsWeeklyPlayed2v2, roundsWeeklyWon2v2 = GetPersonalRatedInfo(1) -- 2v2 bracket index is 1
    local rating3v3, seasonBest3v3, weeklyBest3v3, seasonPlayed3v3, seasonWon3v3, weeklyPlayed3v3, weeklyWon3v3, lastWeeksBest3v3, hasWon3v3, pvpTier3v3, ranking3v3, roundsSeasonPlayed3v3, roundsSeasonWon3v3, roundsWeeklyPlayed3v3, roundsWeeklyWon3v3 = GetPersonalRatedInfo(2) -- 3v3 bracket index is 2
    local ratingSS, seasonBestSS, weeklyBestSS, seasonPlayedSS, seasonWonSS, weeklyPlayedSS, weeklyWonSS, lastWeeksBestSS, hasWonSS, pvpTierSS, rankingSS, roundsSeasonPlayedSS, roundsSeasonWonSS, roundsWeeklyPlayedSS, roundsWeeklyWonSS = GetPersonalRatedInfo(7) -- solo arena bracket index is 7
    local ratingSBG, seasonBestSBG, weeklyBestSBG, seasonPlayedSBG, seasonWonSBG, weeklyPlayedSBG, weeklyWonSBG, lastWeeksBestSBG, hasWonSBG, pvpTierSBG, rankingSBG, roundsSeasonPlayedSBG, roundsSeasonWonSBG, roundsWeeklyPlayedSBG, roundsWeeklyWonSBG = GetPersonalRatedInfo(9) -- solo RBG bracket index is 9
    
    KamberAltsDB[characterName] = KamberAltsDB[characterName] or {}
    local charInfo = KamberAltsDB[characterName]

    charInfo.characterName = playerName
    charInfo.realmName = realmName
    
	charInfo.rating2v2 = rating2v2
	charInfo.rating3v3 = rating3v3
	charInfo.ratingSS = ratingSS
    charInfo.ratingSBG = ratingSBG
	charInfo.weeklyPlayed2v2 = weeklyPlayed2v2
	charInfo.weeklyPlayed3v3 = weeklyPlayed3v3
	charInfo.weeklyPlayedSS = weeklyPlayedSS
    charInfo.weeklyPlayedSBG = weeklyPlayedSBG
	charInfo.weeklyPlayed = weeklyPlayed2v2 + weeklyPlayed3v3 + weeklyPlayedSS + weeklyPlayedSBG
	charInfo.weeklyWon2v2 = weeklyWon2v2
	charInfo.weeklyWon3v3 = weeklyWon3v3
	charInfo.weeklyWonSS = weeklyWonSS
    charInfo.weeklyWonSBG = weeklyWonSBG
	charInfo.weeklyWon = weeklyWon2v2 + weeklyWon3v3 + weeklyWonSS + weeklyWonSBG
end

local function UpdateCurrencyInfo()
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    local characterName = playerName .. "-" .. realmName
    local currency = {} -- initialize currency table
    currency["conquest"] = C_CurrencyInfo.GetCurrencyInfo(CONQUEST_CURRENCY_ID).quantity
    currency["honor"] = C_CurrencyInfo.GetCurrencyInfo(HONOR_CURRENCY_ID).quantity
    currency["gear"] = C_CurrencyInfo.GetCurrencyInfo(GEAR_CURRENCY_ID).quantity
    currency["gearName"] = GEAR_CURRENCY_NAME
    
    KamberAltsDB[characterName] = KamberAltsDB[characterName] or {}
    local charInfo = KamberAltsDB[characterName]

    charInfo.characterName = playerName
    charInfo.realmName = realmName
    
    charInfo.currency = currency
    
end




-- Event handling
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("COMBAT_RATING_UPDATE")
events:RegisterEvent("WEEKLY_REWARDS_UPDATE")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(10, function()
			UpdateGearInfo()
			UpdateCurrencyInfo()
			UpdatePvPInfo()
            UpdateGreatVaultRewards()
            CheckForWeeklyReset()
		end)
        events:UnregisterEvent("PLAYER_LOGIN")
	elseif event == "CURRENCY_DISPLAY_UPDATE" then
		UpdateCurrencyInfo()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		UpdateGearInfo()
	elseif event == "COMBAT_RATING_UPDATE" then
		UpdatePvPInfo()
	elseif event == "WEEKLY_REWARDS_UPDATE" then
		UpdateGreatVaultRewards()
	end
    if event == "ADDON_LOADED" and arg1 == KAname then
        -- Initialize saved variables if non-existent
        KamberAltsDB = KamberAltsDB or {}
        KamberAltsSettings = KamberAltsSettings or {}
        KamberAltsSettings.minimap = KamberAltsSettings.minimap or { hide = false }

        if not KamberAltsSettings.KAversion or KamberAltsSettings.KAversion ~= KAversion then
            print("New Version Detected -- Welcome to " .. KAversion)
            KamberAltsSettings.KAversion = KAversion
        end
        -- Set default sort method
        if KamberAltsSettings.SortMethod == nil then
            KamberAltsSettings.SortMethod = "Name"
        end

    -- Assuming you have a table for your addon's settings, including minimap icon position
        local LibDBIcon = LibStub("LibDBIcon-1.0")

        local minimapIconLDB = LibStub("LibDataBroker-1.1"):NewDataObject("KamberAlts", {
            type = "launcher",
            text = "KamberAlts",
            icon = "Interface\\AddOns\\KamberAlts\\KamberAlts_Icon.tga",
            OnClick = function(self, button)
                if button == "LeftButton" then
                    if KamberAltFrame:IsShown() then
                        KamberAltFrame:Hide()
                    else
                        UpdateGearInfo()
                        UpdateCurrencyInfo()
                        UpdatePvPInfo()
                        UpdateGreatVaultRewards()
                        UpdateKamberAltFrame() -- Function to update the frame contents
                        KamberAltFrame:Show()
                    end
                end
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                tooltip:AddLine(KAversion)
                tooltip:AddLine("Tracks your Alts' progress this week.")
                -- Add more lines as needed
            end,
            })
        LibDBIcon:Register("KamberAlts", minimapIconLDB, KamberAltsSettings.minimap)
        events:UnregisterEvent("ADDON_LOADED")
    elseif event ~= "PLAYER_LOGIN" then
        CheckForWeeklyReset()
    end
end)

--WINDOW SIZING
-- xSpacing is the default distance between columns
local xSpacing = 70
local xWindowSize = 1000
local yWindowSize = 400

    
--Create basic display window
--KamberAltFrame was defined at the top of this file
KamberAltFrame:SetSize(xWindowSize, yWindowSize) -- Width, Height
KamberAltFrame:SetPoint("CENTER") -- Position on the screen
KamberAltFrame:Hide() -- Initially hidden

KamberAltFrame.title = KamberAltFrame:CreateFontString(nil, "OVERLAY")
KamberAltFrame.title:SetFontObject("GameFontHighlight")
KamberAltFrame.title:SetPoint("LEFT", KamberAltFrame.TitleBg, "LEFT", 5, 0)
KamberAltFrame.title:SetText("Kamber Alts")

KamberAltFrame:SetMovable(true)
KamberAltFrame:EnableMouse(true)

KamberAltFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving()
    end
end)

KamberAltFrame:SetScript("OnMouseUp", function(self, button)
    self:StopMovingOrSizing()
end)


-- Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", nil, KamberAltFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", KamberAltFrame.InsetBg, "TOPLEFT", 4, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", KamberAltFrame.InsetBg, "BOTTOMRIGHT", -3, 4)
scrollFrame:SetClipsChildren(true)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(1, 1) -- Dummy size, will be updated dynamically
scrollFrame:SetScrollChild(scrollChild)

local function SortTable(a, b)
	if KamberAltsSettings.SortMethod == "Name" then
		return (a.charInfo.characterName or "") < (b.charInfo.characterName or "")
	elseif KamberAltsSettings.SortMethod == "2v2" then                      -- sort by rating
		return (a.charInfo.rating2v2 or 0) > (b.charInfo.rating2v2 or 0)
	elseif KamberAltsSettings.SortMethod == "3v3" then                      -- sort by rating
		return (a.charInfo.rating3v3 or 0) > (b.charInfo.rating3v3 or 0)
	elseif KamberAltsSettings.SortMethod == "SS" then                      -- sort by rating
		return (a.charInfo.ratingSS or 0) > (b.charInfo.ratingSS or 0)
	elseif KamberAltsSettings.SortMethod == "SBG" then                      -- sort by rating
		return (a.charInfo.ratingSBG or 0) > (b.charInfo.ratingSBG or 0)
	elseif KamberAltsSettings.SortMethod == "ThisWeek" then             -- sort by win %
		local x, y
        if (a.charInfo.weeklyPlayed or 0) == 0 then
            x = 0
        else
            x = (a.charInfo.weeklyWon or 0) / (a.charInfo.weeklyPlayed or 1)
        end
        if (b.charInfo.weeklyPlayed or 0) == 0 then
            y = 0
        else
            y = (b.charInfo.weeklyWon or 0) / (b.charInfo.weeklyPlayed or 1)
        end
        return (x) > (y)
	elseif KamberAltsSettings.SortMethod == "Conquest" then
		return (a.charInfo.currency.conquest or 0) > (b.charInfo.currency.conquest or 0)
	elseif KamberAltsSettings.SortMethod == "Honor" then
		return (a.charInfo.currency.honor or 0) > (b.charInfo.currency.honor or 0)
	elseif KamberAltsSettings.SortMethod == "PvP iLvl" then
		return (a.charInfo.avgItemLevelPvp or 0) > (b.charInfo.avgItemLevelPvp or 0)
	elseif KamberAltsSettings.SortMethod == "PvE iLvl" then
		return (a.charInfo.avgItemLevel or 0) > (b.charInfo.avgItemLevel or 0)
	elseif KamberAltsSettings.SortMethod == "Vaults" then
		return (a.charInfo.vaultilvl or 0) > (b.charInfo.vaultilvl or 0)
	elseif KamberAltsSettings.SortMethod == GEAR_CURRENCY_NAME then
		return (a.charInfo.currency.gear or 0) > (b.charInfo.currency.gear or 0)
	elseif KamberAltsSettings.SortMethod == "Server" then
		return (a.charInfo.realmName or 0) > (b.charInfo.realmName or 0)
	else
		-- reset to default "name" sorting if an invalid sort type is saved
		KamberAltsSettings.SortMethod = "name"
		return (a.charName or "") < (b.charName or "")
	end
end

local function CreateHeaderButton(parent, text, xOffset, sortKey, xSpacing)
--- @class CustomButton:Button
--- @field text FontString
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(xSpacing, 20)  -- Adjust the size as needed
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 0)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetAllPoints()
    button.text:SetText(text)
    button.text:SetJustifyH("LEFT")

    button:SetScript("OnClick", function()
		KamberAltsSettings.SortMethod = sortKey
		--print("changing sort method to " .. sortKey)
		UpdateKamberAltFrame()
    end)

        -- Tooltip setup
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:AddLine(headerTooltips[text] or "")
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return button
end

function UpdateKamberAltFrame()

	-- sort the data table for display
	local sortable = {}
	for characterName, charInfo in pairs(KamberAltsDB) do
		table.insert(sortable, {charName = characterName, charInfo = charInfo})
	end
	table.sort(sortable, SortTable)

-- Clear existing rows to prevent overlap
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

-- Column headers (both titles and sortKeys are the same)
    local headers = {"Name", "2v2", "3v3", "SS", "SBG", "ThisWeek", "PvP iLvl", "PvE iLvl", "Vaults", "Conquest", "Honor", GEAR_CURRENCY_NAME, "Server", ""}

-- Create header
    local headerRow = CreateFrame("Frame", nil, scrollChild)
    headerRow:SetSize(xWindowSize, 20)
    headerRow:SetPoint("TOPLEFT", 0, 0)

    local xOffset = 0
    for i, header in ipairs(headers) do
		CreateHeaderButton(headerRow, header, xOffset, header, xSpacing)
		xOffset = xOffset + xSpacing -- Increase offset for the next column
    end

    -- Create rows for each character
    local yOffset = -20 -- Start just below the header
    for i, entry in ipairs(sortable) do
        local row = CreateFrame("Frame", nil, scrollChild)
        local colnum = 0
        row:SetSize(xWindowSize, 20)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        nameText:SetText(entry.charInfo.characterName)
        
        colnum = colnum + 1
        
        -- 2v2 Rating
        local rating2v2Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rating2v2Text:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        rating2v2Text:SetText(entry.charInfo.rating2v2 or "0")
        colnum = colnum + 1
        
        -- 3v3 Rating
        local rating3v3Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rating3v3Text:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        rating3v3Text:SetText(entry.charInfo.rating3v3 or "0")
        colnum = colnum + 1
        
        -- SS Rating
        local ratingSSText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ratingSSText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        ratingSSText:SetText(entry.charInfo.ratingSS or "0")
        colnum = colnum + 1

        -- SBG Rating
        local ratingSBGText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ratingSBGText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        ratingSBGText:SetText(entry.charInfo.ratingSBG or "0")
        colnum = colnum + 1
        
        -- Games This Week
        local gtwText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local gtwGames = (entry.charInfo.weeklyPlayed or 0)
        local gtwWins = (entry.charInfo.weeklyWon or 0)
        gtwText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        gtwText:SetText(gtwWins .. " / " .. gtwGames)
        colnum = colnum + 1
        
        -- PvP Item Level
        local pvpILvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pvpILvlText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        pvpILvlText:SetText(entry.charInfo.avgItemLevelPvp or "0")
        colnum = colnum + 1
        
        -- PvE Item Level
        local pveILvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pveILvlText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        pveILvlText:SetText(entry.charInfo.avgItemLevel or "0")
        colnum = colnum + 1

         -- Vault Rewards
        local vaultText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        vaultText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        if entry.charInfo.rewardsAvailable then
                vaultText:SetTextColor(0.1, 0.9, 0.1, 1) -- R, G, B, A
                vaultText:SetText("Yes!")
            else
                if entry.charInfo.vaults == 0 or not entry.charInfo.vaults then
                    vaultText:SetTextColor(0.5, 0.5, 0.5, 1) -- R, G, B, A
                    vaultText:SetText("0")    
                else
                    vaultText:SetText((entry.charInfo.vaults or "0") .. " | " .. (entry.charInfo.vaultilvl or "0"))
                end
            end        
        colnum = colnum + 1

        -- Conquest
        local conquestText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        conquestText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        conquestText:SetText(entry.charInfo.currency and entry.charInfo.currency.conquest or "0")
        colnum = colnum + 1
        
        -- Honor
        local honorText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        honorText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        honorText:SetText(entry.charInfo.currency and entry.charInfo.currency.honor or "0")
        colnum = colnum + 1

        -- Gear Tokens
        local gearText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gearText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        if entry.charInfo.currency.gearName == GEAR_CURRENCY_NAME then
            gearText:SetText(entry.charInfo.currency and entry.charInfo.currency.gear or "0")
        else 
            gearText:SetText("")
        end
        colnum = colnum + 1
        
        -- Server
        local servernameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        servernameText:SetPoint("TOPLEFT", row, "TOPLEFT", xSpacing*colnum, 0)
        servernameText:SetText(entry.charInfo.realmName or "")
        colnum = colnum + 1

        -- Delete Button
        local deleteButton = CreateFrame("Button", "DeleteButton"..i, row, "UIPanelButtonTemplate")
        deleteButton:SetSize(20, 20)
        deleteButton:SetText("X")
        deleteButton:SetPoint("TOPLEFT", row, "TOPLEFT", (xSpacing*colnum) + 30, 5)
        deleteButton:SetScript("OnClick", function()
            DeleteCharacter(entry.charInfo.characterName .. "-" .. entry.charInfo.realmName)
        end)
            -- Tooltip setup
            deleteButton:SetScript("OnEnter", function()
                GameTooltip:SetOwner(deleteButton, "ANCHOR_TOP")
                GameTooltip:AddLine("Click to forget " .. entry.charInfo.characterName or "")
                GameTooltip:Show()
            end)
            deleteButton:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

    
        colnum = colnum + 1
        
        yOffset = yOffset - 20 -- Move down for the next row
    end
    scrollChild:SetSize(xWindowSize, -yOffset) -- Update the scroll child size to fit the content
end

--allows the escape key to close the window
tinsert(UISpecialFrames, "KamberAltFrame")
