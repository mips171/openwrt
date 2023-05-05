#!/usr/bin/env lua

local uci = require "uci"
local cjson = require "cjson"

X15G = "5G"

local function shell_exec(cmd)
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        return result:gsub("^%s*(.-)%s*$", "%1")
    end
    return nil
end

Model = shell_exec("cat /proc/device-tree/model")

OverdriveCache = ""

local function cacheOverdriveMode()
    local cursor = uci.cursor()
    return cursor:get("system", "telco", "overdrive")
end

local function restoreOverdriveMode(cachedValue)
    local cursor = uci.cursor()
    if not cachedValue or cachedValue ~= "" then
        -- lets assume it should be on
        cachedValue = "1"
    end
    cursor:set("system", "telco", "overdrive", cachedValue)
    cursor:commit("system", "telco")
end

local function disableOverdriveMode()
    local cursor = uci.cursor()
    cursor:set("system", "telco", "overdrive", "0")
    cursor:commit("system", "telco")
end

local function x15GPre()
    OverdriveCache = cacheOverdriveMode()
    disableOverdriveMode()

    shell_exec("rmmod qmi_wwan_q")
    shell_exec("/etc/init.d/modemmanager restart")
end

local function waitForModem()
    if Model and Model:find(X15G) then
        x15GPre()
        shell_exec("sleep 10")
    end

    local modemstatus

    local modemstatus_raw = shell_exec("mmcli -m any -J")
    if modemstatus_raw ~= nil then
        modemstatus = cjson.decode(modemstatus_raw)
    else
        -- Handle the case where modemstatus_raw is nil
        local count = 0
        local N = 1
        while not modemstatus.modem.dbuspath == "ModemManager" do
            print("Waiting for modem to become ready. This may take a moment.")
            shell_exec("sleep 5")
            count = count + N
            if count > 10 then
                shell_exec(
                    "/usr/bin/logger -t INFO 'Modem Firstboot: Restarting ModemManager after 10 attempts to find modem.'")
                shell_exec("/etc/init.d/modemmanager restart")
                count = 0
            end
        end
        shell_exec("sleep 2")
    end

    local simstatus_raw = shell_exec("mmcli -i any -J")
    local modemstatus_raw = shell_exec("mmcli -m any -J")

    return cjson.decode(modemstatus_raw), cjson.decode(simstatus_raw)
end

local function getOperatorInfo(modemStat, simStat)
    local failedReason = modemStat.modem.generic["state-failed-reason"]
    local operatorCode, operatorName
    if failedReason ~= "sim-missing" then
        operatorCode = simStat.sim.properties["operator-code"]
        operatorName = simStat.sim.properties["operator-name"]
    end
    return failedReason, operatorCode, operatorName
end

local function detectApn(operator, operator_name, model)
    local chosen_apn
    if operator == "50501" then
        if operator_name == "ALDImobile" then
            chosen_apn = "mdata.net.au"
        else
            -- override for Telstra X1 5G
            if model and model:find(X15G) then
                chosen_apn = "telstra.wap"
            else
                chosen_apn = "telstra.internet"
            end
        end
    elseif operator == "50502" then
        chosen_apn = "connect"
    elseif operator == "50503" then
        chosen_apn = "live.vodafone.com"
    elseif operator == "50506" then
        chosen_apn = "3netaccess"
    elseif operator == "53001" then
        chosen_apn = "vodafone"
    elseif operator == "53005" then
        chosen_apn = "internet"
    elseif operator == "53024" then
        chosen_apn = "internet"
    end
    print(string.format("Operator appears to be %s. Using APN: %s", operator, chosen_apn))
    return chosen_apn
end

local function setApnAndCommit(chosenApn)
    local cursor = uci.cursor()

    local telcoIsSet = cursor:get("system", "telco")
    if telcoIsSet ~= "" then
        shell_exec("uci set system.telco=telco")
    end

    cursor:set("system", "telco", "apn", chosenApn)
    cursor:commit("system")

    cursor:set("network", "mobile", "apn", chosenApn)
    cursor:commit("network.mobile.apn")
end

function Contains(p, target)
    for _, v in pairs(p) do
        if string.find(tostring(v), target) then
            return true
        end
    end
end

local function setModemModeIfRequired(modemStat)
    local modemModel = modemStat.modem.generic["model"]
    if modemModel == "EM12-G" then
        print("Modem is EM12-G. Modem should be in MBIM mode most of the time.")
        if not Contains(modemStat.modem.generic.ports, "mbim") then
            local msg = string.format("Modem may not be in MBIM mode. %s %s Setting modem in MBIM mode.",
                modemModel,
                tostring(modemStat.modem.generic.ports))
            print(msg)
            shell_exec("sleep 5")
            shell_exec("/bin/sh /usr/bin/modem_mbim.sh")
        end
    end
end

local function x15GPost()
    restoreOverdriveMode(OverdriveCache)

    shell_exec("insmod qmi_wwan_q")
    shell_exec("/etc/init.d/modemmanager restart")
end

local function setModemStatusReady()
    local cursor = uci.cursor()
    cursor:set("system", "telco", "modemstatus", "ready")
    cursor:commit("system")

    if Model and Model:find(X15G) then
        x15GPost()
    end
end

-- Main

ModemStatus, SimStatus = waitForModem()

if not ModemStatus then
    -- exit with an error
    return error("Could not get modem status")
end

if not SimStatus then
    -- exit with an error
    return error("Could not get SIM status")
end

local failedReason, operatorCode, operatorName = getOperatorInfo(ModemStatus, SimStatus)

if failedReason ~= "sim-missing" then
    local chosenApn = detectApn(operatorCode, operatorName)
    local currentApn = shell_exec("uci get system.telco.apn")

    if chosenApn ~= currentApn then
        setApnAndCommit(chosenApn)
    end
end

setModemModeIfRequired(ModemStatus)
setModemStatusReady()

return {
    detectApn = detectApn
}
