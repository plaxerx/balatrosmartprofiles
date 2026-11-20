-- Smart Profiles: each save profile keeps its own mod list and mod settings, and a fourth
-- profile, V, plays pure vanilla Balatro.
--
-- V sits first in the stock profile picker (V, 1, 2, 3). Loading it turns off every mod but
-- the loader, Smart Profiles itself and Balatro Multiplayer, turns achievements on, and
-- restarts the game. Loading 1, 2 or 3 brings back that profile's own mods and settings.
--
-- The mod list and settings are stored in the profile's own folder
-- (<profile>/smart_profiles.jkr), so they belong to the profile rather than the install and
-- go with it when the profile is deleted.
--
-- Mods are switched the way Steamodded's mod menu switches them (ui.lua:1588): a line in
-- Mods/lovely/blacklist.txt turns one off; removing that line and any .lovelyignore turns it
-- on. Lovely patches and Steamodded loads mods only at launch, so a profile whose mods or
-- settings differ from the running set restarts the game.

SmartProfiles = SmartProfiles or {}
local SP = SmartProfiles
SP.mod = SMODS.current_mod

local VANILLA = 'V'
local DATA_FILE = 'smart_profiles.jkr'
local NFS = SMODS.NFS or NFS
local loader = require 'SMODS.preflight.loader'

-- The only mods profile V runs. Steamodded and Lovely are the loader, and Smart Profiles must
-- stay on or V has no way back. The rest are Balatro Multiplayer: the API with its PvP and
-- Speedrun modes, and the legacy single mod. Multiplayer is on in V unless switched off there.
SP.VANILLA_ALLOWED = {
    Steamodded = true,
    Lovely = true,
    [SP.mod.id] = true,
    MultiplayerAPI = true,
    MultiplayerPvP = true,
    MultiplayerSPDRN = true,
    Multiplayer = true,
    VirtualizedMultiplayer = true,
}

-- Main-menu badge colour per profile.
local BADGE_COLOURS = { V = G.C.BLUE, [1] = G.C.RED, [2] = G.C.GREEN, [3] = G.C.PURPLE }

--============================================================
-- Installed mods
--============================================================
local function folder_of(path)
    if not path then return nil end
    return (path:gsub('[\\/]+$', '')):match('([^\\/]+)$')
end

-- Folders Smart Profiles never switches: Lovely's own folder, the loader, and itself.
local PROTECTED = {
    lovely = true,
    [folder_of(SMODS.path) or ''] = true,
    [folder_of(SP.mod.path) or ''] = true,
}

-- Mod folder name -> mod id, for every mod Steamodded found, enabled or not.
local function mod_ids()
    local ids = {}
    for id, m in pairs(SMODS.Mods) do
        if type(m) == 'table' then
            if m.blacklist_name then ids[m.blacklist_name] = id end
            for _, v in ipairs(m.available_versions or {}) do
                if v.blacklist_name then ids[v.blacklist_name] = id end
            end
        end
    end
    return ids
end

-- Every switchable mod folder -> whether it is on, read from disk rather than from what
-- loaded, so a toggle made in the mod menu this session counts.
local function disk_mods()
    local out, blacklist = {}, loader.readBlacklist(true)
    for _, name in ipairs(NFS.getDirectoryItems(SMODS.MODS_DIR)) do
        local info = NFS.getInfo(SMODS.MODS_DIR .. '/' .. name)
        if info and info.type == 'directory' and not PROTECTED[name] and name:sub(1, 1) ~= '.' then
            out[name] = not blacklist[name]
                and not NFS.getInfo(SMODS.MODS_DIR .. '/' .. name .. '/.lovelyignore')
        end
    end
    return out
end

local function set_enabled(name, on)
    if on then
        local ignore = SMODS.MODS_DIR .. '/' .. name .. '/.lovelyignore'
        if NFS.getInfo(ignore) then NFS.remove(ignore) end
        if loader.readBlacklist(true)[name] then loader.removeFromBlacklist(name) end
    elseif not loader.readBlacklist(true)[name] then
        loader.addToBlacklist(name)
    end
end

-- Switches every installed folder `want` names to its wanted state. Folders `want` doesn't
-- mention (installed since the list was saved) are left alone.
local function apply_mods(want)
    local changed = false
    for name, on in pairs(disk_mods()) do
        local w = want[name]
        if w ~= nil and w ~= on then
            set_enabled(name, w)
            changed = true
        end
    end
    return changed
end

local function mods_differ(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return true end end
    for k, v in pairs(b) do if a[k] ~= v then return true end end
    return false
end

-- Counts mods the way the Mods menu lists them: one per mod even when two folders hold versions
-- of it, plus Smart Profiles itself, which is always on.
local function count_on(mods)
    local ids, seen, n = mod_ids(), {}, 1
    for name, on in pairs(mods or {}) do
        local key = ids[name] or name
        if on and not seen[key] then
            seen[key] = true
            n = n + 1
        end
    end
    return n
end

-- What loaded this session. Steamodded reads the same disk state at boot.
SP.boot_mods = disk_mods()

--============================================================
-- Mod settings
--============================================================
-- Steamodded keeps each mod's settings in config/<id>.jkr. Smart Profiles' own file is
-- install-wide and never swapped.
local function read_configs()
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems('config')) do
        local id = f:match('^(.+)%.jkr$')
        if id and id ~= SP.mod.id then out[id] = love.filesystem.read('config/' .. f) end
    end
    return out
end

-- Ids that could own a settings file: every real mod, loaded or not, plus Steamodded.
local function installed_ids()
    local out = {}
    for id, m in pairs(SMODS.Mods) do
        if type(m) == 'table' and not m.meta_mod and id ~= SP.mod.id then out[id] = true end
    end
    return out
end

local function is_loaded(id)
    local m = SMODS.Mods[id]
    return m and m.can_load and not m.disabled
end

-- Writes the settings `data` recorded. Returns true when a mod running now had its settings
-- changed under it, which only a restart picks up.
local function apply_configs(data)
    local stale = false
    for id in pairs(data.installed or {}) do
        if id ~= SP.mod.id then
            local path = 'config/' .. id .. '.jkr'
            local want = data.configs and data.configs[id]
            local have = love.filesystem.getInfo(path) and love.filesystem.read(path) or nil
            if want ~= have then
                if want then
                    love.filesystem.createDirectory('config')
                    love.filesystem.write(path, want)
                else
                    love.filesystem.remove(path)
                end
                if is_loaded(id) then stale = true end
            end
        end
    end
    return stale
end

--============================================================
-- Per-profile record
--============================================================
local function data_path(p) return p .. '/' .. DATA_FILE end

function SP.read(p)
    local path = data_path(p)
    if not love.filesystem.getInfo(path) then return nil end
    local ok, t = pcall(function()
        return setfenv(assert(loadstring(love.filesystem.read(path))), {})()
    end)
    return ok and type(t) == 'table' and t or nil
end

function SP.write(p, t)
    if not love.filesystem.getInfo(p .. '') then love.filesystem.createDirectory(p .. '') end
    love.filesystem.write(data_path(p), 'return ' .. serialize(t))
end

local function vanilla_allowed(name, ids)
    return SP.VANILLA_ALLOWED[(ids or mod_ids())[name] or ''] or false
end

-- The mods running now, as profile `p` would save them. For V that is only the Multiplayer
-- mods' on/off state, since everything else is always off there.
local function current_mods(p)
    if p ~= VANILLA then return disk_mods() end
    local ids, mods = mod_ids(), {}
    for name, on in pairs(disk_mods()) do
        if vanilla_allowed(name, ids) then mods[name] = on end
    end
    return mods
end

local function remember_last(p, mods)
    if p == VANILLA then return end
    SP.mod.config.last_modded = mods
    SP.mod.config.last_profile = p
    SMODS.save_mod_config(SP.mod)
end

-- Records profile `p`'s mod settings. Its mod list only changes when the player presses Save in
-- the Mods menu; a profile seen for the first time records the mods running now.
function SP.snapshot(p)
    local old = SP.read(p)
    local data = { configs = read_configs(), installed = installed_ids() }
    data.mods = old and old.mods or current_mods(p)
    remember_last(p, data.mods)
    SP.write(p, data)
end

-- Saves the mods running now as profile `p`'s list, along with its mod settings.
function SP.save_mods(p)
    local data = { configs = read_configs(), installed = installed_ids(), mods = current_mods(p) }
    remember_last(p, data.mods)
    SP.write(p, data)
end

-- True when the mods running now differ from profile `p`'s saved list. V's Multiplayer mods
-- count as on until saved off.
function SP.unsaved(p)
    local saved = (SP.read(p) or {}).mods or {}
    for name, on in pairs(current_mods(p)) do
        local want = saved[name]
        if p == VANILLA then want = want ~= false end
        if want ~= on then return true end
    end
    return false
end

-- The record profile `p` runs from. A numbered profile with none of its own borrows the last
-- numbered profile's, so it starts with those mods and settings.
function SP.record_for(p)
    local data = SP.read(p)
    if data or p == VANILLA then return data end
    local last = SP.mod.config.last_profile
    return last and last ~= p and SP.read(last) or nil
end

-- The mod list profile `p` should run. V: everything off except the allowed mods, which are on
-- unless V's record says otherwise. `keep_current` keeps the allowed mods as they are now,
-- for toggles just made in V's mod menu.
function SP.target_mods(p, data, keep_current)
    if p == VANILLA then
        local ids, want, saved = mod_ids(), {}, data and data.mods or {}
        for name, on in pairs(disk_mods()) do
            if not vanilla_allowed(name, ids) then
                want[name] = false
            elseif keep_current then
                want[name] = on
            else
                want[name] = saved[name] ~= false
            end
        end
        return want
    end
    return (data and data.mods) or SP.mod.config.last_modded or nil
end

-- Puts profile `p`'s mods and settings on disk. Returns true when the running game no longer
-- matches them and has to restart.
function SP.apply(p)
    local data = SP.record_for(p)
    local want = SP.target_mods(p, data)
    if want then apply_mods(want) end
    local stale = data and apply_configs(data) or false
    return stale or mods_differ(SP.boot_mods, disk_mods())
end

--============================================================
-- Restart
--============================================================
-- Waits for the profile switch's save to reach the save thread, then restarts. The thread
-- handles requests in order, and Steamodded's restart queues its kill after them.
local function restart_when_saved()
    local since
    G.E_MANAGER:add_event(Event({
        no_delete = true,
        blockable = false,
        blocking = false,
        func = function()
            local fh = G.FILE_HANDLER
            if fh and fh.update_queued and (fh.force or fh.progress or fh.settings) then return false end
            since = since or love.timer.getTime()
            if love.timer.getTime() - since < 0.5 then return false end
            SMODS.restart_game()
            return true
        end,
    }))
end

local function announce(text)
    attention_text({
        text = text, scale = 0.7, hold = 4, major = G.ROOM_ATTACH, align = 'cm',
        offset = { x = 0, y = -1 }, backdrop_colour = G.C.BLUE, silent = true,
    })
end

--============================================================
-- Profile switching
--============================================================
-- Records the profile being left, lets vanilla switch, then loads the new profile's mods and
-- settings, restarting when they differ from what is running.
local sp_load_profile = G.FUNCS.load_profile
G.FUNCS.load_profile = function(delete_prof_data)
    local from, to = G.SETTINGS.profile, G.focused_profile
    -- The Load button passes its own UI element here; only the delete flow passes true.
    if from == to or delete_prof_data == true then return sp_load_profile(delete_prof_data) end

    SMODS.save_all_config()
    SP.snapshot(from)
    sp_load_profile(delete_prof_data)

    -- Queued behind vanilla's load and main-menu events, so the switch is done by now.
    G.E_MANAGER:add_event(Event({
        no_delete = true,
        func = function()
            if SP.apply(to) then
                -- Vanilla's switch doesn't save on its own; settings.jkr has to carry the new
                -- profile across the restart.
                G:save_progress()
                G.FILE_HANDLER.force = true
                announce(to == VANILLA and 'Restarting into Vanilla' or ('Restarting with profile ' .. to .. "'s mods"))
                restart_when_saved()
            end
            return true
        end,
    }))
end

-- A deleted profile's record goes with it, or its folder can't be removed and a new profile
-- in that slot would inherit the old mod list.
local sp_delete_profile = G.FUNCS.delete_profile
G.FUNCS.delete_profile = function(e)
    local warning = e and e.UIBox and e.UIBox:get_UIE_by_ID('warning_text')
    if warning and warning.config.colour == G.C.WHITE and G.focused_profile ~= G.SETTINGS.profile then
        love.filesystem.remove(data_path(G.focused_profile))
    end
    return sp_delete_profile(e)
end

-- Leaving the mod menu: V re-asserts its fixed list over any toggles (Multiplayer may still
-- be switched), and every profile records its mod settings.
local sp_exit_mods = G.FUNCS.exit_mods
G.FUNCS.exit_mods = function(e)
    SMODS.save_all_config()
    local p = G.SETTINGS.profile
    if p == VANILLA then
        if apply_mods(SP.target_mods(VANILLA, nil, true)) then announce('Vanilla runs without mods') end
        SMODS.full_restart = mods_differ(SP.boot_mods, disk_mods()) and 1 or 0
    end
    SP.snapshot(p)
    return sp_exit_mods(e)
end

-- In V's mod menu the list is locked: every mod but Multiplayer shows a fixed "Off", and Smart
-- Profiles a fixed "On", since V needs it to switch back.
local sp_create_toggle = create_toggle
function create_toggle(args)
    local info = args and args.ref_value == 'should_enable' and args.ref_table
    if G.SETTINGS.profile == VANILLA and type(info) == 'table' and info.blacklist_name then
        local own = info.id == SP.mod.id
        if own or not SP.VANILLA_ALLOWED[info.id or ''] then
            return { n = G.UIT.C, config = {
                align = 'cm', minw = 0.8, minh = 0.4, padding = 0.05, r = 0.1,
                colour = own and G.C.GREEN or G.C.UI.BACKGROUND_INACTIVE,
            }, nodes = {
                { n = G.UIT.T, config = { text = own and 'On' or 'Off', scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
            }}
        end
    end
    if type(info) == 'table' and info.blacklist_name and args.callback then
        local cb = args.callback
        args.callback = function(...)
            cb(...)
            SP.save_state = nil
        end
    end
    return sp_create_toggle(args)
end

--============================================================
-- Save button
--============================================================
-- A button beside the Mods menu's page selector saves the mods running now as the current
-- profile's list. It lights up when there are toggles to save and greys out once saved. Its
-- label never changes, so the menu never re-lays itself out while open.
local SAVE_W, SAVE_GAP = 3.4, 0.05

local function profile_label(p)
    return p == VANILLA and 'Vanilla' or ('profile ' .. p)
end

local function set_save_look(e)
    if SP.save_state == nil then SP.save_state = SP.unsaved(G.SETTINGS.profile) end
    e.config.colour = SP.save_state and G.C.GREEN or G.C.UI.BACKGROUND_INACTIVE
    e.config.button = SP.save_state and 'smpr_save_mods' or nil
end

G.FUNCS.smpr_save_mods_state = set_save_look

G.FUNCS.smpr_save_mods = function(e)
    local p = G.SETTINGS.profile
    SMODS.save_all_config()
    SP.save_mods(p)
    SP.save_state = nil
    play_sound('generic1')
end

-- Sized and stacked like the page selector, so the two line up: Steamodded builds the selector
-- with an empty label row above it, and a padded column around its box. The button copies both,
-- so its box sits at the same height and top edge as the "Page" box.
local function save_button()
    local button = { n = G.UIT.C, config = {
        align = 'cm', minw = SAVE_W, minh = 0.64, r = 0.1, padding = 0.05, emboss = 0.1, hover = true,
        func = 'smpr_save_mods_state',
    }, nodes = {
        { n = G.UIT.T, config = {
            text = 'Save to ' .. profile_label(G.SETTINGS.profile), scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true,
        }},
    }}
    set_save_look(button)
    return { n = G.UIT.C, config = { align = 'cm' }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                { n = G.UIT.T, config = { text = '', scale = 0.5 * 0.8, colour = G.C.UI.TEXT_LIGHT } },
            }},
            { n = G.UIT.R, config = { align = 'cm', padding = 0 }, nodes = {
                { n = G.UIT.C, config = { align = 'cm', padding = 0.1, r = 0.1, colour = G.C.CLEAR }, nodes = { button } },
            }},
        }},
    }}
end

-- The page selector is the last row of the mod list's column; it moves into a row with the save
-- button on its right and a matching gap on its left, so it stays centred.
local sp_static_mod_list = SMODS.GUI.staticModListContent
function SMODS.GUI.staticModListContent(...)
    local t = sp_static_mod_list(...)
    SP.save_state = nil
    local column = t.nodes and t.nodes[1] and t.nodes[1].nodes and t.nodes[1].nodes[1]
    if not (column and column.nodes) then return t end
    local selector = column.nodes[#column.nodes]
    local is_selector = selector and selector.nodes and #column.nodes > 1
        and column.nodes[#column.nodes - 1].config and column.nodes[#column.nodes - 1].config.padding == 0.8
    local row = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {} }
    if is_selector then
        row.nodes[1] = { n = G.UIT.C, config = { minw = SAVE_W + 0.3 + SAVE_GAP }, nodes = {} }
        row.nodes[2] = { n = G.UIT.C, config = { align = 'cm' }, nodes = { selector } }
        row.nodes[3] = { n = G.UIT.C, config = { minw = SAVE_GAP }, nodes = {} }
        row.nodes[4] = save_button()
        column.nodes[#column.nodes] = row
    else
        row.nodes[1] = save_button()
        column.nodes[#column.nodes + 1] = row
    end
    return t
end

--============================================================
-- Profile picker
--============================================================
-- Opening the picker reads every profile's saved stats so each tab can show them, but vanilla
-- only reads 1-3. V's are read here too, then the current profile is put back before vanilla
-- reads the rest.
local sp_profile_select_func = G.FUNCS.profile_select
G.FUNCS.profile_select = function(e)
    local current = G.SETTINGS.profile
    if current ~= VANILLA and love.filesystem.getInfo(VANILLA .. '/profile.jkr') then
        G:load_profile(VANILLA)
        G.SETTINGS.profile = current
    end
    return sp_profile_select_func(e)
end

function G.UIDEF.profile_select()
    G.focused_profile = G.focused_profile or G.SETTINGS.profile or 1
    -- A tab's label doubles as its id ('tab_but_' .. label, UI_definitions.lua:2398), which
    -- vanilla looks up by profile key after a delete, so each label IS the profile key.
    local tabs = {}
    for _, p in ipairs({ VANILLA, 1, 2, 3 }) do
        tabs[#tabs + 1] = {
            label = p,
            chosen = G.focused_profile == p,
            tab_definition_function = G.UIDEF.profile_option,
            tab_definition_function_args = p,
        }
    end
    return create_UIBox_generic_options({ padding = 0, contents = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0, draw_layer = 1, minw = 4 }, nodes = {
            create_tabs({ tabs = tabs, snap_to_nav = true }),
        }},
    }})
end

-- One line under the profile name saying what that profile runs.
local sp_profile_option = G.UIDEF.profile_option
function G.UIDEF.profile_option(_profile)
    local t = sp_profile_option(_profile)
    local text
    if _profile == VANILLA then
        text = 'Pure vanilla: mods off except Multiplayer, achievements on'
    else
        local mods = (SP.read(_profile) or {}).mods
        text = mods and (count_on(mods) .. ' mods saved') or 'Starts with the last profile\'s mods'
        if mods and _profile == G.SETTINGS.profile and SP.unsaved(_profile) then
            text = text .. ', unsaved changes'
        end
    end
    table.insert(t.nodes, 2, { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
        { n = G.UIT.T, config = { text = text, scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
    }})
    return t
end

--============================================================
-- Main-menu badge
--============================================================
local sp_profile_button = create_UIBox_profile_button
function create_UIBox_profile_button()
    local p = G.SETTINGS.profile
    local prof = G.PROFILES[p]
    if p == VANILLA and prof and (prof.name or '') == '' then prof.name = 'Vanilla' end
    local t = sp_profile_button()
    -- The badge sits beside the "Profile" title, which has spare width, so the panel keeps
    -- vanilla's size and doesn't slide under the Play button.
    local title = t.nodes[1] and t.nodes[1].nodes and t.nodes[1].nodes[1]
    if title and title.nodes then
        title.nodes[#title.nodes + 1] = { n = G.UIT.C, config = { minw = 0.12 }, nodes = {} }
        title.nodes[#title.nodes + 1] = { n = G.UIT.C, config = {
            align = 'cm', minw = 0.42, minh = 0.42, r = 0.08, padding = 0.03, shadow = true,
            colour = BADGE_COLOURS[p] or G.C.GREY,
        }, nodes = {
            { n = G.UIT.T, config = { text = tostring(p), scale = 0.32, colour = G.C.WHITE, shadow = true } },
        }}
    end
    return t
end

-- Vanilla pins the profile panel to the screen's bottom-left corner, so a menu bar widened by
-- Steamodded's Mods button runs into it. The panel is anchored to the bar instead, the same
-- distance from its left edge as the language panel is from its right edge.
local function find_by_button(node, name)
    if node.config and node.config.button == name then return node end
    for _, c in pairs(node.children or {}) do
        local hit = find_by_button(c, name)
        if hit then return hit end
    end
end

local function menu_bar(menu)
    local node = menu:get_UIE_by_ID('main_menu_play')
    while node and not (node.config and node.config.colour == G.C.L_BLACK) do node = node.parent end
    return node
end

-- First main menu after launch: a game that starts on V with other mods still on, or on a new
-- profile, gets that profile's mods and restarts. A profile with a saved list is left as it is,
-- so Mods-menu toggles take effect across the restart before they are saved.
local function launch_check()
    local p = G.SETTINGS.profile
    local data = SP.read(p)
    local want = p == VANILLA and SP.target_mods(VANILLA, nil, true)
        or not data and SP.target_mods(p, SP.record_for(p))
        or nil
    if want and apply_mods(want) then
        if not data and p ~= VANILLA then apply_configs(SP.record_for(p) or {}) end
        announce(p == VANILLA and 'Restarting into Vanilla' or ('Restarting with profile ' .. p .. "'s mods"))
        restart_when_saved()
    elseif not data then
        SP.snapshot(p)
    end
end

local sp_set_main_menu_UI = set_main_menu_UI
function set_main_menu_UI(...)
    local ret = sp_set_main_menu_UI(...)
    if not SP.launch_checked then
        SP.launch_checked = true
        launch_check()
    end
    G.E_MANAGER:add_event(Event({
        blockable = false,
        blocking = false,
        func = function()
            local menu, box = G.MAIN_MENU_UI, G.PROFILE_BUTTON
            if not menu or menu.REMOVED then return true end
            if not box or box.REMOVED or box.sp_anchored then return box and box.sp_anchored or false end
            local bar = menu_bar(menu)
            if not bar then return true end
            local lang = find_by_button(menu.UIRoot, 'language_selection')
            local gap = lang and lang.parent and (lang.parent.T.x - (bar.T.x + bar.T.w)) or 0.5
            box:set_alignment({ major = bar, type = 'bli', bond = 'Weak',
                offset = { x = -(box.T.w + math.max(0, gap)), y = 0 } })
            box:align_to_major()
            box.sp_anchored = true
            return true
        end,
    }))
    return ret
end

--============================================================
-- Start-up
--============================================================
-- The Lovely patch adds this slot before the saved profile loads; this covers the picker if
-- the patch ever fails to apply.
G.PROFILES.V = G.PROFILES.V or {}

if G.SETTINGS.profile == VANILLA then
    -- Vanilla's own achievement rules: on, but not for seeded runs, challenges or an
    -- all-unlocked profile (Steamodded's option 2; 1 is off, 3 ignores those rules).
    SMODS.config.achievements = 2
    SMODS.config.seeded_unlocks = false
    G.F_NO_ACHIEVEMENTS = false
end
