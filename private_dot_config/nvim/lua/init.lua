-- Mason for LSP server management
require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗",
		},
	},
})

require("mason-lspconfig").setup({
	ensure_installed = {
		"clangd",
		"pyright",
		"lua_ls",
		"julials",
		"cmake",
		"ts_ls",
	},
	automatic_installation = true,
})

-- Enhanced LSP capabilities
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Add file watching capabilities for better performance
capabilities.workspace = capabilities.workspace or {}
capabilities.workspace.didChangeWatchedFiles = capabilities.workspace.didChangeWatchedFiles or {}
capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true

-- LSP server configurations
local lspconfig = require("lspconfig")

lspconfig.clangd.setup({
	capabilities = capabilities,
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
		"--header-insertion=never",
		"--completion-style=detailed",
		"--function-arg-placeholders",
		"--fallback-style=llvm",
		"--query-driver=/usr/bin/g++,/usr/bin/gcc,/usr/local/cuda/bin/nvcc",
		"--enable-config",
		"--limit-references=0",
		"--limit-results=0",
		"--log=verbose",
		"--pch-storage=memory",
		"--malloc-trim",
	},
	init_options = {
		usePlaceholders = true,
		completeUnimported = true,
		clangdFileStatus = true,
	},
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
})
vim.lsp.set_log_level("info")

lspconfig.pyright.setup({
	capabilities = capabilities,
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				diagnosticMode = "workspace",
				useLibraryCodeForTypes = true,
				typeCheckingMode = "basic",
			},
		},
	},
})

lspconfig.lua_ls.setup({
	capabilities = capabilities,
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = { globals = { "vim" } },
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false,
			},
			telemetry = { enable = false },
		},
	},
})

lspconfig.julials.setup({ capabilities = capabilities })
lspconfig.cmake.setup({ capabilities = capabilities })

lspconfig.ts_ls.setup({
	capabilities = capabilities,
	settings = {
		typescript = {
			inlayHints = {
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = false,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayVariableTypeHints = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayEnumMemberValueHints = true,
			},
		},
		javascript = {
			inlayHints = {
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = false,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayVariableTypeHints = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayEnumMemberValueHints = true,
			},
		},
	},
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
})

lspconfig.dockerls.setup({
	capabilities = capabilities,
	settings = {
		docker = {
			languageserver = {
				formatter = {
					ignoreMultilineInstructions = true,
				},
			},
		},
	},
})

lspconfig.glsl_analyzer.setup({
	capabilities = capabilities,
	filetypes = { "glsl", "vert", "frag", "geom", "tesc", "tese", "comp" },
})

lspconfig.html.setup({
	capabilities = capabilities,
	settings = {
		html = {
			format = {
				templating = true,
				wrapLineLength = 120,
				unformatted = "wbr",
				contentUnformatted = "pre,code,textarea",
				indentInnerHtml = true,
				preserveNewLines = true,
				maxPreserveNewLines = 2,
				indentHandlebars = false,
				endWithNewline = false,
				extraLiners = "head, body, /html",
				wrapAttributes = "auto",
			},
			hover = {
				documentation = true,
				references = true,
			},
		},
	},
})

lspconfig.jsonls.setup({
	capabilities = capabilities,
	settings = {
		json = {
			schemas = require("schemastore").json.schemas(),
			validate = { enable = true },
			format = { enable = true },
		},
	},
})

lspconfig.yamlls.setup({
	capabilities = capabilities,
	settings = {
		yaml = {
			schemas = {
				["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
				["https://json.schemastore.org/github-action.json"] = "/action.{yml,yaml}",
				["https://json.schemastore.org/ansible-stable-2.9.json"] = "/tasks/**/*.{yml,yaml}",
				["https://json.schemastore.org/prettierrc.json"] = "/.prettierrc.{yml,yaml}",
				["https://json.schemastore.org/kustomization.json"] = "/kustomization.{yml,yaml}",
				["https://json.schemastore.org/ansible-playbook.json"] = "*play*.{yml,yaml}",
				["https://json.schemastore.org/chart.json"] = "/Chart.{yml,yaml}",
				["https://json.schemastore.org/dependabot-v2.json"] = "/.github/dependabot.{yml,yaml}",
				["https://json.schemastore.org/gitlab-ci.json"] = "/.gitlab-ci.{yml,yaml}",
				["https://json.schemastore.org/bamboo-spec.json"] = "/bamboo-specs/*.{yml,yaml}",
				["https://json.schemastore.org/azure-pipelines.json"] = "/azure-pipelines.{yml,yaml}",
				["https://json.schemastore.org/docker-compose.json"] = "*docker-compose*.{yml,yaml}",
				["https://json.schemastore.org/appveyor.json"] = "/.appveyor.{yml,yaml}",
				["https://json.schemastore.org/travis.json"] = "/.travis.{yml,yaml}",
				["https://json.schemastore.org/cloudbuild.json"] = "/cloudbuild.{yml,yaml}",
			},
			format = { enable = true },
			validate = true,
			completion = true,
			hover = true,
		},
	},
})

-- Macro expansion function for C++
local function expand_macro()
	local params = vim.lsp.util.make_position_params()
	local clients = vim.lsp.get_clients({ bufnr = 0 })

	for _, client in ipairs(clients) do
		if client.name == "clangd" then
			client.request("textDocument/hover", params, function(err, result)
				if result and result.contents then
					-- Look for macro expansion in hover info
					local content = ""
					if type(result.contents) == "string" then
						content = result.contents
					elseif result.contents.value then
						content = result.contents.value
					elseif result.contents[1] and result.contents[1].value then
						content = result.contents[1].value
					end

					-- If it's a macro, show expansion in a floating window
					if content:match("^#define") or content:match("macro") then
						vim.lsp.util.open_floating_preview({ content }, "markdown", {
							border = "rounded",
							max_width = 80,
							max_height = 20,
						})
					else
						-- Fallback to regular code action
						vim.lsp.buf.code_action()
					end
				else
					-- Fallback to code action if no hover info
					vim.lsp.buf.code_action()
				end
			end, 0)
			return
		end
	end

	-- If no clangd client, just do code action
	vim.lsp.buf.code_action()
end

-- Enhanced nvim-cmp setup with better C++ macro support
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},

	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }),
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_locally_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.locally_jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),
	}),

	sources = cmp.config.sources({
		{ name = "nvim_lsp", priority = 1000 },
		{ name = "luasnip", priority = 750 },
		{ name = "buffer", priority = 500, keyword_length = 3 },
		{ name = "path", priority = 250 },
	}),

	formatting = {
		expandable_indicator = true,
		fields = { "kind", "abbr", "menu" },
		format = function(entry, vim_item)
			local kind_icons = {
				Text = "",
				Method = "󰆧",
				Function = "󰊕",
				Constructor = "",
				Field = "󰇽",
				Variable = "󰂡",
				Class = "󰠱",
				Interface = "",
				Module = "",
				Property = "󰜢",
				Unit = "",
				Value = "󰎠",
				Enum = "",
				Keyword = "󰌋",
				Snippet = "",
				Color = "󰏘",
				File = "󰈙",
				Reference = "",
				Folder = "󰉋",
				EnumMember = "",
				Constant = "󰏿",
				Struct = "",
				Event = "",
				Operator = "󰆕",
				TypeParameter = "󰅲",
				Macro = "󰬔", -- Special icon for macros
			}

			vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)
			vim_item.menu = ({
				nvim_lsp = "[LSP]",
				luasnip = "[Snippet]",
				buffer = "[Buffer]",
				path = "[Path]",
			})[entry.source.name]

			return vim_item
		end,
	},

	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},

	experimental = {
		ghost_text = true,
	},
})

-- LSP key mappings
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		local opts = { buffer = ev.buf }

		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "<leader>g", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "<leader>G", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		-- vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
		vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
		vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
		vim.keymap.set("n", "<leader>t", vim.lsp.buf.type_definition, opts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "<leader>R", vim.lsp.buf.references, opts)
		vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
		vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)

		-- Formatting
		vim.keymap.set("n", "<leader>f", function()
			vim.lsp.buf.format({ async = true })
		end, opts)

		-- Alternative file switching using existing ClangdSwitchSourceHeader
		vim.keymap.set("n", "<leader>h", "<cmd>ClangdSwitchSourceHeader<cr>", opts)

		-- Macro expansion and code actions
		vim.keymap.set("n", "<F2>", expand_macro, opts)
	end,
})

-- Enhanced diagnostic configuration
vim.diagnostic.config({
	virtual_text = {
		spacing = 4,
		source = "always", -- Changed from "if_many" to "always"
		prefix = "●",
		format = function(diagnostic)
			if diagnostic.code then
				return string.format("%s [%s]", diagnostic.message, diagnostic.code)
			end
			return diagnostic.message
		end,
	},
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = {
		focusable = true,
		style = "minimal",
		border = "rounded",
		source = "always",
		header = "",
		prefix = "",
		format = function(diagnostic)
			if diagnostic.code then
				return string.format(
					"%s [%s]\nSource: %s",
					diagnostic.message,
					diagnostic.code,
					diagnostic.source or "unknown"
				)
			end
			return diagnostic.message
		end,
	},
})

-- Diagnostic signs
local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

-- LuaSnip configuration (enhanced snippet support)
require("luasnip.loaders.from_vscode").lazy_load()
require("luasnip.loaders.from_snipmate").lazy_load()

local ls = require("luasnip")
ls.config.set_config({
	history = true,
	updateevents = "TextChanged,TextChangedI",
	enable_autosnippets = true,
	ext_opts = {
		[require("luasnip.util.types").choiceNode] = {
			active = {
				virt_text = { { "choiceNode", "Comment" } },
			},
		},
	},
})

-- Snippet keymaps
vim.keymap.set({ "i" }, "<C-K>", function()
	ls.expand()
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-L>", function()
	ls.jump(1)
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-J>", function()
	ls.jump(-1)
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-E>", function()
	if ls.choice_active() then
		ls.change_choice(1)
	end
end, { silent = true })

-- Debugger setup
require("dapui").setup()
require("nvim-dap-virtual-text").setup()

local dap = require("dap")
dap.adapters.cppdbg = {
	id = "cppdbg",
	type = "executable",
	command = "/home/elias/Downloads/ms-vscode.cpptools-1.22.2@linux-x64/extension/debugAdapters/bin/OpenDebugAD7",
}

dap.configurations.cpp = {
	{
		name = "Launch file",
		type = "cppdbg",
		request = "launch",
		program = function()
			return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
		end,
		cwd = "${workspaceFolder}",
		stopAtEntry = false,
		setupCommands = {
			{
				text = "-enable-pretty-printing",
				description = "enable pretty printing",
				ignoreFailures = false,
			},
		},
	},
	{
		name = "Attach to gdbserver :1234",
		type = "cppdbg",
		request = "launch",
		MIMode = "gdb",
		miDebuggerServerAddress = "localhost:1234",
		miDebuggerPath = "/usr/bin/gdb",
		cwd = "${workspaceFolder}",
		program = function()
			return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
		end,
	},
}
dap.configurations.c = dap.configurations.cpp
dap.configurations.rust = dap.configurations.cpp
dap.configurations.cuda = dap.configurations.cpp

local dapui = require("dapui")
dap.listeners.before.attach.dapui_config = function()
	dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
	dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
	dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
	dapui.close()
end

-- Treesitter configuration
require("nvim-treesitter.configs").setup({
	ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "python", "julia" },
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		disable = function(lang, buf)
			local max_filesize = 100 * 1024 -- 100 KB
			local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end,
		additional_vim_regex_highlighting = false,
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gnn",
			node_incremental = "grn",
			scope_incremental = "grc",
			node_decremental = "grm",
		},
	},
})

-- Formatter configuration
require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "isort", "black" },
		rust = { "rustfmt", lsp_format = "fallback" },
		-- javascript = { "biome", "prettierd", "prettier", stop_after_first = true },
		javascript = { "biome", stop_after_first = true },
		typescript = { "biome", stop_after_first = true },
		javascriptreact = { "biome", stop_after_first = true },
		typescriptreact = { "biome", stop_after_first = true },
		json = { "biome" },
		cpp = { "clang-format" },
		cuda = { "clang-format" },
		c = { "clang-format" },
		glsl = { "clang-format" },
		sh = { "shfmt" },
		bash = { "shfmt" },
		zsh = { "shfmt" },
		xml = { "xmlformat" },
	},
	format_on_save = {
		timeout_ms = 5500,
		lsp_format = "fallback",
	},
})

require("nvim-surround").setup({})

local telescope = require("telescope")
local lga_actions = require("telescope-live-grep-args.actions")

telescope.setup({
	defaults = {
		mappings = {
			i = {
				["<C-c>"] = require("telescope.actions").close,
			},
		},
	},
	extensions = {
		media_files = {
			filetypes = { "png", "webp", "jpg", "jpeg", "gif", "pdf", "mp4", "webm", "mp3" },
			find_cmd = "rg",
		},
		live_grep_args = {
			auto_quoting = true,
			mappings = {
				i = {
					["<C-k>"] = lga_actions.quote_prompt(),
					["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
					["<C-space>"] = lga_actions.to_fuzzy_refine,
				},
			},
		},
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		},
	},
})

-- Load extensions
telescope.load_extension("media_files")
telescope.load_extension("live_grep_args")
telescope.load_extension("fzf")
vim.keymap.set("n", "<leader>fs", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
vim.keymap.set("n", "<leader>fe", "<cmd>Telescope diagnostics<cr>")

vim.api.nvim_create_autocmd("CompleteDone", {
	callback = function()
		local info = vim.fn.complete_check()
		if info == 0 then
			vim.cmd("silent! pclose")
		end
	end,
})

require("gitsigns").setup()
require("diffview").setup()
