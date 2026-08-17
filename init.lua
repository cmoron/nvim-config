-- ============================
-- Configuration Neovim
-- Basée sur la config Vim personnelle
-- ============================

-- ============================
-- 1. Settings de base
-- ============================

-- Leader key
vim.g.mapleader = " " -- Espace comme leader
vim.g.maplocalleader = " " -- Espace comme localleader

-- Options générales
vim.opt.number = true -- Numéros de ligne
vim.opt.relativenumber = true -- Numéros relatifs
vim.opt.cursorline = true -- Highlight ligne courante
vim.opt.scrolloff = 7 -- Garde 7 lignes visibles en haut/bas
vim.opt.wrap = true -- Wrap automatique
vim.opt.linebreak = true -- Break sur les mots
vim.opt.shortmess:append("I") -- Désactiver l'écran d'intro au démarrage

-- Indentation
vim.opt.autoindent = true
vim.opt.expandtab = true -- Utiliser des espaces au lieu de tabs
vim.opt.tabstop = 4 -- Tab = 4 espaces
vim.opt.shiftwidth = 4 -- Indent = 4 espaces
vim.opt.smartindent = true -- Indentation intelligente

-- Recherche
vim.opt.ignorecase = true -- Ignorer la casse
vim.opt.smartcase = true -- Sauf si majuscule dans la recherche
vim.opt.hlsearch = true -- Highlight les résultats
vim.opt.incsearch = true -- Recherche incrémentale

-- Interface
vim.opt.termguicolors = true -- Couleurs 24-bit
vim.opt.background = "dark" -- Thème sombre
vim.opt.showmode = false -- Masquer le mode (affiché par lualine)
vim.opt.showcmd = true -- Afficher la commande en cours
vim.opt.ruler = true -- Afficher la position du curseur
vim.opt.list = true -- Afficher les caractères invisibles
vim.opt.listchars = { tab = "→ ", trail = "·", extends = ">", precedes = "<" }
vim.o.winborder = "rounded" -- Bordures arrondies pour les floats

-- Comportement
vim.opt.hidden = true -- Buffers cachés
vim.opt.backup = false -- Pas de backup
vim.opt.writebackup = false -- Pas de writebackup
vim.opt.swapfile = false -- Pas de swapfile
vim.opt.timeoutlen = 500 -- Délai pour les mappings
vim.opt.history = 1000 -- Historique de 1000 commandes
vim.opt.undolevels = 150 -- 150 niveaux d'undo
vim.opt.completeopt = "menu,menuone,noselect" -- Options de complétion
vim.opt.wildmenu = true -- Menu de complétion pour les commandes
vim.opt.wildmode = "longest:list,full" -- Mode de complétion pour les commandes
vim.opt.autoread = true -- Auto-reload fichiers modifiés

-- Encoding
vim.opt.encoding = "utf-8" -- Encoding interne
vim.opt.fileencoding = "utf-8" -- Encoding des fichiers

-- Désactiver le folding
vim.opt.foldenable = false

-- Diagnostics : pas de virtual text (tiny-inline-diagnostic s'en charge),
-- signes dans la gouttière
vim.diagnostic.config({
    virtual_text = false,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "●",
            [vim.diagnostic.severity.WARN] = "●",
            [vim.diagnostic.severity.INFO] = "●",
            [vim.diagnostic.severity.HINT] = "●",
        },
    },
})

-- Clipboard WSL2 : évite le freeze OSC 52 (terminal ne répond pas)
if vim.fn.has("wsl") == 1 then
    vim.g.clipboard = {
        name = "WslClipboard",
        copy = {
            ["+"] = "clip.exe",
            ["*"] = "clip.exe",
        },
        paste = {
            ["+"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).ToString().Replace("`r`n", "`n").Replace("`r", "`n"))',
            ["*"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).ToString().Replace("`r`n", "`n").Replace("`r", "`n"))',
        },
        cache_enabled = 0,
    }
end

-- Désactiver les warnings de deprecation (temporaire)
vim.deprecate = function() end

-- ============================
-- 2. Autocmds (indentation par filetype)
-- ============================

-- Indentation spécifique pour certains filetypes
local function set_indent(pattern, ts, sw)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = pattern,
        callback = function()
            vim.opt_local.tabstop = ts
            vim.opt_local.shiftwidth = sw
            vim.opt_local.expandtab = true
        end,
    })
end

-- 2 espaces pour HTML, JS, Vue, Svelte
set_indent({ "html", "javascript", "vue", "svelte" }, 2, 2)

-- Go : tabs (convention gofmt)
vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function()
        vim.opt_local.expandtab = false
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
    end,
})

-- Auto-reload fichiers modifiés (check au focus/buffer change)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    pattern = "*",
    callback = function()
        if vim.fn.mode() ~= "c" then
            vim.cmd("checktime")
        end
    end,
})

-- Notification quand un fichier est modifié
vim.api.nvim_create_autocmd("FileChangedShellPost", {
    pattern = "*",
    callback = function()
        vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
    end,
})

-- ============================
-- 3. Mappings
-- ============================

-- Helper pour les mappings
local function map(mode, lhs, rhs, opts)
    local options = { noremap = true, silent = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.keymap.set(mode, lhs, rhs, options)
end

-- Scroll plus rapide
map("n", "J", "2<C-e>")
map("n", "K", "3<C-y>")
map("v", "J", "2<C-e>")
map("v", "K", "3<C-y>")

-- Navigation buffers
map("n", "<Tab>", ":bnext<CR>")
map("n", "<S-Tab>", ":bprevious<CR>")
map("n", "<S-F12>", ":bnext<CR>")
map("n", "<S-F11>", ":bprevious<CR>")

-- Ferme le buffer courant sans toucher à la fenêtre. `:bdelete` referme le
-- split quand le buffer n'est affiché qu'une fois ; Snacks conserve le layout.
vim.keymap.set("n", "<leader>x", function()
    Snacks.bufdelete()
end, { silent = true, desc = "Fermer le buffer courant" })

-- Indent/Dedent en mode insertion
map("i", "<S-Tab>", "<C-o><<")

-- Commentaires natifs (Neovim 0.10+ : gcc / gc), garde l'ancien raccourci
vim.keymap.set("n", "<leader>c<leader>", "gcc", { remap = true, silent = true, desc = "Toggle comment line" })
vim.keymap.set("v", "<leader>c<leader>", "gc", { remap = true, silent = true, desc = "Toggle comment selection" })

-- Reload config
map("n", "<Leader><CR>", ":source ~/.config/nvim/init.lua<CR>", { desc = "Reload config" })

-- ============================
-- 4. Bootstrap lazy.nvim
-- ============================

-- Installer lazy.nvim si pas déjà fait
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

-- Ajouter lazy.nvim au runtime path
vim.opt.rtp:prepend(lazypath)

-- ============================
-- 5. Plugins
-- ============================

require("lazy").setup({
    -- Colorscheme (port Lua : définit NormalFloat et les groupes treesitter,
    -- contrairement à morhetz/gruvbox qui laissait un fond noir sur les floats)
    {
        "ellisonleao/gruvbox.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("gruvbox").setup({})
            vim.cmd([[colorscheme gruvbox]])
        end,
    },

    -- Snacks (picker + explorer + indent guides + lazygit)
    {
        "folke/snacks.nvim",
        lazy = false,
        priority = 1000,
        opts = {
            picker = {
                enabled = true,
                sources = {
                    files = {
                        hidden = true, -- Afficher les fichiers cachés (respecte .gitignore)
                    },
                },
            },
            explorer = { enabled = true },
            indent = { enabled = true },
            lazygit = { enabled = true },
        },
        keys = {
            -- Picker (remplace Telescope)
            { "<C-p>", function() Snacks.picker.files() end, desc = "Find files" },
            { "<leader>p", function() Snacks.picker.buffers() end, desc = "Find buffers" },
            { "<leader>g", function() Snacks.picker.grep() end, desc = "Live grep" },
            { "<leader>fh", function() Snacks.picker.help() end, desc = "Help tags" },
            { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
            { "<leader>fr", function() Snacks.picker.lsp_references() end, desc = "LSP references" },
            { "<leader>fs", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
            -- Buffers (remplace BufExplorer)
            { "<F12>", function() Snacks.picker.buffers() end, desc = "Buffer list" },
            { "<leader>b", function() Snacks.picker.buffers() end, desc = "Buffer list" },
            -- Explorer (remplace NvimTree)
            { "<F9>", function() Snacks.explorer() end, desc = "Toggle explorer" },
            {
                "<leader><Tab>",
                function()
                    local ft = vim.bo.filetype
                    if ft == "snacks_picker_list" or ft == "snacks_picker_input" then
                        -- Dans l'explorer : retourner au fichier
                        local explorer = Snacks.picker.get({ source = "explorer" })[1]
                        if explorer and vim.api.nvim_win_is_valid(explorer.main) then
                            vim.api.nvim_set_current_win(explorer.main)
                        end
                    else
                        -- Ailleurs : révéler le fichier dans l'explorer
                        Snacks.explorer.reveal()
                    end
                end,
                desc = "Explorer: reveal / retour fichier",
            },
            -- LazyGit
            { "<leader>lg", function() Snacks.lazygit() end, desc = "LazyGit" },
        },
    },

    -- Bufferline (onglets de buffers en haut)
    {
        "akinsho/bufferline.nvim",
        version = "*",
        dependencies = "nvim-tree/nvim-web-devicons",
        lazy = false, -- Charger au démarrage
        opts = {
            options = {
                mode = "buffers",
                separator_style = "slant",
                always_show_bufferline = true,
                show_buffer_close_icons = false,
                show_close_icon = false,
                offsets = {
                    {
                        filetype = "snacks_picker_list", -- Explorer Snacks (ex-NvimTree)
                        text = "File Explorer",
                        text_align = "center",
                        separator = true,
                    },
                },
            },
        },
    },

    -- Lualine (statusline)
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                theme = "gruvbox",
            },
        },
    },

    -- Git signs (hunks dans la gouttière)
    {
        "lewis6991/gitsigns.nvim",
        opts = {
            signs = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "_" },
                topdelete = { text = "‾" },
                changedelete = { text = "~" },
            },
        },
    },

    -- Fugitive (git dans le buffer : :Git blame, :Gdiffsplit...)
    "tpope/vim-fugitive",

    -- Leap (navigation rapide, remplace vim-sneak)
    {
        url = "https://codeberg.org/andyg/leap.nvim",
        keys = {
            { "s", "<Plug>(leap)", mode = { "n", "x", "o" }, desc = "Leap" },
            { "S", "<Plug>(leap-from-window)", mode = "n", desc = "Leap from window" },
        },
    },

    -- Diagnostics inline (ligne du curseur, preset fantôme)
    {
        "rachartier/tiny-inline-diagnostic.nvim",
        event = "VeryLazy",
        opts = {
            preset = "ghost",
            options = {
                multilines = { enabled = true },
            },
        },
    },

    -- Autopairs (fermeture automatique des parenthèses, quotes, etc.)
    -- L'intégration avec la complétion est gérée par blink.cmp (auto_brackets)
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {},
    },

    -- Which-key (affiche les raccourcis disponibles)
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "modern",
        },
        config = function(_, opts)
            local wk = require("which-key")
            wk.setup(opts)

            -- Groupes de raccourcis
            wk.add({
                { "<leader>f", group = "Find/Format" },
                { "<leader>c", group = "Comment" },
                { "<leader>l", group = "LazyGit" },
            })
        end,
    },

    -- Conform (formatage de code)
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        keys = {
            {
                "<leader>f",
                function()
                    -- ["*"] donne trim_whitespace à tout buffer, donc conform
                    -- considère qu'un formatter existe toujours et "fallback"
                    -- ne se déclenche jamais (cf. conform/init.lua, branche LSP
                    -- conditionnée à `not any_formatters`). On délègue donc au
                    -- serveur LSP dès qu'un filetype n'a pas de formatter dédié
                    -- — valable pour tout langage, sans liste à maintenir.
                    local conform = require("conform")
                    local has_own = conform.formatters_by_ft[vim.bo.filetype] ~= nil
                    conform.format({
                        async = true,
                        lsp_format = has_own and "never" or "prefer",
                    })
                end,
                mode = "",
                desc = "Format buffer",
            },
        },
        opts = {
            formatters_by_ft = {
                -- Trailing whitespace sur tous les filetypes
                ["*"] = { "trim_whitespace" },
                lua = { "stylua" },
                python = { "ruff_fix", "ruff_format" },
                javascript = { "prettier" },
                typescript = { "prettier" },
                svelte = { "prettier" },
                html = { "prettier" },
                css = { "prettier" },
                json = { "prettier" },
                yaml = { "prettier" },
                markdown = { "prettier" },
                -- xmllint (paquet : libxml2-utils / libxml2)
                xml = { "xmllint" },
                -- Go : goimports gère l'import auto + format ; gofmt en fallback
                go = { "goimports", "gofmt" },
            },
            -- Fallback sur LSP si pas de formatter configuré
            format_on_save = false, -- Pas de format automatique
            formatters = {
                xmllint = {
                    command = "xmllint",
                    args = { "--format", "-" },
                    stdin = true,
                },
            },
        },
    },

    -- Colorizer (affiche les couleurs CSS) - fork NvChad maintenu
    {
        "NvChad/nvim-colorizer.lua",
        opts = {
            filetypes = { "*" }, -- Activer pour tous les filetypes
            user_default_options = {
                RGB = true, -- #RGB
                RRGGBB = true, -- #RRGGBB
                names = true, -- "red", "blue", etc.
                RRGGBBAA = true, -- #RRGGBBAA
                rgb_fn = true, -- rgb(), rgba()
                hsl_fn = true, -- hsl(), hsla()
                css = true, -- CSS colors
                css_fn = true, -- CSS functions
            },
        },
    },

    -- Treesitter (syntaxe moderne) - branche main (master est archivée depuis mai 2025)
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSUpdate",
        lazy = false,
        config = function()
            require("nvim-treesitter").setup()
            -- Installation incrémentale : ne compile que les parsers manquants
            -- (nécessite le CLI tree-sitter : brew install tree-sitter)
            -- Exposée en vim.g : l'export offline doit attendre la fin des
            -- compilations, et dupliquer la liste la ferait dériver.
            vim.g.ts_parsers = {
                "lua",
                "vim",
                "vimdoc",
                "javascript",
                "typescript",
                "html",
                "css",
                "python",
                "java",
                "go",
                "gomod",
                "gosum",
                "bash",
                "json",
                "yaml",
                "toml",
                "xml",
                "markdown",
                "markdown_inline",
                "rust",
                "svelte",
                "vue",
                "regex",
            }
            require("nvim-treesitter").install(vim.g.ts_parsers)
            -- Le highlight se lance au FileType (pas de module configs sur main)
            vim.api.nvim_create_autocmd("FileType", {
                callback = function()
                    pcall(vim.treesitter.start)
                end,
            })
        end,
    },

    -- blink.cmp (autocomplétion : remplace nvim-cmp + LuaSnip + sources)
    {
        "saghen/blink.cmp",
        version = "*", -- Binaire fuzzy précompilé, pas besoin de cargo
        dependencies = { "rafamadriz/friendly-snippets" },
        opts = {
            keymap = {
                preset = "default",
                -- Tab : naviguer OU sauter dans le snippet
                ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                ["<CR>"] = { "select_and_accept", "fallback" },
                ["<C-Space>"] = { "show", "fallback" },
                ["<C-e>"] = { "cancel", "fallback" },
            },
            completion = {
                accept = {
                    auto_brackets = { enabled = true }, -- Intégration autopairs native
                },
                documentation = { auto_show = true },
            },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },
        },
        opts_extend = { "sources.default" },
    },

    -- Java LSP (nvim-jdtls gère les spécificités de jdtls : workspace, project detection)
    {
        "mfussenegger/nvim-jdtls",
        ft = "java", -- Chargement paresseux : uniquement sur les fichiers Java
        dependencies = { "mfussenegger/nvim-dap" },
    },

    -- Debug. Les raccourcis sont globaux et non attachés au filetype : pendant
    -- une session, le curseur vit dans les panneaux dap-ui, pas dans le .java.
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
        },
        keys = {
            { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug: breakpoint" },
            {
                "<leader>dB",
                function()
                    require("dap").set_breakpoint(vim.fn.input("Condition du breakpoint : "))
                end,
                desc = "Debug: breakpoint conditionnel",
            },
            { "<F5>", function() require("dap").continue() end, desc = "Debug: lancer / continuer" },
            { "<F10>", function() require("dap").step_over() end, desc = "Debug: pas au-dessus" },
            { "<F11>", function() require("dap").step_into() end, desc = "Debug: pas dedans" },
            { "<leader>do", function() require("dap").step_out() end, desc = "Debug: sortir" },
            { "<leader>dt", function() require("dap").terminate() end, desc = "Debug: arrêter" },
            { "<leader>du", function() require("dapui").toggle() end, desc = "Debug: panneaux" },
        },
        config = function()
            local dap, dapui = require("dap"), require("dapui")
            dapui.setup()

            -- Signes par défaut : un « B » en highlight SignColumn, donc gris sur
            -- gris, illisible à côté des ● colorés des diagnostics. La ligne
            -- d'arrêt est surlignée entièrement, comme dans un IDE.
            vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
            vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
            vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint" })
            vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })

            local function snacks_box()
                for _, w in ipairs(vim.api.nvim_list_wins()) do
                    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_layout_box" then
                        return w
                    end
                end
            end

            -- Largeur de l'explorer relevée au démarrage de la session, avant
            -- qu'un seul panneau ne s'ouvre : c'est la valeur de référence.
            local explorer_width
            dap.listeners.after.event_initialized["dapui"] = function()
                local w = snacks_box()
                explorer_width = w and vim.api.nvim_win_get_width(w)
            end

            -- Les panneaux n'apparaissent qu'à un arrêt réel, pas au démarrage :
            -- un test qui passe au vert ne doit pas faire clignoter l'écran.
            dap.listeners.after.event_stopped["dapui"] = function()
                dapui.open()
            end

            -- En se fermant, nvim-dap-ui rend ses colonnes à la fenêtre voisine
            -- et la boîte de layout de snacks les absorbe : sans ça l'explorer
            -- gagne une quarantaine de colonnes à chaque session.
            local function close()
                dapui.close()
                local w = snacks_box()
                if w and explorer_width then
                    vim.api.nvim_win_set_width(w, explorer_width)
                end
                explorer_width = nil
            end
            dap.listeners.before.event_terminated["dapui"] = close
            dap.listeners.before.event_exited["dapui"] = close
        end,
    },

    {
        "neovim/nvim-lspconfig",
        dependencies = { "saghen/blink.cmp" },
        config = function()
            -- Capabilities pour blink.cmp (meilleure autocomplétion)
            local capabilities = require("blink.cmp").get_lsp_capabilities()

            -- Appliquer les capabilities à tous les serveurs LSP
            vim.lsp.config("*", { capabilities = capabilities })

            -- Config spécifique à ruff : désactiver le hover (conflit avec pyright)
            vim.lsp.config("ruff", {
                on_attach = function(client)
                    client.server_capabilities.hoverProvider = false
                end,
            })

            -- Config spécifique à pyright : pointer l'interpréteur du projet.
            -- Sans cela pyright prend le `python` du PATH et signale en erreur
            -- tous les imports de dépendances, sauf à lancer nvim depuis un
            -- venv activé. `.venv` à la racine est la convention d'uv.
            -- Écrit dans on_init, pas dans before_init : le client fige sa copie
            -- de `settings` à sa création, avant que before_init ne tourne, donc
            -- y réassigner une table n'a aucun effet.
            vim.lsp.config("pyright", {
                on_init = function(client)
                    -- root_dir est nil sur un fichier ouvert hors projet
                    if not client.root_dir then
                        return
                    end
                    local python = client.root_dir .. "/.venv/bin/python"
                    if vim.uv.fs_stat(python) then
                        client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
                            python = { pythonPath = python },
                        })
                        client:notify("workspace/didChangeConfiguration", { settings = client.settings })
                    end
                end,
            })

            -- Config spécifique à lua_ls : connaître l'API vim.* (complétion + doc)
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        workspace = {
                            checkThirdParty = false,
                            library = vim.api.nvim_get_runtime_file("", true),
                        },
                    },
                },
            })

            -- Activer tous les serveurs LSP
            vim.lsp.enable({ "pyright", "bashls", "ts_ls", "svelte", "rust_analyzer", "ruff", "lua_ls", "gopls" })
        end,
    },
})

-- ============================
-- LSP Configuration (Neovim 0.11+)
-- ============================

-- Keymaps LSP (adaptés AZERTY)
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local opts = { buffer = ev.buf, silent = true }

        -- NAVIGATION
        -- gd = Go to Definition (aller à la définition)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)

        -- gD = Go to Declaration (aller à la déclaration)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

        -- grr = Find References (trouver toutes les références)
        -- (raccourci par défaut de Neovim 0.11)

        -- gri = Go to Implementation (aller à l'implémentation)
        -- (raccourci par défaut de Neovim 0.11)

        -- gO = Document symbols (plan du fichier)
        -- (raccourci par défaut de Neovim 0.11)

        -- DOCUMENTATION
        -- H = Hover (afficher la documentation) - remplace K
        vim.keymap.set("n", "H", vim.lsp.buf.hover, opts)

        -- DIAGNOSTICS (adaptés AZERTY, sans [])
        -- <leader>n = Diagnostic suivant (remplace ]d)
        vim.keymap.set("n", "<leader>n", vim.diagnostic.goto_next, opts)

        -- <leader>N = Diagnostic précédent (remplace [d)
        vim.keymap.set("n", "<leader>N", vim.diagnostic.goto_prev, opts)

        -- <leader>e = Afficher l'erreur en float
        vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)

        -- ACTIONS
        -- grn ou <leader>rn = Rename (renommer)
        -- (grn est le raccourci par défaut de Neovim 0.11)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

        -- gra ou <leader>ca = Code Action (actions de code)
        -- (gra est le raccourci par défaut de Neovim 0.11)
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
    end,
})

-- ============================
-- Java (jdtls via nvim-jdtls)
-- ============================

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        local jdtls = require("jdtls")

        -- Chemin vers jdtls (installé dans ~/.local/share/jdtls/)
        local jdtls_dir = vim.fn.expand("~/.local/share/jdtls")

        -- Launcher jar (point d'entrée de jdtls)
        local launcher = vim.fn.glob(jdtls_dir .. "/plugins/org.eclipse.equinox.launcher_*.jar")
        if launcher == "" then
            vim.notify("jdtls: launcher jar introuvable dans " .. jdtls_dir, vim.log.levels.ERROR)
            return
        end

        -- Config native selon l'OS
        local config_dir = jdtls_dir .. (vim.fn.has("macunix") == 1 and "/config_mac" or "/config_linux")

        -- Workspace isolé par projet (évite les conflits entre projets)
        local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
        local workspace_dir = vim.fn.expand("~/.cache/jdtls/workspaces/") .. project_name

        -- Capabilities depuis blink.cmp
        local capabilities = require("blink.cmp").get_lsp_capabilities()

        -- Adaptateur de debug et lanceur de tests, posés par scripts/install.sh.
        -- Absents = LSP seul, sans breakpoints ni tests : on ne casse pas
        -- l'édition pour autant.
        local debug_bundles =
            vim.fn.glob(vim.fn.expand("~/.local/share/java-debug") .. "/*.jar", true, true)

        -- Le lanceur embarque deux jars qui ne sont pas des bundles OSGi ;
        -- jdtls les rejette au démarrage si on les lui passe.
        local test_bundles = vim.tbl_filter(function(jar)
            return not jar:match("test%.runner%-jar%-with%-dependencies%.jar$") and not jar:match("jacocoagent%.jar$")
        end, vim.fn.glob(vim.fn.expand("~/.local/share/java-test") .. "/*.jar", true, true))

        local bundles = vim.list_extend(vim.list_slice(debug_bundles), test_bundles)

        jdtls.start_or_attach({
            cmd = {
                "java",
                "-Declipse.application=org.eclipse.jdt.ls.core.id1",
                "-Dosgi.bundles.defaultStartLevel=4",
                "-Declipse.product=org.eclipse.jdt.ls.core.product",
                "-Dlog.level=ALL",
                "-Xmx1g",
                "--add-modules=ALL-SYSTEM",
                "--add-opens", "java.base/java.util=ALL-UNNAMED",
                "--add-opens", "java.base/java.lang=ALL-UNNAMED",
                "-jar", launcher,
                "-configuration", config_dir,
                "-data", workspace_dir,
            },
            root_dir = jdtls.setup.find_root({ ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),
            capabilities = capabilities,
            -- Les jars s'enfichent dans jdtls : c'est le serveur lui-même qui
            -- expose ensuite l'adaptateur et le lanceur, pas un exécutable séparé.
            init_options = { bundles = bundles },
            on_attach = function()
                if #debug_bundles == 0 then
                    return
                end
                jdtls.setup_dap({ hotcodereplace = "auto" })
                -- Demande au serveur les classes à `main` du projet et en fait
                -- des configurations dap prêtes à lancer.
                require("jdtls.dap").setup_dap_main_class_configs()
            end,
            settings = {
                java = {
                    format = { enabled = true },
                    saveActions = { organizeImports = true },
                    completion = { favoriteStaticMembers = {} },
                    sources = { organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 } },
                },
            },
        })

        -- Lancer les tests. Buffer-local, contrairement aux touches de debug :
        -- ces gestes n'ont de sens que dans un .java. Les deux passent par dap,
        -- donc un breakpoint posé dans le test est honoré.
        if #test_bundles > 0 then
            vim.keymap.set("n", "<leader>tc", jdtls.test_class, { buffer = 0, silent = true, desc = "Test: la classe" })
            vim.keymap.set(
                "n",
                "<leader>tm",
                jdtls.test_nearest_method,
                { buffer = 0, silent = true, desc = "Test: la méthode sous le curseur" }
            )
        end
    end,
})
