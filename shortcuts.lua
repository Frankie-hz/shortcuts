--[[
Copyright (c) 2014, Byrthnoth
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of <addon name> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]--

addon.name    = 'shortcuts';
addon.author  = 'Byrthnoth (Windower), Frankie (Ashita v4 port)';
addon.version = '1.0.0';
addon.desc    = 'Completes and formats typed actions, targets, emotes and party commands.';
addon.link    = 'https://github.com/Frankie-hz/shortcuts';

require('common');
local chat    = require('chat');
local statics = require('statics');

local state = {
    index     = nil,
    aliases   = {},
    last_sent = '',
    debug     = false,
};

local auto_translate_marker = string.char(0xFD);

local roman_steps = {
    { 1000, 'm' }, { 900, 'cm' }, { 500, 'd' }, { 400, 'cd' }, { 100, 'c' }, { 90, 'xc' }, { 50, 'l' },
    { 40, 'xl' }, { 10, 'x' }, { 9, 'ix' }, { 5, 'v' }, { 4, 'iv' }, { 1, 'i' },
};

local target_bits = {
    { 0x01, 'Self' }, { 0x02, 'Player' }, { 0x04, 'Party' }, { 0x08, 'Ally' }, { 0x10, 'NPC' }, { 0x20, 'Enemy' },
};

local function log(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function to_roman(digits)
    local num = tonumber(digits);
    if num > 4599 then
        return digits;
    end
    if num == 0 then
        return 'zilch';
    end
    -- Tier one spells have no numeral, so cure1 matches Cure.
    if num == 1 then
        return '';
    end
    local numerals = {};
    for _, step in ipairs(roman_steps) do
        while num >= step[1] do
            num = num - step[1];
            numerals[#numerals + 1] = step[2];
        end
    end
    return table.concat(numerals);
end

local function strip(name)
    local slug = name:gsub('[^%w]', ''):lower():gsub('%d+', to_roman);
    return slug;
end

local function trim(text)
    local trimmed = text:gsub('^%s+', ''):gsub('%s+$', '');
    return trimmed;
end

local function split_words(text)
    local words = {};
    for word in text:gmatch('[^ ]+') do
        words[#words + 1] = word;
    end
    return words;
end

local function load_aliases()
    local ok, result = pcall(dofile, ('%s/aliases.lua'):fmt(addon.path));
    if not ok or type(result) ~= 'table' then
        print(chat.header(addon.name):append(chat.error(('Could not load aliases.lua: %s'):fmt(tostring(result)))));
        return;
    end
    local aliases = {};
    for key, value in pairs(result) do
        if type(key) == 'string' and type(value) == 'string' then
            aliases[key:lower()] = value;
        end
    end
    state.aliases = aliases;
end

-- Only the action word is aliased so target names like "La" or "Ni" survive.
local function replace_alias(words)
    local position = 1;
    if #words > 1 and statics.action_commands[words[1]:lower()] ~= nil then
        position = 2;
    end
    local alias = state.aliases[words[position]:lower()];
    if alias ~= nil then
        words[position] = alias;
    end
end

local function add_entry(index, entry)
    local slug = strip(entry.name);
    if slug == '' then
        return;
    end
    if index[slug] == nil then
        index[slug] = {};
    end
    table.insert(index[slug], entry);
end

local function build_index()
    local resources = AshitaCore:GetResourceManager();
    local index = {};
    for id = 0, 0x3FF do
        local spell = resources:GetSpellById(id);
        if spell ~= nil then
            local name = trim(spell.Name[1] or '');
            if #name > 1 then
                add_entry(index, { kind = 'spells', id = id, name = name, targets = spell.Targets, skill = spell.Skill });
            end
        end
    end
    -- Ability ids below 0x200 are weapon skills, the rest are job abilities and pet commands.
    for id = 0, 0x5FF do
        local ability = resources:GetAbilityById(id);
        if ability ~= nil then
            local name = trim(ability.Name[1] or '');
            if #name > 1 then
                local kind = 'job_abilities';
                if id < 0x200 then
                    kind = 'weapon_skills';
                end
                add_entry(index, { kind = kind, id = id, name = name, targets = ability.Targets });
            end
        end
    end
    return index;
end

local function ability_index()
    if state.index == nil then
        state.index = build_index();
    end
    return state.index;
end

local function memory()
    return AshitaCore:GetMemoryManager();
end

local function self_index()
    return memory():GetParty():GetMemberTargetIndex(0);
end

local function current_target_index()
    local target = memory():GetTarget();
    local index = target:GetTargetIndex(target:GetIsSubTargetActive());
    if index == 0 or memory():GetEntity():GetRawEntity(index) == nil then
        return nil;
    end
    return index;
end

local function is_pc(flags)
    return bit.band(flags, 0x01) ~= 0;
end

local function is_trust(flags)
    return bit.band(flags, 0x0F) == 0x0E;
end

local function is_targetable(entity, index)
    local render = entity:GetRenderFlags0(index);
    return bit.band(render, 0x200) ~= 0 and bit.band(render, 0x4000) == 0;
end

local function party_slot(index)
    local party = memory():GetParty();
    local zone = party:GetMemberZone(0);
    for slot = 0, 17 do
        if party:GetMemberIsActive(slot) ~= 0 and party:GetMemberZone(slot) == zone and party:GetMemberTargetIndex(slot) == index then
            return slot;
        end
    end
    return nil;
end

local function slot_placeholder(slot)
    if slot < 6 then
        return ('<p%d>'):fmt(slot);
    end
    if slot < 12 then
        return ('<a1%d>'):fmt(slot - 6);
    end
    return ('<a2%d>'):fmt(slot - 12);
end

local function server_id_exists(id)
    local entity = memory():GetEntity();
    for index = 0, 0x8FF do
        if entity:GetRawEntity(index) ~= nil and entity:GetServerId(index) == id then
            return true;
        end
    end
    return false;
end

local function collect_candidates(slug)
    local entity = memory():GetEntity();
    local me = self_index();
    local target = current_target_index();
    local candidates = {};
    for index = 0, 0x8FF do
        if entity:GetRawEntity(index) ~= nil and (index == me or is_targetable(entity, index)) then
            local name = entity:GetName(index) or '';
            local name_slug = strip(name);
            if name_slug ~= '' and name_slug:find(slug, 1, true) ~= nil then
                local flags = entity:GetSpawnFlags(index);
                local candidate = { key = name, slug = name_slug, distance = math.sqrt(entity:GetDistance(index)) };
                if is_pc(flags) then
                    candidate.output = name;
                elseif is_trust(flags) then
                    local slot = party_slot(index);
                    if slot ~= nil then
                        candidate.output = slot_placeholder(slot);
                    end
                elseif index == target then
                    candidate.key = '<t>';
                    candidate.output = '<t>';
                end
                if candidate.output ~= nil then
                    candidates[#candidates + 1] = candidate;
                end
            end
        end
    end
    return candidates;
end

-- Strict only accepts placeholders, server ids and exact names, partial names also match otherwise.
local function resolve_target(text, strict)
    local lowered = text:lower();
    if statics.pass_through_targets[lowered] then
        return lowered;
    end
    local id = tonumber(text);
    if id ~= nil and server_id_exists(id) then
        return text;
    end
    local slug = strip(text);
    if slug == '' then
        return nil;
    end
    local candidates = collect_candidates(slug);
    for _, candidate in ipairs(candidates) do
        if candidate.key == text then
            return candidate.output;
        end
    end
    if strict then
        return nil;
    end
    -- Exact names win, then prefix matches by distance, then substring matches within 50 yalms.
    local best = nil;
    local best_priority = 50;
    for _, candidate in ipairs(candidates) do
        local priority = candidate.distance;
        if candidate.slug == slug then
            priority = 0;
        elseif candidate.slug:sub(1, #slug) == slug then
            priority = candidate.distance / 50;
        end
        if priority < best_priority then
            best_priority = priority;
            best = candidate.output;
        end
    end
    return best;
end

local function current_target_type()
    local index = current_target_index();
    if index == nil then
        return nil;
    end
    local entity = memory():GetEntity();
    if entity:GetHPPercent(index) == 0 then
        return 'Corpse';
    end
    local flags = entity:GetSpawnFlags(index);
    if not is_pc(flags) and not is_trust(flags) then
        return 'Enemy';
    end
    local slot = party_slot(index);
    if slot == nil then
        return 'Ally';
    end
    if is_pc(flags) and entity:GetBallistaFlags(index) ~= entity:GetBallistaFlags(self_index()) then
        return 'Enemy';
    end
    if slot == 0 then
        return 'Self';
    end
    if slot < 6 then
        return 'Party';
    end
    return 'Ally';
end

local function make_target(targets)
    local target_type = current_target_type();
    if target_type ~= nil and target_type ~= 'Self' and targets[target_type] then
        return '<t>';
    end
    if targets.Self then
        return '<me>';
    end
    if targets.Party or targets.Enemy or targets.NPC or targets.Ally or targets.Corpse then
        return '<t>';
    end
    return '';
end

local function target_set(mask)
    local targets = {};
    if bit.band(mask, 0x9D) == 0x9D then
        targets.Corpse = true;
        mask = bit.band(mask, bit.bnot(0x9D));
    end
    for _, bit_name in ipairs(target_bits) do
        if bit.band(mask, bit_name[1]) ~= 0 then
            targets[bit_name[2]] = true;
        end
    end
    return targets;
end

local function has_buff(player, id)
    for _, buff in pairs(player:GetBuffs()) do
        if buff == id then
            return true;
        end
    end
    return false;
end

local function action_targets(player, entry)
    local targets = target_set(entry.targets);
    if entry.kind ~= 'spells' then
        return targets;
    end
    -- Pianissimo (409) lets self-only songs land on party members, Entrust (584) does the same for Indi- spells.
    if entry.skill == 40 and entry.targets == 0x01 and has_buff(player, 409) then
        targets.Party = true;
    elseif entry.skill == 44 and entry.name:sub(1, 5) == 'Indi-' and has_buff(player, 584) then
        targets.Party = true;
    end
    return targets;
end

local function job_can_use(levels, job, level)
    local required = levels[job + 1];
    return required ~= nil and required >= 0 and required <= level;
end

local function is_usable(player, entry)
    if entry.kind == 'spells' then
        if not player:HasSpell(entry.id) then
            return false;
        end
        local levels = AshitaCore:GetResourceManager():GetSpellById(entry.id).LevelRequired;
        return job_can_use(levels, player:GetMainJob(), player:GetMainJobLevel())
            or job_can_use(levels, player:GetSubJob(), player:GetSubJobLevel());
    end
    if entry.kind == 'job_abilities' then
        return player:HasAbility(entry.id) or player:HasPetCommand(entry.id);
    end
    return player:HasWeaponSkill(entry.id);
end

local usable_order  = { 'spells', 'job_abilities', 'weapon_skills' };
local fallback_order = { 'spells', 'weapon_skills', 'job_abilities' };

-- Shared names (Fire IV the spell and the blood pact) prefer the typed prefix, then usable actions in spell, ability, weapon skill order.
local function choose_entry(player, entries, prefix_kind)
    local usable = {};
    local unusable = {};
    local any_usable = false;
    for _, entry in ipairs(entries) do
        if is_usable(player, entry) then
            any_usable = true;
            usable[entry.kind] = usable[entry.kind] or entry;
        else
            unusable[entry.kind] = unusable[entry.kind] or entry;
        end
    end
    local pool = unusable;
    local order = fallback_order;
    if any_usable then
        pool = usable;
        order = usable_order;
    end
    if prefix_kind ~= nil and pool[prefix_kind] ~= nil then
        return pool[prefix_kind];
    end
    for _, kind in ipairs(order) do
        if pool[kind] ~= nil then
            return pool[kind];
        end
    end
    return nil;
end

local function interpret(words, offset)
    local count = #words;
    local index = ability_index();
    local whole = table.concat(words, ' ', 1 + offset, count);
    local target = nil;
    local ability_text = nil;
    if index[strip(whole)] ~= nil then
        ability_text = whole;
    elseif count > 1 then
        local last = words[count];
        target = resolve_target(statics.target_shorthands[last:lower()] or last, false);
    end
    if ability_text == nil then
        local last_word = count;
        if target ~= nil then
            last_word = count - 1;
        end
        ability_text = table.concat(words, ' ', 1 + offset, last_word);
    end
    local entries = index[strip(ability_text)];
    if entries == nil then
        return nil;
    end
    local player = memory():GetPlayer();
    local prefix_kind = nil;
    if offset == 1 then
        prefix_kind = statics.action_commands[words[1]:lower()];
    end
    local entry = choose_entry(player, entries, prefix_kind);
    if target == nil then
        target = make_target(action_targets(player, entry));
    end
    return trim(('%s "%s" %s'):fmt(statics.prefixes[entry.kind], entry.name, target));
end

local function complete_target(spec, command, words, potential_target)
    if spec.args == nil then
        local target = nil;
        if potential_target ~= nil then
            target = resolve_target(potential_target, false);
        end
        if target == nil then
            target = make_target(spec.targets);
        end
        if target == '<me>' then
            return '/' .. command;
        end
        return ('/%s %s'):fmt(command, target);
    end
    local text = command;
    local chosen = nil;
    local targets = spec.targets;
    for _, word in ipairs(words) do
        local sub_targets = spec.args[word:lower()];
        if sub_targets ~= nil then
            text = ('%s %s'):fmt(text, word:lower());
            chosen = word;
            targets = sub_targets;
            break;
        end
    end
    if targets == true then
        return '/' .. text;
    end
    if potential_target == nil or potential_target == chosen then
        return trim(('/%s %s'):fmt(text, make_target(targets)));
    end
    return ('/%s %s'):fmt(text, resolve_target(potential_target, false) or potential_target);
end

local function process(line)
    local words = split_words((line:gsub('^/+', '')));
    if #words == 0 then
        return nil;
    end
    replace_alias(words);
    local command = words[1]:lower();
    if statics.passthrough[command] then
        return nil;
    end
    local spec = statics.target_commands[command];
    if spec ~= nil then
        local potential_target = nil;
        if #words > 1 then
            local last = words[#words];
            potential_target = statics.target_shorthands[last:lower()] or last;
            if resolve_target(potential_target, true) ~= nil then
                if potential_target == last then
                    return nil;
                end
                words[#words] = potential_target;
                return '/' .. table.concat(words, ' ');
            end
        end
        return complete_target(spec, command, words, potential_target);
    end
    local offset = 0;
    if statics.action_commands[command] ~= nil then
        offset = 1;
    end
    return interpret(words, offset);
end

-- Case and quotes around single words do not change what the game does, so those rewrites are skipped.
local function normalize(line)
    local normalized = line:gsub('"([^ ]+)"', '%1'):gsub('%s+', ' '):lower();
    return trim(normalized);
end

local function print_help()
    log('Type actions with any prefix or none: /cure4 bob, /c4, /ma cure4 t, //provoke, /wave, /pcmd add bo');
    log('/shortcuts reload - Reloads aliases.lua and the action list.');
    log('/shortcuts debug - Toggles printing each rewrite.');
end

ashita.events.register('load', 'shortcuts_load', function ()
    load_aliases();
end);

ashita.events.register('command', 'shortcuts_command', function (e)
    if e.blocked then
        return;
    end
    local args = e.command:args();
    if #args > 0 and args[1]:lower() == '/shortcuts' then
        e.blocked = true;
        local sub = (args[2] or ''):lower();
        if sub == 'reload' then
            load_aliases();
            state.index = nil;
            log('Reloaded aliases and actions.');
        elseif sub == 'debug' then
            state.debug = not state.debug;
            log(('Debug %s.'):fmt(tostring(state.debug)));
        else
            print_help();
        end
        return;
    end
    -- Menu (0) and sub target re-processing (3+) are already resolved commands, -3 is Ashita forcing its own handler.
    if e.mode == 0 or e.mode > 2 or e.mode == -3 then
        return;
    end
    if e.injected and e.command == state.last_sent then
        state.last_sent = '';
        return;
    end
    local line = e.command;
    if line:sub(1, 1) ~= '/' then
        return;
    end
    if line:find(auto_translate_marker, 1, true) ~= nil then
        line = AshitaCore:GetChatManager():ParseAutoTranslate(line, false);
    end
    line = line:gsub(' <wait %d+>', '');
    local rewritten = process(line);
    if rewritten == nil or normalize(rewritten) == normalize(line) then
        state.last_sent = '';
        return;
    end
    e.blocked = true;
    state.last_sent = rewritten;
    if state.debug then
        log(('%s -> %s'):fmt(e.command, rewritten));
    end
    -- The client only resolves bare server ids as targets for menu-mode commands.
    local mode = 1;
    if rewritten:match(' %d+$') ~= nil then
        mode = 0;
    end
    AshitaCore:GetChatManager():QueueCommand(mode, rewritten);
end);
