require("lspconfig").pyright.setup({})
-- require'lspconfig'.clangd.setup{}
require("lspconfig").julials.setup({})
require("lspconfig").lua_ls.setup({})
require("lspconfig").cmake.setup({})
require 'lspconfig'.julials.setup {}

require("neodev").setup({
    library = { plugins = { "nvim-dap-ui" }, types = true },
})

-- Debugger
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
require("dap.ext.vscode").load_launchjs(nil, { cppdbg = { "typescript" } })

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

-- Syntax highlighting
require("nvim-treesitter.configs").setup({
    -- A list of parser names, or "all" (the five listed parsers should always be installed)
    ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },

    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,

    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,

    -- List of parsers to ignore installing (or "all")
    -- ignore_install = { "javascript" },

    ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
    -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

    highlight = {
        enable = true,

        -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
        -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
        -- the name of the parser)
        -- list of language that will be disabled
        disable = { "c", "rust" },
        -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
        disable = function(lang, buf)
            local max_filesize = 100 * 1024 -- 100 KB
            local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
                return true
            end
        end,

        -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
        -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
        -- Using this option may slow down your editor, and you may see some duplicate highlights.
        -- Instead of true it can also be a list of languages
        additional_vim_regex_highlighting = false,
    },
})

-- Formatters
require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        -- Conform will run multiple formatters sequentially
        python = { "isort", "black" },
        -- You can customize some of the format options for the filetype (:help conform.format)
        rust = { "rustfmt", lsp_format = "fallback" },
        -- JavaScript-family
        javascript = { "biome", "prettierd", "prettier", stop_after_first = true },
        typescript = { "biome", "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },
        json = { "biome" },
        -- C-family
        cpp = { "clang-format" },
        cuda = { "clang-format" },
        c = { "clang-format" },
        -- Shell scripts
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        xml = { "xmlformat" },
    },
    format_on_save = {
        -- These options will be passed to conform.format()
        timeout_ms = 5500,
        lsp_format = "fallback",
    },
})
require("conform").formatters.xmlformat = {
    prepend_args = { "--blanks", "--selfclose" },
    -- The base args are { "-filename", "$FILENAME" } so the final args will be
    -- { "-i", "2", "-filename", "$FILENAME" }
}

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

require("nvim-surround").setup({})

require 'telescope'.setup {
    extensions = {
        media_files = {
            -- filetypes whitelist
            -- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
            filetypes = { "png", "webp", "jpg", "jpeg" },
            -- find command (defaults to `fd`)
            find_cmd = "rg"
        }
    },
}
require('telescope').load_extension('media_files')

-- LuaSnip
require("luasnip.loaders.from_vscode").lazy_load()

local ls = require("luasnip")
ls.config.set_config({
    history = true,
    updateevents = "TextChanged,TextChangedI",
    enable_autosnippets = true,
})

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

-- Configure nvim-cmp
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },

    -- Configure completion sources with priority
    sources = cmp.config.sources({
        { name = "ycm" },     -- YCM completions with highest priority
        { name = "luasnip" }, -- Snippets next
        { name = "buffer" },  -- Buffer words
        { name = "path" },    -- File paths
    }),

    -- Key mappings
    mapping = {
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.close(),
        ["<CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
        }),
        ["<Tab>"] = function(fallback)
            if cmp.visible() then
                cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
            else
                fallback()
            end
        end,
        ["<S-Tab>"] = function(fallback)
            if cmp.visible() then
                cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end,
    },

    -- Appearance
    formatting = {
        format = function(entry, vim_item)
            vim_item.menu = ({
                ycm = "[YCM]",
                luasnip = "[Snippet]",
                buffer = "[Buffer]",
                path = "[Path]",
            })[entry.source.name]
            return vim_item
        end,
    },
})

-- YCM configuration
vim.g.ycm_key_list_select_completion = { "<C-n>" }
vim.g.ycm_key_list_previous_completion = { "<C-p>" }
vim.g.ycm_auto_trigger = 1
