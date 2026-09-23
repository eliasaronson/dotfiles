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

-- New windows open at the default 80x24 instead of filling the sway tile: an upstream
-- regression in wezterm's Wayland backend (wezterm #7886, open), introduced when it
-- started migrating to winit around 2026-06. Measured here: the tile is 1893x2052
-- physical px but the terminal stays 80x24 = 1520x1032 px (0.80x wide, 0.50x tall) and
-- never applies sway's configure. Ruled out as causes: output scale (happens on both the
-- fractional 1.4 and the integer 2.0 monitor), front_end (WebGpu and Software alike),
-- window_decorations (NONE, RESIZE and the default TITLE|RESIZE all affected),
-- tiling_desktop_environments, and dpi/dpi_by_screen. XWayland (enable_wayland = false)
-- is unaffected but then sway upscales the surface, so text goes soft on both panels.
-- Fix: the wezterm package is pinned to a pre-regression build in ~/nixos-config.
config.hide_tab_bar_if_only_one_tab = true

-- GPU rendering via Vulkan (WebGpu). History on this Meteor Lake iGPU:
--   * "OpenGL" -> Mesa iris is broken (llvmpipe) and the EGL path hit the NVIDIA
--     dGPU, hanging the session on the cross-GPU present. Do not use.
--   * "WebGpu" earlier tripped the iGPU's PL4 peak-power clamp (throttled the whole
--     desktop to 100 MHz) -- but the ROOT cause was a 50W PL4 firmware default.
--     That is now raised to 64W (NixOS raise-pl4 service), and max_fps=30 caps
--     wezterm's continuous redraw, so WebGpu on the Intel iGPU (LowPower, never the
--     NVIDIA dGPU) no longer trips it. This keeps rendering off the CPU (Software
--     was hitting ~1200% CPU under load). Revert to "Software" if the throttle ever
--     returns (check: /sys/class/drm/card1/gt/gt0/throttle_reason_pl4).
-- See [[intel-gl-llvmpipe-regression]].
config.front_end = "WebGpu"
config.webgpu_power_preference = "LowPower"
config.max_fps = 30
config.enable_kitty_graphics = false

-- NOTE: do NOT enable the kitty keyboard protocol (config.enable_kitty_keyboard).
-- On the us_swe layout it reports shifted symbol keys (+, ?, !, etc.) as
-- base-key + shift-modifier via CSI-u instead of the composed character, and
-- apps that don't recompose them (Claude Code) drop the symbol entirely. We get
-- Shift+Enter via the SendString binding in config.keys below instead.

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

config.check_for_updates = false

config.enable_scroll_bar = false

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
	-- Shift+Enter -> ESC+CR, which Claude Code and nvim interpret as "insert
	-- newline" rather than submit. Preferred over the kitty keyboard protocol
	-- because that protocol breaks shifted symbol input on us_swe (see note by
	-- config.enable_kitty_graphics above).
	{
		key = "Enter",
		mods = "SHIFT",
		action = act.SendString("\x1b\r"),
	},
}

-- Bell handler disabled - using notify-send from Claude Code hooks instead
-- wezterm.on("bell", function(window, pane)
-- 	window:toast_notification("Claude Code", "Task completed", nil, 4000)
-- end)

return config
