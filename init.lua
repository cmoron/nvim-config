-- ============================
-- Configuration Neovim minimale
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

-- Navigation buffers (sera amélioré avec bufferline)
map("n", "<Tab>", ":bnext<CR>")
map("n", "<S-Tab>", ":bprevious<CR>")
map("n", "<S-F12>", ":bnext<CR>")
map("n", "<S-F11>", ":bprevious<CR>")

-- Indent/Dedent en mode insertion
map("i", "<S-Tab>", "<C-o><<")

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
    -- Colorscheme
    {
        "morhetz/gruvbox",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd([[colorscheme gruvbox]])
        end,
    },

    -- Nvim-tree (remplace NERDTree)
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<F9>", "<cmd>NvimTreeToggle<cr>", desc = "Toggle NvimTree" },
            { "<leader><Tab>", "<cmd>NvimTreeFindFile<cr>", desc = "Find file in tree" },
        },
        opts = {
            view = {
                width = 30,
            },
            renderer = {
                group_empty = true,
            },
            filters = {
                dotfiles = false,
            },
        },
    },

    -- Bufferline (gestion des buffers - affichage en haut)
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
                        filetype = "NvimTree",
                        text = "File Explorer",
                        text_align = "center",
                        separator = true,
                    },
                },
            },
        },
    },

    -- BufExplorer (gestion de buffers - workflow Vim)
    {
        "jlanzarotta/bufexplorer",
        keys = {
            { "<F12>", "<cmd>BufExplorer<cr>", desc = "Buffer Explorer" },
            { "<leader>b", "<cmd>BufExplorer<cr>", desc = "Buffer Explorer" },
        },
    },

    -- Lualine (statusline - remplace vim-airline)
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                theme = "gruvbox",
            },
        },
    },

    -- Git signs (remplace vim-gitgutter)
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

    -- Fugitive (git)
    "tpope/vim-fugitive",

    -- Comment (remplace nerdcommenter)
    {
        "numToStr/Comment.nvim",
        keys = {
            { "<leader>c<leader>", mode = { "n", "v" }, desc = "Toggle comment" },
        },
        config = function()
            require("Comment").setup()
            -- Mapping personnalisé pour <leader>c<leader>
            vim.keymap.set("n", "<leader>c<leader>", function()
                return vim.api.nvim_get_vvar("count") == 0 and "<Plug>(comment_toggle_linewise_current)"
                    or "<Plug>(comment_toggle_linewise_count)"
            end, { expr = true, silent = true, desc = "Toggle comment line" })

            vim.keymap.set(
                "v",
                "<leader>c<leader>",
                "<Plug>(comment_toggle_linewise_visual)",
                { silent = true, desc = "Toggle comment selection" }
            )
        end,
    },

    -- Telescope (fuzzy finder)
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<C-p>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
            { "<leader>p", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
            { "<leader>g", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
            { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
            { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
            { "<leader>fr", "<cmd>Telescope lsp_references<cr>", desc = "LSP references" },
            { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
        },
        opts = {
            defaults = {
                layout_strategy = "horizontal",
                layout_config = {
                    horizontal = {
                        preview_width = 0.6,
                    },
                },
                mappings = {
                    i = {
                        ["<C-j>"] = "move_selection_next",
                        ["<C-k>"] = "move_selection_previous",
                    },
                },
                -- Filtrer les dossiers et fichiers inutiles
                file_ignore_patterns = {
                    "^.git/", -- Dossier git
                    "node_modules/", -- Dépendances Node.js
                    "%.lock", -- Fichiers lock (package-lock.json, etc.)
                    "__pycache__/", -- Cache Python
                    "%.pyc", -- Bytecode Python
                    "build/", -- Build directories
                    "dist/",
                    "target/", -- Rust build
                    ".cache/",
                    "%.min%.js", -- JS minifié
                    "%.min%.css", -- CSS minifié
                },
            },
            pickers = {
                find_files = {
                    hidden = true, -- Afficher les fichiers cachés (., .., .config, etc.)
                    -- Mais respecte file_ignore_patterns
                },
            },
        },
    },

    -- Autopairs (fermeture automatique des parenthèses, quotes, etc.)
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({})

            -- Intégration avec nvim-cmp
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            local cmp = require("cmp")
            cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
        end,
    },

    -- Harpoon (navigation rapide entre fichiers favoris)
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local harpoon = require("harpoon")
            harpoon:setup()

            -- Mappings
            vim.keymap.set("n", "<leader>a", function()
                harpoon:list():add()
            end, { desc = "Harpoon: Add file" })
            vim.keymap.set("n", "<leader>h", function()
                harpoon.ui:toggle_quick_menu(harpoon:list())
            end, { desc = "Harpoon: Toggle menu" })

            -- Navigation rapide (fichiers 1-4)
            vim.keymap.set("n", "<leader>1", function()
                harpoon:list():select(1)
            end, { desc = "Harpoon: File 1" })
            vim.keymap.set("n", "<leader>2", function()
                harpoon:list():select(2)
            end, { desc = "Harpoon: File 2" })
            vim.keymap.set("n", "<leader>3", function()
                harpoon:list():select(3)
            end, { desc = "Harpoon: File 3" })
            vim.keymap.set("n", "<leader>4", function()
                harpoon:list():select(4)
            end, { desc = "Harpoon: File 4" })

            -- Navigation précédent/suivant
            vim.keymap.set("n", "<C-S-P>", function()
                harpoon:list():prev()
            end, { desc = "Harpoon: Previous" })
            vim.keymap.set("n", "<C-S-N>", function()
                harpoon:list():next()
            end, { desc = "Harpoon: Next" })
        end,
    },

    -- Trouble (diagnostics, quickfix, LSP)
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble: Toggle diagnostics" },
            {
                "<leader>xd",
                "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
                desc = "Trouble: Document diagnostics",
            },
            { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Trouble: Symbols" },
            {
                "<leader>xl",
                "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
                desc = "Trouble: LSP definitions/references",
            },
            { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Trouble: Quickfix" },
        },
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
                { "<leader>x", group = "Trouble" },
                { "<leader>c", group = "Comment" },
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
                    require("conform").format({ async = true, lsp_fallback = true })
                end,
                mode = "",
                desc = "Format buffer",
            },
        },
        opts = {
            formatters_by_ft = {
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
            },
            -- Fallback sur LSP si pas de formatter configuré
            format_on_save = false, -- Pas de format automatique
            formatters = {
                -- Configuration custom si nécessaire
            },
        },
    },

    -- Colorizer (affiche les couleurs CSS)
    {
        "norcalli/nvim-colorizer.lua",
        config = function()
            require("colorizer").setup({
                "*", -- Activer pour tous les filetypes
            }, {
                RGB = true, -- #RGB
                RRGGBB = true, -- #RRGGBB
                names = true, -- "red", "blue", etc.
                RRGGBBAA = true, -- #RRGGBBAA
                rgb_fn = true, -- rgb(), rgba()
                hsl_fn = true, -- hsl(), hsla()
                css = true, -- CSS colors
                css_fn = true, -- CSS functions
            })
        end,
    },

    -- Sneak (navigation rapide)
    {
        "justinmk/vim-sneak",
        config = function()
            vim.g["sneak#label"] = 1
        end,
    },

    -- Copilot (nécessite Node.js >= 18)
    "github/copilot.vim",

    -- Indent guides
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        opts = {
            indent = {
                char = "│",
            },
            scope = {
                enabled = false,
            },
        },
    },

    -- Treesitter (syntaxe moderne)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            local ok, configs = pcall(require, "nvim-treesitter.configs")
            if not ok then
                return
            end
            configs.setup({
                ensure_installed = { "lua", "vim", "vimdoc", "javascript", "typescript", "html", "css", "python" },
                auto_install = true,
                highlight = {
                    enable = true,
                },
                indent = {
                    enable = true,
                },
            })
        end,
    },

    -- nvim-cmp (autocomplétion moderne)
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp", -- Source LSP
            "hrsh7th/cmp-buffer", -- Source buffer
            "hrsh7th/cmp-path", -- Source paths
        },
        config = function()
            local cmp = require("cmp")

            cmp.setup({
                -- Fenêtre de complétion
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },

                -- Mappings
                mapping = cmp.mapping.preset.insert({
                    ["<Tab>"] = cmp.mapping.select_next_item(),
                    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"] = cmp.mapping.abort(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }),
                }),

                -- Sources (ordre = priorité)
                sources = cmp.config.sources({
                    { name = "nvim_lsp" }, -- LSP en priorité
                    { name = "buffer" }, -- Mots du buffer
                    { name = "path" }, -- Chemins de fichiers
                }),

                -- Formatage des items
                formatting = {
                    format = function(entry, vim_item)
                        -- Afficher la source
                        vim_item.menu = ({
                            nvim_lsp = "[LSP]",
                            buffer = "[Buffer]",
                            path = "[Path]",
                        })[entry.source.name]
                        return vim_item
                    end,
                },

                completion = {
                    autocomplete = false,
                },
            })
        end,
    },

    {
        "neovim/nvim-lspconfig",
        dependencies = { "hrsh7th/cmp-nvim-lsp" },
        config = function()
            -- Capabilities pour nvim-cmp (meilleure autocomplétion)
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- Configurer les capabilities pour tous les serveurs LSP
            vim.lsp.config("*", {
                capabilities = capabilities,
            })

            -- Activer les LSP
            vim.lsp.enable("pyright") -- Python
            vim.lsp.enable("bashls") -- Bash
            vim.lsp.enable("ts_ls") -- JavaScript/TypeScript
            vim.lsp.enable("svelte") -- Svelte
            vim.lsp.enable("rust_analyzer") -- Rust

            -- Configurer Ruff LSP
            require("lspconfig").ruff.setup({
                on_attach = function(client, bufnr)
                    -- Désactiver le hover (conflit avec pyright)
                    client.server_capabilities.hoverProvider = false
                end,
            })
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
