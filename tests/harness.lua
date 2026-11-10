local addon_dir = ADDON_DIR
package.path = addon_dir .. '/?.lua;' .. package.path

function string.fmt(s, ...) return string.format(s, ...) end
function string.append(a, b) return a .. b end
function string.args(s)
    local out = {}
    for w in s:gmatch('%S+') do out[#out + 1] = w end
    return out
end
package.loaded['common'] = true
package.loaded['chat'] = {
    header = function(s) return '[' .. s .. '] ' end,
    message = function(s) return s end,
    error = function(s) return 'ERROR ' .. s end,
}

addon = { path = addon_dir }

local handlers = {}
ashita = { events = { register = function(name, id, fn) handlers[name] = fn end } }

local function levels(map)
    local t = {}
    for i = 1, 24 do t[i] = -1 end
    for job, lvl in pairs(map) do t[job + 1] = lvl end
    return t
end

local spells = {
    [1]   = { Name = { 'Cure' }, Targets = 63, Skill = 33, LevelRequired = levels({ [3] = 1, [5] = 3 }) },
    [4]   = { Name = { 'Cure IV' }, Targets = 63, Skill = 33, LevelRequired = levels({ [3] = 41, [5] = 48 }) },
    [12]  = { Name = { 'Raise' }, Targets = 157, Skill = 33, LevelRequired = levels({ [3] = 25 }) },
    [23]  = { Name = { 'Dia' }, Targets = 32, Skill = 35, LevelRequired = levels({ [3] = 3, [5] = 1 }) },
    [54]  = { Name = { 'Stoneskin' }, Targets = 1, Skill = 34, LevelRequired = levels({ [3] = 28 }) },
    [144] = { Name = { 'Fire' }, Targets = 32, Skill = 36, LevelRequired = levels({ [4] = 13 }) },
    [147] = { Name = { 'Fire IV' }, Targets = 32, Skill = 36, LevelRequired = levels({ [4] = 60 }) },
    [338] = { Name = { 'Utsusemi: Ichi' }, Targets = 1, Skill = 39, LevelRequired = levels({ [13] = 12 }) },
    [339] = { Name = { 'Utsusemi: Ni' }, Targets = 1, Skill = 39, LevelRequired = levels({ [13] = 37 }) },
    [394] = { Name = { "Mage's Ballad" }, Targets = 1, Skill = 40, LevelRequired = levels({ [10] = 25 }) },
    [463] = { Name = { 'Foe Lullaby' }, Targets = 32, Skill = 40, LevelRequired = levels({ [10] = 16 }) },
}
local abilities = {
    [42]    = { Name = { 'Savage Blade' }, Targets = 32 },
    [0x223] = { Name = { 'Provoke' }, Targets = 32 },
    [0x2A0] = { Name = { 'Fire IV' }, Targets = 32 },
    [0x200 + 211] = { Name = { 'Light Arts' }, Targets = 1 },
}

local entities = {}
local function ent(index, name, flags, dist, extra)
    local e = { name = name, flags = flags, dist = dist, hpp = 100, render = 0x200, id = 5000 + index, ballista = 0 }
    for k, v in pairs(extra or {}) do e[k] = v end
    entities[index] = e
end
ent(1000, 'Frank', 0x20D, 0)
ent(1001, 'Bobby', 0x0D, 5)
ent(1002, 'Lazarus', 0x01, 12, { id = 1234 })
ent(100, 'Goblin Mugger', 0x10, 8)
ent(101, 'Goblin Smithy', 0x10, 20)
ent(1800, 'Shantotto', 0x0E, 3)
ent(300, 'Hidden Bobber', 0x01, 2, { render = 0x4200 })

local party = { [0] = 1000, [1] = 1001, [2] = 1800 }
local target = { index = 0 }
local player = { main = 3, mainlvl = 75, sub = 5, sublvl = 37, spells = {}, abilities = {}, ws = {}, buffs = {} }
local queued = {}

local entity_api = {
    GetRawEntity = function(_, i) return entities[i] end,
    GetName = function(_, i) return entities[i] and entities[i].name or '' end,
    GetSpawnFlags = function(_, i) return entities[i].flags end,
    GetDistance = function(_, i) return entities[i].dist * entities[i].dist end,
    GetHPPercent = function(_, i) return entities[i].hpp end,
    GetRenderFlags0 = function(_, i) return entities[i].render end,
    GetServerId = function(_, i) return entities[i].id end,
    GetBallistaFlags = function(_, i) return entities[i].ballista end,
}
local party_api = {
    GetMemberTargetIndex = function(_, s) return party[s] or 0 end,
    GetMemberIsActive = function(_, s) if party[s] then return 1 end return 0 end,
    GetMemberZone = function(_, s) return 100 end,
}
local target_api = {
    GetIsSubTargetActive = function() return 0 end,
    GetTargetIndex = function(_, i) return target.index end,
}
local player_api = {
    GetMainJob = function() return player.main end,
    GetMainJobLevel = function() return player.mainlvl end,
    GetSubJob = function() return player.sub end,
    GetSubJobLevel = function() return player.sublvl end,
    HasSpell = function(_, id) return player.spells[id] == true end,
    HasAbility = function(_, id) return player.abilities[id] == true end,
    HasPetCommand = function(_, id) return false end,
    HasWeaponSkill = function(_, id) return player.ws[id] == true end,
    GetBuffs = function() return player.buffs end,
}
AshitaCore = {
    GetResourceManager = function() return {
        GetSpellById = function(_, id) return spells[id] end,
        GetAbilityById = function(_, id) return abilities[id] end,
    } end,
    GetMemoryManager = function() return {
        GetEntity = function() return entity_api end,
        GetParty = function() return party_api end,
        GetTarget = function() return target_api end,
        GetPlayer = function() return player_api end,
    } end,
    GetChatManager = function() return {
        QueueCommand = function(_, mode, cmd) queued[#queued + 1] = { mode = mode, cmd = cmd } end,
        ParseAutoTranslate = function(_, s) return s end,
    } end,
}

dofile(addon_dir .. '/shortcuts.lua')
handlers['load']()

local function set_job(main, mainlvl, sub, sublvl, known_spells, known_abilities, known_ws)
    player.main, player.mainlvl, player.sub, player.sublvl = main, mainlvl, sub, sublvl
    player.spells, player.abilities, player.ws = {}, {}, {}
    for _, id in ipairs(known_spells or {}) do player.spells[id] = true end
    for _, id in ipairs(known_abilities or {}) do player.abilities[id] = true end
    for _, id in ipairs(known_ws or {}) do player.ws[id] = true end
end

local failures = 0
local function run(cmd, opts)
    opts = opts or {}
    queued = {}
    local e = { command = cmd, mode = opts.mode or 1, injected = opts.injected or false, blocked = false }
    handlers['command'](e)
    local got = 'PASS'
    if e.blocked and #queued == 1 then got = queued[1].cmd end
    if e.blocked and #queued == 0 then got = 'BLOCKED' end
    local mode = queued[1] and queued[1].mode
    local ok = got == opts.want
    if ok and opts.want_mode then ok = mode == opts.want_mode end
    if not ok then failures = failures + 1 end
    if got:sub(1, 1) == '/' and mode ~= 0 then
        local again = { command = got, mode = 1, injected = false, blocked = false }
        handlers['command'](again)
        if again.blocked then
            failures = failures + 1
            print('LOOP ' .. got .. ' was rewritten again to ' .. tostring(queued[#queued] and queued[#queued].cmd))
        end
    end
    print(('%s  %-28s -> %-34s %s'):format(ok and 'ok  ' or 'FAIL', cmd, got .. (mode and (' (m' .. mode .. ')') or ''), ok and '' or ('want ' .. opts.want)))
end

set_job(3, 75, 5, 37, { 1, 4, 12, 23, 54 }, {}, { 42 })
target.index = 0
run('/cure4', { want = '/ma "Cure IV" <me>' })
run('/c4 bob', { want = '/ma "Cure IV" Bobby' })
run('/cure 4 bob', { want = '/ma "Cure IV" Bobby' })
run('/c4 la', { want = '/ma "Cure IV" Lazarus' })
run('/c4 shan', { want = '/ma "Cure IV" <p2>' })
run('/c4 bobber', { want = 'PASS' })
run('/ma "Cure IV" <t>', { want = 'PASS' })
run('/ma cure <t>', { want = 'PASS' })
run('/ma cure4 t', { want = '/ma "Cure IV" <t>' })
run('/ma c4 stpc', { want = '/ma "Cure IV" <stpc>' })
run('/ma "Cure IV" <t> <wait 2>', { want = 'PASS' })
run('/dia', { want = '/ma "Dia" <t>' })
run('/savageblade', { want = '/ws "Savage Blade" <t>' })
run('/ws savage blade t', { want = '/ws "Savage Blade" <t>' })
run('/wave', { want = '/wave <me>' })
run('/wave t', { want = '/wave <t>' })
run('/wave motion', { want = 'PASS' })
run('/check laz', { want = '/check Lazarus' })
run('/check Lazarus', { want = 'PASS' })
run('/pcmd add laz', { want = '/pcmd add Lazarus' })
run('/pcmd leave', { want = 'PASS' })
run('/p hello c4', { want = 'PASS' })
run('/tell bob cure4', { want = 'PASS' })
run('/hello there', { want = 'PASS' })
run('/addon load foo', { want = 'PASS' })
run('/c4 1234', { want = '/ma "Cure IV" 1234', want_mode = 0 })
run('/ma "Cure IV" 1234', { want = 'PASS' })
run('/c4', { want = 'PASS', mode = 0 })
run('/ma "Cure IV" <me>', { want = 'PASS', injected = true })

target.index = 100
run('//dia gob', { want = '/ma "Dia" <t>' })
run('/c4', { want = '/ma "Cure IV" <t>' })
run('/ss', { want = '/ma "Stoneskin" <me>' })
run('/ta goblin', { want = '/ta <t>' })
run('/wave', { want = '/wave <t>' })

target.index = 1001
run('/c4', { want = '/ma "Cure IV" <t>' })
entities[1001].hpp = 0
run('/raise', { want = '/ma "Raise" <t>' })
entities[1001].hpp = 100

set_job(4, 75, 3, 37, { 144, 147, 4 }, {}, {})
target.index = 100
run('/fire4', { want = '/ma "Fire IV" <t>' })
run('/ja fire4', { want = '/ma "Fire IV" <t>' })
set_job(15, 75, 3, 37, { 1 }, { 0x2A0 }, {})
run('/fire4', { want = '/ja "Fire IV" <t>' })
run('/ma fire4', { want = '/ja "Fire IV" <t>' })

set_job(10, 75, 13, 37, { 394, 463, 338, 339 }, {}, {})
target.index = 1001
run('/magesballad', { want = "/ma \"Mage's Ballad\" <me>" })
player.buffs = { 409 }
run('/magesballad', { want = "/ma \"Mage's Ballad\" <t>" })
run('/foelullaby', { want = '/ma "Foe Lullaby" <t>' })
player.buffs = {}
run('/ni', { want = '/ma "Utsusemi: Ni" <me>' })
run('/utsusemi ni', { want = '/ma "Utsusemi: Ni" <me>' })
run('/ma utsusemi ni', { want = '/ma "Utsusemi: Ni" <me>' })

print(('%d failure(s)'):format(failures))
return failures
