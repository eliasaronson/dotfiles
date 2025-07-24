local wezterm = require("wezterm")
local io = require("io")
local os = require("os")
local act = wezterm.action

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Credit: https://github.com/sjl/badwolf
local colors = {
	-- Basic colors (Bad Wolf)
	plain = "#f8f6f2",
	snow = "#ffffff",
	coal = "#000000",

	-- Gravel colors (Bad Wolf browns/grays)
	brightgravel = "#d9cec3",
	lightgravel = "#998f84",
	gravel = "#857f78",
	mediumgravel = "#666462",
	deepgravel = "#45413b",
	deepergravel = "#35322d",
	darkgravel = "#242321",
	blackgravel = "#1c1b1a",
	blackestgravel = "#141413",

	-- Bad Wolf accent colors (keeping most)
	dalespale = "#fade3e", -- yellow
	dirtyblonde = "#f4cf86", -- tan/yellow
	taffy = "#ff2c4b", -- red
	saltwatertaffy = "#8cffba", -- mint green
	tardis = "#0a9dff", -- blue (cursor/accent)
	orange = "#ffa724", -- orange
	lime = "#aeee00", -- lime green
	dress = "#ff9eb8", -- pink
	toffee = "#b88853", -- brown
	coffee = "#c7915b", -- coffee brown
	darkroast = "#88633f", -- dark brown

	-- Solarized colors for git and path
	solarized_blue = "#268bd2", -- Solarized blue (for path)
	solarized_green = "#859900", -- Solarized green (clean git)
	solarized_yellow = "#b58900", -- Solarized yellow (dirty git)
	solarized_base0 = "#839496", -- Solarized text color
	solarized_base00 = "#657b83", -- Solarized darker text
}

-- Terminal color scheme
config.colors = {
	-- Foreground and background
	foreground = colors.plain,
	background = colors.blackgravel,

	-- Cursor colors (keeping Bad Wolf tardis blue for consistency)
	cursor_bg = colors.tardis,
	cursor_fg = colors.coal,
	cursor_border = colors.tardis,

	-- Selection colors
	selection_fg = colors.plain,
	selection_bg = colors.deepgravel,

	-- Scrollbar colors
	scrollbar_thumb = colors.mediumgravel,

	-- Tab bar colors
	tab_bar = {
		background = colors.blackgravel,

		active_tab = {
			bg_color = colors.tardis,
			fg_color = colors.coal,
			intensity = "Bold",
		},

		inactive_tab = {
			bg_color = colors.blackgravel,
			fg_color = colors.plain,
		},

		inactive_tab_hover = {
			bg_color = colors.darkgravel,
			fg_color = colors.plain,
			italic = true,
		},

		new_tab = {
			bg_color = colors.blackgravel,
			fg_color = colors.mediumgravel,
		},

		new_tab_hover = {
			bg_color = colors.darkgravel,
			fg_color = colors.plain,
		},
	},

	-- Standard ANSI colors (mixing Bad Wolf + Solarized for specific segments)
	ansi = {
		colors.coal, -- black (used for git dirty text)
		colors.taffy, -- red (Bad Wolf)
		colors.solarized_green, -- green (Solarized - clean git background)
		colors.solarized_yellow, -- yellow (Solarized - dirty git background)
		colors.solarized_blue, -- blue (Solarized - directory background)
		colors.dress, -- magenta (Bad Wolf)
		colors.saltwatertaffy, -- cyan (Bad Wolf)
		colors.lightgravel, -- white (Bad Wolf)
	},

	-- Bright ANSI colors
	brights = {
		colors.mediumgravel, -- bright black (Bad Wolf)
		colors.taffy, -- bright red (Bad Wolf)
		colors.solarized_green, -- bright green (Solarized - git clean state)
		colors.solarized_yellow, -- bright yellow (Solarized - git dirty state)
		colors.solarized_blue, -- bright blue (Solarized - directory)
		colors.dress, -- bright magenta (Bad Wolf)
		colors.saltwatertaffy, -- bright cyan (Bad Wolf)
		colors.snow, -- bright white (Bad Wolf)
	},
}

-- window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

config.check_for_updates = false

config.enable_scroll_bar = true

wezterm.on("trigger-vim-with-scrollback", function(window, pane)
	-- Retrieve the text from the pane
	-- local text = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)
	local text = pane:get_lines_as_escapes(pane:get_dimensions().scrollback_rows)
	text = text:gsub("\27%([AB012]", "") -- Remove charset sequences like (A, (B, (0, etc.
	text = text:gsub("\27%[%?%d*[hl]", "") -- Remove mode setting sequences
	text = text:gsub("\27%[[0-9;]*[HfABCDsu]", "") -- Remove cursor positioning (but keep colors)

	-- Create a temporary file to pass to vim
	local name = os.tmpname() .. ".scrollback"
	local f = io.open(name, "w+")
	f:write(text)
	f:flush()
	f:close()

	-- Open a new window running vim and tell it to open the file
	window:perform_action(
		act.SpawnCommandInNewWindow({
			args = {
				"nvim",
				"-c",
				"ColorHighlight",
				"-c",
				"set nospell",
				name,
			},
		}),
		pane
	)

	-- Wait "enough" time for vim to read the file before we remove it.
	-- The window creation and process spawn are asynchronous wrt. running
	-- this script and are not awaitable, so we just pick a number.
	--
	-- Note: We don't strictly need to remove this file, but it is nice
	-- to avoid cluttering up the temporary directory.
	wezterm.sleep_ms(1000)
	os.remove(name)
end)
config.keys = {
	{
		key = "E",
		mods = "CTRL",
		action = act.EmitEvent("trigger-vim-with-scrollback"),
	},
}

-- and finally, return the configuration to wezterm
return config
