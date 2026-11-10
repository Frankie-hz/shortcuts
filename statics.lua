local statics = {};

local all_targets      = { Player = true, Enemy = true, Party = true, Ally = true, NPC = true, Self = true, Corpse = true };
local pc_targets       = { Player = true, Party = true, Ally = true, Self = true, Corpse = true };
local party_targets    = { Party = true, Self = true, Corpse = true };
local alliance_targets = { Ally = true, Self = true, Corpse = true };
local bst_targets      = { Player = true, Self = true };

local function party_command(member_targets)
    return {
        targets = {},
        args = {
            kick    = member_targets,
            add     = pc_targets,
            leader  = member_targets,
            breakup = true,
            leave   = true,
            looter  = member_targets,
        },
    };
end

local emote = { targets = all_targets, args = { motion = true } };

-- Commands that only need their target completed. args lists sub-commands and the targets each one takes (true = no target).
statics.target_commands = {
    assist      = { targets = all_targets },
    alliancecmd = party_command(alliance_targets),
    acmd        = party_command(alliance_targets),
    partycmd    = party_command(party_targets),
    pcmd        = party_command(party_targets),
    check       = { targets = pc_targets },
    c           = { targets = pc_targets },
    checkparam  = { targets = { Self = true }, args = {} },
    target      = { targets = pc_targets },
    ta          = { targets = pc_targets },
    ra          = { targets = { Enemy = true } },
    shoot       = { targets = { Enemy = true } },
    throw       = { targets = { Enemy = true } },
    follow      = { targets = all_targets },
    recruit     = { targets = pc_targets },
    rec         = { targets = pc_targets },
    retr        = { targets = party_targets, args = { all = true } },
    returntrust = { targets = party_targets, args = { all = true } },
    refa        = { targets = party_targets, args = { all = true } },
    returnfaith = { targets = party_targets, args = { all = true } },
    bstpet      = {
        targets = {},
        args = { ['1'] = bst_targets, ['2'] = bst_targets, ['3'] = bst_targets, ['4'] = bst_targets, ['5'] = bst_targets, ['6'] = bst_targets, ['7'] = bst_targets },
    },
};

for _, name in ipairs({
    'wave', 'poke', 'dance', 'dance1', 'dance2', 'dance3', 'dance4', 'amazed', 'angry', 'bell', 'bellsw', 'blush', 'bow', 'cheer',
    'clap', 'comfort', 'cry', 'disgusted', 'doze', 'doubt', 'huh', 'farewell', 'goodbye', 'fume', 'grin', 'hurray', 'joy', 'kneel',
    'laugh', 'muted', 'no', 'nod', 'yes', 'panic', 'point', 'praise', 'psych', 'salute', 'shocked', 'sigh', 'sit', 'slap', 'smile',
    'stagger', 'stare', 'sulk', 'surprised', 'think', 'toss', 'upset', 'welcome',
}) do
    statics.target_commands[name] = emote;
end

-- Action prefixes and the resource kind each one prefers when a name is ambiguous.
statics.action_commands = {
    ja = 'job_abilities', jobability = 'job_abilities', pet = 'job_abilities',
    ma = 'spells', magic = 'spells', so = 'spells', song = 'spells', nin = 'spells', ninjutsu = 'spells',
    ws = 'weapon_skills', weaponskill = 'weapon_skills',
};

statics.prefixes = {
    spells        = '/ma',
    job_abilities = '/ja',
    weapon_skills = '/ws',
};

-- Chat and game commands that are never rewritten.
statics.passthrough = {};
for _, name in ipairs({
    'p', 'party', 's', 'say', 'sh', 'shout', 'yell', 't', 'tell', 'l', 'linkshell', 'l2', 'linkshell2', 'em', 'emote', 'echo',
    'breaklinkshell', 'item', 'equip', 'raw', 'fish', 'dig', 'range', 'map', 'hide', 'jump', 'attackoff', 'quest',
    'recruitlist', 'rlist', 'statustimer', 'recycle', 'ms', 'monsterskill', 'mo', 'mount',
}) do
    statics.passthrough[name] = true;
end

statics.pass_through_targets = {};
for _, name in ipairs({
    '<t>', '<me>', '<ft>', '<scan>', '<bt>', '<lastst>', '<r>', '<pet>', '<focust>',
    '<p0>', '<p1>', '<p2>', '<p3>', '<p4>', '<p5>',
    '<a10>', '<a11>', '<a12>', '<a13>', '<a14>', '<a15>', '<a20>', '<a21>', '<a22>', '<a23>', '<a24>', '<a25>',
    '<st>', '<stpc>', '<stal>', '<stnpc>', '<stpt>',
}) do
    statics.pass_through_targets[name] = true;
end

statics.target_shorthands = {};
for name in pairs(statics.pass_through_targets) do
    statics.target_shorthands[name:sub(2, -2)] = name;
end

return statics;
