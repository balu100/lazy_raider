LazyRaider_isOpen = false
LazyRaider_AcceptInvite = false
LazyRaider_AcceptSummon = false
LazyRaider_LazyAcceptSummon = false
LazyRaider_AcceptRC = false
LazyRaider_LazyAcceptRC = false
LazyRaider_AcceptRes = false
LazyRaider_AcceptResNotCombat = false
LazyRaider_RC_status = ''

local waitTable = {};
local waitFrame = nil;

function LazyRaider_ToggleDisplay()
    if LazyRaider_isOpen then
        LazyRaider_MainFrame:Hide()
    else
        LazyRaider_MainFrame:Show()
    end
    LazyRaider_isOpen = not LazyRaider_isOpen
end

local addon = LibStub("AceAddon-3.0"):NewAddon("Bunnies", "AceConsole-3.0")

local bunnyLDB = LibStub("LibDataBroker-1.1"):NewDataObject("LazyRaider", {
type = "launcher",
text = "LazyRaider",
label="LazyRaider",
icon = "Interface\\Icons\\inv_elemental_primal_mana",
OnClick = LazyRaider_ToggleDisplay,
})
local icon = LibStub("LibDBIcon-1.0")

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("LazyRaiderDB", { profile = { minimap = { hide = false, }, }, })
    icon:Register("LazyRaider", bunnyLDB, self.db.profile.minimap) 
end

function LazyRaider_wait(delay, func, ...)
  if(type(delay)~="number" or type(func)~="function") then
    return false;
  end
  if(waitFrame == nil) then
    waitFrame = CreateFrame("Frame","WaitFrame", UIParent);
    waitFrame:SetScript("onUpdate",function (self,elapse)
      local count = #waitTable;
      local i = 1;
      while(i<=count) do
        local waitRecord = tremove(waitTable,i);
        local d = tremove(waitRecord,1);
        local f = tremove(waitRecord,1);
        local p = tremove(waitRecord,1);
        if(d>elapse) then
          tinsert(waitTable,i,{d-elapse,f,p});
          i = i + 1;
        else
          count = count - 1;
          f(unpack(p));
        end
      end
    end);
  end
  tinsert(waitTable,{delay,func,{...}});
  return true;
end

function LazyRaider_OnLoad()
    LazyRaider_MainFrame:RegisterEvent("PARTY_INVITE_REQUEST")
    LazyRaider_MainFrame:RegisterEvent("INCOMING_SUMMON_CHANGED")
    LazyRaider_MainFrame:RegisterEvent("READY_CHECK")
    LazyRaider_MainFrame:RegisterEvent("READY_CHECK_CONFIRM")
    LazyRaider_MainFrame:RegisterEvent("READY_CHECK_FINISHED")
    LazyRaider_MainFrame:RegisterEvent("RESURRECT_REQUEST")
    
    LazyRaider_MainFrame:SetScript("OnEvent", LazyRaider_OnEvent)

    LazyRaider_MainFrame_AcceptInviteText:SetText("Auto-accept party invite");
    LazyRaider_MainFrame_AcceptInvite.tooltip = "Automatically accepting all raid and party invites"; 

    LazyRaider_MainFrame_AcceptSummonText:SetText("Auto-accept summon");
    LazyRaider_MainFrame_AcceptSummon.tooltip = "Automatically accepting all summons";
    LazyRaider_MainFrame_LazyAcceptSummonText:SetText("Lazy accept");
    LazyRaider_MainFrame_LazyAcceptSummon.tooltip = "Summon will be accepted 1 second before the end";
    LazyRaider_MainFrame_LazyAcceptSummon:Disable()
    LazyRaider_MainFrame_LazyAcceptSummonText:SetTextColor(0.75,0.75,0.75,0.6)

    LazyRaider_MainFrame_AcceptRCText:SetText("Auto-accept ready check");
    LazyRaider_MainFrame_AcceptRC.tooltip = "Automatically accepting all ready checks";
    LazyRaider_MainFrame_LazyAcceptRCText:SetText("Lazy accept");
    LazyRaider_MainFrame_LazyAcceptRC.tooltip = "Ready check will be accepted 1 second before the end";
    LazyRaider_MainFrame_LazyAcceptRC:Disable()
    LazyRaider_MainFrame_LazyAcceptRCText:SetTextColor(0.75,0.75,0.75,0.6)

    LazyRaider_MainFrame_AcceptResText:SetText("Auto-accept resurrection");
    LazyRaider_MainFrame_AcceptRes.tooltip = "Automatically accepting all resurrections";  
    LazyRaider_MainFrame_AcceptResNotCombatText:SetText("Disable in combat");
    LazyRaider_MainFrame_AcceptResNotCombat.tooltip = "Resurrection will be accepted out of boss encounter only";
    LazyRaider_MainFrame_AcceptResNotCombat:Disable()
    LazyRaider_MainFrame_AcceptResNotCombatText:SetTextColor(0.75,0.75,0.75,0.6)

    local myButton = CreateFrame("Button", "LazyRaider_MainFrame_ToggleButton", LazyRaider_MainFrame, 'UIPanelButtonTemplate')
    myButton:SetSize(60,20)
    myButton:SetPoint("TOPLEFT",15,-220)
    myButton:SetText('Toggle')
    myButton:RegisterForClicks("LeftButtonUp")
    myButton:SetScript("OnClick", function() LazyRaider_ToggleRC_OnClick() end)

    LazyRaider_ChangeRCStatus()
end

function LazyRaider_OnEvent(self, event, ...)
    if event == "PARTY_INVITE_REQUEST" and LazyRaider_AcceptInvite then
        AcceptGroup()
        StaticPopup_Hide("PARTY_INVITE")
        print("|cFF78acffLazyRaider:|r Invite has been accepted")
    end

    if event == "INCOMING_SUMMON_CHANGED" and LazyRaider_AcceptSummon then
        local name = ...
        if name == "player" then
            if LazyRaider_LazyAcceptSummon then
                LazyRaider_wait(119, LazyRaider_AcceptSummonFn)
            else
                LazyRaider_AcceptSummonFn()
            end
        end
    end

    if event == "READY_CHECK" and LazyRaider_AcceptRC then
        LazyRaider_ChangeRCStatus("pending")
        if LazyRaider_LazyAcceptRC then
            local userName, timeout = ...
            LazyRaider_wait(timeout - 1, LazyRaider_AcceptRCFn)
        else
            LazyRaider_AcceptRCFn()
        end
    end

    if event == "READY_CHECK_CONFIRM" and LazyRaider_AcceptRC then
        local name, status = ...
        if (name == "player") then
            if status == true then
                LazyRaider_ChangeRCStatus("accepted")
            else
                LazyRaider_ChangeRCStatus("declined")
            end
        end
    end

    if event == "READY_CHECK_FINISHED" and LazyRaider_AcceptRC then
        LazyRaider_ChangeRCStatus()
    end

    if event == "RESURRECT_REQUEST" and LazyRaider_AcceptRes then
        if LazyRaider_AcceptResNotCombat then
            if not IsEncounterInProgress() then
                AcceptResurrect()
                print("|cFF78acffLazyRaider:|r Resurrection has been accepted")
            end
        else
            AcceptResurrect()
            print("|cFF78acffLazyRaider:|r Resurrection has been accepted")
        end
    end


end

function LazyRaider_AcceptRCFn()
    if ReadyCheckFrame:IsVisible() then
        ConfirmReadyCheck(1)
        ReadyCheckFrame:Hide()	
        LazyRaider_RC_status = 'accepted'
        LazyRaider_MainFrame_RCstatusText:SetText("|c39cc1000Accepted|r")
        print("|cFF78acffLazyRaider:|r Ready check has been accepted")
    end
end

function LazyRaider_AcceptSummonFn()
    if StaticPopup_Visible("CONFIRM_SUMMON") then
        print("|cFF78acffLazyRaider:|r Summon has been accepted")
    end
    C_SummonInfo.ConfirmSummon()
    StaticPopup_Hide("CONFIRM_SUMMON");
end


function LazyRaider_AcceptInvite_OnClick()
    LazyRaider_AcceptInvite = not LazyRaider_AcceptInvite
end

function LazyRaider_AcceptSummon_OnClick()
    LazyRaider_AcceptSummon = not LazyRaider_AcceptSummon
    if LazyRaider_AcceptSummon then
        LazyRaider_MainFrame_LazyAcceptSummon:Enable()
        LazyRaider_MainFrame_LazyAcceptSummonText:SetTextColor(1,1,1,1)
    else
        LazyRaider_MainFrame_LazyAcceptSummon:Disable()
        LazyRaider_MainFrame_LazyAcceptSummonText:SetTextColor(0.75,0.75,0.75,0.6)
    end
end

function LazyRaider_LazyAcceptSummon_OnClick()
    LazyRaider_LazyAcceptSummon = not LazyRaider_LazyAcceptSummon
end

function LazyRaider_AcceptRC_OnClick()
    LazyRaider_AcceptRC = not LazyRaider_AcceptRC
    if LazyRaider_AcceptRC then
        LazyRaider_MainFrame_LazyAcceptRC:Enable()
        LazyRaider_MainFrame_LazyAcceptRCText:SetTextColor(1,1,1,1)
    else
        LazyRaider_MainFrame_LazyAcceptRC:Disable()
        LazyRaider_MainFrame_LazyAcceptRCText:SetTextColor(0.75,0.75,0.75,0.6)
    end
end

function LazyRaider_LazyAcceptRC_OnClick()
    LazyRaider_LazyAcceptRC = not LazyRaider_LazyAcceptRC
end

function LazyRaider_AcceptRes_OnClick()
    LazyRaider_AcceptRes = not LazyRaider_AcceptRes
    if LazyRaider_AcceptRes then
        LazyRaider_MainFrame_AcceptResNotCombat:Enable()
        LazyRaider_MainFrame_AcceptResNotCombatText:SetTextColor(1,1,1,1)
    else
        LazyRaider_MainFrame_AcceptResNotCombat:Disable()
        LazyRaider_MainFrame_AcceptResNotCombatText:SetTextColor(0.75,0.75,0.75,0.6)
    end
end

function LazyRaider_AcceptResNotCombat_OnClick()
    LazyRaider_AcceptResNotCombat = not LazyRaider_AcceptResNotCombat
end

function LazyRaider_ToggleRC_OnClick()
    if LazyRaider_RC_status == 'accepted' then
        ConfirmReadyCheck(false)
        LazyRaider_ChangeRCStatus('declined')
    elseif LazyRaider_RC_status == 'declined' then
        ConfirmReadyCheck(1)
        LazyRaider_ChangeRCStatus('accepted')
    end
end

function LazyRaider_ChangeRCStatus(status)
    if (status == "pending") then
        LazyRaider_RC_status = "pending"
        LazyRaider_MainFrame_ToggleButton:Enable()
        LazyRaider_MainFrame_RCstatus:SetTextColor(1,1,1,1)
        LazyRaider_MainFrame_RCstatusText:SetText("|cffffbf1fPending|r")
    elseif (status == "accepted") then
        LazyRaider_RC_status = 'accepted'
        LazyRaider_MainFrame_RCstatusText:SetText("|cff39cc10Accepted|r")
    elseif (status == "declined") then
        LazyRaider_RC_status = 'declined'
        LazyRaider_MainFrame_RCstatusText:SetText("|cffff0000Declined|r")
    else
        LazyRaider_RC_status = ""
        LazyRaider_MainFrame_ToggleButton:Disable()
        LazyRaider_MainFrame_RCstatusText:SetText("")
        LazyRaider_MainFrame_RCstatus:SetTextColor(0.75,0.75,0.75,0.6)
    end
end
