require'lspconfig'.pyright.setup{}
-- require'lspconfig'.clangd.setup{}
require'lspconfig'.julials.setup{}
require'lspconfig'.lua_ls.setup({})
require'lspconfig'.cmake.setup{}

-- local lsp_zero = require('lsp-zero')

 -- lsp_zero.on_attach(function(client, bufnr)
 --     local opts = {buffer = bufnr, remap = false}
 -- 
 --     vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
 --     vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
 --     vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
 --     vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
 --     vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
 --     vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
 --     vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
 --     vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
 --     vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
 --     vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
 -- end)
 -- 
 -- require('mason').setup({})
 -- require('mason-lspconfig').setup({
 --     ensure_installed = {'lua_ls', 'julials', 'pyright', 'tsserver', 'rust_analyzer'},
 --     handlers = {
 --         lsp_zero.default_setup,
 --         lua_ls = function()
 --             local lua_opts = lsp_zero.nvim_lua_ls()
 --             require('lspconfig').lua_ls.setup(lua_opts)
 --         end,
 --     }
 -- })

-- local cmp = require('cmp')
-- local cmp_select = {behavior = cmp.SelectBehavior.Select}

 -- cmp.setup({
 --     sources = {
 --         {name = 'path'},
 --         {name = 'nvim_lsp'},
 --         {name = 'nvim_lua'},
 --     },
 --     formatting = lsp_zero.cmp_format(),
 --     mapping = cmp.mapping.preset.insert({
 --         ['<CR>'] = cmp.mapping.confirm({select = true}),
 --         ['<Tab>'] = cmp.cmp_action.luasnip_supertab(),
 --         ['<S-Tab>'] = cmp.cmp_action.luasnip_shift_supertab(),
 --         ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
 --         ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
 --         ['<C-y>'] = cmp.mapping.confirm({ select = true }),
 --         ['<C-Space>'] = cmp.mapping.complete(),
 --     }),
 -- })

require'nvim-treesitter.configs'.setup {
    -- A list of parser names, or "all" (the five listed parsers should always be installed)
    ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },

    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,

    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,

    -- List of parsers to ignore installing (or "all")
    ignore_install = { "javascript" },

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
}

