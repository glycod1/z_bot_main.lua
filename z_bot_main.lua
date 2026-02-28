-- ╔══════════════════════════════════════════════════════════════════╗
-- ║           THE GANGS  —  Cherax Discord Bridge  v7.7             ║
-- ║                    Made By Nasser                               ║
-- ║  Place in: C:\Users\Master\Documents\Cherax\Lua                 ║
-- ║  FIXED: Brute force blocking - closes overlay for 4 full seconds║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── NATIVE HELPERS ────────────────────────────────────────────
local function N_GetPlayerPed(playerId)
    return Natives.InvokeInt(0x50FAC3A3E030A6E1, playerId)
end
local function N_DoesEntityExist(entity)
    return Natives.InvokeBool(0x7239B21A38F536BA, entity)
end
local function N_GetEntityCoords(entity)
    local x, y, z = Natives.InvokeV3(0x3FEF770D40960D5A, entity, true)
    return x, y, z
end
local function N_RequestControl(entity)
    return Natives.InvokeBool(0xB69317BF5E782347, entity)
end
local function N_SetEntityHasGravity(entity, toggle)
    Natives.InvokeVoid(0x4A4722448F18EEF5, entity, toggle)
end
local function N_SetEntityVelocity(entity, x, y, z)
    Natives.InvokeVoid(0x1C99BB7B6E96D16F, entity, x, y, z)
end
local function N_AddExplosion(x, y, z, expType, noDamage)
    -- Use Cherax GTA.AddExplosion — bypasses OOS restrictions, works on remote players
    local ok = pcall(function()
        local pos = V3.New(x, y, z)
        local args = CExplosionArgs.New(expType, pos)
        args.IsLocalOnly = false
        args.NoDamage = (noDamage == true)
        args.MakeSound = true
        GTA.AddExplosion(args)
    end)
    if not ok then
        -- Fallback to native (local only)
        Natives.InvokeVoid(0xE3AD2BDBAEE269AC, x, y, z, expType, 1.0, true, false, 1.0, noDamage)
    end
end
local function N_IsPedInVehicle(ped)
    return Natives.InvokeBool(0x997ABD671D25CA0B, ped, false)
end
local function N_GetPedVehicle(ped)
    return Natives.InvokeInt(0x9A9112A0FE9A4713, ped, false)
end
local function N_SetEntityCoords(entity, x, y, z)
    Natives.InvokeVoid(0x239A3351AC1DA385, entity, x, y, z, false, false, false)
end
local function N_FreezeEntityPosition(entity, toggle)
    Natives.InvokeVoid(0x428CA6DBD1094446, entity, toggle)
end
local function N_SetPedToRagdoll(ped, duration)
    Natives.InvokeVoid(0xAE99FB955581844A, ped, duration, duration, 0, false, false, false)
end
local function N_RemoveAllPedWeapons(ped)
    Natives.InvokeVoid(0xF25DF915FA38C5F3, ped, true)
end
local function N_GetEntityModel(entity)
    return Natives.InvokeInt(0x9F47B058362C84B5, entity)
end
local function N_GetVehicleDisplayName(model)
    return Natives.InvokeString(0xB215AAC32D25D019, Natives.InvokeInt(0xD24D37CC275948CC, model))
end
local function N_GetVehicleEngineHealth(vehicle)
    return Natives.InvokeFloat(0xC45D23BAF168AAB8, vehicle)
end
local function N_SetVehicleEngineHealth(vehicle, health)
    Natives.InvokeVoid(0x45F6D8EEF34ABEF1, vehicle, health)
end
local function N_SetVehicleTyreBurst(vehicle, wheel, onRim)
    Natives.InvokeVoid(0xEC4B4B3B9D0F27A3, vehicle, wheel, onRim, 1000.0)
end
local function N_GetPedLastVehicle(ped)
    return Natives.InvokeInt(0xB6B989A1A60B87C0, ped)
end
-- Use Cherax CPed.LastVehicle (bypasses failing native) — pid=player index
local function GetLastVehicleForPlayer(pid)
    local ok, handle = pcall(function()
        local cped = Players.GetCPed(pid)
        if not cped then error("no CPed") end
        local lv = cped.LastVehicle
        if not lv then error("no LastVehicle") end
        local ptr = lv:GetAddress()
        if not ptr or ptr == 0 then error("zero address") end
        local h = GTA.PointerToHandle(ptr)
        if not h or h == 0 then error("PointerToHandle failed") end
        return h
    end)
    if ok and handle and handle ~= 0 then return handle, nil end
    -- Fallback: native (may fail on some Cherax builds)
    local h2 = Natives.InvokeInt(0xB6B989A1A60B87C0, ped)
    if h2 and h2 ~= 0 then return h2, nil end
    return nil, "No last vehicle found for this player"
end
local function N_NetworkGetPlayerIndex(ped)
    return Natives.InvokeInt(0x9873E404B59B6F, ped)
end
local function N_SetPlayerWantedLevel(player, level)
    Natives.InvokeVoid(0x39FF19C64EF7DA5B, player, level, false)
    Script.Yield(80)
    Natives.InvokeVoid(0xE0A7D1E497FFCD6F, player, false)
end
-- Spectate: 0x31E0D2A977F11552 = SPECTATE_NETWORK_PLAYER, 0x30194186056938E1 = SET_SPECTATING
local function N_NetworkSetSpectating(toggle)
    Natives.InvokeVoid(0xE60B64C2F41EF5CA, toggle)
end
local function N_NetworkSpectatePlayer(pid, toggle)
    Natives.InvokeVoid(0x31E0D2A977F11552, pid, toggle)
end

-- HUD/Menu natives for Social Club overlay (ADDED v7.3)
local function N_ActivateFrontendMenu(menuhash, togglePause, component)
    Natives.InvokeVoid(0xEF01D36B9C9D0C7B, menuhash, togglePause, component)
end
local function N_IsPauseMenuActive()
    return Natives.InvokeBool(0xB0034A223497FFCB)
end
local function N_SetFrontendActive(active)
    Natives.InvokeVoid(0x745711A75AB09277, active)
end

-- ── Win32 keypress via user32.dll export table walk ───────────
-- Walks user32.dll's PE export table to find keybd_event address,
-- then calls it directly to simulate the Home key press.
local _keybdEventAddr = nil
local function getExportAddr(moduleName, funcName)
    local ok0, base = pcall(Memory.GetBaseAddress, moduleName)
    if not ok0 or not base or base == 0 then return nil end
    local ok1, peOffset = pcall(Memory.ReadInt, base + 0x3C)
    if not ok1 or peOffset == 0 then return nil end
    -- PE sig(4) + COFF header(20) + opt header export dir offset(0x70) = 0x88
    local ok2, edRVA = pcall(Memory.ReadInt, base + peOffset + 0x88)
    if not ok2 or edRVA == 0 then return nil end
    local ed        = base + edRVA
    local numNames  = Memory.ReadInt(ed + 0x18)
    local funcTable = base + Memory.ReadInt(ed + 0x1C)
    local nameTable = base + Memory.ReadInt(ed + 0x20)
    local ordTable  = base + Memory.ReadInt(ed + 0x24)
    for i = 0, numNames - 1 do
        local ok3, nameRVA = pcall(Memory.ReadInt, nameTable + i * 4)
        if ok3 and nameRVA ~= 0 then
            local ok4, name = pcall(Memory.ReadString, base + nameRVA)
            if ok4 and name == funcName then
                local ordinal = Memory.ReadShort(ordTable + i * 2)
                local funcRVA = Memory.ReadInt(funcTable + ordinal * 4)
                return base + funcRVA
            end
        end
    end
    return nil
end
local function pressHomeKey()
    if not _keybdEventAddr then
        _keybdEventAddr = getExportAddr("user32.dll", "keybd_event")
    end
    if _keybdEventAddr then
        -- keybd_event(VK_HOME=0x24, scan=0, KEYEVENTF_KEYDOWN=0, extra=0)
        pcall(Memory.LuaCallCFunction, _keybdEventAddr, 0x24, 0, 0, 0)
        Script.Yield(50)
        -- keybd_event(VK_HOME=0x24, scan=0, KEYEVENTF_KEYUP=2, extra=0)
        pcall(Memory.LuaCallCFunction, _keybdEventAddr, 0x24, 0, 2, 0)
    end
end

-- ── CONFIG ────────────────────────────────────────────────────
local BRIDGE = {
    dir        = "C:\\Users\\Master\\Desktop\\cherax-discord-bot",
    pollMs     = 300,
    statusMs   = 5000,
    maxLog     = 50,
    vehicleDir = "C:\\Users\\Master\\Documents\\Cherax\\Vehicles",
}
BRIDGE.cmdFile       = BRIDGE.dir .. "\\commands.json"
BRIDGE.respFile      = BRIDGE.dir .. "\\responses.json"
BRIDGE.statFile      = BRIDGE.dir .. "\\status.json"
BRIDGE.logFile       = BRIDGE.dir .. "\\bridge_log.txt"
BRIDGE.featFile      = BRIDGE.dir .. "\\feature_names.txt"
BRIDGE.carsFile      = BRIDGE.dir .. "\\saved_cars.json"
BRIDGE.queueFile     = BRIDGE.dir .. "\\queue.json"
BRIDGE.heistStatFile = BRIDGE.dir .. "\\heist_status.json"
BRIDGE.dmCmdFile     = BRIDGE.dir .. "\\dm_commands.json"
BRIDGE.settingsFile  = BRIDGE.dir .. "\\bot_settings.json"

local FEAT_SUPERDRIVE    = "SuperDrive"
local FEAT_LIGHTNINGMODE = "LightningMode"

-- ── SAFE GLOBALS ──────────────────────────────────────────────
detectedModders    = detectedModders    or {}
State              = State              or {}
State.vehicleLoops = State.vehicleLoops or {}
State.godMode      = State.godMode      or false
State.vehicleGod   = State.vehicleGod   or false
State.spectating   = State.spectating   or false
State.spectatePid  = State.spectatePid  or nil
bridgeEventIds     = bridgeEventIds     or {}

-- ── FRIEND REQUEST QUEUE ──────────────────────────────────────
pendingFriendRequests = pendingFriendRequests or {}

-- ── LOG ───────────────────────────────────────────────────────
bridgeLog       = bridgeLog or {}
local autoScroll = true
local testUsername = ""

local function addLog(cmd, params, ok, msg, src)
    table.insert(bridgeLog, 1, {
        time    = os.date("%H:%M:%S"),
        command = cmd or "?",
        params  = params or {},
        success = ok,
        message = msg or "",
        source  = src or "discord",
    })
    while #bridgeLog > BRIDGE.maxLog do table.remove(bridgeLog) end
    pcall(function()
        local line = string.format("[%s %s] [%s] [%s] %s\n",
            os.date("%Y-%m-%d"), os.date("%H:%M:%S"),
            ((src or "discord"):upper()), (ok and "OK" or "FAIL"), msg or "")
        FileMgr.WriteFileContent(BRIDGE.logFile, line, true)
    end)
    pcall(function()
        if ok then Logger.Log(eLogColor.GREEN, "[The Gangs]", tostring(msg))
        else       Logger.Log(eLogColor.RED,   "[The Gangs]", tostring(msg)) end
    end)
end

-- ── JSON ──────────────────────────────────────────────────────
local json = {}
local function jSkip(s, i)
    while i <= #s do
        local b = s:byte(i)
        if b==32 or b==9 or b==10 or b==13 then i=i+1 else break end
    end
    return i
end
local jParseValue
local function jParseString(s, i)
    i = i + 1
    local parts = {}
    while i <= #s do
        local c = s:sub(i, i)
        if c == '"' then return table.concat(parts), i + 1
        elseif c == '\\' then
            i = i + 1
            local ec = s:sub(i, i)
            local esc = {['"']='"',['\\']='\\',['/']=  '/',['n']='\n',['r']='\r',['t']='\t'}
            parts[#parts+1] = esc[ec] or ec
        else parts[#parts+1] = c end
        i = i + 1
    end
    return table.concat(parts), i
end
local function jParseArray(s, i)
    i = i + 1; local arr = {}; i = jSkip(s, i)
    if s:sub(i,i) == ']' then return arr, i+1 end
    while i <= #s do
        local val, ni = jParseValue(s, i); arr[#arr+1] = val; i = jSkip(s, ni)
        local c = s:sub(i,i)
        if c == ']' then return arr, i+1 end
        if c == ',' then i = jSkip(s, i+1) end
    end
    return arr, i
end
local function jParseObject(s, i)
    i = i + 1; local obj = {}; i = jSkip(s, i)
    if s:sub(i,i) == '}' then return obj, i+1 end
    while i <= #s do
        i = jSkip(s, i)
        local key, ni = jParseString(s, i); i = jSkip(s, ni); i = i+1; i = jSkip(s, i)
        local val, ni2 = jParseValue(s, i); obj[key] = val; i = jSkip(s, ni2)
        local c = s:sub(i,i)
        if c == '}' then return obj, i+1 end
        if c == ',' then i = jSkip(s, i+1) end
    end
    return obj, i
end
jParseValue = function(s, i)
    i = jSkip(s, i); local c = s:sub(i, i)
    if     c == '"' then return jParseString(s, i)
    elseif c == '{' then return jParseObject(s, i)
    elseif c == '[' then return jParseArray(s, i)
    elseif c == 't' then return true,  i+4
    elseif c == 'f' then return false, i+5
    elseif c == 'n' then return nil,   i+4
    else
        local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
        if num then return tonumber(num), i+#num end
        return nil, i+1
    end
end
function json.decode(s)
    if not s or s == "" then return nil end
    local ok, val = pcall(function() local v = jParseValue(s, 1); return v end)
    if ok then return val end; return nil
end
function json.encode(val)
    local t = type(val)
    if t=="nil"     then return "null" end
    if t=="boolean" then return tostring(val) end
    if t=="number"  then return tostring(val) end
    if t=="string"  then return '"'..val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','')..'"' end
    if t=="table" then
        local isArr, n = true, 0
        for k in pairs(val) do n=n+1; if type(k)~="number" then isArr=false end end
        if isArr and n==#val then
            local p={}; for _,v in ipairs(val) do p[#p+1]=json.encode(v) end
            return "["..table.concat(p,",").."]"
        end
        local p={}
        for k,v in pairs(val) do p[#p+1]=json.encode(tostring(k))..":"..json.encode(v) end
        return "{"..table.concat(p,",").."}"
    end
    return '"[?]"'
end

-- ── FILE I/O ──────────────────────────────────────────────────
local function readJson(path)
    local ok, raw = pcall(FileMgr.ReadFileContent, path)
    if not ok or not raw or raw == "" then return {} end
    local ok2, val = pcall(json.decode, raw)
    if ok2 and val then return val end; return {}
end
local function writeJson(path, data)
    local ok, enc = pcall(json.encode, data)
    if ok and enc then pcall(FileMgr.WriteFileContent, path, enc, false) end
end
local function ensureDir()
    pcall(FileMgr.CreateDir, BRIDGE.dir)
end

-- ── SAVED CAR LOADER ─────────────────────────────────────────
-- FIX v6.0: Improved path parsing, also reads from cached carsFile written by Lua itself
savedCarsList      = savedCarsList   or {}
savedCarsLoaded    = savedCarsLoaded or false
savedCarsLastLoad  = savedCarsLastLoad or 0   -- epoch seconds of last successful load
savedCarsLoadError = savedCarsLoadError or ""  -- last error message if load failed

local function loadSavedCars()
    local cars = {}
    local debugLog = {}

    local function addCar(name)
        if type(name) == "string" and name ~= "" then
            table.insert(cars, name)
        end
    end

    local function dlog(msg)
        table.insert(debugLog, msg)
        Logger.LogInfo("[SavedCars] " .. msg)
    end

    -- ── METHOD 1: Cherax internal feature hash 514776905 ──────────────────
    -- GetList() returns userdata (not a plain table) — must use numeric for loop
    -- with # operator and [i] indexing (confirmed from elf script usage).
    do
        local ok, err = pcall(function()
            local f = FeatureMgr.GetFeature(514776905)
            if not f then
                dlog("M1: GetFeature(514776905) returned nil")
                return
            end
            dlog("M1: Feature found — name=" .. tostring(f:GetName()) .. " hash=" .. tostring(f:GetHash()))
            local list = f:GetList()
            if not list then
                dlog("M1: GetList() returned nil")
                return
            end
            local len = #list
            dlog("M1: GetList() type=" .. type(list) .. " len=#list=" .. tostring(len))
            for i = 1, len do
                local ok2, v = pcall(function() return list[i] end)
                if ok2 and v then addCar(v) end
            end
            dlog("M1: Added " .. #cars .. " cars from feature list")
        end)
        if not ok then
            dlog("M1: pcall error — " .. tostring(err))
        end
    end

    -- ── METHOD 2: Fallback by feature name ───────────────────────────────
    if #cars == 0 then
        local ok, err = pcall(function()
            local f = FeatureMgr.GetFeatureByName("Saved Vehicles")
            if not f then
                dlog("M2: GetFeatureByName('Saved Vehicles') returned nil")
                return
            end
            dlog("M2: Feature found — hash=" .. tostring(f:GetHash()))
            local list = f:GetList()
            local len = #list
            dlog("M2: GetList() type=" .. type(list) .. " len=" .. tostring(len))
            for i = 1, len do
                local ok2, v = pcall(function() return list[i] end)
                if ok2 and v then addCar(v) end
            end
            dlog("M2: Added " .. #cars .. " cars")
        end)
        if not ok then
            dlog("M2: pcall error — " .. tostring(err))
        end
    end

    -- ── METHOD 3: FileMgr scan using dynamic Cherax root path ─────────────
    -- Unicode filenames can crash FindFiles — wrapped per-file
    if #cars == 0 then
        local ok, err = pcall(function()
            local rootPath = FileMgr.GetMenuRootPath()
            dlog("M3: GetMenuRootPath()=" .. tostring(rootPath))
            if rootPath and rootPath ~= "" then
                local vehiclesPath = rootPath .. "\\Vehicles"
                dlog("M3: Scanning " .. vehiclesPath)
                local files
                local fok, ferr = pcall(function()
                    files = FileMgr.FindFiles(vehiclesPath, ".json", false)
                end)
                if not fok then
                    dlog("M3: FindFiles error (unicode filename?) — " .. tostring(ferr))
                    return
                end
                files = files or {}
                dlog("M3: Found " .. #files .. " files")
                for _, f in ipairs(files) do
                    pcall(function()
                        local fname = tostring(f)
                        local name  = fname:match("[/\\]([^/\\]+)$") or fname
                        local base  = name:match("^(.+)%.json$") or name
                        addCar(base)
                    end)
                end
                dlog("M3: Added " .. #cars .. " cars")
            end
        end)
        if not ok then
            dlog("M3: pcall error — " .. tostring(err))
        end
    end

    -- ── METHOD 4: FileMgr scan using configured vehicleDir ────────────────
    if #cars == 0 then
        local ok, err = pcall(function()
            dlog("M4: Scanning BRIDGE.vehicleDir=" .. tostring(BRIDGE.vehicleDir))
            local files
            local fok, ferr = pcall(function()
                files = FileMgr.FindFiles(BRIDGE.vehicleDir, ".json", false)
            end)
            if not fok then
                dlog("M4: FindFiles error (unicode filename?) — " .. tostring(ferr))
                return
            end
            files = files or {}
            dlog("M4: Found " .. #files .. " files")
            for _, f in ipairs(files) do
                pcall(function()
                    local fname = tostring(f)
                    local name  = fname:match("[/\\]([^/\\]+)$") or fname
                    local base  = name:match("^(.+)%.json$") or name
                    addCar(base)
                end)
            end
            dlog("M4: Added " .. #cars .. " cars")
        end)
        if not ok then
            dlog("M4: pcall error — " .. tostring(err))
        end
    end

    -- ── METHOD 5: Cached JSON from previous successful load ───────────────
    if #cars == 0 then
        local ok, err = pcall(function()
            dlog("M5: Trying cache file " .. tostring(BRIDGE.carsFile))
            local cached = readJson(BRIDGE.carsFile)
            if cached and type(cached.cars) == "table" then
                for _, c in ipairs(cached.cars) do addCar(c) end
                dlog("M5: Added " .. #cars .. " cars from cache")
            else
                dlog("M5: Cache empty or invalid")
            end
        end)
        if not ok then
            dlog("M5: pcall error — " .. tostring(err))
        end
    end

    -- Remove duplicates, preserve order
    local seen = {}; local unique = {}
    for _, c in ipairs(cars) do
        if not seen[c] then seen[c] = true; table.insert(unique, c) end
    end
    cars = unique

    dlog("FINAL: " .. #cars .. " unique cars loaded")

    writeJson(BRIDGE.carsFile, {cars=cars, updated=os.time(), debug=debugLog})
    savedCarsList      = cars
    savedCarsLoaded    = (#cars > 0)
    savedCarsLastLoad  = os.time()
    savedCarsLoadError = (#cars == 0) and ("No cars found — check Cherax log for [SavedCars] debug info") or ""
    return cars
end

-- ── RESPOND ───────────────────────────────────────────────────
local function respond(id, ok, msg, extra)
    local data = readJson(BRIDGE.respFile)
    data.results = data.results or {}
    local e = {id=id, success=ok, message=msg, timestamp=os.time()}
    if extra then for k,v in pairs(extra) do e[k]=v end end
    table.insert(data.results, e)
    writeJson(BRIDGE.respFile, data)
end

-- ── USERNAME → PLAYER ID ──────────────────────────────────────
local function normName(s)
    return (s or ""):lower():gsub("[^%w]", "")
end
local function findPlayerByName(username)
    if not username or username == "" then return nil, "No username provided" end
    local want_raw  = username:lower():gsub("^%s+",""):gsub("%s+$","")
    local want_norm = normName(username)
    local allIds    = Players.Get() or {}
    local exact_matches, partial_matches = {}, {}
    for _, pid in ipairs(allIds) do
        local raw  = Players.GetName(pid) or ""
        local low  = raw:lower()
        local norm = normName(raw)
        if low:gsub("^%s+",""):gsub("%s+$","") == want_raw then return pid, nil end
        if want_norm ~= "" and norm == want_norm then
            table.insert(exact_matches, {pid=pid, name=raw})
        elseif want_norm ~= "" and norm:find(want_norm, 1, true) then
            table.insert(partial_matches, {pid=pid, name=raw})
        elseif want_norm ~= "" and want_norm:find(norm, 1, true) and norm ~= "" then
            table.insert(partial_matches, {pid=pid, name=raw})
        end
    end
    if #exact_matches == 1 then return exact_matches[1].pid, nil end
    if #exact_matches > 1 then
        local names={}; for _,m in ipairs(exact_matches) do names[#names+1]=m.name end
        return nil, "Multiple matches: "..table.concat(names,", ")
    end
    if #partial_matches == 1 then return partial_matches[1].pid, nil end
    if #partial_matches > 1 then
        local names={}; for _,m in ipairs(partial_matches) do names[#names+1]=m.name end
        return nil, "Multiple partial matches: "..table.concat(names,", ")
    end
    local nameList={}
    for _, pid in ipairs(allIds) do nameList[#nameList+1] = Players.GetName(pid) or "?" end
    local listStr = #nameList > 0 and (" (online: "..table.concat(nameList,", ")..") ") or " (session empty)"
    return nil, "Player '"..username.."' not found"..listStr
end

-- ── HANDLERS ──────────────────────────────────────────────────
local handlers = {}

handlers.fling = function(p, id)
    local username = p.username or p.player_name or ""
    local power    = tonumber(p.power) or 50
    local count    = math.min(tonumber(p.count) or 3, 10)
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("fling", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not N_DoesEntityExist(pedHnd) then error("Entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            for i = 1, count do N_AddExplosion(x, y, z-0.3, 14, true); Script.Yield(50) end
        end)
        local msg = ok and ("Flung "..username.." power="..power) or tostring(err2)
        respond(id, ok, msg); addLog("fling", p, ok, msg)
    end)
end

handlers.moon = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then
        if not en then respond(id, true, "Moon OFF "..username); addLog("moon",p,true,"Moon OFF "..username); return end
        respond(id, false, err); addLog("moon", p, false, err); return
    end
    State.vehicleLoops[pid] = State.vehicleLoops[pid] or {}
    State.vehicleLoops[pid].moon = en
    local msg = "Moon "..(en and "ON" or "OFF").." "..username
    respond(id, true, msg); addLog("moon", p, true, msg)
end

handlers.explode = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("explode", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not N_DoesEntityExist(pedHnd) then error("Entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            N_AddExplosion(x, y, z, 4, false)
        end)
        local msg = ok and ("Exploded "..username) or tostring(err2)
        respond(id, ok, msg); addLog("explode", p, ok, msg)
    end)
end

handlers.obliterate = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("obliterate", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not N_DoesEntityExist(pedHnd) then error("Entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            local types = {4,14,1,59,5,10,8,24,3,7}
            for _, t in ipairs(types) do N_AddExplosion(x,y,z,t,false); Script.Yield(60) end
        end)
        local msg = ok and ("Obliterated "..username) or tostring(err2)
        respond(id, ok, msg); addLog("obliterate", p, ok, msg)
    end)
end

handlers.kill = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("kill", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not N_DoesEntityExist(pedHnd) then error("Entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            N_AddExplosion(x, y, z, 59, false); Script.Yield(60); N_AddExplosion(x, y, z, 1, false)
        end)
        local msg = ok and ("Killed "..username) or tostring(err2)
        respond(id, ok, msg); addLog("kill", p, ok, msg)
    end)
end

handlers.burnout = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("burnout", p, false, err); return end
    State.vehicleLoops[pid] = State.vehicleLoops[pid] or {}
    State.vehicleLoops[pid].burnout = en
    local msg = "Burnout "..(en and "ON" or "OFF").." "..username
    respond(id, true, msg); addLog("burnout", p, true, msg)
end

handlers.shockwave = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("shockwave", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not N_DoesEntityExist(pedHnd) then error("Entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            for i = 0, 7 do
                local angle = (i/8)*2*math.pi
                N_AddExplosion(x+2.5*math.cos(angle), y+2.5*math.sin(angle), z, 14, true)
                Script.Yield(40)
            end
        end)
        local msg = ok and ("Shockwave on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("shockwave", p, ok, msg)
    end)
end

handlers.firework = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("firework", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not N_DoesEntityExist(pedHnd) then error("Entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            for _, t in ipairs({48,59,61,62,63,64,65,66,67,68,69,70}) do
                N_AddExplosion(x, y, z+2.0, t, true); Script.Yield(80)
            end
        end)
        local msg = ok and ("Firework on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("firework", p, ok, msg)
    end)
end

handlers.repair = function(p, id)
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local ped = GTA.GetLocalPed()
            if not ped then error("No local ped") end
            if not ped:IsInVehicle() then error("Not in a vehicle") end
            local veh = GTA.GetLocalVehicle()
            if not veh then error("No vehicle found") end
            local vh = GTA.PointerToHandle(veh)
            if not vh or vh == 0 then error("Could not get vehicle handle") end
            Natives.InvokeVoid(0x115722B1B9C14C1C, vh)
        end)
        local msg = ok and "Vehicle repaired!" or tostring(err)
        respond(id, ok, msg); addLog("repair", p, ok, msg)
    end)
end

handlers.godmode = function(p, id)
    local en = p.enabled == true or p.enabled == "true"
    State.godMode = en
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local localPed = GTA.GetLocalPed()
            if not localPed then error("No local ped") end
            if en then localPed:EnableInvincible() else localPed:DisableInvincible() end
        end)
        local msg = ok and ("God Mode "..(en and "ON" or "OFF")) or tostring(err)
        respond(id, ok, msg); addLog("godmode", p, ok, msg)
    end)
end

handlers.superdrive = function(p, id)
    local en = p.enabled == true or p.enabled == "true"
    local ok, err = pcall(function()
        local f = FeatureMgr.GetFeature(Utils.Joaat(FEAT_SUPERDRIVE))
        if not f then error("SuperDrive feature not found") end
        f:SetBoolValue(en)
    end)
    local msg = ok and (FEAT_SUPERDRIVE.." "..(en and "ON" or "OFF")) or tostring(err)
    respond(id, ok, msg); addLog("superdrive", p, ok, msg)
end

handlers.modders = function(p, id)
    local list, seen = {}, {}
    local allIds = Players.Get() or {}
    for _, pid in ipairs(allIds) do
        local ok, dets = pcall(ModderDB.GetModderDetectionsByPlayerId, pid)
        if ok and dets and #dets > 0 then
            local name = Players.GetName(pid) or "Unknown"
            seen[pid] = true
            if not detectedModders[pid] then detectedModders[pid] = {name=name} end
            local detList = {}
            for _, d in ipairs(dets) do table.insert(detList, {name=d.name, count=d.count}) end
            table.insert(list, {id=pid, name=name, detections=detList})
        end
    end
    for pid, m in pairs(detectedModders) do
        if not seen[pid] then
            table.insert(list, {id=pid, name=m.name or "Unknown", detections=m.detections or {}})
        end
    end
    local msg = #list > 0 and (#list.." modder(s) found") or "No modders detected"
    respond(id, true, msg, {modders=list}); addLog("modders", p, true, msg)
end

handlers.players = function(p, id)
    local allIds = Players.Get() or {}
    local list = {}
    for _, pid in ipairs(allIds) do
        local name = Players.GetName(pid) or "Unknown"
        table.insert(list, {id=pid, name=name})
    end
    local msg = #list.." player(s) in session"
    respond(id, true, msg, {players=list}); addLog("players", p, true, msg)
end

handlers.sethealth = function(p, id)
    local health = tonumber(p.health)
    local armor  = tonumber(p.armor)
    if not health and not armor then
        respond(id, false, "Provide health and/or armor value"); addLog("sethealth",p,false,"No values"); return
    end
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local localPed = GTA.GetLocalPed()
            if not localPed then error("No local ped") end
            if health then
                if health > localPed.MaxHealth then localPed.MaxHealth = health end
                localPed.Health = health
            end
            if armor then localPed.Armor = armor end
        end)
        local parts = {}
        if health then parts[#parts+1] = "health="..tostring(health) end
        if armor  then parts[#parts+1] = "armor="..tostring(armor)   end
        local msg = ok and ("Set "..table.concat(parts," ")) or tostring(err)
        respond(id, ok, msg); addLog("sethealth", p, ok, msg)
    end)
end

handlers.vehiclegod = function(p, id)
    local en = p.enabled == true or p.enabled == "true"
    State.vehicleGod = en
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local v = GTA.GetLocalVehicle()
            if not v then if en then error("Not in a vehicle") end; return end
            if en then v:EnableInvincible() else v:DisableInvincible() end
        end)
        local msg = ok and ("Vehicle God Mode "..(en and "ON" or "OFF")) or tostring(err)
        respond(id, ok, msg); addLog("vehiclegod", p, ok, msg)
    end)
end

handlers.sendchat = function(p, id)
    local msg_text = p.message or p.text or ""
    if msg_text == "" then respond(id, false, "No message provided"); addLog("sendchat",p,false,"No msg"); return end
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local sent = false
            pcall(function()
                Natives.InvokeVoid(0x1B546BE15EB3B8A0, msg_text, Players.GetLocalId(), false)
                sent = true
            end)
            if not sent then
                Natives.InvokeVoid(0x5C00C0F4A5C93489, msg_text, 0, false)
            end
        end)
        local result = ok and ("Chat sent: "..msg_text) or tostring(err)
        respond(id, ok, result); addLog("sendchat", p, ok, result)
    end)
end

-- ── /waypoint ─────────────────────────────────────────────────
handlers.waypoint = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("waypoint", p, false, err); return end

    Script.QueueJob(function()
        local ok_call, result = pcall(function()
            local has, pos, owner = Players.GetWaypoint(pid)
            if not has then return {has=false} end
            local wx, wy, wz = 0, 0, 0
            pcall(function() wx = pos.x; wy = pos.y; wz = pos.z end)
            if wx == 0 and wy == 0 then
                pcall(function() if pos[1] then wx=pos[1]; wy=pos[2]; wz=pos[3] or 0 end end)
            end
            if wx == 0 and wy == 0 then
                pcall(function() local a,b,c = pos:Unpack(); if a then wx=a;wy=b;wz=c or 0 end end)
            end
            if wx == 0 and wy == 0 then
                pcall(function() wx=pos:GetX(); wy=pos:GetY(); wz=pos:GetZ() or 0 end)
            end
            return {has=true, wx=wx, wy=wy, wz=wz, owner=owner}
        end)
        if not ok_call then
            local msg = "Waypoint error: "..tostring(result)
            respond(id, false, msg); addLog("waypoint", p, false, msg); return
        end
        if not result.has then
            local msg = username.." has no active waypoint"
            respond(id, true, msg, {has_waypoint=false}); addLog("waypoint",p,true,msg); return
        end
        local wx, wy, wz = result.wx or 0, result.wy or 0, result.wz or 0
        local msg = string.format("%s waypoint: X=%.2f Y=%.2f Z=%.2f", username, wx, wy, wz)
        respond(id, true, msg, {has_waypoint=true, x=wx, y=wy, z=wz, owner=result.owner})
        addLog("waypoint", p, true, msg)
    end)
end

-- ── /wanted ───────────────────────────────────────────────────
handlers.wanted = function(p, id)
    local username = p.username or p.player_name or ""
    local level    = tonumber(p.level)
    if not level or level < 0 or level > 5 then
        respond(id, false, "Provide wanted level 0-5"); addLog("wanted",p,false,"Invalid level"); return
    end

    if username == "" then
        -- Set wanted on self (local)
        Script.QueueJob(function()
            local ok, err2 = pcall(function()
                local localPid = GTA.GetLocalPlayerId() or 0
                N_SetPlayerWantedLevel(localPid, level)
            end)
            local stars = level > 0 and string.rep("*", level) or "0"
            local msg = ok and ("Wanted ["..stars.."] set on Self") or tostring(err2)
            respond(id, ok, msg); addLog("wanted", p, ok, msg)
        end)
        return
    end

    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("wanted",p,false,err); return end

    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            -- Method 1: TriggerScriptEvent — CE_GIVE_WANTED_STARS
            -- bitflag = (1 << pid) to target specific player
            -- args[1] = local player id (sender), args[2] = target player id, args[3] = stars
            -- This is the standard cross-menu approach to set wanted on other players
            local localPid = GTA.GetLocalPlayerId() or 0
            local bitflag  = 1 << pid  -- send to specific player

            -- Try script event method first (most reliable for remote wanted)
            local seOk = pcall(function()
                -- GIVE_WANTED_STARS event
                GTA.TriggerScriptEvent(bitflag, {localPid, pid, level, 0})
            end)
            if seOk then return end

            -- Method 2: Loop-trigger via repeated native on their ped
            -- N_SetPlayerWantedLevel only works properly on local player,
            -- but can sometimes affect remote if you're script host
            N_SetPlayerWantedLevel(pid, level)
        end)
        local stars = level > 0 and string.rep("*", level) or "0"
        local msg = ok and ("Wanted ["..stars.."] set on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("wanted", p, ok, msg)
    end)
end

-- ── /bringme (was teleporttome) ───────────────────────────────
-- Uses Cherax native "Teleport To Me" + "Teleport Vehicle To Me" player features (all 32 hashes each)
local TELE_TO_ME_HASHES = {
    3312174853, 2527979862, 1768230597, 845062329, 2230437342, 3749935872,
    2982715275, 2064003591, 3445315248, 159305466, 1477361145, 1826154381,
    1579338273, 3779055705, 325694636, 113417054, 930708683, 2591572679,
    3438553026, 3148317993, 2273876976, 551243411, 782756396, 1920692694,
    1336224810, 3859798269, 4115330931, 4220224500, 416267900, 2741425064,
    2287347031, 1989050824,
}
local TELE_VEH_TO_ME_HASHES = {
    2118004218, 1749287430, 562295939, 4224362769, 1169997044, 793677848,
    3363324521, 3123291596, 3976530822, 3738005267, 3729985448, 4286927372,
    820262089, 607329127, 2526740541, 3366970470, 3116517003, 3976572173,
    1602064899, 2443474512, 2972921845, 2037432433, 4217127994, 3861060040,
    4157652259, 3361463878, 1113969228, 1429764081, 497813721, 796503156,
    118905486, 3703965166,
}
handlers.teleporttome = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("teleporttome",p,false,err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            -- Fire all "Teleport To Me" hashes
            for _, h in ipairs(TELE_TO_ME_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(10)
            end
            -- Also fire all "Teleport Vehicle To Me" hashes (covers if they're in a vehicle)
            for _, h in ipairs(TELE_VEH_TO_ME_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(10)
            end
        end)
        local msg = ok and ("Teleported "..username.." to you") or tostring(err2)
        respond(id, ok, msg); addLog("teleporttome", p, ok, msg)
    end)
end

handlers.playerip = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("playerip",p,false,err); return end
    local ok1, ipStr  = pcall(Players.GetIPString, pid)
    local ok2, ipInfo = pcall(Players.GetIPInfo,   pid)
    local ip_string = (ok1 and ipStr) or "N/A"
    local ip_table  = (ok2 and ipInfo) or {}
    local msg = username.." IP: "..ip_string
    respond(id, true, msg, {ip=ip_string, info=ip_table}); addLog("playerip",p,true,msg)
end

-- ── NEW: /spectate ────────────────────────────────────────────
-- Spectate a player using Cherax Players tab / native spectate
handlers.spectate = function(p, id)
    local username = p.username or p.player_name or ""
    local stop     = p.stop == true or p.stop == "true"

    -- Stop spectating
    if stop or username == "" then
        Script.QueueJob(function()
            local ok, err = pcall(function()
                State.spectating  = false
                State.spectatePid = nil
                -- Method 1: Cherax high-level
                pcall(function()
                    local lp = Players.GetLocalId and Players.GetLocalId() or 0
                    Players.SpectatePlayer(lp)
                end)
                -- Method 2: Native
                pcall(function() N_NetworkSetSpectating(false) end)
            end)
            local msg = ok and "Stopped spectating" or tostring(err)
            respond(id, ok, msg); addLog("spectate", p, ok, msg)
        end)
        return
    end

    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("spectate", p, false, err); return end

    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            State.spectating  = true
            State.spectatePid = pid
            -- Method 1: Cherax high-level Players tab spectate
            local m1ok = pcall(function()
                if Players.SpectatePlayer then Players.SpectatePlayer(pid); return end
                error("no SpectatePlayer")
            end)
            if m1ok then return end

            -- Method 2: Native NETWORK_SPECTATE_PLAYER
            pcall(function() N_NetworkSpectatePlayer(pid, true) end)

            -- Method 3: Position-based follow (teleport to player)
            local pedHnd = N_GetPlayerPed(pid)
            if not pedHnd or pedHnd == 0 then error("Cannot get ped handle") end
            if not N_DoesEntityExist(pedHnd) then error("Ped does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            local myPed = GTA.GetLocalPed()
            if myPed then
                local myHandle = GTA.PointerToHandle(myPed)
                if myHandle and myHandle ~= 0 then
                    N_SetEntityCoords(myHandle, x+2.0, y, z)
                end
            end
        end)
        local msg = ok and ("Now spectating "..username) or tostring(err2)
        respond(id, ok, msg); addLog("spectate", p, ok, msg)
    end)
end

-- ── NEW: /getped ──────────────────────────────────────────────
-- Get the CPed handle/address of a player directly
handlers.getped = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("getped", p, false, err); return end

    Script.QueueJob(function()
        local ok, result = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not pedHnd or pedHnd == 0 then error("Could not get ped handle") end
            if not N_DoesEntityExist(pedHnd) then error("Ped entity does not exist") end
            local x, y, z = N_GetEntityCoords(pedHnd)
            -- Try to get the CObject pointer / address
            local addr = 0
            pcall(function()
                local netPlayer = Players.GetById(pid)
                if netPlayer then
                    local ped = netPlayer:GetPed()
                    if ped then addr = GTA.HandleToPointer and GTA.HandleToPointer(pedHnd) or 0 end
                end
            end)
            return {
                handle = pedHnd,
                address = string.format("0x%X", addr),
                x = math.floor(x*100)/100,
                y = math.floor(y*100)/100,
                z = math.floor(z*100)/100,
                in_vehicle = N_IsPedInVehicle(pedHnd),
            }
        end)
        if not ok then
            respond(id, false, tostring(result)); addLog("getped", p, false, tostring(result)); return
        end
        local msg = string.format("%s CPed handle=%d addr=%s pos=(%.1f,%.1f,%.1f)",
            username, result.handle, result.address, result.x, result.y, result.z)
        respond(id, true, msg, result); addLog("getped", p, true, msg)
    end)
end

-- ── NEW: /getcurrentvehicle ───────────────────────────────────
-- Get a player's current vehicle info
handlers.getcurrentvehicle = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("getcurrentvehicle", p, false, err); return end

    Script.QueueJob(function()
        local ok, result = pcall(function()
            local pedHnd = N_GetPlayerPed(pid)
            if not pedHnd or pedHnd == 0 then error("Could not get ped handle") end
            if not N_DoesEntityExist(pedHnd) then error("Ped does not exist") end
            if not N_IsPedInVehicle(pedHnd) then error(username.." is not in a vehicle") end

            local vehHnd = N_GetPedVehicle(pedHnd)
            if not vehHnd or vehHnd == 0 then error("Could not get vehicle handle") end
            if not N_DoesEntityExist(vehHnd) then error("Vehicle does not exist") end

            local model = N_GetEntityModel(vehHnd)
            local modelName = ""
            pcall(function()
                modelName = GTA.GetModelNameFromHash(model) or ""
            end)
            if modelName == "" then
                pcall(function()
                    modelName = N_GetVehicleDisplayName(model) or ""
                end)
            end

            local vx, vy, vz = N_GetEntityCoords(vehHnd)
            local engHealth = 0
            pcall(function() engHealth = N_GetVehicleEngineHealth(vehHnd) end)

            return {
                handle = vehHnd,
                model  = modelName ~= "" and modelName or string.format("hash:0x%X", model),
                engine_health = math.floor(engHealth),
                x = math.floor(vx*100)/100,
                y = math.floor(vy*100)/100,
                z = math.floor(vz*100)/100,
            }
        end)
        if not ok then
            respond(id, false, tostring(result)); addLog("getcurrentvehicle", p, false, tostring(result)); return
        end
        local msg = string.format("%s is in: %s (engine: %d%%) @ (%.1f, %.1f, %.1f)",
            username, result.model, result.engine_health, result.x, result.y, result.z)
        respond(id, true, msg, result); addLog("getcurrentvehicle", p, true, msg)
    end)
end

-- ── NEW: /getlastvehicle ──────────────────────────────────────
-- Get a player's last vehicle
handlers.getlastvehicle = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("getlastvehicle", p, false, err); return end

    Script.QueueJob(function()
        local ok, result = pcall(function()
            -- Primary: use CPed.LastVehicle (Cherax high-level API)
            local vehHnd = nil
            local cheraxOk = pcall(function()
                local cped = Players.GetCPed(pid)
                if not cped then error("no CPed") end
                local lv = cped.LastVehicle
                if not lv then error("no LastVehicle field") end
                local ptr = lv:GetAddress()
                if not ptr or ptr == 0 then error("zero ptr") end
                local h = GTA.PointerToHandle(ptr)
                if not h or h == 0 then error("PointerToHandle failed") end
                vehHnd = h
            end)
            -- Fallback: native
            if not vehHnd or vehHnd == 0 then
                local pedHnd = N_GetPlayerPed(pid)
                if not N_DoesEntityExist(pedHnd) then error("Ped does not exist") end
                vehHnd = N_GetPedLastVehicle(pedHnd)
            end
            if not vehHnd or vehHnd == 0 then error(username.." has no last vehicle recorded") end
            if not N_DoesEntityExist(vehHnd) then error("Last vehicle no longer exists") end

            local model = N_GetEntityModel(vehHnd)
            local modelName = ""
            pcall(function() modelName = GTA.GetModelNameFromHash(model) or "" end)
            if modelName == "" then
                pcall(function() modelName = N_GetVehicleDisplayName(model) or "" end)
            end

            local vx, vy, vz = N_GetEntityCoords(vehHnd)
            return {
                handle = vehHnd,
                model  = modelName ~= "" and modelName or string.format("hash:0x%X", model),
                x = math.floor(vx*100)/100,
                y = math.floor(vy*100)/100,
                z = math.floor(vz*100)/100,
            }
        end)
        if not ok then
            respond(id, false, tostring(result)); addLog("getlastvehicle", p, false, tostring(result)); return
        end
        local msg = string.format("%s last vehicle: %s @ (%.1f, %.1f, %.1f)",
            username, result.model, result.x, result.y, result.z)
        respond(id, true, msg, result); addLog("getlastvehicle", p, true, msg)
    end)
end

-- ── NEW: /ragdoll ─────────────────────────────────────────────
-- Uses Cherax native "Remote Ragdoll Loop" player feature (all 32 hashes, t=1 toggle)
local RAGDOLL_LOOP_HASHES = {
    4058829599, 3022509974, 2723361773, 3746213335, 3434285224, 1973541515,
    1491706139, 2453574596, 2274197090, 422027600, 613854603, 1918880028,
    979163415, 272532699, 3590361184, 3953114014, 3486975057, 3929225481,
    4101361038, 4274446896, 855034835, 1027399775, 891179046, 1138716072,
    3650165005, 3897243265, 2658706141, 196771167, 3252513190, 2400388114,
    2608011526, 3451583893,
}
handlers.ragdoll = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("ragdoll", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(RAGDOLL_LOOP_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(true) end
                end)
                Script.Yield(5)
            end
            -- Auto-disable after 5 seconds
            Script.Yield(5000)
            for _, h in ipairs(RAGDOLL_LOOP_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(false) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Ragdolled "..username) or tostring(err2)
        respond(id, ok, msg); addLog("ragdoll", p, ok, msg)
    end)
end

-- ── NEW: /freeze ──────────────────────────────────────────────
-- Uses Cherax native "Freeze Player" player feature (all 32 hashes)
local FREEZE_PLAYER_HASHES = {
    1337705630, 718043840, 4249329591, 3358930315, 415258280, 3552103570,
    3053490466, 1902872569, 2202839995, 2628083308, 1090329828, 2756371330,
    1922695201, 2278042237, 3609938154, 3888245271, 3465787323, 464376302,
    838794896, 571957021, 1306635929, 795308457, 19961148, 846493631,
    83500235, 366395012, 3625272066, 3926189793, 3149302341, 3447795162,
    3150123130, 2398434967,
}
handlers.freeze = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("freeze", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            -- t=1 means toggle — set state then trigger
            for _, h in ipairs(FREEZE_PLAYER_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Freeze "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("freeze", p, ok, msg)
    end)
end

-- ── NEW: /stripweapons ────────────────────────────────────────
-- Uses Cherax native "Remove All Weapons" player feature (all 32 hashes, t=0 action)
local REMOVE_WEAPONS_HASHES = {
    4232037880, 166617429, 3752135875, 3982141486, 3537662770, 2828410534,
    3059202601, 2121550447, 2705362971, 3640328079, 515269849, 216777028,
    3419488016, 3095369837, 3893688215, 3588641594, 54570494, 4052421267,
    515007713, 218612108, 3652869114, 3938582025, 2896462287, 3193251120,
    3496692084, 3802721775, 730595252, 3032093202, 4262995149, 429677525,
    1492343686, 776078884,
}
handlers.stripweapons = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("stripweapons", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(REMOVE_WEAPONS_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Stripped all weapons from "..username) or tostring(err2)
        respond(id, ok, msg); addLog("stripweapons", p, ok, msg)
    end)
end

-- ── NEW: /poptyres ────────────────────────────────────────────
-- Uses Cherax native "Pop Tires" player feature (all 32 hashes, t=0 action)
local POP_TIRES_HASHES = {
    1154277603, 1007275869, 537565023, 2387211228, 2206457424, 1928281383,
    928368113, 622469498, 449842406, 2291558513, 3156117261, 2500999409,
    2798378084, 49648826, 355711286, 3482824191, 3755298426, 2735789302,
    2429497459, 1848568627, 2639415353, 4115626038, 3272348592, 4241622843,
    210577073, 546262709, 716858123, 1156650876, 1397142567, 2345772348,
    2448108455, 1212553310,
}
handlers.poptyres = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("poptyres", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(POP_TIRES_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Popped tyres on "..username.."'s vehicle") or tostring(err2)
        respond(id, ok, msg); addLog("poptyres", p, ok, msg)
    end)
end

-- ── NEW: /killengine ──────────────────────────────────────────
-- Uses Cherax native "Blow Vehicle Engine" player feature (all 32 hashes, t=0 action)
local BLOW_ENGINE_HASHES = {
    3196290361, 752214492, 3760736386, 3463587094, 2217742511, 4124865514,
    1323279883, 3097459081, 1928359468, 1563050656, 1599956300, 3991536231,
    1277411033, 1517181806, 2867952755, 959387888, 2272114028, 2508542363,
    3450094048, 3816648082, 260361084, 617084418, 4151876452, 3443082982,
    3660112069, 2951121985, 3199543774, 2491143528, 2769385107, 1926402582,
    2506478572, 2795599459,
}
handlers.killengine = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("killengine", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(BLOW_ENGINE_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Killed engine on "..username.."'s vehicle") or tostring(err2)
        respond(id, ok, msg); addLog("killengine", p, ok, msg)
    end)
end

-- ── NEW: /explodeloop ────────────────────────────────────────
-- Uses Cherax native "Explode Loop" player feature (toggle, t=1)
handlers.explodeloop = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("explodeloop", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(EXPLODE_LOOP_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Explode Loop "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("explodeloop", p, ok, msg)
    end)
end

-- ── NEW: /fireloop ────────────────────────────────────────────
-- Uses Cherax native "Fire Loop" player feature (toggle, t=1)
handlers.fireloop = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("fireloop", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(FIRE_LOOP_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Fire Loop "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("fireloop", p, ok, msg)
    end)
end

-- ── NEW: /shockwaveloop ───────────────────────────────────────
-- Uses Cherax native "Shock Wave Loop" player feature (toggle, t=1)
handlers.shockwaveloop = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("shockwaveloop", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(SHOCK_WAVE_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Shock Wave Loop "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("shockwaveloop", p, ok, msg)
    end)
end

-- ── NEW: /waterloop ───────────────────────────────────────────
-- Uses Cherax native "Water Loop" player feature (toggle, t=1)
handlers.waterloop = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("waterloop", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(WATER_LOOP_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Water Loop "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("waterloop", p, ok, msg)
    end)
end

-- ── NEW: /stunloop ────────────────────────────────────────────
-- Uses Cherax native "Stun Player" feature (toggle, t=1)
handlers.stunloop = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("stunloop", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(STUN_PLAYER_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Stun Loop "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("stunloop", p, ok, msg)
    end)
end

-- ── NEW: /clearwanted ─────────────────────────────────────────
-- Uses Cherax native "Clear Wanted" player feature (action, t=0)
handlers.clearwanted = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("clearwanted", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(CLEAR_WANTED_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Cleared wanted level on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("clearwanted", p, ok, msg)
    end)
end

-- ── NEW: /offradar ────────────────────────────────────────────
-- Uses Cherax native "Off The Radar" player feature (toggle, t=1)
handlers.offradar = function(p, id)
    local username = p.username or p.player_name or ""
    local en       = p.enabled == true or p.enabled == "true"
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("offradar", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(OFF_RADAR_HASHES) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(en) end
                end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Off The Radar "..(en and "ON" or "OFF").." on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("offradar", p, ok, msg)
    end)
end

-- ── NEW: /bounty ──────────────────────────────────────────────
-- Uses Cherax native "Set Bounty" player feature (action, t=0)
handlers.bounty = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("bounty", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(BOUNTY_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Set bounty on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("bounty", p, ok, msg)
    end)
end

-- ── NEW: /cage ────────────────────────────────────────────────
-- Uses Cherax native "Cage Player" feature (action, t=0)
handlers.cage = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("cage", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(CAGE_PLAYER_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Caged "..username) or tostring(err2)
        respond(id, ok, msg); addLog("cage", p, ok, msg)
    end)
end

-- ── NEW: /killplayer ──────────────────────────────────────────
-- Uses Cherax native "Kill Player" feature (action, t=0)
handlers.killplayer = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("killplayer", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(KILL_PLAYER_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Killed "..username) or tostring(err2)
        respond(id, ok, msg); addLog("killplayer", p, ok, msg)
    end)
end

-- ── NEW: kill_all ─────────────────────────────────────────────
-- Kills every player in the current session using KILL_PLAYER_HASHES.
handlers.kill_all = function(p, id)
    Script.QueueJob(function()
        local allIds = Players.Get() or {}
        local localId = nil
        pcall(function() localId = Players.GetLocalId() end)
        local killed, skipped = 0, 0
        for _, pid in ipairs(allIds) do
            if pid ~= localId then
                pcall(function()
                    Utils.SetSelectedPlayer(pid)
                    Script.Yield(80)
                    for _, h in ipairs(KILL_PLAYER_HASHES) do
                        pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                        Script.Yield(5)
                    end
                end)
                killed = killed + 1
                Script.Yield(150)   -- small gap between players
            else
                skipped = skipped + 1
            end
        end
        local msg = string.format("Kill All done — %d players killed, %d skipped (self)", killed, skipped)
        respond(id, true, msg)
        addLog("kill_all", p, true, msg)
        GUI.AddToast("The Gangs", msg, 4000)
    end)
end

-- ── NEW: /airstrike ───────────────────────────────────────────
-- Uses Cherax native "Airstrike" player feature (action, t=0)
handlers.airstrike = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("airstrike", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(AIRSTRIKE_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Airstrike called on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("airstrike", p, ok, msg)
    end)
end

-- ── NEW: /orbitalstrike ───────────────────────────────────────
-- Uses Cherax native "Orbital Strike" player feature (action, t=0)
handlers.orbitalstrike = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("orbitalstrike", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(ORBITAL_STRIKE_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Orbital strike on "..username) or tostring(err2)
        respond(id, ok, msg); addLog("orbitalstrike", p, ok, msg)
    end)
end

-- ── NEW: /launchvehicle ───────────────────────────────────────
-- Uses Cherax native "Launch Vehicle" player feature (action, t=0)
handlers.launchvehicle = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("launchvehicle", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(LAUNCH_VEH_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Launched "..username.."'s vehicle") or tostring(err2)
        respond(id, ok, msg); addLog("launchvehicle", p, ok, msg)
    end)
end

-- ── NEW: /sendsky ─────────────────────────────────────────────
-- Uses Cherax native "Send To Sky" player feature (action, t=0)
handlers.sendsky = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("sendsky", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(SEND_SKY_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Sent "..username.." to the sky") or tostring(err2)
        respond(id, ok, msg); addLog("sendsky", p, ok, msg)
    end)
end

-- ── NEW: /deathbarrier ────────────────────────────────────────
-- Uses Cherax native "Send To Death Barrier" player feature (action, t=0)
handlers.deathbarrier = function(p, id)
    local username = p.username or p.player_name or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("deathbarrier", p, false, err); return end
    Script.QueueJob(function()
        local ok, err2 = pcall(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(DEATH_BARRIER_HASHES) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        local msg = ok and ("Sent "..username.." to the death barrier") or tostring(err2)
        respond(id, ok, msg); addLog("deathbarrier", p, ok, msg)
    end)
end

-- ── /spawnsaved ───────────────────────────────────────────────
handlers.spawnsaved = function(p, id)
    local carName   = p.car or p.model or ""
    local targetUser = p.username or p.player_name or ""  -- optional: spawn for another player
    if carName == "" then
        local cars = loadSavedCars()
        if #cars == 0 then
            respond(id, false, "No saved cars found in "..BRIDGE.vehicleDir)
            addLog("spawnsaved", p, false, "No saved cars")
        else
            respond(id, true, "Available: "..table.concat(cars,", "), {cars=cars})
            addLog("spawnsaved", p, true, #cars.." cars available")
        end
        return
    end

    -- Resolve target player (if any)
    local targetPid = nil
    if targetUser ~= "" then
        local tp, terr = findPlayerByName(targetUser)
        if not tp then respond(id, false, terr); addLog("spawnsaved",p,false,terr); return end
        targetPid = tp
    end

    local ped = GTA.GetLocalPed()
    if not ped then respond(id, false, "No local ped"); addLog("spawnsaved",p,false,"No local ped"); return end
    local pos = ped.Position
    if not pos then respond(id, false, "Could not get position"); addLog("spawnsaved",p,false,"No pos"); return end

    Script.QueueJob(function()
        local ok, result = pcall(function()
            -- Determine model hash: try saved JSON first, then treat carName as model
            local modelHash = nil

            local jsonPath = BRIDGE.vehicleDir.."\\"..carName..".json"
            local ok_read, raw = pcall(FileMgr.ReadFileContent, jsonPath)
            if ok_read and raw and raw ~= "" then
                local vdata = json.decode(raw)
                if vdata and vdata.model then
                    modelHash = vdata.model
                end
            end

            if not modelHash then
                -- Try VehicleMgr.SpawnSavedVehicle first (Cherax built-in, for self only)
                if not targetPid then
                    local m1ok = pcall(function() VehicleMgr.SpawnSavedVehicle(carName) end)
                    if m1ok then return "Spawned saved vehicle: "..carName end
                end
                modelHash = Utils.Joaat(carName)
            end

            -- Load model
            Natives.InvokeVoid(0x963D27A58DF860AC, modelHash)
            local timeout = 80
            while not Natives.InvokeBool(0x98A4EB5D89A0C952, modelHash) and timeout > 0 do
                Script.Yield(50); timeout = timeout - 1
            end

            local handle
            if targetPid then
                -- Spawn for another player using Cherax API
                handle = GTA.SpawnVehicleForPlayer(modelHash, targetPid, 5.0)
                if not handle or handle == 0 then error("SpawnVehicleForPlayer failed") end
                Natives.InvokeVoid(0xE532F5D78798DAAB, modelHash)
                return "Spawned "..carName.." at "..targetUser.."'s location"
            else
                handle = GTA.SpawnVehicle(modelHash, pos.x, pos.y+5.0, pos.z, 0.0, true, true)
                if not handle or handle == 0 then error("SpawnVehicle failed") end
                Natives.InvokeVoid(0xE532F5D78798DAAB, modelHash)
                return "Spawned "..carName
            end
        end)
        local msg = ok and tostring(result) or tostring(result)
        respond(id, ok, msg); addLog("spawnsaved", p, ok, msg)
    end)
end

handlers.spawn = function(p, id)
    local model = (p.model or p.vehicle or ""):lower():gsub("%s+","")
    if model == "" then respond(id, false, "No model provided"); addLog("spawn",p,false,"No model"); return end
    local ped = GTA.GetLocalPed()
    if not ped then respond(id, false, "No local ped"); addLog("spawn",p,false,"No local ped"); return end
    local pos = ped.Position
    if not pos then respond(id, false, "No position"); addLog("spawn",p,false,"No pos"); return end
    local modelHash = Utils.Joaat(model)
    Script.QueueJob(function()
        local ok, result = pcall(function()
            Natives.InvokeVoid(0x963D27A58DF860AC, modelHash)
            local timeout = 80
            while not Natives.InvokeBool(0x98A4EB5D89A0C952, modelHash) and timeout > 0 do
                Script.Yield(50); timeout = timeout - 1
            end
            local handle = GTA.SpawnVehicle(modelHash, pos.x, pos.y+5.0, pos.z, 0.0, true, true)
            if not handle or handle == 0 then error("SpawnVehicle failed for: "..model) end
            Natives.InvokeVoid(0xE532F5D78798DAAB, modelHash)
            return handle
        end)
        local msg = ok and ("Spawned "..model) or tostring(result)
        respond(id, ok, msg); addLog("spawn", p, ok, msg)
    end)
end

handlers.spawnforplayer = function(p, id)
    local username = p.username or p.player_name or ""
    local model    = (p.model or p.vehicle or "adder"):lower():gsub("%s+","")
    local forward  = tonumber(p.forward) or 5.0
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); addLog("spawnforplayer",p,false,err); return end

    Script.QueueJob(function()
        local ok, result = pcall(function()
            -- Try to resolve model hash from saved vehicle JSON first
            local modelHash = nil
            local jsonPath = BRIDGE.vehicleDir.."\\"..model..".json"
            local jok, jraw = pcall(FileMgr.ReadFileContent, jsonPath)
            if jok and jraw and jraw ~= "" then
                local vdata = json.decode(jraw)
                if vdata and vdata.model then modelHash = vdata.model end
            end
            if not modelHash then modelHash = Utils.Joaat(model) end

            Natives.InvokeVoid(0x963D27A58DF860AC, modelHash)
            local timeout = 80
            while not Natives.InvokeBool(0x98A4EB5D89A0C952, modelHash) and timeout > 0 do
                Script.Yield(50); timeout = timeout - 1
            end
            -- Use GTA.SpawnVehicleForPlayer (Cherax native — places it in front of the player)
            local handle = GTA.SpawnVehicleForPlayer(modelHash, pid, forward)
            if not handle or handle == 0 then
                -- Fallback: get player position and use SpawnVehicle
                local pedHnd = N_GetPlayerPed(pid)
                if not N_DoesEntityExist(pedHnd) then error("Ped does not exist") end
                local px, py, pz = N_GetEntityCoords(pedHnd)
                handle = GTA.SpawnVehicle(modelHash, px, py+forward, pz, 0.0, true, false)
                if not handle or handle == 0 then error("SpawnVehicle failed for: "..model) end
            end
            Natives.InvokeVoid(0xE532F5D78798DAAB, modelHash)
            return handle
        end)
        local msg = ok and ("Spawned "..model.." at "..username.."'s location") or tostring(result)
        respond(id, ok, msg); addLog("spawnforplayer", p, ok, msg)
    end)
end

-- ── /addfriend — Auto-process: if player not in session, auto-gets RID and retries ───
handlers.addfriend = function(p, id)
    local username = p.username or p.player_name or ""
    if not username or username == "" then
        respond(id, false, "No username provided")
        addLog("addfriend", p, false, "No username")
        return
    end

    -- Check if player is currently in session
    local pid = nil
    pcall(function()
        local want = username:lower():gsub("[^%w]","")
        local allIds = Players.Get() or {}
        for _, p2 in ipairs(allIds) do
            local n = (Players.GetName(p2) or ""):lower():gsub("[^%w]","")
            if n == want or n:find(want, 1, true) then pid = p2; break end
        end
    end)

    local ridHint = tonumber(p.rid or p.rockstar_id or "")

    local entry = {
        username   = username,
        pid        = pid,
        rid        = ridHint,
        id         = id,
        queued     = os.time(),
        status     = "ready_to_process",
        autoProcess = true,   -- always auto-process immediately
    }
    table.insert(pendingFriendRequests, entry)

    if pid then
        -- Player is in session → let them know and auto-process
        respond(id, true, "Player '" .. username .. "' found in session — sending friend request automatically...")
        addLog("addfriend", p, true, "In-session auto-process — " .. username)
    else
        -- Player NOT in session → notify and auto-process via SC RID lookup
        respond(id, true,
            "Player '" .. username .. "' not in session — auto-looking up RID via Social Club and sending friend request...")
        addLog("addfriend", p, true, "Not in session, auto RID lookup queued — " .. username)
        GUI.AddToast("The Gangs",
            "🔍 Auto-processing: " .. username .. "\n(not in session — looking up RID...)", 4000)
    end

    -- Immediately kick off processing without requiring manual click
    processAddFriend(entry)
end

-- ── PROCESS ADD FRIEND ──────────────────────────────
-- In session  → NETWORK_HANDLE_FROM_PLAYER → NETWORK_ADD_FRIEND (silent)
-- ══════════════════════════════════════════════════════════════
--  RID RESOLUTION  v7.3
--  Priority order:
--  1. In-session  → NETWORK_HANDLE_FROM_PLAYER (0x388EB2B86C73B6B3) native
--  2. In-session  → Players.GetById().GetGamerInfo().RockstarId  (Cherax high-level)
--  3. In-session  → Players.GetIPInfo / presence scan for cached handle
--  4. Not in sess → Walk all known player presence data (Cherax CNetworkPlayerMgr)
--  5. Not in sess → Stand-style: write RID directly into rlGamerHandle_buffer + open
--                   friends list (0xD528C7E2) + trigger "Add Friend" context option
--  6. Not in sess → GamerHandle.New() with RockstarId field  (Cherax high-level)
--  7. Not in sess → NETWORK_HANDLE_FROM_USER_ID (RID string → handle)
--  8. Fallback    → Open Social Club overlay manually
-- ══════════════════════════════════════════════════════════════

-- ── RID CACHE (persists across calls in same session) ──────────
local ridCache = ridCache or {}
local addFriendStringHash = nil
local converterTriggerHash = nil  -- discovered at runtime  -- discovered at runtime   -- ridCache[normName] = rid

-- Extract RID from a live GamerHandleBuffer (after NETWORK_HANDLE_FROM_PLAYER)
-- The rlGamerHandle layout: first 8 bytes = RID (int64, little-endian)
local function ridFromHandleBuffer(buf)
    if not buf then return nil end
    local rid = nil
    pcall(function()
        -- Try Cherax high-level field first
        if buf.RockstarId then
            rid = tonumber(buf.RockstarId)
            return
        end
        -- Fallback: read raw int64 from buffer pointer
        local ptr = buf:GetBuffer()
        if ptr and ptr ~= 0 then
            rid = tonumber(Memory.ReadInt64(ptr))
        end
    end)
    if rid and rid ~= 0 then return rid end
    return nil
end

-- Try to read RID from Cherax Players API for a player currently in session
local function getRidFromSession(pid)
    if not pid then return nil end
    local rid = nil

    -- Method A: NETWORK_HANDLE_FROM_PLAYER → read buffer
    pcall(function()
        local buf = GamerHandleBuffer.New()
        if not buf then return end
        Natives.InvokeVoid(0x388EB2B86C73B6B3, pid, buf:GetBuffer(), 13)
        if Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
            rid = ridFromHandleBuffer(buf)
        end
    end)
    if rid and rid ~= 0 then return rid end

    -- Method B: Players.GetById().GetGamerInfo().RockstarId
    pcall(function()
        local np = Players.GetById(pid)
        if not np then return end
        local info = np:GetGamerInfo()
        if info and info.RockstarId and info.RockstarId ~= 0 then
            rid = tonumber(info.RockstarId)
        end
    end)
    if rid and rid ~= 0 then return rid end

    -- Method C: presence / stats approach
    pcall(function()
        local np = Players.GetById(pid)
        if not np then return end
        -- Some builds expose .RockstarId directly on the player object
        if np.RockstarId and np.RockstarId ~= 0 then
            rid = tonumber(np.RockstarId)
        end
    end)

    return (rid and rid ~= 0) and rid or nil
end

-- Scan ALL players currently in session and cache their RIDs by normalised name
local function cacheSessionRids()
    local allIds = Players.Get() or {}
    for _, pid in ipairs(allIds) do
        local name = Players.GetName(pid) or ""
        if name ~= "" then
            local key = name:lower():gsub("[^%w]","")
            if not ridCache[key] then
                local rid = getRidFromSession(pid)
                if rid then
                    ridCache[key] = rid
                    Logger.Log(eLogColor.CYAN, "[The Gangs]",
                        string.format("[RID cache] %s = %d", name, rid))
                end
            end
        end
    end
end

-- Look up RID by username — checks cache, then live session
-- Read GTA5's SC Bearer token from process memory.
-- Rockstar RS256 JWTs always start with the same 36-byte header:
-- eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9
local scBearerToken = nil
local scBearerScannedAt = 0

local function getScBearerToken()
    -- Cache for 4 minutes (token expires ~5 min)
    if scBearerToken and (os.time() - scBearerScannedAt) < 240 then
        return scBearerToken
    end
    scBearerToken = nil
    pcall(function()
        -- Full constant RS256 header — unique to Rockstar JWTs
        local addr = Memory.Scan(
            "65 79 4A 68 62 47 63 69 4F 69 4A 53 55 7A 49 31 4E 69 49 73 49 6E 52 35 63 43 49 36 49 6B 70 58 56 43 4A 39")
        if not addr or addr == 0 then
            -- Shorter fallback: "eyJhbGci"
            addr = Memory.Scan("65 79 4A 68 62 47 63 69")
        end
        if not addr or addr == 0 then return end
        local t = Memory.ReadString(addr)
        if t and #t > 200 and t:find("%.") then
            scBearerToken = t
            scBearerScannedAt = os.time()
            Logger.Log(eLogColor.GREEN, "[The Gangs]",
                "[SC token] Found in memory, length=" .. #t)
        end
    end)
    return scBearerToken
end

-- SC API lookup using the live Bearer token from GTA memory
local function scLookupRid(username)
    if not username or username == "" then return nil end

    local encoded = username:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", c:byte())
    end)

    local token = getScBearerToken()
    if not token then
        Logger.Log(eLogColor.RED, "[The Gangs]", "[SC lookup] No Bearer token in memory")
        return nil
    end

    local rid = nil

    pcall(function()
        local c = Curl.Easy()
        c:Setopt(eCurlOption.CURLOPT_URL,
            "https://scapi.rockstargames.com/search/user?includeCommentCount=true&searchTerm=" .. encoded)
        c:Setopt(eCurlOption.CURLOPT_USERAGENT,
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        c:Setopt(eCurlOption.CURLOPT_NOPROGRESS, 1)
        c:Setopt(eCurlOption.CURLOPT_XOAUTH2_BEARER, token)
        c:AddHeader("X-Requested-With: XMLHttpRequest")
        c:AddHeader("x-lang: en-US")
        c:AddHeader("x-cache-ver: 0")
        c:AddHeader("Referer: https://socialclub.rockstargames.com/")
        c:Perform()
        local t = 0
        while not c:GetFinished() and t < 300 do Script.Yield(50); t = t + 1 end
        local code, resp = c:GetResponse()
        resp = resp or ""
        Logger.Log(eLogColor.CYAN, "[The Gangs]",
            string.format("[SC search] code=%s len=%d body=%s", tostring(code), #resp, resp:sub(1,150)))
        local wantLower = username:lower()
        for name, ridStr in resp:gmatch('"name":"([^"]+)","rockstarId":(%d+)') do
            if name:lower() == wantLower then rid = tonumber(ridStr); return end
        end
        if not rid then rid = tonumber(resp:match('"rockstarId":(%d+)')) end
    end)

    return (rid and rid ~= 0) and rid or nil
end

-- Scan in-game friend list for a matching name → RID
-- Uses NETWORK_GET_FRIEND_COUNT/NAME + NETWORK_HANDLE_FROM_FRIEND
local function scanFriendListForRid(username)
    local rid = nil
    pcall(function()
        local wantKey = username:lower():gsub("[^%w]","")
        -- 0x203F1CFD823B27A4 = NETWORK_GET_FRIEND_COUNT
        local friendCount = Natives.InvokeInt(0x203F1CFD823B27A4)
        if not friendCount or friendCount <= 0 then return end

        for i = 0, friendCount - 1 do
            -- 0xE11EBBB2A783FE8B = NETWORK_GET_FRIEND_NAME
            local fname = Natives.InvokeString(0xE11EBBB2A783FE8B, i) or ""
            local fkey  = fname:lower():gsub("[^%w]","")
            if fkey == wantKey or fkey:find(wantKey, 1, true) or wantKey:find(fkey, 1, true) then
                -- 0xD45CB817D7E177D2 = NETWORK_HANDLE_FROM_FRIEND
                local buf = GamerHandleBuffer.New()
                if buf then
                    Natives.InvokeVoid(0xD45CB817D7E177D2, i, buf:GetBuffer(), 13)
                    if Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
                        local handle = buf:ToHandle()
                        if handle and handle.RockstarId and handle.RockstarId ~= 0 then
                            rid = handle.RockstarId
                            break
                        end
                        -- fallback: read raw int64
                        local ptr = buf:GetBuffer()
                        if ptr and ptr ~= 0 then
                            local raw = Memory.ReadLong(ptr)
                            if raw and raw ~= 0 then rid = raw; break end
                        end
                    end
                end
            end
        end
    end)
    return rid
end

local function resolveRid(username)
    if not username or username == "" then return nil end
    local key = username:lower():gsub("[^%w]","")

    -- 1. Check cache
    if ridCache[key] then return ridCache[key] end

    -- 2. Try live session match (in-game memory)
    local allIds = Players.Get() or {}
    for _, pid in ipairs(allIds) do
        local name = Players.GetName(pid) or ""
        local nkey = name:lower():gsub("[^%w]","")
        if nkey == key or nkey:find(key, 1, true) or key:find(nkey, 1, true) then
            local rid = getRidFromSession(pid)
            if rid then
                ridCache[key] = rid
                ridCache[nkey] = rid
                return rid
            end
        end
    end

    -- 3. Scan in-game SC friend list (no HTTP needed)
    local rid3 = scanFriendListForRid(username)
    if rid3 then
        ridCache[key] = rid3
        Logger.Log(eLogColor.GREEN, "[The Gangs]",
            string.format("[RID] Found via friend list scan: %s = %d", username, rid3))
        return rid3
    end

    -- 4. HTTP: socialclub.rockstargames.com/friends/MemberSearch (no auth required)
    GUI.AddToast("The Gangs", "🌐 Looking up RID for " .. username .. " via Social Club...", 4000)
    local rid4 = scLookupRid(username)
    if rid4 then
        ridCache[key] = rid4
        Logger.Log(eLogColor.GREEN, "[The Gangs]",
            string.format("[RID] Found via SC lookup: %s = %d", username, rid4))
        return rid4
    end

    return nil
end

-- Opens the Social Club friends list overlay
-- Returns: true if opened successfully, false otherwise
local function openSocialClubFriendsList()
    while N_IsPauseMenuActive() do
        N_SetFrontendActive(false)
        Script.Yield(50)
    end
    N_ActivateFrontendMenu(0xD528C7E2, 0, 2)
    local waitCount = 0
    while not N_IsPauseMenuActive() and waitCount < 100 do
        Script.Yield(50)
        waitCount = waitCount + 1
    end
    return N_IsPauseMenuActive()
end

-- Send friend request given a known RID
-- Uses Stand-source-inspired approach: write RID into rlGamerHandle buffer,
-- open friends list, trigger "Add Friend" context option (0xE1E8D5DC)
local function sendAddFriendByRid(rid)
    -- ── Method 1: GamerHandle.New() with RockstarId ──────────────
    local ok1 = false
    pcall(function()
        local handle = GamerHandle.New()
        handle.RockstarId = rid
        handle.Platform   = 3
        if handle:IsValid() then
            local buf = handle:ToBuffer()
            if buf then
                ok1 = Natives.InvokeBool(0x8E02D73914064223, buf:GetBuffer(), "")
            end
        end
    end)
    if ok1 then return true, "sent via GamerHandle.New()" end

    -- ── Method 2: NETWORK_HANDLE_FROM_USER_ID → NETWORK_ADD_FRIEND ─
    local ok2 = false
    pcall(function()
        local buf = GamerHandleBuffer.New()
        if not buf then return end
        Natives.InvokeVoid(0xDCD51DD8F87AEC5C, tostring(rid), buf:GetBuffer(), 13)
        if Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
            ok2 = Natives.InvokeBool(0x8E02D73914064223, buf:GetBuffer(), "")
        end
    end)
    if ok2 then return true, "sent via USER_ID handle" end

    -- ── Method 3: NETWORK_HANDLE_FROM_MEMBER_ID ────────────────────
    local ok3 = false
    pcall(function()
        local buf = GamerHandleBuffer.New()
        if not buf then return end
        Natives.InvokeVoid(0xA0FD21BED61E5C4C, tostring(rid), buf:GetBuffer(), 13)
        if Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
            ok3 = Natives.InvokeBool(0x8E02D73914064223, buf:GetBuffer(), "")
        end
    end)
    if ok3 then return true, "sent via MEMBER_ID handle" end

    -- ── Method 4 (Stand-style): write RID → rlGamerHandle_buffer,
    --    open friends list, trigger "Add Friend" context option 0xE1E8D5DC
    --    As per JoinUtil::inviteViaRid() in Stand source ──────────────
    local ok4 = false
    local msg4 = ""
    pcall(function()
        -- Write RID as int64 into a scratch GamerHandleBuffer
        -- then pass it to NETWORK_ADD_FRIEND directly
        local buf = GamerHandleBuffer.New()
        if not buf then return end
        local ptr = buf:GetBuffer()
        if not ptr or ptr == 0 then return end

        -- Write the RID as a 64-bit integer at offset 0 of the buffer
        -- (rlGamerHandle: first 8 bytes = m_rockstarId)
        Memory.WriteInt64(ptr, rid)
        -- Mark platform = 3 (PC) at offset 8 (4 bytes)
        Memory.WriteInt32(ptr + 8, 3)

        -- Force-validate by calling IS_HANDLE_VALID check
        -- (skipping NETWORK_HANDLE_FROM_x; we're writing directly like Stand does)
        ok4 = Natives.InvokeBool(0x8E02D73914064223, ptr, "")
        if ok4 then msg4 = "sent via direct buffer write (Stand-style)" end
    end)
    if ok4 then return true, msg4 end

    -- ── Method 5 (FeatureMgr built-in) ────────────────────────────
    local ok5 = false
    pcall(function()
        FeatureMgr.SetFeatureInt(24693643, rid)
        FeatureMgr.TriggerFeatureCallback(1744318427)
        ok5 = true
    end)
    if ok5 then return true, "sent via FeatureMgr built-in" end

    -- ── Method 6: Open SC overlay — user adds manually ────────────
    local ok6 = false
    pcall(function() ok6 = openSocialClubFriendsList() end)
    if ok6 then return "manual", "opened_social_club" end

    return false, "all methods failed for RID=" .. tostring(rid)
end

-- In-session: build handle from live player slot → NETWORK_ADD_FRIEND
local function sendAddFriendByPid(pid)
    local buf = GamerHandleBuffer.New()
    if not buf then return false, "GamerHandleBuffer.New() failed" end
    Natives.InvokeVoid(0x388EB2B86C73B6B3, pid, buf:GetBuffer(), 13)
    if not Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
        return false, "handle invalid after NETWORK_HANDLE_FROM_PLAYER"
    end
    local ok = Natives.InvokeBool(0x8E02D73914064223, buf:GetBuffer(), "")
    return ok, ok and "sent" or "NETWORK_ADD_FRIEND returned false"
end

-- ── Friend / Invite hashes (from Cherax native scan) ────────
-- These are player-context features — require SetSelectedPlayer(pid) first
SN_FRIEND = {
    -- "Friend" context features
    F1            = -544796115,  -- hash 3750171181 unsigned
    F2            =  2091521983,
    -- "Invite / Session" context features  
    AddFriend     =  1744318427, -- confirmed: Send Friend Request
    I1            =  1970271281,
    I2            =   896960880,
    I3            = -1732593250, -- hash 2562374046 unsigned
    I4            =   124438863,
}

-- All 5 invite hashes (signed int32 — Cherax requires signed values)
-- 2562374046 unsigned = -1732593250 signed (was the bug — passed wrong value)
local INVITE_HASHES = {
    1744318427,
    1970271281,
    -1732593250,  -- was 2562374046 unsigned — FIXED
     124438863,
     896960880,
}

-- ── Cherax player feature hash tables (from full dump, 32 hashes each) ─────
-- t=1 = toggle,  t=0 = action (TriggerFeatureCallback)
local STUN_PLAYER_HASHES = {
    3849408494, 1974104162, 1207211255, 1556758178, 3637229371, 3338146708,
    4230905344, 3936606955, 265626957, 4248797218, 1304349574, 980133088,
    693764797, 385867273, 114900412, 4102330643, 3801118007, 3504787940,
    3664798955, 3355754516, 2133928730, 2749920392, 2033262350, 2810706875,
    2325987827, 3219532919, 2957413688, 3734071757, 77968897, 4082832236,
    959258599, 1139225947,
}
local CAGE_PLAYER_HASHES = {
    1505541845, 1013974076, 1798234553, 1573209830, 192750163, 36179881,
    803859244, 3557372780, 3368230112, 4135123019, 1814773935, 2184998097,
    1797963442, 2039896969, 3333617093, 1427804818, 2723032316, 2959067423,
    4255802291, 2345795588, 1558062509, 1251442976, 3226037382, 2920007691,
    3357637690, 3059210407, 3986966335, 2603688538, 3510931072, 4237223188,
    3881810406, 1097690620,
}
local KILL_PLAYER_HASHES = {
    1722033568, 410880332, 2318527675, 1106369588, 800503742, 3772258818,
    1395293861, 3938463190, 3573219916, 237696171, 4062396094, 1864939719,
    2238113091, 1990477758, 684239880, 2852007537, 2554235634, 3445617972,
    3148566987, 16768115, 2481291492, 342360559, 628728850, 988335856,
    1244097901, 1554879097, 1859335876, 2166905710, 2471690179, 2376299736,
    1951948914, 110363911,
}
local EXPLODE_LOOP_HASHES = {
    4116120077, 1815015351, 1497909738, 1057494378, 3167326451, 845249569,
    407914495, 101491576, 3802225822, 3502029013, 2718377707, 1947585289,
    2254663588, 1962724539, 1468764633, 1754543082, 976639791, 1305443937,
    278529015, 561817020, 3462759027, 3766167198, 1276771802, 359370878,
    663565505, 356814892, 665203951, 1929628585, 2218946086, 1317536434,
    3183566811, 3405118020,
}
local CLEAR_WANTED_HASHES = {
    1012309971, 1242315582, 2427537543, 2674615803, 4113273214, 333631212,
    1501944369, 1748236173, 3201443020, 3432562777, 471681852, 4038980738,
    3199668341, 358858185, 3811694954, 3505763566, 2661470281, 4085873173,
    3269302462, 1482015660, 889290856, 4282225885, 162048435, 1676336694,
    1847390874, 3094480715, 3804322793, 349159425, 658859244, 1112906516,
    1321513678, 141665829,
}
local SHOCK_WAVE_HASHES = {
    1176089013, 997629039, 3650443438, 1899005934, 2659148427, 2497597257,
    399004947, 3363845764, 3148487896, 3926653339, 108030438, 3407541052,
    3889900732, 2930784871, 2642089981, 4092347630, 96299152, 3633286709,
    3131658857, 3400462964, 596384833, 691677085, 2063518505, 1584960029,
    1882338704, 3252017366, 3549985883, 2508685370, 2815304903, 4239249073,
    1625331765, 3034202151,
}
local FIRE_LOOP_HASHES = {
    519813992, 279584453, 979595831, 1451928165, 1221922554, 1931961246,
    1697564589, 2641246251, 2411371716, 3121672560, 960290195, 3687457459,
    371791724, 1214282714, 2124703841, 608285597, 1532928470, 1288701113,
    1530110340, 1292436783, 3884300562, 3654032799, 1128001657, 897144052,
    529344796, 290426017, 542386862, 303468083, 2093900705, 1856751452,
    163011793, 394655854,
}
local WATER_LOOP_HASHES = {
    2508911675, 3513084911, 1660030730, 217604908, 2670200713, 4200250865,
    4219846727, 1454372506, 3891337502, 582487723, 3818905835, 3648965801,
    305282495, 4216524801, 630580358, 390154205, 3409358793, 3027075639,
    2122028620, 3615410265, 191508871, 1604901379, 774338305, 4234711940,
    4291926622, 109750224, 473125665, 821656749, 3910429924, 3067250785,
    2021324451, 1723814700,
}
local AIRSTRIKE_HASHES = {
    486649102, 2404618672, 3246749203, 3023264623, 3866509304, 654164222,
    1492624629, 1272548025, 2103733710, 4033762272, 2248816668, 1975457670,
    2743989027, 2435567199, 3237064170, 2927692041, 3695928477, 3390423090,
    4187430704, 659094163, 1423267015, 1655631994, 1073654554, 2379171518,
    2608783901, 2881618539, 3187058388, 275729344, 4072214612, 84653305,
    2349908457, 2163452847,
}
local ORBITAL_STRIKE_HASHES = {
    834804738, 2618093718, 3330262395, 2965281273, 1777831020, 3566625192,
    496595889, 257349420, 3240049342, 3001130563, 166416370, 458453698,
    607454341, 905455627, 3502235036, 2728231256, 4016773874, 19971709,
    310010048, 3827794971, 4176163794, 3932264127, 328722731, 96816518,
    794861756, 554894369, 1137854883, 900443478, 1601634540, 1361405001,
    4024312464, 3259058007,
}
local LAUNCH_VEH_HASHES = {
    2410817009, 2347310687, 4128699065, 3903084500, 1387441139, 1148194670,
    2919621272, 2680964645, 529384874, 425113916, 1796672990, 3561349178,
    2387465291, 2031004109, 111854843, 4041841017, 2787705845, 338518016,
    963553922, 733286159, 699599931, 937404564, 199118994, 2851835086,
    4072644181, 11156010, 1177273628, 1407279239, 2628547100, 948677084,
    667026673, 1023422317,
}
local SEND_SKY_HASHES = {
    1072758421, 4135840700, 474822478, 805068468, 1035401769, 148476015,
    445330386, 1728302274, 1959946335, 1131349401, 3627388574, 3834816356,
    3594816200, 519150625, 4074390515, 1031592247, 799161730, 1494192220,
    1263400153, 3824199148, 3525248489, 2837656566, 2656968300, 3313364139,
    3132348183, 1371374884, 1068687631, 2389606021, 2086722154, 4207269682,
    328041417, 3045279658,
}
local OFF_RADAR_HASHES = {
    403453963, 712891630, 357872248, 688314844, 971799463, 3416334098,
    3728294978, 4058999726, 2201620069, 2508534523, 2050583497, 3290660768,
    1288605940, 2533729637, 2966214899, 4117455407, 2235040202, 3655052048,
    3952496261, 751882493, 770959307, 466174838, 758572629, 460866264,
    3335100792, 4111201788, 3794882631, 2423631057, 2142505806, 2918344650,
    930478451, 694443344,
}
local BOUNTY_HASHES = {
    2873413534, 2570267515, 2260207237, 4014692310, 10910348, 972844343,
    3693851031, 2790245824, 3078678562, 2427066997, 3268896222, 2948939706,
    2655755463, 2937732712, 2640354037, 2343139199, 2029179410, 1716300998,
    1402898282, 1118692745, 1946765119, 2897918105, 2658737174, 3382669922,
    3143816681, 3625848683, 3127235579, 4103161937, 3866995754, 510893077,
    3317902666, 3063451381,
}
local DEATH_BARRIER_HASHES = {
    3735745903, 3411267265, 3106810486, 938551294, 620790301, 2451725407,
    2173614904, 1657339289, 1351964978, 1047475430, 2581095018, 2344076841,
    2239412655, 2019237744, 1642263172, 1020831856, 782175229, 423485755,
    184239286, 100612798, 333696823, 587033962, 2946074268, 3195806817,
    3630192681, 3935173764, 1979454306, 2285025231, 2706958875, 867274446,
    837256634, 590374988,
}

-- Core invite dispatcher
-- Mutex: prevent overlapping invite jobs
local inviteBusy = false

-- doInvite: fires all 5 invite hashes.
-- In-session:  SetSelectedPlayer(pid) → fire all INVITE_HASHES
-- Offline:     resolveRid → SetFeatureInt(24693643, rid) → fire all INVITE_HASHES
--              Same pattern as processAddFriend which is confirmed working.
local function doInvite(pid, label, friendIdx)
    Script.QueueJob(function()

        local waited = 0
        while inviteBusy and waited < 3000 do
            Script.Yield(50)
            waited = waited + 50
        end
        inviteBusy = true

        local ok, err = pcall(function()

            if pid then
                -- IN-SESSION: select player then fire all invite hashes
                Logger.Log(eLogColor.CYAN, "[Invite]",
                    string.format("In-session invite -> %s (pid=%d)", label, pid))
                Utils.SetSelectedPlayer(pid)
                Script.Yield(80)
                for _, h in ipairs(INVITE_HASHES) do
                    pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                    Script.Yield(30)
                end
                Logger.Log(eLogColor.GREEN, "[Invite]", "All hashes fired for " .. label)
            else
                -- OFFLINE: load RID into feature 24693643 (same as addFriend), fire all invite hashes
                Logger.Log(eLogColor.CYAN, "[Invite]", "Offline invite -> " .. label)
                local rid = resolveRid(label)
                if not rid then
                    Logger.Log(eLogColor.RED, "[Invite]", "RID not resolved for " .. label)
                    return
                end
                Logger.Log(eLogColor.GREEN, "[Invite]",
                    string.format("  RID=%d, firing all %d invite hashes", rid, #INVITE_HASHES))
                FeatureMgr.SetFeatureInt(24693643, rid)
                Script.Yield(150)
                for _, h in ipairs(INVITE_HASHES) do
                    pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                    Script.Yield(30)
                end
                Logger.Log(eLogColor.GREEN, "[Invite]",
                    string.format("All invite hashes fired for %s (RID=%d)", label, rid))
            end
        end)

        inviteBusy = false
        if not ok then
            Logger.Log(eLogColor.RED, "[Invite]", "doInvite error: " .. tostring(err))
        end
    end)
end

-- Invite player to session — tries each invite hash with SetSelectedPlayer
handlers.invite_player = function(p, id)
    local username = (p and p.username) or ""
    local pid, err = findPlayerByName(username)
    if not pid then respond(id, false, err); return end

    Script.QueueJob(function()
        pcall(function() Utils.SetSelectedPlayer(pid) end)
        Script.Yield(80)
        for _, h in ipairs(INVITE_HASHES) do
            pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
            Script.Yield(30)
        end
        local msg = "Invite sent to "..username
        Logger.Log(eLogColor.GREEN, "[The Gangs]", msg)
        addLog("invite_player", p, true, msg)
        respond(id, true, msg)
    end)
end

local function processAddFriend(entry)
    entry.status = "processing"
    Script.QueueJob(function()
        local username = entry.username or ""
        local rid = entry.rid  -- may be pre-filled from manual RID input

        -- Re-check if player joined session since queuing
        local pid = entry.pid
        if not pid then
            pcall(function()
                local want = username:lower():gsub("[^%w]","")
                local allIds = Players.Get() or {}
                for _, p in ipairs(allIds) do
                    local n = (Players.GetName(p) or ""):lower():gsub("[^%w]","")
                    if n == want or n:find(want, 1, true) then pid = p; break end
                end
            end)
        end

        -- Path A: player in session → SetSelectedPlayer + trigger "Send Friend Request"
        if pid then
            local sentOk = false
            pcall(function()
                Utils.SetSelectedPlayer(pid)
                Script.Yield(200)   -- wait for Cherax to process the selection
                Utils.SetSelectedPlayer(pid)  -- set again to be safe after yield
                Script.Yield(100)
                FeatureMgr.TriggerFeatureCallback(2296637101)
                sentOk = true
            end)
            if sentOk then
                entry.status = "done"
                entry.result = "Friend request sent to " .. username .. " (in session)"
                addLog("addfriend", {username=username}, true, entry.result)
                GUI.AddToast("The Gangs", entry.result, 4000)
                pcall(function() respond(entry.id, true, entry.result) end)
                return
            end
            -- fallback: get RID from session for offline method
            pcall(function()
                local np = Players.GetById(pid)
                if np then
                    local info = np:GetGamerInfo()
                    if info and info.RockstarId and info.RockstarId ~= 0 then
                        rid = info.RockstarId
                    end
                end
            end)
        end

        -- Path B: SetFeatureString -> Cherax resolves -> GetFeatureInt reads back RID
        -- Pass the username to feature 24693643 as a string, Cherax resolves it
        -- internally, then read the resolved RID back with GetFeatureInt.
        if not rid then
            pcall(function()
                -- CRITICAL: Clear the cached value first to prevent getting old RID
                FeatureMgr.SetFeatureInt(24693643, 0)
                Script.Yield(100)
                FeatureMgr.SetFeatureString(24693643, "")
                Script.Yield(100)
                
                -- Now set the new username
                local before = FeatureMgr.GetFeatureInt(24693643) or 0
                FeatureMgr.SetFeatureString(24693643, username)
                Script.Yield(150)
                
                -- Wait up to 3s for Cherax to resolve username -> RID
                for i = 1, 60 do
                    Script.Yield(50)
                    local cur = FeatureMgr.GetFeatureInt(24693643) or 0
                    if cur ~= 0 and cur ~= before then
                        rid = cur
                        break
                    end
                end
            end)
            if rid then
                addLog("addfriend", {username=username}, true,
                    "RID resolved via SetFeatureString: " .. tostring(rid) .. " for " .. username)
            end
        end

        -- Path C: cache / friend list / SC lookup fallback
        if not rid then
            cacheSessionRids()
            rid = resolveRid(username)
        end

        -- ── Offline: Cherax built-in username→RID converter (hardcoded hashes) ──
        -- 503433448  = "Converter Mode" (list: 0=RID→Name, 1=Name→RID)
        -- 2563258164 = "Converter In"   (string input)
        -- 3276760136 = "Convert"        (trigger button)
        -- 2627874692 = "Converter Out"  (string output — the resolved RID)
        if not rid then
            pcall(function()
                -- CRITICAL: Clear converter cache first
                FeatureMgr.SetFeatureString(2563258164, "")
                Script.Yield(100)
                FeatureMgr.SetFeatureString(2627874692, "")
                Script.Yield(100)
                
                -- Now set new values
                FeatureMgr.SetFeatureListIndex(503433448, 1)  -- Name→RID mode
                Script.Yield(100)
                FeatureMgr.SetFeatureString(2563258164, username)
                Script.Yield(150)
                FeatureMgr.TriggerFeatureCallback(3276760136)  -- press Convert
                Script.Yield(100)
            end)

            -- Poll output for up to 5 seconds
            for i = 1, 100 do
                Script.Yield(50)
                local out = nil
                pcall(function() out = FeatureMgr.GetFeatureString(2627874692) end)
                local resolved = tonumber(out)
                if resolved and resolved > 1000 then
                    rid = resolved
                    Logger.Log(eLogColor.GREEN, "[The Gangs]",
                        string.format("[Converter] %s → RID=%d", username, rid))
                    break
                end
            end
        end

        if not rid then
            entry.status = "failed"
            entry.result = "Could not resolve RID for '" .. username .. "'"
            addLog("addfriend", {username=username}, false, entry.result)
            GUI.AddToast("The Gangs", entry.result, 4000)
            pcall(function() respond(entry.id, false, entry.result) end)
            return
        end

        -- Fire — send friend request by RID
        FeatureMgr.SetFeatureInt(24693643, rid)
        Script.Yield(150)
        FeatureMgr.SetFeatureString(1418003384, username)
        Script.Yield(150)
        -- Only use ONE callback
        pcall(function()
            FeatureMgr.TriggerFeatureCallback(2296637101)
        end)

        -- Wait for request to send
        Script.Yield(800)

        -- Method 1 ONLY (testing): Home key via user32.dll keybd_event
        pressHomeKey()
        Script.Yield(500)

        entry.status = "done"
        entry.result = "Friend request sent to " .. username .. " (RID: " .. tostring(rid) .. ")"
        addLog("addfriend", {username=username}, true, entry.result)
        GUI.AddToast("The Gangs", entry.result, 4000)
        pcall(function() respond(entry.id, true, entry.result) end)
    end)
end

-- ── SilentNight: Nightclub ────────────────────────────────────
-- Uses Utils.Joaat() to call SilentNight feature callbacks.
-- SilentNight must be loaded for these to work.
-- Hashes pre-computed from eFeature.lua J("SN_...") keys.
local SN = {
    Nightclub = {
        Open     = -606472730,   -- Open Computer (button)
        Setup    = -378167917,   -- Skip Setup (button)
        Fill     = -1789372830,  -- Fill Safe (button)
        Collect  =  1959272889,  -- Collect Safe (button)
        Unbrick  =  1230378092,  -- Unbrick Safe (button)
        Cooldown = -1562267577,  -- Kill Cooldowns (toggle) — NOTE: typo in SN source "Nighclub"
        Price    = -2073487253,  -- Maximize Price (loop)
        PopMax   = -1180803088,  -- Popularity Max (button)
        PopMin   =  -588075100,  -- Popularity Min (button)
    }
}

local function snTrigger(hash)
    local ok = false
    pcall(function()
        FeatureMgr.TriggerFeatureCallback(hash)
        ok = true
    end)
    return ok
end

local function snToggle(hash, enabled)
    local ok = false
    pcall(function()
        local f = FeatureMgr.GetFeature(hash)
        if f then
            f:Toggle(enabled)
            ok = true
        end
    end)
    return ok
end



-- Verify SilentNight hashes are actually registered in Cherax
handlers.sn_dump = function(p, id)
    Script.QueueJob(function()
        -- All pre-computed SN_ joaat hashes to verify
        local snHashes = {
            -- Diamond Casino
            { hash =  880689876, key = "SN_DiamondCasino_Complete"       },
            { hash = 1000340906, key = "SN_DiamondCasino_Reset"          },
            { hash =   42128082, key = "SN_DiamondCasino_Finish"         },
            { hash = -425401770, key = "SN_DiamondCasino_Launch"         },
            { hash = -444964543, key = "SN_DiamondCasino_Force"          },
            { hash = -210608263, key = "SN_DiamondCasino_FingerprintHack"},
            { hash = -488438405, key = "SN_DiamondCasino_KeypadHack"     },
            { hash = -888427170, key = "SN_DiamondCasino_VaultDoorDrill" },
            { hash =  795655781, key = "SN_DiamondCasino_Autograbber"    },
            { hash =    -390299, key = "SN_DiamondCasino_Cooldown"       },
            { hash = -273052068, key = "SN_DiamondCasino_MaxPayout"      },
            -- Nightclub
            { hash = -606472730, key = "SN_Nightclub_Open"    },
            { hash = -378167917, key = "SN_Nightclub_Setup"   },
            { hash = -1789372830,key = "SN_Nightclub_Fill"    },
            { hash = 1959272889, key = "SN_Nightclub_Collect" },
            { hash = 1230378092, key = "SN_Nightclub_Unbrick" },
            { hash =-1562267577, key = "SN_Nighclub_Cooldown" },
            { hash =-1180803088, key = "SN_Nightclub_Max"     },
            -- Teleports
            { hash =  856093405, key = "SN_Agency_Entrance"         },
            { hash =  515889825, key = "SN_CayoPerico_Teleport"     },
            { hash =-2027444131, key = "SN_DiamondCasino_Entrance"  },
            { hash = -946253062, key = "SN_DiamondCasino_Board"     },
            { hash = 1757188373, key = "SN_Bunker_Entrance"         },
            { hash = 1256153318, key = "SN_Hangar_Entrance"         },
            { hash = -835861917, key = "SN_Nightclub_Entrance"      },
            -- Cuts
            { hash = -971601383, key = "SN_DiamondCasino_Player1_Cut" },
            { hash =-1550203166, key = "SN_DiamondCasino_Apply"       },
            { hash =  954877045, key = "SN_CayoPerico_Player1_Cut"    },
            { hash =  721953058, key = "SN_CayoPerico_Apply"          },
        }
        local ok_count, fail_count = 0, 0
        for _, entry in ipairs(snHashes) do
            local name = "NOT FOUND"
            local found = false
            pcall(function()
                local f = FeatureMgr.GetFeature(entry.hash)
                if f then
                    name = f:GetName() or "?"
                    found = true
                end
            end)
            local color = found and eLogColor.GREEN or eLogColor.RED
            Logger.Log(color, "[SN Verify]",
                string.format("[%s] hash=%d display=%q", found and "OK" or "MISS", entry.hash, name))
            if found then ok_count = ok_count + 1 else fail_count = fail_count + 1 end
        end
        local msg = string.format("%d OK / %d MISSING — check log for details", ok_count, fail_count)
        Logger.Log(eLogColor.CYAN, "[SN Verify]", msg)
        respond(id, true, msg)
    end)
end

-- Scan ALL Cherax native features matching a keyword
-- /cherax_scan category=friend|invite|session|all
handlers.cherax_scan = function(p, id)
    local category = (p and p.category) or "friend"
    Script.QueueJob(function()
        local sets = {
            friend  = {"friend","Friend","Add Friend","Send Friend"},
            invite  = {"Invite","invite","Session","Join"},
            session = {"Session","session","Join","Matchmaking"},
            all     = {"friend","Friend","Invite","invite","Session","session",
                       "Social","Rockstar","Add","Request"},
        }
        local terms = sets[category] or sets.all
        local found = 0

        local function scanHashList(hashList, source)
            for _, hash in ipairs(hashList) do
                local name = ""
                local ftype = "?"
                pcall(function()
                    local f = FeatureMgr.GetFeature(hash)
                    if f then
                        name  = f:GetName() or ""
                        ftype = tostring(f:GetType())
                    end
                end)
                if name ~= "" then
                    for _, term in ipairs(terms) do
                        if name:find(term, 1, true) then
                            Logger.Log(eLogColor.CYAN, "[Cherax Scan]",
                                string.format("[%s] hash=%d type=%s name=%q", source, hash, ftype, name))
                            found = found + 1
                            break
                        end
                    end
                end
            end
        end

        -- Scan both regular AND player-context features
        -- (invite/session actions live in player features)
        scanHashList(FeatureMgr.GetAllFeatureHashes() or {}, "feature")
        scanHashList(FeatureMgr.GetAllPlayerFeatureHashes() or {}, "player_feature")

        Logger.Log(eLogColor.GREEN, "[Cherax Scan]",
            string.format("Done — %d matches for [%s] (checked feature + player_feature hashes)", found, category))
        respond(id, true, string.format("%d features found — check Cherax log", found))
    end)
end

-- ── SilentNight: Diamond Casino Heist ────────────────────────
SN.DiamondCasino = {
    Complete        =  880689876,   -- Apply & Complete Preps (button)
    Reset           = 1000340906,   -- Reset Preps (button)
    Reload          =  686847283,   -- Reload Preps (button)
    Launch          = -425401770,   -- Solo Launch (toggle)
    LaunchReset     = -270831077,   -- Reset Solo Launch (button)
    Force           = -444964543,   -- Force Heist (button)
    Finish          =   42128082,   -- Finish Heist (button)
    FingerprintHack = -210608263,   -- Auto Fingerprint Hack (toggle)
    KeypadHack      = -488438405,   -- Auto Keypad Hack (toggle)
    VaultDoorDrill  = -888427170,   -- Auto Vault Door Drill (toggle)
    Autograbber     =  795655781,   -- Auto Grabber (toggle)
    Cooldown        =    -390299,   -- Kill Cooldowns (toggle)
    MaxPayout       = -273052068,   -- Max Payout (toggle)
}

-- ── SilentNight: Cayo Perico Heist ───────────────────────────
SN.CayoPerico = {
    Complete        = -242608804,   -- Apply & Complete Preps (button)
    Reset           = -365209653,   -- Reset Preps (button)
    Reload          = -641965750,   -- Reload Preps (button)
    Launch          = 1768995574,   -- Solo Launch (toggle)
    LaunchReset     = -1067035016,  -- Reset Solo Launch (button)
    Force           = -1749577588,  -- Force Heist (button)
    Finish          = 1473112550,   -- Finish Heist (button)
    FingerprintHack = 1242829781,   -- Auto Fingerprint Hack (toggle)
    PlasmaCutter    = -259770489,   -- Auto Plasma Cutter (toggle)
    DrainagePipe    = 1888659592,   -- Auto Drainage Pipe (toggle)
    Bag             = -1508430446,  -- Auto Bag (toggle)
    SoloCooldown    = 1711109084,   -- Kill Solo Cooldown (toggle)
    TeamCooldown    = -186370355,   -- Kill Team Cooldown (toggle)
    MaxPayout       = -1068582605,  -- Max Payout (toggle)
    Crew            = 1054635001,   -- Crew (toggle)
    Teleport        = 515889825,    -- Teleport to Kosatka (button)
}

-- ── SilentNight: Doomsday Heist ──────────────────────────────
SN.Doomsday = {
    Act             = 101269549,    -- Select Act (list)
    Complete        = 531142350,    -- Apply & Complete Preps (button)
    Reset           = -1205214720,  -- Reset Preps (button)
    Reload          = -2115968239,  -- Reload Preps (button)
    Launch          = 1951345930,   -- Solo Launch (toggle)
    LaunchReset     = 160762128,    -- Reset Solo Launch (button)
    Force           = -1049328465,  -- Force Heist (button)
    DataHack        = 1884731716,   -- Auto Data Hack (toggle)
    DoomsdayHack    = 351358884,    -- Auto Doomsday Hack (toggle)
    Cooldown        = -1948562566,  -- Kill Cooldowns (toggle)
    MaxPayout       = 1833223294,   -- Max Payout (toggle)
}

-- ── SilentNight: Apartment (Legacy) Heists ───────────────────
SN.Apartment = {
    Complete        = -74155063,    -- Apply & Complete Preps (button)
    Reload          = -336203263,   -- Reload Preps (button)
    Launch          = 2035430584,   -- Solo Launch (toggle)
    LaunchReset     = -1471663085,  -- Reset Solo Launch (button)
    Force           = -171356745,   -- Force Heist (button)
    Finish          = -245418285,   -- Finish Heist (button)
    FleecaHack      = -1960642477,  -- Auto Fleeca Hack (toggle)
    FleecaDrill     = -2143058475,  -- Auto Fleeca Drill (toggle)
    PacificHack     = 1432884331,   -- Auto Pacific Hack (toggle)
    Cooldown        =  658317448,   -- Kill Cooldowns (toggle)
    MaxPayout       = 1456656135,   -- Max Payout (toggle)
    Bonus           = -1807409550,  -- Bonus Cash (toggle)
    Double          = 1590092642,   -- Double Cash (toggle)
}

-- ── SilentNight: Agency (Dr. Dre / Contract) ─────────────────
SN.Agency = {
    Complete        = -1517032611,  -- Apply & Complete Preps (button)
    Cooldown        = 1114004650,   -- Kill Cooldowns (toggle)
    Finish          =  393684502,   -- Finish Heist (button)
    SelectPayout    = 1560786087,   -- Select Payout (int)
    MaxPayout       = 1986871866,   -- Max Payout (button)
    ApplyPayout     = -1020624594,  -- Apply Payout (button)
}

handlers.casino = function(p, id)
    local action = (p and p.action) or ""
    local ok, msg = false, "Unknown action: " .. action

    if action == "complete" then
        ok = snTrigger(SN.DiamondCasino.Complete)
        msg = ok and "Diamond Casino preps completed" or "Failed — is SilentNight loaded?"

    elseif action == "reset" then
        ok = snTrigger(SN.DiamondCasino.Reset)
        msg = ok and "Diamond Casino preps reset" or "Failed — is SilentNight loaded?"

    elseif action == "reload" then
        ok = snTrigger(SN.DiamondCasino.Reload)
        msg = ok and "Diamond Casino preps reloaded" or "Failed — is SilentNight loaded?"

    elseif action == "launch_on" then
        ok = snToggle(SN.DiamondCasino.Launch, true)
        msg = ok and "Solo Launch ON" or "Failed — is SilentNight loaded?"

    elseif action == "launch_off" then
        ok = snToggle(SN.DiamondCasino.Launch, false)
        msg = ok and "Solo Launch OFF" or "Failed — is SilentNight loaded?"

    elseif action == "force" then
        ok = snTrigger(SN.DiamondCasino.Force)
        msg = ok and "Diamond Casino heist forced" or "Failed — is SilentNight loaded?"

    elseif action == "finish" then
        ok = snTrigger(SN.DiamondCasino.Finish)
        msg = ok and "Diamond Casino heist finished" or "Failed — is SilentNight loaded?"

    elseif action == "fingerprint_on" then
        ok = snToggle(SN.DiamondCasino.FingerprintHack, true)
        msg = ok and "Auto Fingerprint Hack ON" or "Failed — is SilentNight loaded?"

    elseif action == "fingerprint_off" then
        ok = snToggle(SN.DiamondCasino.FingerprintHack, false)
        msg = ok and "Auto Fingerprint Hack OFF" or "Failed — is SilentNight loaded?"

    elseif action == "keypad_on" then
        ok = snToggle(SN.DiamondCasino.KeypadHack, true)
        msg = ok and "Auto Keypad Hack ON" or "Failed — is SilentNight loaded?"

    elseif action == "keypad_off" then
        ok = snToggle(SN.DiamondCasino.KeypadHack, false)
        msg = ok and "Auto Keypad Hack OFF" or "Failed — is SilentNight loaded?"

    elseif action == "drill_on" then
        ok = snToggle(SN.DiamondCasino.VaultDoorDrill, true)
        msg = ok and "Auto Vault Door Drill ON" or "Failed — is SilentNight loaded?"

    elseif action == "drill_off" then
        ok = snToggle(SN.DiamondCasino.VaultDoorDrill, false)
        msg = ok and "Auto Vault Door Drill OFF" or "Failed — is SilentNight loaded?"

    elseif action == "autograb_on" then
        ok = snToggle(SN.DiamondCasino.Autograbber, true)
        msg = ok and "Auto Grabber ON" or "Failed — is SilentNight loaded?"

    elseif action == "autograb_off" then
        ok = snToggle(SN.DiamondCasino.Autograbber, false)
        msg = ok and "Auto Grabber OFF" or "Failed — is SilentNight loaded?"

    elseif action == "cooldown_on" then
        ok = snToggle(SN.DiamondCasino.Cooldown, true)
        msg = ok and "Kill Cooldowns ON" or "Failed — is SilentNight loaded?"

    elseif action == "cooldown_off" then
        ok = snToggle(SN.DiamondCasino.Cooldown, false)
        msg = ok and "Kill Cooldowns OFF" or "Failed — is SilentNight loaded?"

    elseif action == "maxpayout_on" then
        ok = snToggle(SN.DiamondCasino.MaxPayout, true)
        msg = ok and "Max Payout ON" or "Failed — is SilentNight loaded?"

    elseif action == "maxpayout_off" then
        ok = snToggle(SN.DiamondCasino.MaxPayout, false)
        msg = ok and "Max Payout OFF" or "Failed — is SilentNight loaded?"
    end

    addLog("casino", p, ok, msg)
    respond(id, ok, msg)
end

-- ── heist_status: called by /heists_status Discord command ───
handlers.heist_status = function(p, id)
    local hs = readJson(BRIDGE.heistStatFile)
    local enabled = hs and hs.enabled == true
    respond(id, true, "Heist status read", { enabled = enabled })
    addLog("heist_status", {}, true, "Heist status sent to Discord", "discord")
end

-- ── SilentNight: Teleports ───────────────────────────────────
SN.Teleports = {
    Agency       = { Entrance = 856093405,   Computer  = 1311289145 },
    Apartment    = { Board    = 763505139 },
    AutoShop     = { Entrance = 1990872693,  Board     = 381573650  },
    CayoPerico   = { Heist    = 515889825 },
    Diamond      = { Entrance = -2027444131, Board     = -946253062 },
    SalvageYard  = { Entrance = -805570118,  Board     = 409957130  },
    Bunker       = { Entrance = 1757188373,  Laptop    = 1312406213 },
    Hangar       = { Entrance = 1256153318,  Laptop    = -407343182 },
    Nightclub    = { Entrance = -835861917,  Computer  = 2083568774 },
}

-- ── SilentNight: Cut % ────────────────────────────────────────
SN.Cuts = {
    Generic = {
        Cut   = -788556735,   -- self cut input
        Apply = 1972048685,   -- apply self cut
    },
    Diamond = {
        P1    = -971601383,  P2 = -286994425,
        P3    =  -59404757,  P4 =  873494079,
        T1    = 2103883133,  T2 = -1846182120,
        T3    = 2147295840,  T4 = -1493848893,
        Apply = -1550203166,
    },
    Cayo = {
        P1    =  954877045,  P2 =  578525703,
        P3    = -1532579673, P4 = -956967198,
        T1    = 2039909835,  T2 = -1175437268,
        T3    = 1805890371,  T4 =  170996380,
        Apply =  721953058,
    },
    Agency = {
        Payout = 599464923,
        Max    = 1986871866,
        Apply  = -1020624594,
    },
    AutoShop = {
        Max    = -311846960,
        Apply  =  832029677,
    },
    Doomsday = {
        P1    = 1080952131,  P2 = 1829658243,
        P3    =  383758887,  P4 = -1305679677,
        T1    = 1337622796,  T2 =  412492061,
        T3    = -1099896471, T4 =  63756583,
        Apply = -2131844361,
    },
    Apartment = {
        P1    = -1773140351, P2 = -1046913773,
        P3    = -1418186539, P4 = -1161867421,
        T1    = 1252615255,  T2 = -418688617,
        T3    = 1992928735,  T4 = -997869769,
        Apply =  -801249795,
    },
}

-- teleport handler
handlers.sn_teleport = function(p, id)
    local dest  = (p and p.dest)  or ""
    local place = (p and p.place) or ""
    local hash  = nil
    if dest == "agency" then
        hash = place == "computer" and SN.Teleports.Agency.Computer or SN.Teleports.Agency.Entrance
    elseif dest == "apartment" then
        hash = SN.Teleports.Apartment.Board
    elseif dest == "autoshop" then
        hash = place == "board" and SN.Teleports.AutoShop.Board or SN.Teleports.AutoShop.Entrance
    elseif dest == "cayo" then
        hash = SN.Teleports.CayoPerico.Heist
    elseif dest == "diamond" then
        hash = place == "board" and SN.Teleports.Diamond.Board or SN.Teleports.Diamond.Entrance
    elseif dest == "salvage" then
        hash = place == "board" and SN.Teleports.SalvageYard.Board or SN.Teleports.SalvageYard.Entrance
    elseif dest == "bunker" then
        hash = place == "laptop" and SN.Teleports.Bunker.Laptop or SN.Teleports.Bunker.Entrance
    elseif dest == "hangar" then
        hash = place == "laptop" and SN.Teleports.Hangar.Laptop or SN.Teleports.Hangar.Entrance
    elseif dest == "nightclub" then
        hash = place == "computer" and SN.Teleports.Nightclub.Computer or SN.Teleports.Nightclub.Entrance
    end
    if not hash then
        respond(id, false, "Unknown destination: " .. dest)
        return
    end
    local ok = snTrigger(hash)
    local msg = ok and ("Teleported to " .. dest .. " " .. place) or "Failed — is SilentNight loaded?"
    addLog("sn_teleport", p, ok, msg)
    respond(id, ok, msg)
end

-- casino cut handler
handlers.casino_cut = function(p, id)
    local slot   = tonumber(p and p.slot)  or 1   -- 1-4
    local amount = tonumber(p and p.amount) or 0
    local apply  = (p and p.apply) == true or (p and p.apply) == "true"

    -- clamp slot
    slot = math.max(1, math.min(4, slot))
    -- clamp amount 0-100
    amount = math.max(0, math.min(100, amount))

    local cutHashes = {
        SN.Cuts.Diamond.P1, SN.Cuts.Diamond.P2,
        SN.Cuts.Diamond.P3, SN.Cuts.Diamond.P4
    }

    local ok = false
    pcall(function()
        local f = FeatureMgr.GetFeature(cutHashes[slot])
        if f then f:SetIntValue(amount); ok = true end
    end)

    if ok and apply then
        Script.QueueJob(function()
            Script.Yield(100)
            snTrigger(SN.Cuts.Diamond.Apply)
        end)
    end

    local msg = ok and string.format("Player %d cut set to %d%%%s", slot, amount, apply and " + applied" or "") or "Failed"
    addLog("casino_cut", p, ok, msg)
    respond(id, ok, msg)
end

handlers.nightclub = function(p, id)
    local action = (p and p.action) or ""
    local ok, msg = false, "Unknown action: " .. action

    if action == "open" then
        ok = snTrigger(SN.Nightclub.Open)
        msg = ok and "Nightclub computer opened" or "Failed — is SilentNight loaded?"

    elseif action == "setup" then
        ok = snTrigger(SN.Nightclub.Setup)
        msg = ok and "Nightclub setup skipped (change session to apply)" or "Failed — is SilentNight loaded?"

    elseif action == "fill" then
        ok = snTrigger(SN.Nightclub.Fill)
        msg = ok and "Nightclub safe filled ($300,000)" or "Failed — is SilentNight loaded?"

    elseif action == "collect" then
        ok = snTrigger(SN.Nightclub.Collect)
        msg = ok and "Nightclub safe collected" or "Failed — is SilentNight loaded?"

    elseif action == "unbrick" then
        ok = snTrigger(SN.Nightclub.Unbrick)
        msg = ok and "Nightclub safe unbricked" or "Failed — is SilentNight loaded?"

    elseif action == "cooldown_on" then
        ok = snToggle(SN.Nightclub.Cooldown, true)
        msg = ok and "Nightclub cooldowns killed" or "Failed — is SilentNight loaded?"

    elseif action == "cooldown_off" then
        ok = snToggle(SN.Nightclub.Cooldown, false)
        msg = ok and "Nightclub cooldowns restored" or "Failed — is SilentNight loaded?"

    elseif action == "price_on" then
        ok = snToggle(SN.Nightclub.Price, true)
        msg = ok and "Nightclub price maximizer ON" or "Failed — is SilentNight loaded?"

    elseif action == "price_off" then
        ok = snToggle(SN.Nightclub.Price, false)
        msg = ok and "Nightclub price maximizer OFF" or "Failed — is SilentNight loaded?"

    elseif action == "popularity_max" then
        ok = snTrigger(SN.Nightclub.PopMax)
        msg = ok and "Nightclub popularity maxed" or "Failed — is SilentNight loaded?"

    elseif action == "popularity_min" then
        ok = snTrigger(SN.Nightclub.PopMin)
        msg = ok and "Nightclub popularity minimized" or "Failed — is SilentNight loaded?"
    end

    addLog("nightclub", p, ok, msg)
    respond(id, ok, msg)
end

handlers.listcars = function(p, id)
    local cars = loadSavedCars()
    if #cars == 0 then
        respond(id, false, "No saved cars found in "..BRIDGE.vehicleDir)
        addLog("listcars", p, false, "No saved cars")
    else
        respond(id, true, #cars.." saved cars found", {cars=cars})
        addLog("listcars", p, true, #cars.." cars available")
    end
end

-- ── STATUS WRITER ─────────────────────────────────────────────
local function writeStatus()
    pcall(function()
        local ped = GTA.GetLocalPed()
        local inVeh = ped and ped:IsInVehicle() or false
        local vName, spd = "None", 0
        if inVeh then
            local veh = GTA.GetLocalVehicle()
            if veh then
                local v = veh:GetVelocity()
                if v then spd = math.floor(math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z)*10)/10 end
                local mi = veh.ModelInfo
                if mi then local n=GTA.GetModelNameFromHash(mi.Model); if n and n~="" then vName=n end end
            end
        end
        local mc = 0; for _ in pairs(detectedModders or {}) do mc=mc+1 end
        local allIds = Players.Get() or {}
        local playerList = {}
        for _, pid in ipairs(allIds) do
            playerList[#playerList+1] = {id=pid, name=Players.GetName(pid) or "Unknown"}
        end
        local sd = FeatureMgr.GetFeature(Utils.Joaat(FEAT_SUPERDRIVE))
        local lm = FeatureMgr.GetFeature(Utils.Joaat(FEAT_LIGHTNINGMODE))
        local health, armor = 0, 0
        if ped then
            pcall(function() health = ped.Health end)
            pcall(function() armor  = ped.Armor  end)
        end
        writeJson(BRIDGE.statFile, {
            online        = true,
            updated_at    = os.time()*1000,
            player_count  = #allIds,
            modder_count  = mc,
            vehicle       = vName,
            speed         = spd,
            godmode       = State.godMode,
            vehicle_god   = State.vehicleGod,
            superdrive    = sd and sd:IsToggled() or false,
            lightning     = lm and lm:IsToggled() or false,
            health        = math.floor(health),
            armor         = math.floor(armor),
            spectating    = State.spectating,
            spectate_pid  = State.spectatePid,
            player_list   = playerList,
        })
    end)
end

-- ── POLL ──────────────────────────────────────────────────────
local function poll()
    local data = readJson(BRIDGE.cmdFile)
    if not data.pending or #data.pending == 0 then return end
    for _, cmd in ipairs(data.pending) do
        local h = handlers[cmd.command]
        if h then pcall(h, cmd.params or {}, cmd.id)
        else      respond(cmd.id, false, "Unknown command: "..tostring(cmd.command)) end
    end
    data.pending = {}
    writeJson(BRIDGE.cmdFile, data)
end

testQueue = testQueue or {}

-- ── LOOPS ─────────────────────────────────────────────────────
Script.RegisterLooped(function()
    if ShouldUnload() then return end
    ensureDir()
    while #testQueue > 0 do
        local item = table.remove(testQueue, 1)
        local h = handlers[item.name]
        if h then pcall(h, item.params, "test_"..tostring(os.clock())) end
    end
    poll()
    Script.Yield(BRIDGE.pollMs)
end)

Script.RegisterLooped(function()
    if ShouldUnload() then return end
    writeStatus(); Script.Yield(BRIDGE.statusMs)
end)

Script.RegisterLooped(function()
    if ShouldUnload() then return end
    if State.godMode then
        pcall(function()
            local ped = GTA.GetLocalPed()
            if ped then ped:EnableInvincible() end
        end)
    end
    Script.Yield(500)
end)

Script.RegisterLooped(function()
    if ShouldUnload() then return end
    if State.vehicleGod then
        pcall(function()
            local veh = GTA.GetLocalVehicle()
            if veh then veh:EnableInvincible() end
        end)
    end
    Script.Yield(500)
end)

Script.RegisterLooped(function()
    if ShouldUnload() then return end
    for pid, loops in pairs(State.vehicleLoops) do
        if loops.moon then
            Script.QueueJob(function()
                pcall(function()
                    -- Use Cherax CPed/CVehicle for remote players (natives unreliable)
                    local cped = Players.GetCPed(pid)
                    if not cped then return end

                    -- Try to get vehicle via CPed.CurVehicle (Cherax high-level)
                    local inVehicle = false
                    local vehPtr = nil
                    pcall(function()
                        local cv = cped.CurVehicle
                        if cv then
                            local ptr = cv:GetAddress()
                            if ptr and ptr ~= 0 then vehPtr = ptr; inVehicle = true end
                        end
                    end)

                    if inVehicle and vehPtr then
                        local vehHnd = GTA.PointerToHandle(vehPtr)
                        if vehHnd and vehHnd ~= 0 then
                            for _ = 1, 5 do if N_RequestControl(vehHnd) then break end; Script.Yield(30) end
                            N_SetEntityHasGravity(vehHnd, false)
                            N_SetEntityVelocity(vehHnd, 0.0, 0.0, 6.0)
                        end
                    else
                        -- Ped on foot — get handle and apply
                        local pedPtr = cped:GetAddress()
                        if pedPtr and pedPtr ~= 0 then
                            local pedHnd = GTA.PointerToHandle(pedPtr)
                            if pedHnd and pedHnd ~= 0 then
                                for _ = 1, 5 do if N_RequestControl(pedHnd) then break end; Script.Yield(30) end
                                N_SetEntityHasGravity(pedHnd, false)
                                N_SetEntityVelocity(pedHnd, 0.0, 0.0, 6.0)
                            end
                        end
                    end
                end)
            end)
        end
    end
    Script.Yield(500)
end)

Script.RegisterLooped(function()
    if ShouldUnload() then return end
    for pid, loops in pairs(State.vehicleLoops) do
        if loops.burnout then
            Script.QueueJob(function()
                pcall(function()
                    -- Use Cherax CPed.Position directly for remote player coords
                    local cped = Players.GetCPed(pid)
                    if not cped then return end
                    local pos = cped.Position
                    if not pos then return end
                    -- Use Cherax GTA.AddExplosion — works on remote players (IsLocalOnly=false)
                    local args = CExplosionArgs.New(0, V3.New(pos.x, pos.y, pos.z - 0.5))
                    args.IsLocalOnly = false
                    args.NoDamage = true
                    args.MakeSound = false
                    GTA.AddExplosion(args)
                end)
            end)
        end
    end
    Script.Yield(800)
end)

-- ── MODDER DETECTION ──────────────────────────────────────────
if not bridgeEventIds.reactionHandler then
    bridgeEventIds.reactionHandler = EventMgr.RegisterHandler(eLuaEvent.ON_REACTION, function(...)
        local a1, a2, a3 = ...
        pcall(function()
            local playerId = a1; local reactionType = a2; local detName = a3 or "Unknown"
            if not playerId then return end
            local name = ""; pcall(function() name = Players.GetName(playerId) or "" end)
            if name == "" then name = "id="..tostring(playerId) end
            if not detectedModders[playerId] then
                detectedModders[playerId] = {name=name, detections={}}
            end
            local det = detectedModders[playerId]; det.name = name
            det.detections = det.detections or {}
            table.insert(det.detections, {reason=tostring(detName), type=tostring(reactionType or "?"), time=os.time()})
            pcall(ModderDB.AddModderByPlayerId, playerId, tostring(detName))
            local msg = "Modder detected: "..name.." | "..tostring(detName)
            Logger.Log(eLogColor.YELLOW, "[The Gangs]", msg)
            addLog("modders", {player=name}, true, msg, "system")
            writeStatus()
        end)
    end)
end

if not bridgeEventIds.joinHandler then
    bridgeEventIds.joinHandler = EventMgr.RegisterHandler(eLuaEvent.ON_PLAYER_JOIN, function(playerId)
        pcall(function()
            local name = Players.GetName(playerId) or "Unknown"
            local msg = string.format("Player joined: %s (id=%d)", name, playerId)
            Logger.Log(eLogColor.CYAN, "[The Gangs]", msg)
            addLog("system", {}, true, msg, "system"); writeStatus()
            -- Cache their RID while they're in session
            Script.Yield(500)   -- short delay to let game register the player
            local rid = getRidFromSession(playerId)
            if rid then
                local key = name:lower():gsub("[^%w]","")
                ridCache[key] = rid
                Logger.Log(eLogColor.CYAN, "[The Gangs]",
                    string.format("[RID cache] Cached on join: %s = %d", name, rid))
            end
        end)
    end)
end

if not bridgeEventIds.leaveHandler then
    bridgeEventIds.leaveHandler = EventMgr.RegisterHandler(eLuaEvent.ON_PLAYER_LEFT, function(playerId)
        pcall(function()
            local name = ""; pcall(function() name = Players.GetName(playerId) or "" end)
            local nameStr = name ~= "" and name or ("id="..tostring(playerId))
            local msg = "Player left: "..nameStr
            Logger.Log(eLogColor.LIGHTGRAY, "[The Gangs]", msg)
            addLog("system", {}, true, msg, "system")
            if State.vehicleLoops[playerId] then State.vehicleLoops[playerId] = nil end
            if State.spectatePid == playerId then
                State.spectating = false; State.spectatePid = nil
            end
            writeStatus()
        end)
    end)
end

-- ══════════════════════════════════════════════════════════════
--  GUI  —  "The Gangs"  v8.0  Redesign
-- ══════════════════════════════════════════════════════════════

local GUI_STATE = {
    selectedCarIdx  = 1,
    -- 1=Dashboard  2=Controls  3=Casino  4=Vehicles  5=Members  6=Log
    activeTab       = 1,
    filterText      = "",
    memberName      = "",
    memberRid       = "",
    casinoTab       = 1,    -- kept for compat
    casinoCuts      = {0, 0, 0, 0},
    -- ── Heists section ──────────────────────────────────────────
    heistSel        = 1,    -- 1=Diamond  2=Cayo  3=Doomsday  4=Apartment  5=Agency
    heistTab        = 1,    -- 1=Actions  2=Cut%  3=Teleports
    cayoCuts        = {0, 0, 0, 0},
    doomCuts        = {0, 0, 0, 0},
    aptCuts         = {0, 0, 0, 0},
    agencyPayout    = 1000000,
    -- player enabled toggles per heist (false = OFF by default, user enables manually)
    dcToggles       = {false, false, false, false},
    cpToggles       = {false, false, false, false},
    ddToggles       = {false, false, false, false},
    apToggles       = {false, false, false, false},
    friendFilter    = "",
    friendList      = {},
    friendListLoaded = false,
}

local function pulse(speed) return 0.5 + 0.5*math.sin(os.clock()*(speed or 2.5)) end
local function clamp01(v) return math.max(0, math.min(1, v)) end

-- ── COLOUR PALETTE ───────────────────────────────────────────
local T = {
    bg0    = {0.04,0.04,0.07},
    bg1    = {0.07,0.07,0.11},
    bg2    = {0.10,0.10,0.15},
    bg3    = {0.13,0.13,0.19},
    accent = {0.25,0.52,1.00},
    green  = {0.12,0.88,0.48},
    red    = {1.00,0.20,0.20},
    orange = {1.00,0.52,0.08},
    purple = {0.62,0.35,1.00},
    yellow = {1.00,0.86,0.12},
    cyan   = {0.15,0.86,0.92},
    gold   = {1.00,0.70,0.00},
    pink   = {1.00,0.40,0.72},
    txt    = {0.90,0.90,0.96},
    dim    = {0.38,0.38,0.52},
    sep    = {0.16,0.16,0.26},
}

-- ── PUSH/POP THEME ───────────────────────────────────────────
local function pushTheme()
    ImGui.PushStyleColor(ImGuiCol.WindowBg,             T.bg0[1],T.bg0[2],T.bg0[3],0.98)
    ImGui.PushStyleColor(ImGuiCol.ChildBg,              T.bg1[1],T.bg1[2],T.bg1[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.PopupBg,              T.bg2[1],T.bg2[2],T.bg2[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.Border,               T.sep[1],T.sep[2],T.sep[3],0.85)
    ImGui.PushStyleColor(ImGuiCol.Separator,            T.sep[1],T.sep[2],T.sep[3],0.55)
    ImGui.PushStyleColor(ImGuiCol.Button,               T.bg3[1],T.bg3[2],T.bg3[3],0.95)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered,        0.16,0.26,0.48,1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,         T.accent[1],T.accent[2],T.accent[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.FrameBg,              T.bg2[1],T.bg2[2],T.bg2[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered,       0.12,0.12,0.19,1.00)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,        0.15,0.19,0.30,1.00)
    ImGui.PushStyleColor(ImGuiCol.Header,               0.14,0.24,0.44,0.80)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered,        0.20,0.33,0.58,1.00)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive,         T.accent[1],T.accent[2],T.accent[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.Text,                 T.txt[1],T.txt[2],T.txt[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled,         T.dim[1],T.dim[2],T.dim[3],1.00)
    ImGui.PushStyleColor(ImGuiCol.ScrollbarBg,          T.bg0[1],T.bg0[2],T.bg0[3],0.80)
    ImGui.PushStyleColor(ImGuiCol.ScrollbarGrab,        0.20,0.20,0.34,0.85)
    ImGui.PushStyleColor(ImGuiCol.ScrollbarGrabHovered, 0.30,0.30,0.48,1.00)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding,   6)
    ImGui.PushStyleVar(ImGuiStyleVar.GrabRounding,    4)
    ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding,   6)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing,     7, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding,    8, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding,   12, 10)
end
local function popTheme()
    ImGui.PopStyleVar(7)
    ImGui.PopStyleColor(19)
end

-- ── BUTTON HELPERS ───────────────────────────────────────────
local function cBtn(label, r, g, b, w, h)
    ImGui.PushStyleColor(ImGuiCol.Button,        r*0.16, g*0.16, b*0.16, 1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r*0.38, g*0.38, b*0.38, 1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  r,      g,      b,      1.00)
    ImGui.PushStyleColor(ImGuiCol.Border,        r*0.48, g*0.48, b*0.48, 0.70)
    local clicked
    if w and h then clicked = ImGui.Button(label, w, h)
    else            clicked = ImGui.Button(label) end
    ImGui.PopStyleColor(4)
    return clicked
end
local function cBtnW(label, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.Button,        r*0.14, g*0.14, b*0.14, 1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r*0.36, g*0.36, b*0.36, 1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  r,      g,      b,      1.00)
    ImGui.PushStyleColor(ImGuiCol.Border,        r*0.44, g*0.44, b*0.44, 0.60)
    local clicked = ImGui.Button(label, -1, 0)
    ImGui.PopStyleColor(4)
    return clicked
end
local function sectionHdr(icon, title, r, g, b)
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Text, r, g, b, 1)
    ImGui.Text(icon.."  "..title)
    ImGui.PopStyleColor(1)
    ImGui.PushStyleColor(ImGuiCol.Separator, r*0.35, g*0.35, b*0.35, 0.55)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()
end
local function kv(label, val, vr, vg, vb)
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, label)
    ImGui.SameLine()
    ImGui.TextColored(vr or T.txt[1], vg or T.txt[2], vb or T.txt[3], 1, tostring(val))
end
local function onOff(state)
    if state then ImGui.TextColored(T.green[1],T.green[2],T.green[3],1," ON")
    else          ImGui.TextColored(T.red[1],  T.red[2],  T.red[3],  1," OFF") end
end
local function badge(text, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.Button,        r*0.12,g*0.12,b*0.12,1)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r*0.12,g*0.12,b*0.12,1)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  r*0.12,g*0.12,b*0.12,1)
    ImGui.PushStyleColor(ImGuiCol.Text,          r,g,b,1)
    ImGui.SmallButton(" "..text.." ")
    ImGui.PopStyleColor(4)
end
local function subTab(label, idx, currentIdx, r, g, b)
    local active = (currentIdx == idx)
    if active then
        ImGui.PushStyleColor(ImGuiCol.Button, r*0.22, g*0.22, b*0.22, 1)
        ImGui.PushStyleColor(ImGuiCol.Text,   r, g, b, 1)
        ImGui.PushStyleColor(ImGuiCol.Border, r*0.55, g*0.55, b*0.55, 0.9)
    else
        ImGui.PushStyleColor(ImGuiCol.Button, T.bg2[1], T.bg2[2], T.bg2[3], 0.9)
        ImGui.PushStyleColor(ImGuiCol.Text,   T.dim[1], T.dim[2], T.dim[3], 1)
        ImGui.PushStyleColor(ImGuiCol.Border, T.sep[1], T.sep[2], T.sep[3], 0.5)
    end
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    local clicked = ImGui.Button(label)
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
    return clicked
end

local function runTest(name, params)
    table.insert(testQueue, {name=name, params=params})
    GUI.AddToast("The Gangs", "/"..name.." queued!", 1500)
    addLog(name, params, true, "GUI queued", "test")
end

local inp = {target="", spawnModel="", chatMsg="", spectateTarget=""}

-- ══════════════════════════════════════════════════════════════
--  TAB 1 ─ DASHBOARD
-- ══════════════════════════════════════════════════════════════
local function renderDashboard()
    local s = readJson(BRIDGE.statFile)
    local p = pulse(3.0)

    -- ── Online status pill ───────────────────────────────────
    if s and s.online then
        local c = T.green
        ImGui.TextColored(c[1]*p+0.1, c[2], c[3]*0.6, 1, "●")
        ImGui.SameLine()
        ImGui.TextColored(c[1],c[2],c[3],1, "BRIDGE ONLINE")
        ImGui.SameLine()
        local ts = s.updated_at and os.date("%H:%M:%S", math.floor(s.updated_at/1000)) or "?"
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "   last sync "..ts)
    else
        ImGui.TextColored(T.red[1],T.red[2],T.red[3],1,"●  OFFLINE")
        ImGui.SameLine()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  — start the Discord bot")
    end
    ImGui.PushStyleColor(ImGuiCol.Separator, T.accent[1]*0.25,T.accent[2]*0.18,T.accent[3]*0.35,0.6)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    if not (s and s.online) then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Start the Discord bot to see status.")
        return
    end

    -- ── Self status card ─────────────────────────────────────
    sectionHdr("", "SELF", T.accent[1],T.accent[2],T.accent[3])

    local hp = math.floor(s.health or 0)
    local ar = math.floor(s.armor  or 0)
    local hr = hp > 150 and T.green[1] or (hp > 80 and T.yellow[1] or T.red[1])
    local hg = hp > 150 and T.green[2] or (hp > 80 and T.yellow[2] or T.red[2])
    local hb = hp > 150 and T.green[3] or (hp > 80 and T.yellow[3] or T.red[3])

    -- Health bar
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, hr, hg, hb, 1)
    ImGui.ProgressBar(hp/200.0, -1, 14, string.format("HP  %d / 200", hp))
    ImGui.PopStyleColor(1)
    -- Armor bar
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, T.cyan[1], T.cyan[2], T.cyan[3], 0.85)
    ImGui.ProgressBar(ar/100.0, -1, 14, string.format("Armor  %d / 100", ar))
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- Vehicle + speed
    local vname = s.vehicle or "None"
    kv("  Vehicle:", vname, T.yellow[1],T.yellow[2],T.yellow[3])
    if vname ~= "None" then
        ImGui.SameLine()
        kv("    Speed:", string.format("%.1f m/s", s.speed or 0), T.accent[1],T.accent[2],T.accent[3])
    end
    ImGui.Spacing()

    -- Mode badges in a row
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Modes: ")
    ImGui.SameLine()
    if s.godmode     then badge("GOD",        T.green[1], T.green[2],  T.green[3])
    else                  badge("no god",     T.dim[1],   T.dim[2],    T.dim[3]) end
    ImGui.SameLine()
    if s.vehicle_god then badge("VEH GOD",   T.cyan[1],  T.cyan[2],   T.cyan[3])
    else                  badge("no vgod",   T.dim[1],   T.dim[2],    T.dim[3]) end
    ImGui.SameLine()
    if s.superdrive  then badge("SUPERDRIVE", T.orange[1],T.orange[2], T.orange[3])
    else                  badge("no sd",      T.dim[1],   T.dim[2],    T.dim[3]) end
    ImGui.SameLine()
    if s.spectating  then badge("SPECTATING", T.yellow[1],T.yellow[2], T.yellow[3]) end
    ImGui.Spacing()

    -- ── Session / Player cards ────────────────────────────────
    sectionHdr("", "SESSION", T.purple[1],T.purple[2],T.purple[3])

    local pc = s.player_count or 0
    local mc = s.modder_count or 0
    kv("  Players:", tostring(pc), T.cyan[1],T.cyan[2],T.cyan[3])
    ImGui.SameLine()
    if mc > 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"     Modders:")
        ImGui.SameLine()
        ImGui.TextColored(T.red[1],T.red[2],T.red[3],1," "..mc.." ⚠")
    else
        kv("     Modders:", "0 ✓", T.green[1],T.green[2],T.green[3])
    end
    ImGui.Spacing()

    -- Player cards (improved — one card per row with ID + status)
    local allIds  = Players.Get() or {}
    local plist   = s.player_list or {}
    local modSet  = {}
    if s.modders then
        for _, m in ipairs(s.modders) do modSet[m.name or ""] = true end
    end

    if #allIds > 0 then
        ImGui.TextColored(T.accent[1],T.accent[2],T.accent[3],1,"  Players in session:")
        ImGui.Spacing()
        for _, pid in ipairs(allIds) do
            local pname  = Players.GetName(pid) or "?"
            local isMod  = modSet[pname]
            local nr, ng, nb = T.accent[1], T.accent[2], T.accent[3]
            if isMod then nr, ng, nb = T.red[1], T.red[2], T.red[3] end

            -- Card background
            ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1], T.bg2[2], T.bg2[3], 1)
            ImGui.BeginChild("##pc"..pid, -1, 36, true)
                ImGui.Spacing()
                -- ID badge
                ImGui.PushStyleColor(ImGuiCol.Text, T.dim[1],T.dim[2],T.dim[3],1)
                ImGui.Text(string.format("  [%2d]", pid))
                ImGui.PopStyleColor(1)
                ImGui.SameLine()
                -- Name
                ImGui.TextColored(nr, ng, nb, 1, pname)
                if isMod then
                    ImGui.SameLine()
                    ImGui.TextColored(T.red[1],T.red[2],T.red[3],0.8,"  ⚠ modder")
                end
                -- Quick-target button on right
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 60)
                if cBtn("Target##t"..pid, T.accent[1],T.accent[2],T.accent[3], 60, 0) then
                    inp.target = pname
                    GUI_STATE.activeTab = 2
                end
            ImGui.EndChild()
            ImGui.PopStyleColor(1)
            ImGui.Spacing()
        end
    else
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Solo session.")
    end
    ImGui.Spacing()

    if cBtnW("  Refresh Status", T.accent[1],T.accent[2],T.accent[3]) then
        writeStatus()
        GUI.AddToast("The Gangs","Status refreshed!",1400)
    end
end

-- ══════════════════════════════════════════════════════════════
--  TAB 2 ─ CONTROLS
-- ══════════════════════════════════════════════════════════════
local function renderControls()
    local allIds = Players.Get() or {}

    -- ── Target input + quick-select ──────────────────────────
    sectionHdr("", "TARGET PLAYER", T.cyan[1],T.cyan[2],T.cyan[3])
    ImGui.SetNextItemWidth(-1)
    local nn,nc = ImGui.InputText("##tgt", inp.target, 64)
    if nc then inp.target = nn end

    local targetFound = false
    for _, pid in ipairs(allIds) do
        if normName(Players.GetName(pid) or "") == normName(inp.target) then
            ImGui.TextColored(T.green[1],T.green[2],T.green[3],1,"  ✓ "..(Players.GetName(pid) or ""))
            targetFound = true; break
        end
    end
    if not targetFound and inp.target ~= "" then
        ImGui.TextColored(T.orange[1],T.orange[2],T.orange[3],1,"  ✗ not in session (offline commands still work)")
    end
    -- Vertical player list
    if #allIds > 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Quick select:")
        ImGui.Spacing()
        for _, pid in ipairs(allIds) do
            local pn = Players.GetName(pid) or "?"
            local isSelected = normName(pn) == normName(inp.target)
            local r,g,b
            if isSelected then r,g,b = T.green[1],T.green[2],T.green[3]
            else               r,g,b = T.accent[1]*0.45,T.accent[2]*0.45,T.accent[3]*0.45 end
            if cBtnW("  ["..pid.."]  "..pn, r,g,b) then
                inp.target = pn
            end
        end
    end
    ImGui.Spacing()

    -- ── Explosions ───────────────────────────────────────────
    sectionHdr("", "EXPLOSIONS", T.orange[1],T.orange[2],T.orange[3])
    if cBtnW("  Explode",    T.red[1],   T.red[2]*0.3, 0.1)               then runTest("explode",    {username=inp.target}) end
    if cBtnW("  Obliterate", T.red[1],   0.1,          0.1)               then runTest("obliterate", {username=inp.target}) end
    if cBtnW("  Kill",       0.80,       0.05,         0.05)              then runTest("kill",       {username=inp.target}) end
    if cBtnW("  Shockwave",  T.orange[1],T.orange[2]*0.6, 0.1)           then runTest("shockwave",  {username=inp.target}) end
    if cBtnW("  Firework",   T.yellow[1],T.yellow[2]*0.7, 0.2)           then runTest("firework",   {username=inp.target}) end
    if cBtnW("  Fling",      T.accent[1]*0.6,T.accent[2],T.accent[3])    then runTest("fling",      {username=inp.target,power=50}) end
    ImGui.Spacing()

    -- ── Troll loops (Cherax native player features) ───────────
    sectionHdr("", "TROLL LOOPS", T.purple[1],T.purple[2],T.purple[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Uses Cherax native player features — set target first")
    ImGui.Spacing()
    -- Helper: fire all hashes of a toggle feature ON or OFF
    local function firePlayerToggle(hashes, enable, pid)
        if not pid then return end
        Script.QueueJob(function()
            Utils.SetSelectedPlayer(pid)
            Script.Yield(80)
            for _, h in ipairs(hashes) do
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then f:Toggle(enable) end
                end)
                Script.Yield(5)
            end
        end)
    end
    local targetPidForLoops = nil
    for _, pid in ipairs(allIds) do
        if normName(Players.GetName(pid) or "") == normName(inp.target) then targetPidForLoops=pid; break end
    end
    -- Explode Loop
    if cBtnW("  Explode Loop ON",  T.red[1],T.red[2]*0.4,0.1)     then firePlayerToggle(EXPLODE_LOOP_HASHES,  true,  targetPidForLoops) end
    if cBtnW("  Explode Loop OFF", T.dim[1],T.dim[2],T.dim[3]+0.2) then firePlayerToggle(EXPLODE_LOOP_HASHES,  false, targetPidForLoops) end
    ImGui.Spacing()
    -- Fire Loop
    if cBtnW("  Fire Loop ON",  T.orange[1],T.orange[2],0.1)        then firePlayerToggle(FIRE_LOOP_HASHES, true,  targetPidForLoops) end
    if cBtnW("  Fire Loop OFF", T.dim[1],T.dim[2],T.dim[3]+0.2)     then firePlayerToggle(FIRE_LOOP_HASHES, false, targetPidForLoops) end
    ImGui.Spacing()
    -- Shock Wave Loop
    if cBtnW("  Shock Wave ON",  T.purple[1],T.purple[2],T.purple[3]) then firePlayerToggle(SHOCK_WAVE_HASHES, true,  targetPidForLoops) end
    if cBtnW("  Shock Wave OFF", T.dim[1],T.dim[2],T.dim[3]+0.2)      then firePlayerToggle(SHOCK_WAVE_HASHES, false, targetPidForLoops) end
    ImGui.Spacing()
    -- Water Loop
    if cBtnW("  Water Loop ON",  T.cyan[1],T.cyan[2],T.cyan[3])     then firePlayerToggle(WATER_LOOP_HASHES, true,  targetPidForLoops) end
    if cBtnW("  Water Loop OFF", T.dim[1],T.dim[2],T.dim[3]+0.2)    then firePlayerToggle(WATER_LOOP_HASHES, false, targetPidForLoops) end
    ImGui.Spacing()
    -- Stun Loop
    if cBtnW("  Stun Loop ON",  T.yellow[1],T.yellow[2],T.yellow[3]) then firePlayerToggle(STUN_PLAYER_HASHES, true,  targetPidForLoops) end
    if cBtnW("  Stun Loop OFF", T.dim[1],T.dim[2],T.dim[3]+0.2)     then firePlayerToggle(STUN_PLAYER_HASHES, false, targetPidForLoops) end
    ImGui.Spacing()
    -- Ragdoll Loop
    if cBtnW("  Ragdoll Loop ON",  T.orange[1],T.orange[2],T.orange[3]) then firePlayerToggle(RAGDOLL_LOOP_HASHES, true,  targetPidForLoops) end
    if cBtnW("  Ragdoll Loop OFF", T.dim[1],T.dim[2],T.dim[3]+0.2)     then firePlayerToggle(RAGDOLL_LOOP_HASHES, false, targetPidForLoops) end
    ImGui.Spacing()

    -- ── Wanted ────────────────────────────────────────────────
    sectionHdr("", "WANTED LEVEL", T.yellow[1],T.yellow[2],T.yellow[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Cherax native — set target first")
    ImGui.Spacing()
    -- Clear Wanted (Cherax native, all 32 hashes, t=0 action)
    if cBtnW("  ✕  Clear Wanted (Cherax)",T.green[1],T.green[2],T.green[3]) then
        local tpid = nil
        for _, pid in ipairs(allIds) do
            if normName(Players.GetName(pid) or "") == normName(inp.target) then tpid=pid; break end
        end
        if tpid then
            Script.QueueJob(function()
                Utils.SetSelectedPlayer(tpid)
                Script.Yield(80)
                for _, h in ipairs(CLEAR_WANTED_HASHES) do
                    pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                    Script.Yield(5)
                end
            end)
        end
        GUI.AddToast("The Gangs","Clear Wanted fired on "..inp.target, 1500)
    end
    ImGui.Spacing()
    -- Bribe Authorities (Off The Radar loop toggle) 
    if cBtnW("  Off The Radar ON  (Bribe Authorities)",T.yellow[1],T.yellow[2],T.yellow[3]) then
        local tpid = nil
        for _, pid in ipairs(allIds) do
            if normName(Players.GetName(pid) or "") == normName(inp.target) then tpid=pid; break end
        end
        if tpid then
            Script.QueueJob(function()
                Utils.SetSelectedPlayer(tpid)
                Script.Yield(80)
                for _, h in ipairs(OFF_RADAR_HASHES) do
                    pcall(function()
                        local f = FeatureMgr.GetFeature(h)
                        if f then f:Toggle(true) end
                    end)
                    Script.Yield(5)
                end
            end)
        end
        GUI.AddToast("The Gangs","Off The Radar ON for "..inp.target, 1500)
    end
    if cBtnW("  Off The Radar OFF", T.dim[1],T.dim[2],T.dim[3]+0.2) then
        local tpid = nil
        for _, pid in ipairs(allIds) do
            if normName(Players.GetName(pid) or "") == normName(inp.target) then tpid=pid; break end
        end
        if tpid then
            Script.QueueJob(function()
                Utils.SetSelectedPlayer(tpid)
                Script.Yield(80)
                for _, h in ipairs(OFF_RADAR_HASHES) do
                    pcall(function()
                        local f = FeatureMgr.GetFeature(h)
                        if f then f:Toggle(false) end
                    end)
                    Script.Yield(5)
                end
            end)
        end
        GUI.AddToast("The Gangs","Off The Radar OFF for "..inp.target, 1500)
    end
    ImGui.Spacing()
    -- Set Bounty
    if cBtnW("  Set Bounty On Player",T.orange[1],T.orange[2],T.orange[3]) then
        local tpid = nil
        for _, pid in ipairs(allIds) do
            if normName(Players.GetName(pid) or "") == normName(inp.target) then tpid=pid; break end
        end
        if tpid then
            Script.QueueJob(function()
                Utils.SetSelectedPlayer(tpid)
                Script.Yield(80)
                for _, h in ipairs(BOUNTY_HASHES) do
                    pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                    Script.Yield(5)
                end
            end)
        end
        GUI.AddToast("The Gangs","Bounty set on "..inp.target, 1500)
    end
    ImGui.Spacing()

    -- ── Troll actions ─────────────────────────────────────────
    sectionHdr("", "TROLL ACTIONS", T.orange[1],T.orange[2],T.orange[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Cherax native player features — set target first")
    ImGui.Spacing()
    local function firePlayerAction(hashes)
        local tpid = nil
        for _, pid in ipairs(allIds) do
            if normName(Players.GetName(pid) or "") == normName(inp.target) then tpid=pid; break end
        end
        if not tpid then GUI.AddToast("The Gangs","Target not in session", 1500); return end
        Script.QueueJob(function()
            Utils.SetSelectedPlayer(tpid)
            Script.Yield(80)
            for _, h in ipairs(hashes) do
                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                Script.Yield(5)
            end
        end)
        GUI.AddToast("The Gangs","Action fired on "..inp.target, 1200)
    end
    if cBtnW("  Ragdoll",       T.orange[1],T.orange[2],T.orange[3])      then runTest("ragdoll",     {username=inp.target,duration=5000}) end
    if cBtnW("  Strip Weapons", T.red[1]*0.8,T.red[2]*0.5,0.2)           then runTest("stripweapons",{username=inp.target}) end
    if cBtnW("  Pop Tyres",     T.yellow[1],T.yellow[2]*0.6,0.1)          then runTest("poptyres",    {username=inp.target}) end
    if cBtnW("  Kill Engine",   T.red[1]*0.7,0.1,0.1)                    then runTest("killengine",  {username=inp.target}) end
    if cBtnW("  Freeze ON",     T.cyan[1]*0.7,T.cyan[2],T.cyan[3])       then runTest("freeze",      {username=inp.target,enabled=true}) end
    if cBtnW("  Freeze OFF",    T.dim[1],T.dim[2],T.dim[3]+0.2)          then runTest("freeze",      {username=inp.target,enabled=false}) end
    ImGui.Spacing()
    if cBtnW("  Cage Player",      T.purple[1],T.purple[2],T.purple[3])   then firePlayerAction(CAGE_PLAYER_HASHES) end
    if cBtnW("  Kill Player",      T.red[1],T.red[2]*0.2,0.1)            then firePlayerAction(KILL_PLAYER_HASHES) end
    if cBtnW("  Airstrike",        T.red[1],T.red[2]*0.5,0.1)            then firePlayerAction(AIRSTRIKE_HASHES) end
    if cBtnW("  Orbital Strike",   T.orange[1],T.orange[2]*0.5,0.1)      then firePlayerAction(ORBITAL_STRIKE_HASHES) end
    if cBtnW("  Launch Vehicle",   T.accent[1],T.accent[2],T.accent[3])  then firePlayerAction(LAUNCH_VEH_HASHES) end
    if cBtnW("  Send To Sky",      T.cyan[1]*0.5,T.cyan[2],T.cyan[3])    then firePlayerAction(SEND_SKY_HASHES) end
    if cBtnW("  Send To Death Barrier", T.red[1]*0.6,0.1,0.1)            then firePlayerAction(DEATH_BARRIER_HASHES) end
    ImGui.Spacing()

    -- ── Movement ──────────────────────────────────────────────
    sectionHdr("", "MOVEMENT & INFO", T.cyan[1],T.cyan[2],T.cyan[3])
    if cBtnW("  Bring To Me (all hashes)",T.accent[1],T.accent[2],T.accent[3])     then runTest("teleporttome",     {username=inp.target}) end
    if cBtnW("  Get Waypoint",   T.purple[1],T.purple[2],T.purple[3])          then runTest("waypoint",          {username=inp.target}) end
    if cBtnW("  Player IP",      T.dim[1],T.dim[2],T.dim[3]+0.2)               then runTest("playerip",          {username=inp.target}) end
    if cBtnW("  Get CPed",       T.purple[1],T.purple[2],T.purple[3])          then runTest("getped",            {username=inp.target}) end
    if cBtnW("  Current Vehicle",T.cyan[1],T.cyan[2],T.cyan[3])                then runTest("getcurrentvehicle", {username=inp.target}) end
    if cBtnW("  Last Vehicle",   T.orange[1]*0.8,T.orange[2]*0.8,T.orange[3]) then runTest("getlastvehicle",    {username=inp.target}) end
    ImGui.Spacing()

    if State.spectating then
        local specName = "pid="..(State.spectatePid or "?")
        for _, pid in ipairs(allIds) do
            if pid == State.spectatePid then specName = Players.GetName(pid) or specName; break end
        end
        ImGui.TextColored(T.cyan[1],T.cyan[2],T.cyan[3],1,"  ◉ Spectating: "..specName)
        if cBtnW("  Stop Spectating", T.red[1],T.red[2],T.red[3]) then runTest("spectate",{stop=true}) end
    else
        if cBtnW("  Spectate", T.yellow[1],T.yellow[2],T.yellow[3]) then
            if inp.target ~= "" then runTest("spectate",{username=inp.target}) end
        end
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  (set target first)")
    end
    ImGui.Spacing()

    -- ── Self ──────────────────────────────────────────────────
    sectionHdr("", "SELF", T.green[1],T.green[2],T.green[3])
    if State.godMode then
        if cBtnW("  ◉ GOD MODE ON — click to disable", T.red[1],T.red[2],T.red[3]) then runTest("godmode",{enabled=false}) end
    else
        if cBtnW("  ○ GOD MODE OFF — click to enable", T.green[1],T.green[2],T.green[3]) then runTest("godmode",{enabled=true}) end
    end
    if State.vehicleGod then
        if cBtnW("  ◉ VEHICLE GOD ON — click to disable", T.red[1],T.red[2],T.red[3]) then runTest("vehiclegod",{enabled=false}) end
    else
        if cBtnW("  ○ VEHICLE GOD OFF — click to enable", T.cyan[1],T.cyan[2],T.cyan[3]) then runTest("vehiclegod",{enabled=true}) end
    end
    ImGui.Spacing()
    if cBtnW("  Repair Vehicle",  T.green[1],T.green[2],T.green[3])         then runTest("repair",   {}) end
    if cBtnW("  Max HP + Armor",  T.cyan[1]*0.7,T.cyan[2],T.cyan[3])        then runTest("sethealth",{health=200,armor=100}) end
    ImGui.Spacing()
    local sd = FeatureMgr.GetFeature(Utils.Joaat(FEAT_SUPERDRIVE))
    local sdOn = sd and sd:IsToggled()
    if sdOn then
        if cBtnW("  ◉ SuperDrive ON — click to disable",T.red[1],T.red[2],T.red[3]) then runTest("superdrive",{enabled=false}) end
    else
        if cBtnW("  ○ SuperDrive OFF — click to enable",T.green[1]*0.5,T.green[2],T.green[3]*0.5) then runTest("superdrive",{enabled=true}) end
    end
    ImGui.Spacing()

    -- ── Chat ──────────────────────────────────────────────────
    sectionHdr("", "CHAT", T.orange[1],T.orange[2],T.orange[3])
    ImGui.SetNextItemWidth(-1)
    local nc2,nc2c = ImGui.InputText("##chat", inp.chatMsg, 128)
    if nc2c then inp.chatMsg = nc2 end
    ImGui.Spacing()
    if cBtnW("  Send Chat to Everyone",T.orange[1],T.orange[2],T.orange[3]) then
        runTest("sendchat",{message=inp.chatMsg})
    end
end

-- ══════════════════════════════════════════════════════════════
--  TAB 3 ─ CASINO  (SilentNight)
-- ══════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
--  HEISTS — shared helpers
-- ══════════════════════════════════════════════════════════════

local function renderCutPanel(cutsTable, snCuts, accentC, toastLabel, uid, toggles)
    -- Total of enabled players only
    local total = 0
    for i=1,4 do if toggles[i] then total = total + (cutsTable[i] or 0) end end
    local tc
    if total == 100 then tc = T.green
    elseif total > 100 then tc = T.orange
    else tc = T.yellow end
    ImGui.TextColored(tc[1],tc[2],tc[3],1, string.format("  Active total: %d%%  |  Toggle players ON, set %%, click Apply.", total))
    ImGui.Spacing()

    local pH = {snCuts.P1, snCuts.P2, snCuts.P3, snCuts.P4}
    local tH = {snCuts.T1, snCuts.T2, snCuts.T3, snCuts.T4}

    for i=1,4 do
        if pH[i] then
            local enabled = toggles[i]
            local bc
            if enabled then bc = accentC else bc = T.dim end
            local bgAlpha = enabled and 1.0 or 0.45
            ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3], bgAlpha)
            ImGui.PushStyleColor(ImGuiCol.Border,  bc[1]*0.5, bc[2]*0.5, bc[3]*0.5, 0.85)
            ImGui.BeginChild("##cut_"..uid..i, -1, 44, true)

                -- Toggle button
                local tLabel
                if enabled then tLabel = "[ON]  P"..i else tLabel = "[OFF] P"..i end
                local tr,tg,tb
                if enabled then tr,tg,tb = accentC[1],accentC[2],accentC[3]
                else             tr,tg,tb = T.dim[1],T.dim[2],T.dim[3] end
                if cBtn(tLabel.."##tog_"..uid..i, tr,tg,tb, 80, 0) then
                    toggles[i] = not toggles[i]
                end
                ImGui.SameLine()

                -- % value — free InputInt, no upper cap
                local pct = cutsTable[i] or 0
                ImGui.SetNextItemWidth(100)
                local iv, ivc = ImGui.InputInt("##ci_"..uid..i, pct, 1, 10)
                if ivc then cutsTable[i] = math.max(0, iv) end
                ImGui.SameLine()

                ImGui.TextColored(bc[1],bc[2],bc[3],1, string.format("%d%%", cutsTable[i] or 0))

            ImGui.EndChild()
            ImGui.PopStyleColor(2)
            ImGui.Spacing()
        end
    end

    -- Presets
    ImGui.PushStyleColor(ImGuiCol.Text, T.dim[1],T.dim[2],T.dim[3],1)
    ImGui.Text("  Presets:"); ImGui.PopStyleColor(1); ImGui.SameLine()
    if cBtn(" Solo ",accentC[1],accentC[2],accentC[3],48,0) then
        cutsTable[1]=100; cutsTable[2]=0;  cutsTable[3]=0;  cutsTable[4]=0
        toggles[1]=true;  toggles[2]=false; toggles[3]=false; toggles[4]=false
    end; ImGui.SameLine()
    if cBtn(" 2P ",T.cyan[1],T.cyan[2],T.cyan[3],38,0) then
        cutsTable[1]=50;  cutsTable[2]=50;  cutsTable[3]=0;  cutsTable[4]=0
        toggles[1]=true;  toggles[2]=true;  toggles[3]=false; toggles[4]=false
    end; ImGui.SameLine()
    if cBtn(" 3P ",T.accent[1],T.accent[2],T.accent[3],38,0) then
        cutsTable[1]=34;  cutsTable[2]=33;  cutsTable[3]=33;  cutsTable[4]=0
        toggles[1]=true;  toggles[2]=true;  toggles[3]=true;  toggles[4]=false
    end; ImGui.SameLine()
    if cBtn(" 4P ",T.purple[1],T.purple[2],T.purple[3],38,0) then
        cutsTable[1]=25;  cutsTable[2]=25;  cutsTable[3]=25;  cutsTable[4]=25
        toggles[1]=true;  toggles[2]=true;  toggles[3]=true;  toggles[4]=true
    end
    ImGui.Spacing()

    -- Apply — sets each player's value + toggle into SN, then fires Apply
    if cBtnW("  Apply Cuts", T.green[1],T.green[2],T.green[3]) then
        local cuts_snap   = {cutsTable[1], cutsTable[2], cutsTable[3], cutsTable[4]}
        local toggle_snap = {toggles[1],   toggles[2],   toggles[3],   toggles[4]}
        Script.QueueJob(function()
            for i=1,4 do
                if pH[i] then
                    -- Write % into SilentNight's InputInt feature
                    pcall(function()
                        FeatureMgr.SetFeatureInt(pH[i], cuts_snap[i] or 0)
                    end)
                    Script.Yield(50)
                    -- Write toggle state into SilentNight's Toggle feature
                    if tH[i] then
                        pcall(function() snToggle(tH[i], toggle_snap[i]) end)
                    end
                    Script.Yield(50)
                end
            end
            Script.Yield(150)
            -- Fire SilentNight's Apply — reads the values we just wrote
            snTrigger(snCuts.Apply)
        end)
        GUI.AddToast("The Gangs", toastLabel.." cuts applied!", 2500)
    end
end

local function toggleRow(labelOn, labelOff, hashOn, hashOff, cr, cg, cb)
    if cBtnW("  o "..labelOn,  cr, cg, cb)                         then Script.QueueJob(function() snToggle(hashOn,  true)  end) end
    if cBtnW("  * "..labelOff, T.dim[1],T.dim[2],T.dim[3]+0.15)   then Script.QueueJob(function() snToggle(hashOff, false) end) end
end

-- ══════════════════════════════════════════════════════════════
--  TAB 3 - HEISTS
-- ══════════════════════════════════════════════════════════════
local function renderHeists()
    local heists = {
        { label = "  Diamond Casino  ", color = T.gold   },
        { label = "  Cayo Perico     ", color = T.green  },
        { label = "  Doomsday        ", color = T.red    },
        { label = "  Apt Heists      ", color = T.accent },
        { label = "  Agency          ", color = T.cyan   },
    }

    for i, h in ipairs(heists) do
        local c = h.color
        local active = (GUI_STATE.heistSel == i)
        if active then
            ImGui.PushStyleColor(ImGuiCol.Button, c[1]*0.22, c[2]*0.22, c[3]*0.22, 1)
            ImGui.PushStyleColor(ImGuiCol.Text,   c[1],      c[2],      c[3],      1)
            ImGui.PushStyleColor(ImGuiCol.Border, c[1]*0.65, c[2]*0.65, c[3]*0.65, 0.95)
        else
            ImGui.PushStyleColor(ImGuiCol.Button, T.bg2[1], T.bg2[2], T.bg2[3], 0.85)
            ImGui.PushStyleColor(ImGuiCol.Text,   T.dim[1], T.dim[2], T.dim[3], 1)
            ImGui.PushStyleColor(ImGuiCol.Border, T.sep[1], T.sep[2], T.sep[3], 0.45)
        end
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
        if ImGui.Button(h.label) then
            GUI_STATE.heistSel = i
            GUI_STATE.heistTab = 1
        end
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(3)
        if i < #heists then ImGui.SameLine() end
    end

    local ac = heists[GUI_STATE.heistSel].color
    ImGui.PushStyleColor(ImGuiCol.Separator, ac[1]*0.5, ac[2]*0.35, ac[3]*0.20, 0.8)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg1[1], T.bg1[2], T.bg1[3], 1)
    ImGui.BeginChild("##heist_panel", -1, -1, false)

        if subTab("  Actions   ", 1, GUI_STATE.heistTab, ac[1],ac[2],ac[3]) then GUI_STATE.heistTab=1 end; ImGui.SameLine()
        if subTab("  Cut %     ", 2, GUI_STATE.heistTab, T.green[1],T.green[2],T.green[3]) then GUI_STATE.heistTab=2 end; ImGui.SameLine()
        if subTab(" Teleports  ", 3, GUI_STATE.heistTab, T.cyan[1],T.cyan[2],T.cyan[3]) then GUI_STATE.heistTab=3 end
        ImGui.PushStyleColor(ImGuiCol.Separator, ac[1]*0.2,ac[2]*0.15,ac[3]*0.08,0.5)
        ImGui.Separator()
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.6, "  Requires SilentNight to be loaded.")
        ImGui.Spacing()

        -- 1: DIAMOND CASINO
        if GUI_STATE.heistSel == 1 then
            if GUI_STATE.heistTab == 1 then
                sectionHdr("", "PREPS", T.gold[1],T.gold[2],T.gold[3])
                if cBtnW("  Apply & Complete Preps", T.gold[1],T.gold[2],T.gold[3])   then runTest("casino",{action="complete"}) end
                if cBtnW("  Reset Preps",  T.red[1]*0.7,T.red[2]*0.4,0.1)              then runTest("casino",{action="reset"})   end
                if cBtnW("  Reload Preps", T.accent[1],T.accent[2],T.accent[3])         then runTest("casino",{action="reload"})  end
                ImGui.Spacing()
                sectionHdr("", "HEIST FLOW", T.orange[1],T.orange[2],T.orange[3])
                if cBtnW("  o Solo Launch ON",   T.green[1],T.green[2],T.green[3])      then runTest("casino",{action="launch_on"})  end
                if cBtnW("  * Solo Launch OFF",  T.dim[1],T.dim[2],T.dim[3]+0.2)        then runTest("casino",{action="launch_off"}) end
                if cBtnW("  Force Ready",        T.orange[1],T.orange[2],T.orange[3])   then runTest("casino",{action="force"})      end
                if cBtnW("  Instant Finish",     T.green[1]*0.8,T.green[2],T.green[3])  then runTest("casino",{action="finish"})     end
                ImGui.Spacing()
                sectionHdr("", "AUTO HACKS", T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Bypass Fingerprint ON","Bypass Fingerprint OFF", SN.DiamondCasino.FingerprintHack, SN.DiamondCasino.FingerprintHack, T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Bypass Keypad ON",     "Bypass Keypad OFF",      SN.DiamondCasino.KeypadHack,      SN.DiamondCasino.KeypadHack,      T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Vault Door Drill ON",  "Vault Door Drill OFF",   SN.DiamondCasino.VaultDoorDrill,  SN.DiamondCasino.VaultDoorDrill,  T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Autograbber ON",       "Autograbber OFF",        SN.DiamondCasino.Autograbber,     SN.DiamondCasino.Autograbber,     T.green[1],T.green[2],T.green[3])
                ImGui.Spacing()
                sectionHdr("", "MISC", T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Kill Cooldown ON", "Kill Cooldown OFF", SN.DiamondCasino.Cooldown,  SN.DiamondCasino.Cooldown,  T.purple[1],T.purple[2],T.purple[3])
                toggleRow("3.6M Payout ON",   "3.6M Payout OFF",  SN.DiamondCasino.MaxPayout, SN.DiamondCasino.MaxPayout, T.gold[1],T.gold[2],T.gold[3])
            elseif GUI_STATE.heistTab == 2 then
                renderCutPanel(GUI_STATE.casinoCuts, SN.Cuts.Diamond, T.gold, "Diamond Casino", "dc", GUI_STATE.dcToggles)
            elseif GUI_STATE.heistTab == 3 then
                sectionHdr("", "TELEPORTS", T.gold[1],T.gold[2],T.gold[3])
                if cBtnW("  Entrance",       T.gold[1],T.gold[2],T.gold[3])              then Script.QueueJob(function() snTrigger(SN.Teleports.Diamond.Entrance) end) end
                if cBtnW("  Planning Board", T.gold[1]*0.7,T.gold[2]*0.7,T.gold[3]*0.3) then Script.QueueJob(function() snTrigger(SN.Teleports.Diamond.Board)    end) end
            end

        -- 2: CAYO PERICO
        elseif GUI_STATE.heistSel == 2 then
            if GUI_STATE.heistTab == 1 then
                sectionHdr("", "PREPS", T.green[1],T.green[2],T.green[3])
                if cBtnW("  Apply & Complete Preps", T.green[1],T.green[2],T.green[3])  then Script.QueueJob(function() snTrigger(SN.CayoPerico.Complete)   end) end
                if cBtnW("  Reset Preps",  T.red[1]*0.7,T.red[2]*0.4,0.1)               then Script.QueueJob(function() snTrigger(SN.CayoPerico.Reset)      end) end
                if cBtnW("  Reload Preps", T.accent[1],T.accent[2],T.accent[3])          then Script.QueueJob(function() snTrigger(SN.CayoPerico.Reload)     end) end
                ImGui.Spacing()
                sectionHdr("", "HEIST FLOW", T.orange[1],T.orange[2],T.orange[3])
                toggleRow("Solo Launch ON",  "Solo Launch OFF",  SN.CayoPerico.Launch, SN.CayoPerico.Launch, T.green[1],T.green[2],T.green[3])
                if cBtnW("  Reset Launch",   T.dim[1],T.dim[2],T.dim[3]+0.2)            then Script.QueueJob(function() snTrigger(SN.CayoPerico.LaunchReset) end) end
                if cBtnW("  Force Ready",    T.orange[1],T.orange[2],T.orange[3])        then Script.QueueJob(function() snTrigger(SN.CayoPerico.Force)       end) end
                if cBtnW("  Instant Finish", T.green[1]*0.8,T.green[2],T.green[3])       then Script.QueueJob(function() snTrigger(SN.CayoPerico.Finish)      end) end
                ImGui.Spacing()
                sectionHdr("", "AUTO TOOLS", T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Fingerprint Hack ON", "Fingerprint Hack OFF", SN.CayoPerico.FingerprintHack, SN.CayoPerico.FingerprintHack, T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Plasma Cutter ON",    "Plasma Cutter OFF",    SN.CayoPerico.PlasmaCutter,    SN.CayoPerico.PlasmaCutter,    T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Drainage Pipe ON",    "Drainage Pipe OFF",    SN.CayoPerico.DrainagePipe,    SN.CayoPerico.DrainagePipe,    T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Auto Bag ON",         "Auto Bag OFF",         SN.CayoPerico.Bag,             SN.CayoPerico.Bag,             T.green[1],T.green[2],T.green[3])
                ImGui.Spacing()
                sectionHdr("", "MISC", T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Kill Solo Cooldown ON", "Kill Solo Cooldown OFF", SN.CayoPerico.SoloCooldown, SN.CayoPerico.SoloCooldown, T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Kill Team Cooldown ON", "Kill Team Cooldown OFF", SN.CayoPerico.TeamCooldown, SN.CayoPerico.TeamCooldown, T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Max Payout ON",         "Max Payout OFF",         SN.CayoPerico.MaxPayout,    SN.CayoPerico.MaxPayout,    T.gold[1],T.gold[2],T.gold[3])
            elseif GUI_STATE.heistTab == 2 then
                renderCutPanel(GUI_STATE.cayoCuts, SN.Cuts.Cayo, T.green, "Cayo Perico", "cp", GUI_STATE.cpToggles)
            elseif GUI_STATE.heistTab == 3 then
                sectionHdr("", "TELEPORTS", T.green[1],T.green[2],T.green[3])
                if cBtnW("  Teleport to Kosatka", T.green[1],T.green[2],T.green[3]) then
                    Script.QueueJob(function() snTrigger(SN.CayoPerico.Teleport) end)
                end
            end

        -- 3: DOOMSDAY
        elseif GUI_STATE.heistSel == 3 then
            if GUI_STATE.heistTab == 1 then
                sectionHdr("", "PREPS", T.red[1],T.red[2],T.red[3])
                if cBtnW("  Apply & Complete Preps", T.red[1],T.red[2]*0.6,T.red[3]*0.2) then Script.QueueJob(function() snTrigger(SN.Doomsday.Complete)   end) end
                if cBtnW("  Reset Preps",  T.red[1]*0.5,0.1,0.1)                          then Script.QueueJob(function() snTrigger(SN.Doomsday.Reset)      end) end
                if cBtnW("  Reload Preps", T.accent[1],T.accent[2],T.accent[3])            then Script.QueueJob(function() snTrigger(SN.Doomsday.Reload)     end) end
                ImGui.Spacing()
                sectionHdr("", "HEIST FLOW", T.orange[1],T.orange[2],T.orange[3])
                toggleRow("Solo Launch ON",  "Solo Launch OFF",  SN.Doomsday.Launch, SN.Doomsday.Launch, T.red[1],T.red[2]*0.5,T.red[3]*0.2)
                if cBtnW("  Reset Launch",   T.dim[1],T.dim[2],T.dim[3]+0.2)               then Script.QueueJob(function() snTrigger(SN.Doomsday.LaunchReset) end) end
                if cBtnW("  Force Ready",    T.orange[1],T.orange[2],T.orange[3])           then Script.QueueJob(function() snTrigger(SN.Doomsday.Force)       end) end
                ImGui.Spacing()
                sectionHdr("", "AUTO HACKS", T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Data Hack ON",     "Data Hack OFF",     SN.Doomsday.DataHack,     SN.Doomsday.DataHack,     T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Doomsday Hack ON", "Doomsday Hack OFF", SN.Doomsday.DoomsdayHack, SN.Doomsday.DoomsdayHack, T.cyan[1],T.cyan[2],T.cyan[3])
                ImGui.Spacing()
                sectionHdr("", "MISC", T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Kill Cooldowns ON", "Kill Cooldowns OFF", SN.Doomsday.Cooldown,  SN.Doomsday.Cooldown,  T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Max Payout ON",     "Max Payout OFF",     SN.Doomsday.MaxPayout, SN.Doomsday.MaxPayout, T.gold[1],T.gold[2],T.gold[3])
            elseif GUI_STATE.heistTab == 2 then
                renderCutPanel(GUI_STATE.doomCuts, SN.Cuts.Doomsday, T.red, "Doomsday", "dd", GUI_STATE.ddToggles)
            elseif GUI_STATE.heistTab == 3 then
                sectionHdr("", "TELEPORTS", T.red[1],T.red[2]*0.5,T.red[3]*0.2)
                if cBtnW("  Facility Entrance", T.red[1],T.red[2]*0.5,T.red[3]*0.2) then
                    Script.QueueJob(function() snTrigger(-1517210096) end)
                end
                if cBtnW("  Facility Screen",   T.red[1]*0.6,T.red[2]*0.3,0.1) then
                    Script.QueueJob(function() snTrigger(978528392) end)
                end
            end

        -- 4: APARTMENT (LEGACY)
        elseif GUI_STATE.heistSel == 4 then
            if GUI_STATE.heistTab == 1 then
                sectionHdr("", "PREPS", T.accent[1],T.accent[2],T.accent[3])
                if cBtnW("  Apply & Complete Preps", T.accent[1],T.accent[2],T.accent[3])    then Script.QueueJob(function() snTrigger(SN.Apartment.Complete)    end) end
                if cBtnW("  Reload Preps", T.accent[1]*0.6,T.accent[2]*0.6,T.accent[3]*0.6)  then Script.QueueJob(function() snTrigger(SN.Apartment.Reload)      end) end
                ImGui.Spacing()
                sectionHdr("", "HEIST FLOW", T.orange[1],T.orange[2],T.orange[3])
                toggleRow("Solo Launch ON",  "Solo Launch OFF",  SN.Apartment.Launch, SN.Apartment.Launch, T.accent[1],T.accent[2],T.accent[3])
                if cBtnW("  Reset Launch",   T.dim[1],T.dim[2],T.dim[3]+0.2)                  then Script.QueueJob(function() snTrigger(SN.Apartment.LaunchReset) end) end
                if cBtnW("  Force Ready",    T.orange[1],T.orange[2],T.orange[3])               then Script.QueueJob(function() snTrigger(SN.Apartment.Force)       end) end
                if cBtnW("  Instant Finish", T.green[1]*0.8,T.green[2],T.green[3])              then Script.QueueJob(function() snTrigger(SN.Apartment.Finish)      end) end
                ImGui.Spacing()
                sectionHdr("", "AUTO TOOLS  (Fleeca / Pacific)", T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Fleeca Hack ON",  "Fleeca Hack OFF",  SN.Apartment.FleecaHack,  SN.Apartment.FleecaHack,  T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Fleeca Drill ON", "Fleeca Drill OFF", SN.Apartment.FleecaDrill, SN.Apartment.FleecaDrill, T.cyan[1],T.cyan[2],T.cyan[3])
                toggleRow("Pacific Hack ON", "Pacific Hack OFF", SN.Apartment.PacificHack, SN.Apartment.PacificHack, T.cyan[1],T.cyan[2],T.cyan[3])
                ImGui.Spacing()
                sectionHdr("", "MISC", T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Kill Cooldowns ON", "Kill Cooldowns OFF", SN.Apartment.Cooldown,  SN.Apartment.Cooldown,  T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Max Payout ON",     "Max Payout OFF",     SN.Apartment.MaxPayout, SN.Apartment.MaxPayout, T.gold[1],T.gold[2],T.gold[3])
                toggleRow("Bonus Cash ON",     "Bonus Cash OFF",     SN.Apartment.Bonus,     SN.Apartment.Bonus,     T.yellow[1],T.yellow[2],T.yellow[3])
                toggleRow("Double Cash ON",    "Double Cash OFF",    SN.Apartment.Double,    SN.Apartment.Double,    T.yellow[1],T.yellow[2],T.yellow[3])
            elseif GUI_STATE.heistTab == 2 then
                renderCutPanel(GUI_STATE.aptCuts, SN.Cuts.Apartment, T.accent, "Apartment", "ap", GUI_STATE.apToggles)
            elseif GUI_STATE.heistTab == 3 then
                sectionHdr("", "TELEPORTS", T.accent[1],T.accent[2],T.accent[3])
                if cBtnW("  Planning Room",  T.accent[1],T.accent[2],T.accent[3])           then Script.QueueJob(function() snTrigger(SN.Teleports.Apartment.Board) end) end
                if cBtnW("  Apartment Tele", T.accent[1]*0.6,T.accent[2]*0.6,T.accent[3]*0.6) then Script.QueueJob(function() snTrigger(1331339394)                  end) end
            end

        -- 5: AGENCY
        elseif GUI_STATE.heistSel == 5 then
            if GUI_STATE.heistTab == 1 then
                sectionHdr("", "PREPS", T.cyan[1],T.cyan[2],T.cyan[3])
                if cBtnW("  Apply & Complete Preps", T.cyan[1],T.cyan[2],T.cyan[3])    then Script.QueueJob(function() snTrigger(SN.Agency.Complete) end) end
                ImGui.Spacing()
                sectionHdr("", "HEIST FLOW", T.orange[1],T.orange[2],T.orange[3])
                if cBtnW("  Instant Finish", T.green[1]*0.8,T.green[2],T.green[3])     then Script.QueueJob(function() snTrigger(SN.Agency.Finish)   end) end
                ImGui.Spacing()
                sectionHdr("", "MISC", T.purple[1],T.purple[2],T.purple[3])
                toggleRow("Kill Cooldowns ON", "Kill Cooldowns OFF", SN.Agency.Cooldown, SN.Agency.Cooldown, T.purple[1],T.purple[2],T.purple[3])
            elseif GUI_STATE.heistTab == 2 then
                sectionHdr("", "AGENCY PAYOUT", T.cyan[1],T.cyan[2],T.cyan[3])
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Set a fixed payout value, then apply.")
                ImGui.Spacing()
                ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
                ImGui.BeginChild("##agency_pay", -1, 52, true)
                    ImGui.TextColored(T.cyan[1],T.cyan[2],T.cyan[3],1,"  Payout:")
                    ImGui.SameLine()
                    ImGui.SetNextItemWidth(160)
                    local pv, pvc = ImGui.InputInt("##apay", GUI_STATE.agencyPayout, 100000, 500000)
                    if pvc then GUI_STATE.agencyPayout = math.max(0, pv) end
                    ImGui.SameLine()
                    local payStr = tostring(GUI_STATE.agencyPayout)
                    ImGui.TextColored(T.gold[1],T.gold[2],T.gold[3],1, "$"..payStr)
                ImGui.EndChild()
                ImGui.PopStyleColor(1)
                ImGui.Spacing()
                if cBtn("  Max Payout  ", T.gold[1],T.gold[2],T.gold[3]) then
                    Script.QueueJob(function() snTrigger(SN.Agency.MaxPayout) end)
                    GUI.AddToast("The Gangs", "Agency payout maximised!", 2000)
                end
                ImGui.SameLine()
                if cBtn("  Apply Payout  ", T.green[1],T.green[2],T.green[3]) then
                    Script.QueueJob(function()
                        pcall(function()
                            local f = FeatureMgr.GetFeature(SN.Agency.SelectPayout)
                            if f then f:SetIntValue(GUI_STATE.agencyPayout) end
                        end)
                        Script.Yield(100)
                        snTrigger(SN.Agency.ApplyPayout)
                    end)
                    GUI.AddToast("The Gangs", string.format("Agency payout -> $%d", GUI_STATE.agencyPayout), 2000)
                end
            elseif GUI_STATE.heistTab == 3 then
                sectionHdr("", "TELEPORTS", T.cyan[1],T.cyan[2],T.cyan[3])
                if cBtnW("  Agency Entrance", T.cyan[1],T.cyan[2],T.cyan[3])           then Script.QueueJob(function() snTrigger(SN.Teleports.Agency.Entrance) end) end
                if cBtnW("  Agency Computer", T.cyan[1]*0.7,T.cyan[2]*0.7,T.cyan[3])   then Script.QueueJob(function() snTrigger(SN.Teleports.Agency.Computer) end) end
            end
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Shared Businesses teleports (shown in Teleports sub-tab for all heists)
        if GUI_STATE.heistTab == 3 then
            sectionHdr("", "BUSINESSES", T.purple[1],T.purple[2],T.purple[3])
            if cBtnW("  Bunker Entrance",    T.purple[1],T.purple[2],T.purple[3])               then Script.QueueJob(function() snTrigger(SN.Teleports.Bunker.Entrance)   end) end
            if cBtnW("  Bunker Laptop",      T.purple[1]*0.7,T.purple[2]*0.7,T.purple[3])       then Script.QueueJob(function() snTrigger(SN.Teleports.Bunker.Laptop)     end) end
            ImGui.Spacing()
            if cBtnW("  Hangar Entrance",    T.orange[1],T.orange[2],T.orange[3])               then Script.QueueJob(function() snTrigger(SN.Teleports.Hangar.Entrance)   end) end
            if cBtnW("  Hangar Laptop",      T.orange[1]*0.7,T.orange[2]*0.7,T.orange[3])       then Script.QueueJob(function() snTrigger(SN.Teleports.Hangar.Laptop)     end) end
            ImGui.Spacing()
            if cBtnW("  Nightclub Entrance", T.pink[1],T.pink[2],T.pink[3])                     then Script.QueueJob(function() snTrigger(SN.Teleports.Nightclub.Entrance) end) end
            if cBtnW("  Nightclub Computer", T.pink[1]*0.7,T.pink[2]*0.7,T.pink[3])             then Script.QueueJob(function() snTrigger(SN.Teleports.Nightclub.Computer) end) end
            ImGui.Spacing()
            if cBtn(" Auto Shop Entrance ", T.yellow[1],T.yellow[2],T.yellow[3])                then Script.QueueJob(function() snTrigger(SN.Teleports.AutoShop.Entrance) end) end
            ImGui.SameLine()
            if cBtn(" Auto Shop Board ",    T.yellow[1]*0.7,T.yellow[2]*0.7,T.yellow[3])        then Script.QueueJob(function() snTrigger(SN.Teleports.AutoShop.Board)    end) end
        end

    ImGui.EndChild()
    ImGui.PopStyleColor(1)
end

-- ══════════════════════════════════════════════════════════════
--  TAB 4 ─ VEHICLES
-- ══════════════════════════════════════════════════════════════
local function renderVehicles()
    sectionHdr("", "SAVED CARS", T.green[1],T.green[2],T.green[3])

    local statusColor, statusMsg
    if savedCarsLoaded and #savedCarsList > 0 then
        statusColor = T.green
        statusMsg   = string.format("  %d cars loaded", #savedCarsList)
        if savedCarsLastLoad > 0 then
            statusMsg = statusMsg.."  (loaded "..os.date("%H:%M:%S", savedCarsLastLoad)..")"
        end
    elseif savedCarsLoadError and savedCarsLoadError ~= "" then
        statusColor = T.red
        statusMsg   = "  ERROR: "..savedCarsLoadError.." | Check Cherax log for [SavedCars] debug"
    else
        statusColor = T.orange
        statusMsg   = "  Not loaded — click Refresh"
    end
    ImGui.TextColored(statusColor[1],statusColor[2],statusColor[3],1, statusMsg)
    ImGui.Spacing()

    if cBtn("   Refresh Car List  ",T.accent[1],T.accent[2],T.accent[3]) then
        loadSavedCars()
        GUI.AddToast("The Gangs", #savedCarsList > 0 and ("Loaded "..(#savedCarsList).." cars!") or "No cars found!", 2500)
    end
    ImGui.Spacing()

    if #savedCarsList == 0 then
        ImGui.Separator(); ImGui.Spacing()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  No saved cars found.")
        ImGui.TextColored(T.orange[1],T.orange[2],T.orange[3],1,"  "..BRIDGE.vehicleDir)
        return
    end

    -- Filter state
    GUI_STATE.carFilterText   = GUI_STATE.carFilterText  or ""
    GUI_STATE.carComboIdx     = GUI_STATE.carComboIdx    or 0

    -- Build filtered list
    local filteredList = {}
    local filter = GUI_STATE.carFilterText:lower()
    for _, car in ipairs(savedCarsList) do
        if filter == "" or car:lower():find(filter, 1, true) then
            table.insert(filteredList, car)
        end
    end
    if GUI_STATE.carComboIdx >= #filteredList then
        GUI_STATE.carComboIdx = math.max(0, #filteredList - 1)
    end

    -- Vehicle Name filter (just like Cherax's own input)
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Vehicle Name")
    ImGui.SetNextItemWidth(-1)
    local nf, nfc = ImGui.InputText("##carf", GUI_STATE.carFilterText, 64)
    if nfc then
        GUI_STATE.carFilterText = nf
        GUI_STATE.carComboIdx   = 0
    end
    ImGui.Spacing()

    -- Cherax-style combo dropdown showing full names
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Saved Vehicles")
    ImGui.SetNextItemWidth(-1)
    local newIdx, changed = ImGui.Combo("##savedcarscombo", GUI_STATE.carComboIdx, filteredList, #filteredList, 12)
    if changed then
        GUI_STATE.carComboIdx = newIdx
        local picked = filteredList[newIdx + 1]
        if picked then inp.spawnModel = picked end
    end
    ImGui.Spacing(); ImGui.Separator(); ImGui.Spacing()

    local selName  = filteredList[GUI_STATE.carComboIdx + 1] or ""
    local spawnCar = selName

    -- Spawn buttons
    if cBtn("   Spawn for Me   ", T.green[1],T.green[2],T.green[3]) then
        if spawnCar ~= "" then runTest("spawnsaved", {car=spawnCar}) end
    end
    ImGui.SameLine()
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  For player:")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(120)
    local nt2, nt2c = ImGui.InputText("##sfptgt", inp.target, 64)
    if nt2c then inp.target = nt2 end
    ImGui.SameLine()
    if cBtn("   Spawn For Player   ", T.cyan[1],T.cyan[2],T.cyan[3]) then
        if spawnCar ~= "" and inp.target ~= "" then runTest("spawnsaved", {car=spawnCar, username=inp.target}) end
    end
    ImGui.Spacing(); ImGui.Separator(); ImGui.Spacing()
    sectionHdr("","SPAWN ANY MODEL",T.dim[1],T.dim[2],T.dim[3]+0.25)
    ImGui.SetNextItemWidth(180)
    local nsm,nsmc = ImGui.InputText("##manspawn", inp.spawnModel, 64)
    if nsmc then inp.spawnModel = nsm end
    ImGui.SameLine()
    if cBtn("  Spawn  ",T.accent[1],T.accent[2],T.accent[3]) then
        if inp.spawnModel ~= "" then runTest("spawn",{model=inp.spawnModel}) end
    end
end

-- ══════════════════════════════════════════════════════════════
--  TAB 5 ─ MEMBERS  (split into Members + Friends sub-tabs)
-- ══════════════════════════════════════════════════════════════

-- Scan state persists across frames
local scanResults  = {}
local scanRunning  = false
local scanDone     = false
local scanKeyword  = ""
local GUI_SCAN     = { keyword = "invite,Invite to Session,Friend Request" }

-- Sub-tab state  0 = Members  1 = Friends
local membersSubTab = 0

-- ── helpers ────────────────────────────────────────────────────
local function runFeatureScan(keyword)
    if scanRunning then return end
    scanRunning = true
    scanDone    = false
    scanResults = {}
    scanKeyword = keyword

    Script.QueueJob(function()
        local terms = {}
        for word in keyword:gmatch("[^,]+") do
            local w = word:match("^%s*(.-)%s*$")
            if w ~= "" then table.insert(terms, w) end
        end
        if #terms == 0 then terms = {keyword} end

        local function scanList(hashList, src)
            for _, hash in ipairs(hashList) do
                local name, ftype = "", "?"
                pcall(function()
                    local f = FeatureMgr.GetFeature(hash)
                    if f then
                        name  = f:GetName() or ""
                        ftype = tostring(f:GetType())
                    end
                end)
                if name ~= "" then
                    for _, term in ipairs(terms) do
                        if name:lower():find(term:lower(), 1, true) then
                            table.insert(scanResults, { hash=hash, ftype=ftype, name=name, src=src })
                            break
                        end
                    end
                end
            end
        end

        -- Scan BOTH regular features AND player-context features
        scanList(FeatureMgr.GetAllFeatureHashes()       or {}, "feat")
        scanList(FeatureMgr.GetAllPlayerFeatureHashes() or {}, "player")

        -- Also use fuzzy SearchFeature for each term
        for _, term in ipairs(terms) do
            local hits = {}
            pcall(function() hits = FeatureMgr.SearchFeature(term, 20, 60) or {} end)
            for _, hash in ipairs(hits) do
                -- avoid duplicates
                local already = false
                for _, r in ipairs(scanResults) do
                    if r.hash == hash then already = true; break end
                end
                if not already then
                    local name, ftype = "", "?"
                    pcall(function()
                        local f = FeatureMgr.GetFeature(hash)
                        if f then name = f:GetName() or ""; ftype = tostring(f:GetType()) end
                    end)
                    if name ~= "" then
                        table.insert(scanResults, { hash=hash, ftype=ftype, name=name, src="search" })
                    end
                end
            end
        end

        scanRunning = false
        scanDone    = true
        Logger.Log(eLogColor.GREEN, "[Feature Scan]",
            string.format("Done — %d results for %q (feat+player+search)", #scanResults, keyword))
    end)
end

-- Core invite dispatcher
-- Mutex: prevent overlapping invite jobs
local inviteBusy = false

-- doInvite: fires all 5 invite hashes.
-- In-session:  SetSelectedPlayer(pid) → fire all INVITE_HASHES
-- Offline:     resolveRid → SetFeatureInt(24693643, rid) → fire all INVITE_HASHES
--              Same pattern as processAddFriend which is confirmed working.
local function doInvite(pid, label, friendIdx)
    Script.QueueJob(function()

        local waited = 0
        while inviteBusy and waited < 3000 do
            Script.Yield(50)
            waited = waited + 50
        end
        inviteBusy = true

        local ok, err = pcall(function()

            if pid then
                -- IN-SESSION: select player then fire all invite hashes
                Logger.Log(eLogColor.CYAN, "[Invite]",
                    string.format("In-session invite -> %s (pid=%d)", label, pid))
                Utils.SetSelectedPlayer(pid)
                Script.Yield(80)
                for _, h in ipairs(INVITE_HASHES) do
                    pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                    Script.Yield(30)
                end
                Logger.Log(eLogColor.GREEN, "[Invite]", "All hashes fired for " .. label)
            else
                -- OFFLINE: load RID into feature 24693643 (same as addFriend), fire all invite hashes
                Logger.Log(eLogColor.CYAN, "[Invite]", "Offline invite -> " .. label)
                local rid = resolveRid(label)
                if not rid then
                    Logger.Log(eLogColor.RED, "[Invite]", "RID not resolved for " .. label)
                    return
                end
                Logger.Log(eLogColor.GREEN, "[Invite]",
                    string.format("  RID=%d, firing all %d invite hashes", rid, #INVITE_HASHES))
                FeatureMgr.SetFeatureInt(24693643, rid)
                Script.Yield(150)
                for _, h in ipairs(INVITE_HASHES) do
                    pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                    Script.Yield(30)
                end
                Logger.Log(eLogColor.GREEN, "[Invite]",
                    string.format("All invite hashes fired for %s (RID=%d)", label, rid))
            end
        end)

        inviteBusy = false
        if not ok then
            Logger.Log(eLogColor.RED, "[Invite]", "doInvite error: " .. tostring(err))
        end
    end)
end

-- Dump all player-feature names to log (debug)
local function dumpPlayerFeatureNames()
    Script.QueueJob(function()
        local hashes = FeatureMgr.GetAllPlayerFeatureHashes() or {}
        Logger.Log(eLogColor.CYAN, "[The Gangs]",
            string.format("=== Player feature dump: %d hashes ===", #hashes))
        for _, h in ipairs(hashes) do
            local name, ftype = "?", "?"
            pcall(function()
                local f = FeatureMgr.GetFeature(h)
                if f then
                    name  = f:GetName()  or "?"
                    ftype = tostring(f:GetType() or "?")
                end
            end)
            Logger.Log(eLogColor.WHITE, "[The Gangs]",
                string.format("  hash=%-12d  type=%-6s  name=%q", h, ftype, name))
        end
        Logger.Log(eLogColor.CYAN, "[The Gangs]", "=== end dump ===")
    end)
end

-- ── Scanner sub-section ────────────────────────────────────────
local function renderScanner()
    sectionHdr("", "FEATURE SCANNER  —  Find any Cherax feature hash",
        T.purple[1],T.purple[2],T.purple[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        "  Keywords (comma-separated) — scans features, player-features & fuzzy search.")
    ImGui.Spacing()

    ImGui.SetNextItemWidth(260)
    local nk, nkc = ImGui.InputText("##scankey", GUI_SCAN.keyword, 128)
    if nkc then GUI_SCAN.keyword = nk end
    ImGui.SameLine()

    if scanRunning then
        ImGui.TextColored(T.yellow[1],T.yellow[2],T.yellow[3],1,"  Scanning...")
    else
        if cBtn("  Scan  ", T.purple[1],T.purple[2],T.purple[3]) then
            runFeatureScan(GUI_SCAN.keyword)
        end
        ImGui.SameLine()
        if cBtn(" friend ", T.green[1],T.green[2],T.green[3]) then
            GUI_SCAN.keyword = "friend,Friend Request,Add Friend,Send Friend"
            runFeatureScan(GUI_SCAN.keyword)
        end
        ImGui.SameLine()
        if cBtn(" invite ", T.cyan[1],T.cyan[2],T.cyan[3]) then
            GUI_SCAN.keyword = "invite,Invite to Session,Session Invite"
            runFeatureScan(GUI_SCAN.keyword)
        end
    end
    ImGui.Spacing()

    if not scanDone and #scanResults == 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Press Scan or a preset to search.")
        return
    end

    local rc = #scanResults > 0 and T.green or T.red
    ImGui.TextColored(rc[1],rc[2],rc[3],1,
        string.format("  %d results for %q", #scanResults, scanKeyword))
    ImGui.Spacing()

    if #scanResults == 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "  Nothing found — try different keywords.")
        return
    end

    for _, r in ipairs(scanResults) do
        local srcColor = r.src == "player" and T.cyan or
                         r.src == "search"  and T.yellow or T.dim
        ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
        ImGui.BeginChild("##sr"..r.hash, -1, 40, true)
            ImGui.Spacing()
            ImGui.TextColored(srcColor[1],srcColor[2],srcColor[3],1,
                string.format("  [%-6s t%s]", r.src, r.ftype))
            ImGui.SameLine()
            ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, r.name)
            ImGui.SameLine()
            ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
                string.format("  #%d", r.hash))
            ImGui.SameLine(ImGui.GetContentRegionAvail() - 110)
            if cBtn("Copy##ch"..r.hash, T.accent[1],T.accent[2],T.accent[3], 110, 0) then
                ImGui.SetClipboardText(tostring(r.hash))
                GUI.AddToast("The Gangs",
                    string.format("Copied #%d (%s)", r.hash, r.name), 2500)
            end
        ImGui.EndChild()
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end
end

-- ── Sub-tab: MEMBERS (friend request queue) ───────────────────
local function renderMembersSubtab()
    sectionHdr("", "ADD MEMBER  —  Send Friend Request",
        T.green[1],T.green[2],T.green[3])

    -- Input row
    ImGui.SetNextItemWidth(180)
    local mn,mc = ImGui.InputText("##mname", GUI_STATE.memberName, 64)
    if mc then GUI_STATE.memberName = mn end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(110)
    local mr,mrc = ImGui.InputText("RID##mrid", GUI_STATE.memberRid, 20)
    if mrc then GUI_STATE.memberRid = mr end
    ImGui.SameLine()
    if cBtn("  SC URL  ", T.accent[1],T.accent[2],T.accent[3]) then
        local name = (GUI_STATE.memberName or ""):match("^%s*(.-)%s*$")
        if name ~= "" then
            ImGui.SetClipboardText("https://socialclub.rockstargames.com/member/"..name)
            GUI.AddToast("The Gangs","SC URL copied!",2500)
        end
    end
    ImGui.Spacing()

    if cBtnW("  + Queue Friend Request", T.green[1],T.green[2],T.green[3]) then
        local name   = (GUI_STATE.memberName or ""):match("^%s*(.-)%s*$")
        local ridStr = (GUI_STATE.memberRid  or ""):match("^%s*(.-)%s*$")
        if name ~= "" then
            table.insert(pendingFriendRequests, {
                username = name, rid = tonumber(ridStr), pid = nil,
                id       = "gui_"..tostring(math.floor(os.clock()*1000)),
                queued   = os.time(), status = "ready_to_process",
            })
            GUI.AddToast("The Gangs","Queued \xe2\x86\x92 "..name, 2000)
            GUI_STATE.memberName = ""
            GUI_STATE.memberRid  = ""
        end
    end

    ImGui.Separator(); ImGui.Spacing()

    -- Pending queue
    if #pendingFriendRequests == 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Queue is empty.")
        return
    end

    ImGui.TextColored(T.accent[1],T.accent[2],T.accent[3],1,
        "  QUEUE  ("..#pendingFriendRequests..")")
    ImGui.Spacing()

    local toRemove = {}
    for i, entry in ipairs(pendingFriendRequests) do
        -- Try to resolve pid if missing
        if not entry.pid then
            for _, pid2 in ipairs(Players.Get() or {}) do
                local pn2   = (Players.GetName(pid2) or ""):lower():gsub("[^%w]","")
                local want2 = (entry.username or ""):lower():gsub("[^%w]","")
                if pn2 == want2 then entry.pid = pid2; break end
            end
        end

        local sr,sg,sb
        if     entry.status=="done"             then sr,sg,sb=T.green[1], T.green[2], T.green[3]
        elseif entry.status=="failed"           then sr,sg,sb=T.red[1],   T.red[2],   T.red[3]
        elseif entry.status=="processing"       then sr,sg,sb=T.cyan[1],  T.cyan[2],  T.cyan[3]
        elseif entry.status=="manual"           then sr,sg,sb=T.purple[1],T.purple[2],T.purple[3]
        elseif entry.status=="ready_to_process" then sr,sg,sb=T.orange[1],T.orange[2],T.orange[3]
        else                                         sr,sg,sb=T.yellow[1],T.yellow[2],T.yellow[3] end

        local cardH = entry.pid and 60 or 42
        ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
        ImGui.BeginChild("##fr"..i, -1, cardH, true)
            ImGui.Spacing()
            -- Status dot + name + status label
            ImGui.TextColored(sr,sg,sb,1,"  \xe2\x97\x8f")
            ImGui.SameLine()
            ImGui.Text(entry.username)
            ImGui.SameLine()
            ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"["..entry.status.."]")
            -- Action buttons on right side of same row
            ImGui.SameLine(ImGui.GetContentRegionAvail() - 150)
            if entry.status=="ready_to_process" or entry.status=="pending" then
                if cBtn("Process##p"..i, T.green[1],T.green[2],T.green[3], 80, 0) then
                    processAddFriend(entry)
                end
                ImGui.SameLine()
            elseif entry.status=="failed" or entry.status=="manual" then
                if cBtn("Retry##r"..i, T.orange[1],T.orange[2],T.orange[3], 60, 0) then
                    entry.status = "ready_to_process"
                end
                ImGui.SameLine()
            end
            if cBtn("X##x"..i, T.red[1]*0.7,T.red[2]*0.7,T.red[3]*0.7, 28, 0) then
                table.insert(toRemove, i)
            end
            -- Invite row (only when pid is known / player in session)
            if entry.pid then
                local invPid   = entry.pid
                local invLabel = entry.username
                if cBtnW("  \xe2\x9c\x89 Invite to Session##qi"..i, T.cyan[1],T.cyan[2],T.cyan[3]) then
                    doInvite(invPid, invLabel)
                    GUI.AddToast("The Gangs","\xe2\x9c\x89 Invite \xe2\x86\x92 "..invLabel, 2000)
                end
            end
        ImGui.EndChild()
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end
    for i = #toRemove,1,-1 do table.remove(pendingFriendRequests, toRemove[i]) end
end

-- ── Sub-tab: FRIENDS (session players — add friend + invite) ──
-- ── Hash Explorer state ───────────────────────────────────────
local hashDump        = {}        -- { hash, name, ftype, src }
local hashDumpRunning = false
local hashDumpDone    = false
local hashDumpFilter  = ""

local function runHashDump()
    if hashDumpRunning then return end
    hashDumpRunning = true
    hashDumpDone    = false
    hashDump        = {}
    Script.QueueJob(function()
        local seen = {}
        local function addHash(h, src)
            if seen[h] then return end
            seen[h] = true
            local name, ftype = "", "?"
            pcall(function()
                local f = FeatureMgr.GetFeature(h)
                if f then
                    name  = f:GetName() or ""
                    ftype = tostring(f:GetType())
                end
            end)
            table.insert(hashDump, { hash=h, name=name, ftype=ftype, src=src })
        end

        for _, h in ipairs(FeatureMgr.GetAllFeatureHashes()       or {}) do addHash(h, "feat")   end
        for _, h in ipairs(FeatureMgr.GetAllPlayerFeatureHashes() or {}) do addHash(h, "player") end

        -- sort by name so it's readable
        table.sort(hashDump, function(a,b)
            return (a.name:lower()) < (b.name:lower())
        end)

        hashDumpRunning = false
        hashDumpDone    = true
        Logger.Log(eLogColor.GREEN,"[The Gangs]",
            string.format("Hash dump done — %d total hashes (feat+player)", #hashDump))
    end)
end

local function renderHashExplorer()
    sectionHdr("", "HASH EXPLORER  —  All Cherax feature hashes",
        T.purple[1],T.purple[2],T.purple[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        "  Dumps every feature & player-feature hash. Filter to find what you need.")
    ImGui.Spacing()

    -- Dedicated player-feature console dump
    if cBtnW("  >> LOG ALL PLAYER FEATURE HASHES TO CONSOLE <<",
            T.orange[1],T.orange[2],T.orange[3]) then
        Script.QueueJob(function()
            local hashes = FeatureMgr.GetAllPlayerFeatureHashes() or {}
            Logger.Log(eLogColor.CYAN,"[The Gangs]",
                string.format("=== PLAYER FEATURE DUMP: %d hashes ===", #hashes))
            for i, h in ipairs(hashes) do
                local name, ftype = "(nil)", "?"
                pcall(function()
                    local f = FeatureMgr.GetFeature(h)
                    if f then
                        name  = f:GetName() or "(empty)"
                        ftype = tostring(f:GetType())
                    end
                end)
                Logger.Log(eLogColor.CYAN,"[The Gangs]",
                    string.format("[%03d] hash=%-14d  t=%-2s  name=%q", i, h, ftype, name))
                Script.Yield(2)
            end
            Logger.Log(eLogColor.GREEN,"[The Gangs]",
                string.format("=== PLAYER FEATURE DUMP DONE: %d hashes ===", #hashes))
            GUI.AddToast("The Gangs",
                string.format("Dumped %d player hashes to Cherax log", #hashes), 4000)
        end)
    end
    ImGui.Spacing()

    -- Controls row
    if hashDumpRunning then
        ImGui.TextColored(T.yellow[1],T.yellow[2],T.yellow[3],1,"  Dumping...")
    else
        if cBtn("  Dump All Hashes  ", T.purple[1],T.purple[2],T.purple[3]) then
            runHashDump()
        end
        if hashDumpDone then
            ImGui.SameLine()
            ImGui.TextColored(T.green[1],T.green[2],T.green[3],1,
                string.format("  %d hashes loaded", #hashDump))
            ImGui.SameLine()
            if cBtn(" Clear ", T.red[1]*0.7, T.red[2]*0.7, T.red[3]*0.7) then
                hashDump = {}; hashDumpDone = false; hashDumpFilter = ""
            end
        end
    end

    if not hashDumpDone or #hashDump == 0 then
        ImGui.Spacing()
        return
    end

    -- Filter input
    ImGui.Spacing()
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  Filter:")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(-1)
    local nf, nfc = ImGui.InputText("##hdf", hashDumpFilter, 64)
    if nfc then hashDumpFilter = nf end
    ImGui.Spacing()

    -- Filtered list
    local filterLow = hashDumpFilter:lower()
    local shown = 0
    for _, r in ipairs(hashDump) do
        local nameLow = r.name:lower()
        local hashStr = tostring(r.hash)
        if filterLow == ""
            or nameLow:find(filterLow, 1, true)
            or hashStr:find(filterLow, 1, true)
            or r.src:find(filterLow, 1, true) then

            shown = shown + 1
            -- cap display at 200 rows to avoid lag
            if shown > 200 then
                ImGui.TextColored(T.yellow[1],T.yellow[2],T.yellow[3],1,
                    "  ... refine filter to see more (showing 200/"..#hashDump..")")
                break
            end

            local srcColor = r.src == "player" and T.cyan or T.dim
            ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
            ImGui.BeginChild("##hd"..r.hash, -1, 40, true)
                ImGui.Spacing()
                ImGui.TextColored(srcColor[1],srcColor[2],srcColor[3],1,
                    string.format("  [%-6s t%s]", r.src, r.ftype))
                ImGui.SameLine()
                if r.name ~= "" then
                    ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, r.name)
                else
                    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "(no name)")
                end
                ImGui.SameLine()
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
                    string.format("  %d", r.hash))
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 190)
                if cBtn("Fire##fire"..r.hash,
                        T.orange[1],T.orange[2],T.orange[3], 50, 0) then
                    Script.QueueJob(function()
                        pcall(function()
                            FeatureMgr.TriggerFeatureCallback(r.hash)
                        end)
                        Logger.Log(eLogColor.CYAN,"[The Gangs]",
                            string.format("Fired hash=%d name=%q", r.hash, r.name))
                    end)
                    GUI.AddToast("The Gangs",
                        string.format("Fired: %s (#%d)", r.name ~= "" and r.name or "?", r.hash), 2000)
                end
                ImGui.SameLine()
                if cBtn("Copy##hcp"..r.hash,
                        T.accent[1],T.accent[2],T.accent[3], 50, 0) then
                    ImGui.SetClipboardText(tostring(r.hash))
                    GUI.AddToast("The Gangs",
                        string.format("Copied #%d", r.hash), 1500)
                end
                ImGui.SameLine()
                -- unsigned version (positive)
                local unsigned = r.hash < 0 and (r.hash + 2^32) or r.hash
                if cBtn("Copy+##hcpu"..r.hash,
                        T.green[1]*0.7,T.green[2]*0.7,T.green[3]*0.7, 60, 0) then
                    ImGui.SetClipboardText(string.format("%.0f", unsigned))
                    GUI.AddToast("The Gangs",
                        string.format("Copied unsigned %.0f", unsigned), 1500)
                end
            ImGui.EndChild()
            ImGui.PopStyleColor(1)
        end
    end
end

local function renderFriendsSubtab()
    local allIds = Players.Get() or {}

    -- ── Hash Explorer ─────────────────────────────────────────
    renderHashExplorer()
    ImGui.Separator(); ImGui.Spacing()

    -- ── Friends List panel ────────────────────────────────────
    sectionHdr("", "FRIENDS LIST", T.green[1],T.green[2],T.green[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        "  Opens the Cherax friends list overlay (hash 3750171181).")
    ImGui.Spacing()
    -- Refresh button + auto-load
    local bw2 = (ImGui.GetContentRegionAvail() - 8) * 0.5
    if cBtn("  Refresh Online Friends  ", T.green[1],T.green[2],T.green[3], bw2, 0) then
        Script.QueueJob(function()
            local list = {}
            pcall(function()
                -- 0x203F1CFD823B27A4 = NETWORK_GET_FRIEND_COUNT
                local count = Natives.InvokeInt(0x203F1CFD823B27A4) or 0
                Logger.Log(eLogColor.CYAN,"[The Gangs]",
                    string.format("Friend count from native: %d", count))
                for i = 0, count - 1 do
                    -- 0xE11EBBB2A783FE8B = NETWORK_GET_FRIEND_NAME
                    local fname = Natives.InvokeString(0xE11EBBB2A783FE8B, i) or ""
                    -- If name looks like an encoded token (contains non-printable or symbols), try display name native
                    if fname:match("[^%w%s%_%-%.]") or #fname > 30 then
                        local dname = ""
                        pcall(function()
                            -- 0xE8F1A9D6CA96ED20 = NETWORK_GET_FRIEND_DISPLAY_NAME(friendIndex)
                            dname = Natives.InvokeString(0xE8F1A9D6CA96ED20, i) or ""
                        end)
                        if dname ~= "" then fname = dname end
                    end
                    -- 0xBAD8F2A42B844821 = NETWORK_IS_FRIEND_INDEX_ONLINE(friendIndex int)
                    -- 0x57005C18827F3A28 = NETWORK_IS_FRIEND_IN_MULTIPLAYER(friendName string)
                    -- 0x425A44533437B64D = NETWORK_IS_FRIEND_ONLINE(name string)
                    local online = false
                    local inGTA  = false
                    -- index-based online check (safe — takes integer)
                    pcall(function()
                        online = Natives.InvokeBool(0xBAD8F2A42B844821, i) == true
                    end)
                    -- name-based in-multiplayer check (safe — takes string)
                    if fname ~= "" then
                        pcall(function()
                            inGTA = Natives.InvokeBool(0x57005C18827F3A28, fname) == true
                        end)
                        -- also try by-name online as secondary confirm
                        if not online then
                            pcall(function()
                                online = Natives.InvokeBool(0x425A44533437B64D, fname) == true
                            end)
                        end
                    end
                    -- resolve pid if in same session
                    local pid = nil
                    for _, p2 in ipairs(Players.Get() or {}) do
                        local pn2 = (Players.GetName(p2) or ""):lower():gsub("[^%w]","")
                        local fn2 = fname:lower():gsub("[^%w]","")
                        if pn2 == fn2 then pid = p2; break end
                    end
                    table.insert(list, { name=fname, online=online, inGTA=inGTA, pid=pid, idx=i })
                end
            end)
            -- sort: online first, then alpha
            table.sort(list, function(a,b)
                -- in GTA session > online elsewhere > offline
                local aScore = (a.pid and 3) or (a.inGTA and 2) or (a.online and 1) or 0
                local bScore = (b.pid and 3) or (b.inGTA and 2) or (b.online and 1) or 0
                if aScore ~= bScore then return aScore > bScore end
                return a.name:lower() < b.name:lower()
            end)
            GUI_STATE.friendList       = list
            GUI_STATE.friendListLoaded = true
                local onlineCount, gtaCount = 0, 0
            for _, f in ipairs(list) do
                if f.online then onlineCount=onlineCount+1 end
                if f.inGTA  then gtaCount=gtaCount+1 end
            end
            Logger.Log(eLogColor.GREEN,"[The Gangs]",
                string.format("Friends loaded: %d total, %d online, %d in GTA Online",
                    #list, onlineCount, gtaCount))
            GUI.AddToast("The Gangs",
                string.format("Friends: %d in GTA / %d online / %d total",
                    gtaCount, onlineCount, #list), 3000)
        end)
    end
    ImGui.SameLine()
    if cBtn("  Clear  ", T.red[1]*0.7,T.red[2]*0.7,T.red[3]*0.7, -1, 0) then
        GUI_STATE.friendList       = {}
        GUI_STATE.friendListLoaded = false
    end
    ImGui.SameLine()
    if cBtn("  ð Dump Feature Names  ", T.purple[1],T.purple[2],T.purple[3], -1, 0) then
        dumpPlayerFeatureNames()
        GUI.AddToast("The Gangs","Dumping player feature names to log...", 2500)
    end
    ImGui.Spacing()

    if not GUI_STATE.friendListLoaded then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "  Press Refresh to load your friends list from game memory.")
    elseif #GUI_STATE.friendList == 0 then
        ImGui.TextColored(T.orange[1],T.orange[2],T.orange[3],1,
            "  No friends found — make sure you are online in GTA.")
    else
        local onlineCount = 0
        for _, f in ipairs(GUI_STATE.friendList) do
            if f.online then onlineCount=onlineCount+1 end
        end
        ImGui.TextColored(T.green[1],T.green[2],T.green[3],1,
            string.format("  %d online", onlineCount))
        ImGui.SameLine()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            string.format("/ %d total", #GUI_STATE.friendList))
        ImGui.Spacing()

        for _, f in ipairs(GUI_STATE.friendList) do
            local nr, ng, nb
            if f.pid then
                nr,ng,nb = T.green[1],T.green[2],T.green[3]   -- in your session
            elseif f.inGTA then
                nr,ng,nb = T.yellow[1],T.yellow[2],T.yellow[3] -- in GTA Online elsewhere
            elseif f.online then
                nr,ng,nb = T.cyan[1],T.cyan[2],T.cyan[3]       -- online on platform
            else
                nr,ng,nb = T.dim[1],T.dim[2],T.dim[3]          -- offline
            end

            -- show buttons for any online/inGTA friend
            local showButtons = f.online or f.inGTA
            local cardH = showButtons and 62 or 42
            ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
            ImGui.BeginChild("##fl"..f.idx, -1, cardH, true)
                ImGui.Spacing()
                -- Row 1: status dot + name + badge
                ImGui.TextColored(nr,ng,nb,1, showButtons and "  â" or "  â")
                ImGui.SameLine()
                ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, f.name)
                ImGui.SameLine()
                if f.pid then
                    ImGui.TextColored(T.green[1],T.green[2],T.green[3],1,
                        string.format("  [pid %d â in session]", f.pid))
                elseif f.inGTA then
                    ImGui.TextColored(T.yellow[1],T.yellow[2],T.yellow[3],1,"  [in GTA Online]")
                elseif f.online then
                    ImGui.TextColored(T.cyan[1],T.cyan[2],T.cyan[3],1,"  [online]")
                end
                -- Row 2: Add Friend + Invite for all online friends
                if showButtons then
                    local fw = (ImGui.GetContentRegionAvail() - 8) * 0.5
                    if cBtn("  + Add Friend##fla"..f.idx,
                            T.green[1],T.green[2],T.green[3], fw, 0) then
                        table.insert(pendingFriendRequests, {
                            username = f.name, pid = f.pid,
                            id       = "gui_"..tostring(math.floor(os.clock()*1000)),
                            queued   = os.time(), status = "ready_to_process",
                        })
                        GUI.AddToast("The Gangs", "Friend queued â "..f.name, 2000)
                    end
                    ImGui.SameLine()
                    if cBtn("  ✉ Invite##fli"..f.idx,
                            T.cyan[1],T.cyan[2],T.cyan[3], -1, 0) then
                        doInvite(f.pid, f.name, f.idx)
                        GUI.AddToast("The Gangs", "✉ Invite sent → "..f.name, 4000)
                    end
                end

            ImGui.EndChild()
            ImGui.PopStyleColor(1)
            ImGui.Spacing()
        end

    end

    ImGui.Separator(); ImGui.Spacing()

    -- ── Session players ───────────────────────────────────────
    sectionHdr("", "FRIENDS CONTROL  —  Session Players",
        T.cyan[1],T.cyan[2],T.cyan[3])

    if #allIds == 0 then
        ImGui.Spacing()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "  No other players in session.")
        return
    end

    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        string.format("  %d player(s) online", #allIds))
    ImGui.Spacing()

    for _, pid in ipairs(allIds) do
        local pname = Players.GetName(pid) or "?"
        ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
        ImGui.BeginChild("##fp"..pid, -1, 60, true)
            -- Row 1: player label
            ImGui.Spacing()
            ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
                string.format("  [%02d]", pid))
            ImGui.SameLine()
            ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, pname)
            -- Row 2: two equal buttons side-by-side
            local bw = (ImGui.GetContentRegionAvail() - 12) * 0.5
            if cBtn("  + Add Friend##af"..pid,
                    T.green[1],T.green[2],T.green[3], bw, 0) then
                table.insert(pendingFriendRequests, {
                    username = pname, pid = pid,
                    id       = "gui_"..tostring(math.floor(os.clock()*1000)),
                    queued   = os.time(), status = "ready_to_process",
                })
                GUI.AddToast("The Gangs","Friend request queued \xe2\x86\x92 "..pname, 2000)
            end
            ImGui.SameLine()
            if cBtn("  \xe2\x9c\x89 Invite to Session##is"..pid,
                    T.cyan[1],T.cyan[2],T.cyan[3], bw, 0) then
                doInvite(pid, pname)
                GUI.AddToast("The Gangs","Invite sent \xe2\x86\x92 "..pname, 2000)
            end
        ImGui.EndChild()
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end
end

-- ── TAB 5 root render ─────────────────────────────────────────
local function renderMembers()
    -- Sub-tab switcher
    local stLabels = {"  Members  ","  Friends  "}
    local stColors = {T.green, T.cyan}
    for i, lbl in ipairs(stLabels) do
        local active = (membersSubTab == i-1)
        local tc     = stColors[i]
        if active then
            ImGui.PushStyleColor(ImGuiCol.Button, tc[1]*0.22, tc[2]*0.22, tc[3]*0.22, 1)
            ImGui.PushStyleColor(ImGuiCol.Text,   tc[1],      tc[2],      tc[3],      1)
            ImGui.PushStyleColor(ImGuiCol.Border, tc[1]*0.55, tc[2]*0.55, tc[3]*0.55, 0.90)
        else
            ImGui.PushStyleColor(ImGuiCol.Button, T.bg1[1], T.bg1[2], T.bg1[3], 0.85)
            ImGui.PushStyleColor(ImGuiCol.Text,   T.dim[1], T.dim[2], T.dim[3], 1)
            ImGui.PushStyleColor(ImGuiCol.Border, T.sep[1], T.sep[2], T.sep[3], 0.50)
        end
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
        if ImGui.Button(lbl) then membersSubTab = i-1 end
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(3)
        if i < #stLabels then ImGui.SameLine() end
    end
    ImGui.Separator(); ImGui.Spacing()

    if membersSubTab == 0 then
        renderMembersSubtab()
        ImGui.Separator(); ImGui.Spacing()
        renderScanner()
    else
        renderFriendsSubtab()
    end
end

-- ══════════════════════════════════════════════════════════════
--  TAB 6 ─ LOG
-- ══════════════════════════════════════════════════════════════
local function renderLog()
    if cBtn("  Clear  ",T.red[1],T.red[2],T.red[3]) then bridgeLog = {} end
    ImGui.SameLine()
    if autoScroll then
        if cBtn("  Auto-Scroll ON  ",T.green[1],T.green[2],T.green[3]) then autoScroll=false end
    else
        if cBtn("  Auto-Scroll OFF ",T.orange[1],T.orange[2],T.orange[3]) then autoScroll=true end
    end
    ImGui.SameLine()
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, string.format("  %d/%d",#bridgeLog,BRIDGE.maxLog))
    ImGui.Separator(); ImGui.Spacing()

    if #bridgeLog == 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  No commands yet."); return
    end

    local cc = {
        fling=T.accent, moon=T.purple, explode=T.orange, obliterate=T.red,
        kill=T.red, burnout=T.orange, superdrive=T.cyan, godmode=T.green,
        repair=T.green, modders=T.yellow, players=T.cyan, sethealth=T.green,
        vehiclegod=T.cyan, sendchat=T.orange, waypoint=T.purple, playerip=T.accent,
        spawn=T.green, spawnforplayer=T.green, spawnsaved=T.green,
        teleporttome=T.cyan, addfriend=T.green, shockwave=T.orange, firework=T.yellow,
        wanted=T.yellow, system=T.dim, listcars=T.purple, spectate=T.yellow,
        getped=T.purple, getcurrentvehicle=T.cyan, getlastvehicle=T.orange,
        ragdoll=T.orange, freeze=T.cyan, stripweapons=T.red, poptyres=T.yellow,
        killengine=T.red, casino=T.gold, nightclub=T.pink, casino_cut=T.gold,
        sn_teleport=T.cyan,
    }

    for _, e in ipairs(bridgeLog) do
        if     e.source=="test"   then ImGui.TextColored(T.green[1],T.green[2],T.green[3],0.8,"[T]")
        elseif e.source=="system" then ImGui.TextColored(T.dim[1],  T.dim[2],  T.dim[3],  1,  "[S]")
        else                           ImGui.TextColored(T.accent[1],T.accent[2],T.accent[3],0.9,"[D]") end
        ImGui.SameLine()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, e.time)
        ImGui.SameLine()
        local cv = cc[e.command] or T.txt
        ImGui.TextColored(cv[1],cv[2],cv[3],1, "/"..e.command)
        if e.params and (e.params.username or e.params.player_name) then
            ImGui.SameLine()
            ImGui.TextColored(T.yellow[1],T.yellow[2],T.yellow[3],1," ["..(e.params.username or e.params.player_name).."]")
        end
        ImGui.SameLine()
        if e.success then ImGui.TextColored(T.green[1],T.green[2],T.green[3],1," ✓")
        else               ImGui.TextColored(T.red[1],  T.red[2],  T.red[3],  1," ✗") end
        ImGui.SameLine()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "  "..e.message)
    end
    if autoScroll then ImGui.SetScrollHereY(1.0) end
end

-- ══════════════════════════════════════════════════════════════════
--  TAB 7 -- DISCORD MANAGER
-- ══════════════════════════════════════════════════════════════════

-- State
local DM = {
    statusMsg   = "",
    detailsOpen = false,
    lastRefresh = 0,
    cache       = nil,
    actionMsg   = "",
    actionColor = nil,
    -- Add All progress tracking
    addAllRunning  = false,
    addAllProgress = {},
    addAllTotal    = 0,
    addAllDone     = 0,
}

-- Sequential "Add All" processor — one player at a time, live progress in UI
local function dmRunAddAll(entries)
    if DM.addAllRunning then return end
    if #entries == 0 then return end

    DM.addAllRunning  = true
    DM.addAllProgress = {}
    DM.addAllTotal    = #entries
    DM.addAllDone     = 0
    
    -- Processing lock to prevent concurrent jobs
    local processingLock = false

    -- Pre-fill progress rows so the UI shows all names immediately
    for _, e in ipairs(entries) do
        table.insert(DM.addAllProgress, {
            name   = e.name or "?",
            status = "waiting",
            result = "",
        })
    end
    
    -- Disable frontend globally before starting
    pcall(function() 
        N_SetFrontendActive(false)
        Natives.InvokeVoid(0xBA751764F0821256, false)  -- SET_PAUSE_MENU_ACTIVE
    end)
    Script.Yield(500)

    -- Chain: each player gets its OWN isolated QueueJob.
    -- We schedule them one after the other by chaining from within each job,
    -- so Cherax's shared feature slots are never touched concurrently.
    local function processIndex(i)
        if i > #entries then
            -- All done - re-enable frontend
            DM.addAllRunning = false
            DM.actionMsg     = string.format("Add All done: %d / %d sent", DM.addAllDone, DM.addAllTotal)
            DM.actionColor   = T.green
            GUI.AddToast("The Gangs",
                string.format("Add All finished: %d / %d", DM.addAllDone, DM.addAllTotal), 4000)
            return
        end
        
        -- Wait for previous job to complete
        local waitStart = os.clock()
        while processingLock and (os.clock() - waitStart) < 30 do
            Script.Yield(100)
        end
        
        if processingLock then
            -- Timeout - something went wrong
            DM.addAllRunning = false
            DM.actionMsg = "Add All timed out - previous player still processing"
            DM.actionColor = T.red
            return
        end
        
        processingLock = true  -- Lock before starting job

        local e     = entries[i]
        local uname = e.name or ""
        local prog  = DM.addAllProgress[i]
        prog.status = "processing"

        Script.QueueJob(function()
            local done   = false
            local result = ""

            -- ── Path A: player is in session right now ─────────
            local pid = nil
            pcall(function()
                local want = uname:lower():gsub("[^%w]","")
                for _, p2 in ipairs(Players.Get() or {}) do
                    local n = (Players.GetName(p2) or ""):lower():gsub("[^%w]","")
                    if n == want or n:find(want,1,true) then pid = p2; break end
                end
            end)

            if pid then
                pcall(function()
                    Utils.SetSelectedPlayer(pid)
                    Script.Yield(50)
                    FeatureMgr.TriggerFeatureCallback(2296637101)
                    Script.Yield(200)
                    done   = true
                    result = "Sent (in session)"
                end)
            end

            -- ── Path B: RID from session gamer info ────────────
            local rid = nil
            if not done then
                if pid then
                    pcall(function()
                        local np = Players.GetById(pid)
                        if np then
                            local info = np:GetGamerInfo()
                            if info and info.RockstarId and info.RockstarId ~= 0 then
                                rid = info.RockstarId
                            end
                        end
                    end)
                end

                -- ── Path C: SetFeatureString resolver ──────────
                if not rid then
                    pcall(function()
                        -- CRITICAL: Clear the cached value first
                        FeatureMgr.SetFeatureInt(24693643, 0)
                        Script.Yield(100)
                        FeatureMgr.SetFeatureString(24693643, "")
                        Script.Yield(100)
                    end)
                    
                    local before = 0
                    pcall(function() before = FeatureMgr.GetFeatureInt(24693643) or 0 end)
                    pcall(function() FeatureMgr.SetFeatureString(24693643, uname) end)
                    Script.Yield(150)
                    
                    for _ = 1, 60 do
                        Script.Yield(50)
                        local cur = 0
                        pcall(function() cur = FeatureMgr.GetFeatureInt(24693643) or 0 end)
                        if cur ~= 0 and cur ~= before then rid = cur; break end
                    end
                end

                -- ── Path D: Cherax name→RID converter ──────────
                if not rid then
                    pcall(function()
                        -- CRITICAL: Clear converter cache first
                        FeatureMgr.SetFeatureString(2563258164, "")
                        Script.Yield(100)
                        FeatureMgr.SetFeatureString(2627874692, "")
                        Script.Yield(100)
                        
                        -- Now set new values
                        FeatureMgr.SetFeatureListIndex(503433448, 1)
                        Script.Yield(100)
                        FeatureMgr.SetFeatureString(2563258164, uname)
                        Script.Yield(150)
                        FeatureMgr.TriggerFeatureCallback(3276760136)
                        Script.Yield(100)
                    end)
                    for _ = 1, 100 do
                        Script.Yield(50)
                        local out = nil
                        pcall(function() out = FeatureMgr.GetFeatureString(2627874692) end)
                        local resolved = tonumber(out)
                        if resolved and resolved > 1000 then rid = resolved; break end
                    end
                end

                -- ── Fire with RID ───────────────────────────────
                if rid then
                    pcall(function()
                        FeatureMgr.SetFeatureInt(24693643, rid)
                        Script.Yield(150)
                        FeatureMgr.SetFeatureString(1418003384, uname)
                        Script.Yield(150)
                        -- Only use the callback that works
                        FeatureMgr.TriggerFeatureCallback(2296637101)
                    end)
                    
                    Script.Yield(800)

                    -- Method 1 ONLY (testing): Home key via user32.dll keybd_event
                    pressHomeKey()
                    Script.Yield(500)
                    
                    done   = true
                    result = "Sent (RID: "..tostring(rid)..")"
                else
                    result = "Failed - RID not found"
                end
            end

            -- Update this player's row in the progress panel
            prog.status   = done and "done" or "failed"
            prog.result   = result
            DM.addAllDone = DM.addAllDone + 1
            addLog("addfriend", {username=uname}, done, result)
            GUI.AddToast("The Gangs",
                (done and "[OK] " or "[!] ")..uname.." - "..result, 3000)

            -- Fixed delay before next player (overlay should be closed by now)
            Script.Yield(1000)
            
            -- Release lock - next player can now start
            processingLock = false
            
            processIndex(i + 1)  -- chain to next player
        end)
    end

    processIndex(1)  -- kick off the chain
end


local function dmReadQueue()
    local ok, data = pcall(readJson, BRIDGE.queueFile)
    if not ok or type(data) ~= "table" then
        return { active=false, friends={}, invites={} }
    end
    if type(data.friends) ~= "table" then data.friends = {} end
    if type(data.invites) ~= "table" then data.invites = {} end
    return data
end

local function dmWriteQueue(q)
    pcall(writeJson, BRIDGE.queueFile, q)
end

local function dmQueue()
    if os.time() - DM.lastRefresh >= 1 then
        DM.cache       = dmReadQueue()
        DM.lastRefresh = os.time()
    end
    return DM.cache or { active=false, friends={}, invites={} }
end

-- Single member card: name + discord id + individual action button
local function dmMemberCard(entry, idx, listKey)
    ImGui.BeginChild("##dm_card_"..listKey..idx, -1, 38, true)
        ImGui.TextColored(T.accent[1],T.accent[2],T.accent[3],1,
            string.format("  %d.", idx))
        ImGui.SameLine()
        ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, entry.name or "?")
        ImGui.SameLine()
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.7,
            "  <@" .. (entry.discordId or "?") .. ">")
        ImGui.SameLine()
        local actLbl = listKey == "inv" and "Invite##dmi"..idx or "Add##dma"..idx
        local actCol = listKey == "inv" and T.cyan or T.green
        if cBtn(actLbl, actCol[1],actCol[2],actCol[3]) then
            local uname = entry.name or ""
            if listKey == "inv" then
                Script.QueueJob(function()
                    local ok2, errMsg = false, "not in session"
                    pcall(function()
                        local pid = nil
                        local want = uname:lower():gsub("[^%w]","")
                        for _, p2 in ipairs(Players.Get() or {}) do
                            local n = (Players.GetName(p2) or ""):lower():gsub("[^%w]","")
                            if n == want or n:find(want,1,true) then pid = p2; break end
                        end
                        if pid then
                            Utils.SetSelectedPlayer(pid)
                            Script.Yield(80)
                            for _, h in ipairs({1744318427, 1970271281, 896960880, -1732593250, 124438863}) do
                                pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                                Script.Yield(30)
                            end
                            ok2 = true; errMsg = "Invite sent to "..uname
                        end
                    end)
                    DM.actionMsg   = errMsg
                    DM.actionColor = ok2 and T.green or T.red
                    GUI.AddToast("The Gangs", (ok2 and "[OK] " or "[!] ")..errMsg, 3000)
                end)
            else
                local fake_id = "dm_addfriend_"..tostring(os.clock()*1000)
                local fake_entry = {
                    username    = uname,
                    pid         = nil,
                    rid         = nil,
                    id          = fake_id,
                    queued      = os.time(),
                    status      = "ready_to_process",
                    autoProcess = true,
                }
                table.insert(pendingFriendRequests, fake_entry)
                processAddFriend(fake_entry)
                DM.actionMsg   = "Processing friend request: "..uname
                DM.actionColor = T.green
                GUI.AddToast("The Gangs", "Processing: "..uname, 2000)
            end
        end
    ImGui.EndChild()
end

-- ══════════════════════════════════════════════════════════════════
--  renderDiscordManager
-- ══════════════════════════════════════════════════════════════════
local function renderDiscordManager()
    local q = dmQueue()

    sectionHdr("", "DISCORD MANAGER", T.accent[1],T.accent[2],T.accent[3])

    -- Status + refresh row
    if q.active then
        ImGui.TextColored(T.green[1],T.green[2],T.green[3],1, "  [OPEN]  Queue is active")
    else
        ImGui.TextColored(T.red[1],T.red[2],T.red[3],1, "  [CLOSED]  Queue is inactive")
    end
    ImGui.SameLine()
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        string.format("   |   %d entries", #q.friends + #q.invites))
    ImGui.SameLine()
    if cBtn("  Refresh  ", T.dim[1],T.dim[2],T.dim[3]+0.3) then
        DM.lastRefresh = 0
    end
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Separator, T.accent[1]*0.28,T.accent[2]*0.20,T.accent[3]*0.38,0.70)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- ── Reusable table-style list renderer ───────────────────────
    local function drawTable(label, labelColor, entries, listType)
        ImGui.TextColored(labelColor[1],labelColor[2],labelColor[3],1,
            "  "..label.."  ("..#entries..")")
        ImGui.Spacing()

        -- Header bar
        ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.12,0.12,0.20,1)
        ImGui.BeginChild("##thdr_"..listType, -1, 24, false)
            ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "  Player")
            if listType == "fr" then
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 312)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "DM Msg")
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 232)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "DM FR")
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 152)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "Add")
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 72)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "Invite")
            else
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 232)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "DM Msg")
                ImGui.SameLine(ImGui.GetContentRegionAvail() - 152)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.85, "Invite")
            end
        ImGui.EndChild()
        ImGui.PopStyleColor(1)

        if #entries == 0 then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg1[1],T.bg1[2],T.bg1[3],1)
            ImGui.BeginChild("##tempty_"..listType, -1, 30, false)
                ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.45, "  Empty")
            ImGui.EndChild()
            ImGui.PopStyleColor(1)
        else
            for i, entry in ipairs(entries) do
                local uname     = entry.name      or "?"
                local discordId = entry.discordId or ""
                local bg = (i % 2 == 0)
                    and {T.bg2[1], T.bg2[2], T.bg2[3]}
                    or  {T.bg1[1], T.bg1[2], T.bg1[3]}

                ImGui.PushStyleColor(ImGuiCol.ChildBg, bg[1],bg[2],bg[3],1)
                ImGui.BeginChild("##trow_"..listType..i, -1, 30, false)
                    ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, "  "..uname)

                    -- ── DM Message button ─────────────────────────────
                    ImGui.SameLine(ImGui.GetContentRegionAvail() - (listType == "fr" and 312 or 232))
                    if cBtn("DM##dmsg"..listType..i, T.purple[1],T.purple[2],T.purple[3], 70, 0) then
                        if discordId ~= "" then
                            pcall(function()
                                local settings = readJson(BRIDGE.settingsFile)
                                local msg = (settings and settings.dm_message)
                                    or "I have added you in GTA, please accept the friend request as soon as possible!"
                                local dmData = readJson(BRIDGE.dmCmdFile)
                                dmData.pending = dmData.pending or {}
                                table.insert(dmData.pending, {
                                    command = "dm_all",
                                    params  = {
                                        message = msg,
                                        members = {{ name = uname, discordId = discordId }},
                                    },
                                })
                                writeJson(BRIDGE.dmCmdFile, dmData)
                            end)
                            DM.actionMsg   = "DM sent to "..uname
                            DM.actionColor = T.purple
                            GUI.AddToast("The Gangs", "DM → "..uname, 2000)
                        else
                            DM.actionMsg   = "No Discord ID for "..uname
                            DM.actionColor = T.red
                        end
                    end

                    -- ── DM FR / Invite button ─────────────────────────
                    ImGui.SameLine(ImGui.GetContentRegionAvail() - (listType == "fr" and 232 or 152))
                    if listType == "fr" then
                        -- DM FR: sends a Discord DM specifically about the friend request
                        if cBtn("DM FR##dfr"..i, T.orange[1],T.orange[2],T.orange[3], 70, 0) then
                            if discordId ~= "" then
                                pcall(function()
                                    local dmData = readJson(BRIDGE.dmCmdFile)
                                    dmData.pending = dmData.pending or {}
                                    table.insert(dmData.pending, {
                                        command = "dm_all",
                                        params  = {
                                            message = "I have sent you a Rockstar friend request! Please accept it as soon as possible (usually takes 2-3 minutes to appear).",
                                            members = {{ name = uname, discordId = discordId }},
                                        },
                                    })
                                    writeJson(BRIDGE.dmCmdFile, dmData)
                                end)
                                DM.actionMsg   = "DM FR sent to "..uname
                                DM.actionColor = T.orange
                                GUI.AddToast("The Gangs", "DM FR → "..uname, 2000)
                            else
                                DM.actionMsg   = "No Discord ID for "..uname
                                DM.actionColor = T.red
                            end
                        end

                        -- ── Add button: does the actual in-game friend add ──
                        ImGui.SameLine(ImGui.GetContentRegionAvail() - 152)
                        if cBtn("Add##dadd"..i, T.green[1],T.green[2],T.green[3], 70, 0) then
                            local fake_entry = {
                                username    = uname,
                                pid         = nil,
                                rid         = nil,
                                id          = "dm_fr_"..tostring(math.floor(os.clock()*1000))..i,
                                queued      = os.time(),
                                status      = "ready_to_process",
                                autoProcess = true,
                            }
                            table.insert(pendingFriendRequests, fake_entry)
                            processAddFriend(fake_entry)
                            DM.actionMsg   = "Processing: "..uname
                            DM.actionColor = T.green
                            GUI.AddToast("The Gangs", "Processing: "..uname, 2000)
                        end

                        -- ── Invite button: SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE ──
                        ImGui.SameLine(ImGui.GetContentRegionAvail() - 72)
                        if cBtn("Invite##dfinv"..i, T.yellow[1],T.yellow[2],T.yellow[3], 70, 0) then
                            Script.QueueJob(function()
                                local ok2, msg2 = false, "could not find '"..uname.."' in friend list"
                                pcall(function()
                                    local want   = uname:lower():gsub("[^%w]","")
                                    local fCount = Natives.InvokeInt(0x203F1CFD823B27A4) or 0
                                    local fIdx   = nil
                                    for fi = 0, fCount - 1 do
                                        local fn = (Natives.InvokeString(0xE11EBBB2A783FE8B, fi) or ""):lower():gsub("[^%w]","")
                                        if fn == want or fn:find(want,1,true) or want:find(fn,1,true) then
                                            fIdx = fi; break
                                        end
                                    end
                                    if not fIdx then
                                        for fi = 0, fCount - 1 do
                                            local fn2 = ""
                                            pcall(function() fn2 = (Natives.InvokeString(0xE8F1A9D6CA96ED20, fi) or ""):lower():gsub("[^%w]","") end)
                                            if fn2 ~= "" and (fn2 == want or fn2:find(want,1,true) or want:find(fn2,1,true)) then
                                                fIdx = fi; break
                                            end
                                        end
                                    end
                                    if not fIdx then
                                        msg2 = "'"..uname.."' not found in friend list ("..fCount.." checked)"
                                        return
                                    end
                                    local buf = GamerHandleBuffer.New()
                                    if not buf then error("GamerHandleBuffer.New() failed") end
                                    Natives.InvokeVoid(0xD45CB817D7E177D2, fIdx, buf:GetBuffer(), 13)
                                    if not Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
                                        msg2 = "Handle invalid for '"..uname.."' (idx "..fIdx..")"
                                        return
                                    end
                                    local sent = Natives.InvokeBool(0x1171A97A3D3981B6, buf:GetBuffer(), "invite", 0, 0)
                                    ok2  = sent
                                    msg2 = sent and ("Invite sent to "..uname) or ("Native returned false for "..uname)
                                end)
                                DM.actionMsg   = msg2
                                DM.actionColor = ok2 and T.green or T.red
                                GUI.AddToast("The Gangs", (ok2 and "[OK] " or "[!] ")..msg2, 3000)
                                Logger.Log(eLogColor.CYAN, "[Invite]", msg2)
                            end)
                        end

                    else
                        -- Invite button — SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE
                        -- Works out-of-session: scans friend list by name -> builds handle -> fires native
                        if cBtn("Invite##dinv"..i, T.yellow[1],T.yellow[2],T.yellow[3], 70, 0) then
                            Script.QueueJob(function()
                                local ok2, msg2 = false, "could not find '"..uname.."' in friend list"
                                pcall(function()
                                    local want   = uname:lower():gsub("[^%w]","")
                                    local fCount = Natives.InvokeInt(0x203F1CFD823B27A4) or 0
                                    local fIdx   = nil

                                    for fi = 0, fCount - 1 do
                                        local fn = (Natives.InvokeString(0xE11EBBB2A783FE8B, fi) or ""):lower():gsub("[^%w]","")
                                        if fn == want or fn:find(want,1,true) or want:find(fn,1,true) then
                                            fIdx = fi; break
                                        end
                                    end
                                    if not fIdx then
                                        for fi = 0, fCount - 1 do
                                            local fn2 = ""
                                            pcall(function() fn2 = (Natives.InvokeString(0xE8F1A9D6CA96ED20, fi) or ""):lower():gsub("[^%w]","") end)
                                            if fn2 ~= "" and (fn2 == want or fn2:find(want,1,true) or want:find(fn2,1,true)) then
                                                fIdx = fi; break
                                            end
                                        end
                                    end

                                    if not fIdx then
                                        msg2 = "'"..uname.."' not found in friend list ("..fCount.." checked)"
                                        return
                                    end

                                    local buf = GamerHandleBuffer.New()
                                    if not buf then error("GamerHandleBuffer.New() failed") end
                                    Natives.InvokeVoid(0xD45CB817D7E177D2, fIdx, buf:GetBuffer(), 13)

                                    if not Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
                                        msg2 = "Handle invalid for '"..uname.."' (friend idx "..fIdx..")"
                                        return
                                    end

                                    local sent = Natives.InvokeBool(0x1171A97A3D3981B6, buf:GetBuffer(), "invite", 0, 0)
                                    if sent then
                                        ok2  = true
                                        msg2 = "Invite sent to "..uname
                                    else
                                        msg2 = "Native returned false for "..uname
                                    end
                                end)
                                DM.actionMsg   = msg2
                                DM.actionColor = ok2 and T.green or T.red
                                GUI.AddToast("The Gangs", (ok2 and "[OK] " or "[!] ")..msg2, 3000)
                                Logger.Log(eLogColor.CYAN, "[Invite]", msg2)
                            end)
                        end

                    end
                ImGui.EndChild()
                ImGui.PopStyleColor(1)
            end
        end
    end

    -- ── Friend Requests table ─────────────────────────────────────
    drawTable("FRIEND REQUESTS", T.green, q.friends, "fr")
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Separator, T.sep[1],T.sep[2],T.sep[3],0.50)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- ── Invite Requests table ─────────────────────────────────────
    drawTable("INVITE REQUESTS", T.cyan, q.invites, "inv")
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Separator, T.accent[1]*0.20,T.accent[2]*0.14,T.accent[3]*0.30,0.50)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- ── Bottom action buttons (4 columns) ────────────────────────
    local bw = (ImGui.GetContentRegionAvail() - 16) * 0.25

    if cBtn("  Clear  ", T.orange[1],T.orange[2],T.orange[3], bw, 0) then
        local q2   = dmReadQueue()
        q2.friends = {}
        q2.invites = {}
        dmWriteQueue(q2)
        DM.cache       = q2
        DM.lastRefresh = os.time()
        DM.actionMsg   = "Queue cleared."
        DM.actionColor = T.orange
        GUI.AddToast("The Gangs", "Queue cleared", 2000)
    end
    ImGui.SameLine()

    if cBtn("  Add All  ", T.green[1],T.green[2],T.green[3], bw, 0) then
        if #q.friends == 0 then
            DM.actionMsg   = "No friend requests in queue."
            DM.actionColor = T.yellow
        else
            local count = 0
            for _, e in ipairs(q.friends) do
                local uname = e.name or ""
                if uname ~= "" then
                    table.insert(pendingFriendRequests, {
                        username    = uname,
                        pid         = nil,
                        rid         = nil,
                        id          = "dm_addall_"..tostring(math.floor(os.clock()*1000))..count,
                        queued      = os.time(),
                        status      = "ready_to_process",
                        autoProcess = false,
                    })
                    count = count + 1
                end
            end
            DM.actionMsg   = string.format("Queued %d → Members tab", count)
            DM.actionColor = T.green
            GUI.AddToast("The Gangs", string.format("%d names queued in Members", count), 3000)
        end
    end
    ImGui.SameLine()

    -- Kill All Session — kills every player in session (skips self)
    if cBtn("  Kill All  ", T.red[1],T.red[2]*0.3,T.red[3]*0.3, bw, 0) then
        Script.QueueJob(function()
            local allIds  = Players.Get() or {}
            local localId = nil
            pcall(function() localId = Players.GetLocalId() end)
            local killed = 0
            for _, pid in ipairs(allIds) do
                if pid ~= localId then
                    pcall(function()
                        Utils.SetSelectedPlayer(pid)
                        Script.Yield(80)
                        for _, h in ipairs(KILL_PLAYER_HASHES) do
                            pcall(function() FeatureMgr.TriggerFeatureCallback(h) end)
                            Script.Yield(5)
                        end
                    end)
                    killed = killed + 1
                    Script.Yield(150)
                end
            end
            local msg = string.format("Kill All — %d players killed", killed)
            DM.actionMsg   = msg
            DM.actionColor = T.red
            GUI.AddToast("The Gangs", msg, 4000)
        end)
    end
    ImGui.SameLine()

    if cBtn("  End Queue  ", T.red[1],T.red[2],T.red[3], bw, 0) then
        local q2   = dmReadQueue()
        q2.active  = false
        q2.friends = {}
        q2.invites = {}
        dmWriteQueue(q2)
        DM.cache       = q2
        DM.lastRefresh = os.time()
        DM.actionMsg   = "Queue ended."
        DM.actionColor = T.red
        GUI.AddToast("The Gangs", "Queue ended", 2000)
    end

    -- ── Heist Status toggle (full width) ─────────────────────────
    ImGui.Spacing()
    local heistStat = readJson(BRIDGE.heistStatFile)
    local hsEnabled = heistStat and heistStat.enabled == true
    local hsR = hsEnabled and T.green[1] or T.red[1]
    local hsG = hsEnabled and T.green[2] or T.red[2]*0.4
    local hsB = hsEnabled and T.green[3] or T.red[3]*0.4
    local hsLabel = hsEnabled
        and "  Heist Status  [ENABLED]  "
        or  "  Heist Status  [DISABLED]  "
    if cBtn(hsLabel, hsR, hsG, hsB, -1, 0) then
        local newEnabled = not hsEnabled
        local newStat = {
            enabled          = newEnabled,
            pending_announce = true,   -- always announce on both enable and disable
        }
        pcall(writeJson, BRIDGE.heistStatFile, newStat)
        DM.actionMsg   = "Heist Status " .. (newEnabled and "ENABLED" or "DISABLED") .. " — announcing to Discord"
        DM.actionColor = newEnabled and T.green or T.red
        GUI.AddToast("The Gangs", DM.actionMsg, 2000)
    end

    -- Action feedback
    if DM.actionMsg ~= "" then
        ImGui.Spacing()
        local c = DM.actionColor or T.dim
        ImGui.TextColored(c[1],c[2],c[3],0.9, "  >> "..DM.actionMsg)
    end
end


-- ══════════════════════════════════════════════════════════════
--  TAB 8 ─ 🧪 INVITE LAB  (out-of-session invite testing)
--
--  Goal: invite a friend who is NOT in your current session.
--
--  How it works:
--    Step 1 — Build a GamerHandle from the friend list index
--             using NETWORK_HANDLE_FROM_FRIEND (0xD45CB817D7E177D2).
--             This does NOT require the player to be in your session.
--             For non-friends with a known RID use
--             NETWORK_HANDLE_FROM_USER_ID (0xDCD51DD8F87AEC5C).
--
--    Step 2 — Validate with NETWORK_IS_HANDLE_VALID (0x6F79B93B0A8E4133).
--
--    Step 3 — Fire one or more presence-invite natives:
--      [1] NETWORK_SEND_INVITE_VIA_PRESENCE             (0xC3C7A6AFDB244624)
--          Standard freemode session invite notification.
--      [2] NETWORK_SEND_TRANSITION_INVITE_VIA_PRESENCE  (0xC116FF9B4D488291)
--          Transition/lobby invite (shows up during loading screens too).
--      [3] NETWORK_SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE (0x1171A97A3D3981B6)
--          High-priority version of [2] — harder to miss.
--      [ALL] Fires all three back-to-back for maximum reach.
--
--  The original Friends tab is completely untouched.
-- ══════════════════════════════════════════════════════════════

local LAB = {
    friendList       = {},
    friendListLoaded = false,
    friendFilter     = "",
    ridInput         = "",      -- manual RID for non-friend invite
    ridLabel         = "",      -- optional display name for RID invite
    lastResult       = "",
    lastResultColor  = nil,
    logLines         = {},
}

local function labLog(msg, color)
    table.insert(LAB.logLines, 1, {
        msg   = msg,
        color = color or T.dim,
        time  = os.date("%H:%M:%S"),
    })
    while #LAB.logLines > 40 do table.remove(LAB.logLines) end
    Logger.Log(eLogColor.CYAN, "[Invite Lab]", msg)
    LAB.lastResult      = msg
    LAB.lastResultColor = color or T.dim
end

-- ── Core: build handle from friend index → fire invite native(s) ─
-- nativeList: array of { hash, label } to try in sequence
local function labFirePresenceInvites(buf, nativeList, targetName)
    local results = {}
    for _, n in ipairs(nativeList) do
        local ok, err = pcall(function()
            local sent = Natives.InvokeBool(n.hash, buf:GetBuffer(), "invite", 0, 0)
            if not sent then error(n.label .. " returned false") end
        end)
        local msg = ok
            and ("✓ " .. n.label .. " → " .. targetName)
            or  ("✗ " .. n.label .. " failed: " .. tostring(err))
        table.insert(results, { ok = ok, msg = msg })
        labLog(msg, ok and T.green or T.red)
        Script.Yield(80)
    end
    return results
end

-- Build handle from friend-list index (works offline — no session needed)
local function labInviteFromFriendIndex(friendIdx, friendName, nativeList)
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local buf = GamerHandleBuffer.New()
            if not buf then error("GamerHandleBuffer.New() failed") end

            -- NETWORK_HANDLE_FROM_FRIEND(friendIndex, buf, 13)
            -- Key: uses friend-list slot, NOT player session ID → works offline
            Natives.InvokeVoid(0xD45CB817D7E177D2, friendIdx, buf:GetBuffer(), 13)

            -- NETWORK_IS_HANDLE_VALID
            if not Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
                error("Handle invalid — friend may have gone offline")
            end

            labFirePresenceInvites(buf, nativeList, friendName)
        end)
        if not ok then
            labLog("✗ Handle build failed for " .. friendName .. ": " .. tostring(err), T.red)
            GUI.AddToast("The Gangs", "✗ " .. friendName .. " — " .. tostring(err), 3000)
        else
            GUI.AddToast("The Gangs", "Invite(s) sent → " .. friendName, 3000)
        end
    end)
end

-- Build handle from RID string (for non-friends or manual RID entry)
local function labInviteFromRid(ridStr, label, nativeList)
    Script.QueueJob(function()
        local ok, err = pcall(function()
            local buf = GamerHandleBuffer.New()
            if not buf then error("GamerHandleBuffer.New() failed") end

            -- Try NETWORK_HANDLE_FROM_USER_ID first (RID as string)
            Natives.InvokeVoid(0xDCD51DD8F87AEC5C, tostring(ridStr), buf:GetBuffer(), 13)
            local valid = Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13)

            -- Fallback: NETWORK_HANDLE_FROM_MEMBER_ID
            if not valid then
                Natives.InvokeVoid(0xA0FD21BED61E5C4C, tostring(ridStr), buf:GetBuffer(), 13)
                valid = Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13)
            end

            -- Fallback: write RID directly into buffer (Stand-style)
            if not valid then
                local ptr = buf:GetBuffer()
                if ptr and ptr ~= 0 then
                    Memory.WriteInt64(ptr, tonumber(ridStr) or 0)
                    Memory.WriteInt32(ptr + 8, 3)  -- platform = PC
                    valid = true  -- attempt anyway
                end
            end

            if not valid then error("Could not build valid handle for RID " .. tostring(ridStr)) end

            labFirePresenceInvites(buf, nativeList, label ~= "" and label or ("RID:" .. ridStr))
        end)
        if not ok then
            labLog("✗ RID invite failed: " .. tostring(err), T.red)
            GUI.AddToast("The Gangs", "✗ RID invite — " .. tostring(err), 3000)
        else
            GUI.AddToast("The Gangs", "Invite(s) sent → " .. (label ~= "" and label or ridStr), 3000)
        end
    end)
end

-- ── Native definitions used in buttons ───────────────────────
local LAB_NATIVES = {
    N1  = { hash = 0xC3C7A6AFDB244624, label = "SEND_INVITE_VIA_PRESENCE" },
    N2  = { hash = 0xC116FF9B4D488291, label = "SEND_TRANSITION_INVITE_VIA_PRESENCE" },
    N3  = { hash = 0x1171A97A3D3981B6, label = "SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE" },
}
local LAB_ALL = { LAB_NATIVES.N1, LAB_NATIVES.N2, LAB_NATIVES.N3 }

-- ── Render ────────────────────────────────────────────────────
local function renderInviteLab()
    -- Banner
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.05, 0.05, 0.10, 1)
    ImGui.BeginChild("##lab_banner", -1, 52, true)
        ImGui.Spacing()
        ImGui.TextColored(T.yellow[1],T.yellow[2],T.yellow[3],1,
            "  🧪  INVITE LAB  —  Out-of-session invite testing")
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "  Builds GamerHandle from friend-list index or RID → fires presence invite natives")
    ImGui.EndChild()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- ── Method legend ─────────────────────────────────────────
    ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
    ImGui.BeginChild("##lab_legend", -1, 76, true)
        ImGui.Spacing()
        ImGui.TextColored(T.orange[1],T.orange[2],T.orange[3],1, "  [1]")
        ImGui.SameLine(); ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "NETWORK_SEND_INVITE_VIA_PRESENCE              (0xC3C7A6AFDB244624)  — freemode session invite")
        ImGui.TextColored(T.accent[1],T.accent[2],T.accent[3],1, "  [2]")
        ImGui.SameLine(); ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "NETWORK_SEND_TRANSITION_INVITE_VIA_PRESENCE   (0xC116FF9B4D488291)  — transition lobby invite")
        ImGui.TextColored(T.cyan[1],T.cyan[2],T.cyan[3],1, "  [3]")
        ImGui.SameLine(); ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE (0x1171A97A3D3981B6)  — high-priority version of [2]")
    ImGui.EndChild()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- ── SECTION A: Friends list ───────────────────────────────
    sectionHdr("", "FRIENDS LIST  (NETWORK_HANDLE_FROM_FRIEND — works offline)",
        T.green[1],T.green[2],T.green[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        "  Handle built from friend-list index — player does NOT need to be in your session.")
    ImGui.Spacing()

    local bw2 = (ImGui.GetContentRegionAvail() - 8) * 0.5
    if cBtn("  Refresh Friends  ", T.green[1],T.green[2],T.green[3], bw2, 0) then
        Script.QueueJob(function()
            local list = {}
            pcall(function()
                local count = Natives.InvokeInt(0x203F1CFD823B27A4) or 0
                labLog(string.format("Friend count: %d", count), T.cyan)
                for i = 0, count - 1 do
                    local fname = Natives.InvokeString(0xE11EBBB2A783FE8B, i) or ""
                    -- try display name if encoded
                    if fname:match("[^%w%s%_%-%.]") or #fname > 30 then
                        local dn = ""
                        pcall(function() dn = Natives.InvokeString(0xE8F1A9D6CA96ED20, i) or "" end)
                        if dn ~= "" then fname = dn end
                    end
                    local online, inGTA = false, false
                    pcall(function() online = Natives.InvokeBool(0xBAD8F2A42B844821, i) == true end)
                    if fname ~= "" then
                        pcall(function() inGTA = Natives.InvokeBool(0x57005C18827F3A28, fname) == true end)
                        if not online then
                            pcall(function() online = Natives.InvokeBool(0x425A44533437B64D, fname) == true end)
                        end
                    end
                    -- also try to scan RID from friend handle while we're here
                    local rid = nil
                    pcall(function()
                        local buf = GamerHandleBuffer.New()
                        if buf then
                            Natives.InvokeVoid(0xD45CB817D7E177D2, i, buf:GetBuffer(), 13)
                            if Natives.InvokeBool(0x6F79B93B0A8E4133, buf:GetBuffer(), 13) then
                                local gh = buf:ToHandle()
                                if gh and gh.RockstarId and gh.RockstarId ~= 0 then
                                    rid = gh.RockstarId
                                end
                            end
                        end
                    end)
                    table.insert(list, {
                        name   = fname,
                        online = online,
                        inGTA  = inGTA,
                        idx    = i,
                        rid    = rid,
                    })
                end
            end)
            -- sort: online first
            table.sort(list, function(a, b)
                local aS = (a.inGTA and 2) or (a.online and 1) or 0
                local bS = (b.inGTA and 2) or (b.online and 1) or 0
                if aS ~= bS then return aS > bS end
                return a.name:lower() < b.name:lower()
            end)
            LAB.friendList       = list
            LAB.friendListLoaded = true
            local onC, gtaC = 0, 0
            for _, f in ipairs(list) do
                if f.online then onC = onC + 1 end
                if f.inGTA  then gtaC = gtaC + 1 end
            end
            labLog(string.format("Loaded %d friends (%d online, %d in GTA)", #list, onC, gtaC), T.green)
            GUI.AddToast("The Gangs",
                string.format("[Lab] %d friends | %d online | %d in GTA", #list, onC, gtaC), 3000)
        end)
    end
    ImGui.SameLine()
    if cBtn("  Clear  ", T.red[1]*0.7, T.red[2]*0.7, T.red[3]*0.7, -1, 0) then
        LAB.friendList = {}; LAB.friendListLoaded = false
    end
    ImGui.Spacing()

    if not LAB.friendListLoaded then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
            "  Press Refresh to load friend list from game memory.")
    elseif #LAB.friendList == 0 then
        ImGui.TextColored(T.orange[1],T.orange[2],T.orange[3],1,
            "  No friends found — make sure you are in GTA Online.")
    else
        -- filter bar
        ImGui.SetNextItemWidth(200)
        local nff, nffc = ImGui.InputText("##lab_ff", LAB.friendFilter, 32)
        if nffc then LAB.friendFilter = nff end
        ImGui.SameLine()
        local onC2 = 0
        for _, f in ipairs(LAB.friendList) do if f.online then onC2 = onC2 + 1 end end
        ImGui.TextColored(T.green[1],T.green[2],T.green[3],1,
            string.format(" %d online / %d total", onC2, #LAB.friendList))
        ImGui.Spacing()

        local filt = LAB.friendFilter:lower()
        for _, f in ipairs(LAB.friendList) do
            if filt == "" or f.name:lower():find(filt, 1, true) then
                local nr, ng, nb
                if     f.inGTA  then nr,ng,nb = T.yellow[1],T.yellow[2],T.yellow[3]
                elseif f.online then nr,ng,nb = T.cyan[1],  T.cyan[2],  T.cyan[3]
                else               nr,ng,nb = T.dim[1],   T.dim[2],   T.dim[3] end

                ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
                ImGui.BeginChild("##labf"..f.idx, -1, 58, true)
                    -- Row 1: status + name + RID if known
                    ImGui.Spacing()
                    ImGui.TextColored(nr,ng,nb,1, f.inGTA and "  ● GTA" or (f.online and "  ● ONL" or "  ○ OFF"))
                    ImGui.SameLine()
                    ImGui.TextColored(T.txt[1],T.txt[2],T.txt[3],1, f.name)
                    if f.rid then
                        ImGui.SameLine()
                        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],0.7,
                            string.format("  RID:%d", f.rid))
                    end
                    -- Row 2: invite buttons (use friend index — works even if offline)
                    local fi  = f.idx
                    local fn  = f.name
                    local bwF = (ImGui.GetContentRegionAvail() - 18) / 4

                    if cBtn("[1]##l1"..fi, T.orange[1],T.orange[2],T.orange[3], bwF, 0) then
                        labInviteFromFriendIndex(fi, fn, { LAB_NATIVES.N1 })
                    end
                    if ImGui.IsItemHovered() then ImGui.SetTooltip("SEND_INVITE_VIA_PRESENCE\nFreemode session invite") end
                    ImGui.SameLine()

                    if cBtn("[2]##l2"..fi, T.accent[1],T.accent[2],T.accent[3], bwF, 0) then
                        labInviteFromFriendIndex(fi, fn, { LAB_NATIVES.N2 })
                    end
                    if ImGui.IsItemHovered() then ImGui.SetTooltip("SEND_TRANSITION_INVITE_VIA_PRESENCE\nTransition lobby invite") end
                    ImGui.SameLine()

                    if cBtn("[3]##l3"..fi, T.cyan[1],T.cyan[2],T.cyan[3], bwF, 0) then
                        labInviteFromFriendIndex(fi, fn, { LAB_NATIVES.N3 })
                    end
                    if ImGui.IsItemHovered() then ImGui.SetTooltip("SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE\nHigh-priority transition invite") end
                    ImGui.SameLine()

                    if cBtn("[ALL]##la"..fi, T.green[1],T.green[2],T.green[3], bwF, 0) then
                        labInviteFromFriendIndex(fi, fn, LAB_ALL)
                    end
                    if ImGui.IsItemHovered() then ImGui.SetTooltip("Fires all three invite natives\n[1]+[2]+[3] with 80ms gap each") end

                ImGui.EndChild()
                ImGui.PopStyleColor(1)
                ImGui.Spacing()
            end
        end
    end

    ImGui.Separator(); ImGui.Spacing()

    -- ── SECTION B: Manual RID invite (non-friends) ────────────
    sectionHdr("", "MANUAL RID INVITE  (NETWORK_HANDLE_FROM_USER_ID — any player)",
        T.orange[1],T.orange[2],T.orange[3])
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,
        "  Enter a Rockstar ID to invite any player, even if not on your friend list.")
    ImGui.Spacing()

    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "  RID:"); ImGui.SameLine()
    ImGui.SetNextItemWidth(160)
    local nr2, nr2c = ImGui.InputText("##lab_rid", LAB.ridInput, 24)
    if nr2c then LAB.ridInput = nr2 end
    ImGui.SameLine()
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "  Name (optional):"); ImGui.SameLine()
    ImGui.SetNextItemWidth(130)
    local nl2, nl2c = ImGui.InputText("##lab_rlbl", LAB.ridLabel, 32)
    if nl2c then LAB.ridLabel = nl2 end
    ImGui.Spacing()

    local ridValid = LAB.ridInput ~= "" and tonumber(LAB.ridInput) ~= nil
    if not ridValid then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "  Enter a numeric RID to enable buttons.")
    else
        local ridDisplay = LAB.ridLabel ~= "" and LAB.ridLabel or ("RID:" .. LAB.ridInput)
        local bwR = (ImGui.GetContentRegionAvail() - 18) / 4

        if cBtn("[1]##r1", T.orange[1],T.orange[2],T.orange[3], bwR, 0) then
            labInviteFromRid(LAB.ridInput, LAB.ridLabel, { LAB_NATIVES.N1 })
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("SEND_INVITE_VIA_PRESENCE") end
        ImGui.SameLine()

        if cBtn("[2]##r2", T.accent[1],T.accent[2],T.accent[3], bwR, 0) then
            labInviteFromRid(LAB.ridInput, LAB.ridLabel, { LAB_NATIVES.N2 })
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("SEND_TRANSITION_INVITE_VIA_PRESENCE") end
        ImGui.SameLine()

        if cBtn("[3]##r3", T.cyan[1],T.cyan[2],T.cyan[3], bwR, 0) then
            labInviteFromRid(LAB.ridInput, LAB.ridLabel, { LAB_NATIVES.N3 })
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("SEND_IMPORTANT_TRANSITION_INVITE_VIA_PRESENCE") end
        ImGui.SameLine()

        if cBtn("[ALL]##ra", T.green[1],T.green[2],T.green[3], bwR, 0) then
            labInviteFromRid(LAB.ridInput, LAB.ridLabel, LAB_ALL)
        end
        if ImGui.IsItemHovered() then ImGui.SetTooltip("Fires all three invite natives") end
    end

    ImGui.Separator(); ImGui.Spacing()

    -- ── Last result feedback ───────────────────────────────────
    if LAB.lastResult ~= "" then
        local c = LAB.lastResultColor or T.dim
        ImGui.PushStyleColor(ImGuiCol.ChildBg, T.bg2[1],T.bg2[2],T.bg2[3],1)
        ImGui.BeginChild("##lab_res", -1, 34, true)
            ImGui.Spacing()
            ImGui.TextColored(c[1],c[2],c[3],1, "  >> " .. LAB.lastResult)
        ImGui.EndChild()
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end

    -- ── Lab log ───────────────────────────────────────────────
    sectionHdr("", "LAB LOG", T.dim[1],T.dim[2],T.dim[3]+0.3)
    if cBtn(" Clear ", T.red[1]*0.7,T.red[2]*0.7,T.red[3]*0.7) then LAB.logLines = {} end
    ImGui.Spacing()
    if #LAB.logLines == 0 then
        ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, "  No events yet — press an invite button above.")
    else
        for _, l in ipairs(LAB.logLines) do
            ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1, l.time)
            ImGui.SameLine()
            ImGui.TextColored(l.color[1],l.color[2],l.color[3],1, "  " .. l.msg)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  MAIN RENDER
-- ══════════════════════════════════════════════════════════════
local function renderGangsTab()
    pushTheme()

    -- Title
    local p = pulse(1.2)
    ImGui.PushStyleColor(ImGuiCol.Text,
        T.accent[1]*0.6+p*0.4, T.accent[2]*0.4+p*0.2, T.accent[3], 1)
    ImGui.Text("  THE GANGS  v8.0")
    ImGui.PopStyleColor(1)
    ImGui.SameLine()
    ImGui.TextColored(T.dim[1],T.dim[2],T.dim[3],1,"  By Nasser  |  GTA V × Cherax × Discord × SilentNight")
    ImGui.PushStyleColor(ImGuiCol.Separator, T.accent[1]*0.28,T.accent[2]*0.20,T.accent[3]*0.38,0.70)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    -- Tab bar:  Dashboard  Controls  Casino  Vehicles  Members  Log
    local tabs      = {"  Dashboard","  Controls","  Heists","  Vehicles","  Members","  Log","  Discord","  🧪 Lab"}
    local tabColors = {T.accent, T.orange, T.gold, T.green, T.green, T.dim, T.cyan, T.yellow}

    for i, tabName in ipairs(tabs) do
        local isActive = (GUI_STATE.activeTab == i)
        local tc = tabColors[i]
        local label = tabName
        -- Badge for members queue
        if i == 5 and #pendingFriendRequests > 0 then
            label = tabName.." ("..#pendingFriendRequests..")"
        end
        if i == 7 then
            local dq = dmReadQueue and dmReadQueue() or {friends={},invites={}}
            local dqtotal = #(dq.friends or {}) + #(dq.invites or {})
            if dqtotal > 0 then label = tabName.." ("..dqtotal..")" end
        end
        if isActive then
            ImGui.PushStyleColor(ImGuiCol.Button, tc[1]*0.20, tc[2]*0.20, tc[3]*0.20, 1)
            ImGui.PushStyleColor(ImGuiCol.Text,   tc[1],      tc[2],      tc[3],      1)
            ImGui.PushStyleColor(ImGuiCol.Border, tc[1]*0.55, tc[2]*0.55, tc[3]*0.55, 0.90)
        else
            ImGui.PushStyleColor(ImGuiCol.Button, T.bg1[1], T.bg1[2], T.bg1[3], 0.85)
            ImGui.PushStyleColor(ImGuiCol.Text,   T.dim[1], T.dim[2], T.dim[3], 1)
            ImGui.PushStyleColor(ImGuiCol.Border, T.sep[1], T.sep[2], T.sep[3], 0.50)
        end
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
        if ImGui.Button(label) then GUI_STATE.activeTab = i end
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(3)
        if i < #tabs then ImGui.SameLine() end
    end

    ImGui.PushStyleColor(ImGuiCol.Separator, T.accent[1]*0.20,T.accent[2]*0.14,T.accent[3]*0.30,0.50)
    ImGui.Separator()
    ImGui.PopStyleColor(1)
    ImGui.Spacing()

    if     GUI_STATE.activeTab == 1 then renderDashboard()
    elseif GUI_STATE.activeTab == 2 then renderControls()
    elseif GUI_STATE.activeTab == 3 then renderHeists()
    elseif GUI_STATE.activeTab == 4 then renderVehicles()
    elseif GUI_STATE.activeTab == 5 then renderMembers()
    elseif GUI_STATE.activeTab == 6 then renderLog()
    elseif GUI_STATE.activeTab == 7 then renderDiscordManager()
    elseif GUI_STATE.activeTab == 8 then renderInviteLab()
    end

    popTheme()
end

-- ── REGISTER ─────────────────────────────────────────────────
ClickGUI.AddTab("The Gangs", renderGangsTab)

-- Feature name dump (for debugging)
pcall(function()
    ensureDir()
    local allF  = FeatureMgr.GetAllFeatures() or {}
    local lines = {"[FEATURE DUMP]\n"}
    for _, f in pairs(allF) do
        local ok, name = pcall(function() return f:GetName() end)
        if ok and name and name ~= "" then lines[#lines+1] = name.."\n" end
    end
    lines[#lines+1] = "[END]\n"
    FileMgr.WriteFileContent(BRIDGE.featFile, table.concat(lines), false)
end)

-- Initial car load + seed RID cache from current session
pcall(loadSavedCars)
pcall(cacheSessionRids)

Logger.Log(eLogColor.CYAN, "[The Gangs]",
    "v7.7 loaded — Brute force: 4 seconds of continuous overlay closing per request | Made By Nasser")
addLog("system",{},"true","The Gangs v7.7 loaded — Blocking overlay close approach","system")
print("[The Gangs] v7.7 loaded - brute force overlay closing. Made By Nasser.")
