-- =============================================================================
-- offline-tsconfig.lua
-- Config minimale pour compiler les parsers Treesitter sans charger
-- la config nvim principale ni déclencher lazy.nvim.
--
-- Appelé par build-offline.sh via :
--   nvim --headless -l offline-tsconfig.lua -- parser1 parser2 ...
-- =============================================================================

local lazy_root = vim.fn.expand("~/.local/share/nvim/lazy")
local ts_path = lazy_root .. "/nvim-treesitter"

-- Vérification
if vim.fn.isdirectory(ts_path) == 0 then
    io.stderr:write("Erreur : nvim-treesitter introuvable dans " .. lazy_root .. "\n")
    vim.cmd("cq 1")
    return
end

-- Ajouter nvim-treesitter au rtp sans passer par lazy
vim.opt.rtp:prepend(ts_path)

-- Récupérer la liste des parsers passés en arguments (après --)
local parsers = {}
for i, arg in ipairs(vim.v.argv) do
    if arg == "--" then
        for j = i + 1, #vim.v.argv do
            table.insert(parsers, vim.v.argv[j])
        end
        break
    end
end

if #parsers == 0 then
    io.stderr:write("Erreur : aucun parser spécifié\n")
    vim.cmd("cq 1")
    return
end

print("Compilation de " .. #parsers .. " parsers : " .. table.concat(parsers, ", "))

local ok, configs = pcall(require, "nvim-treesitter.configs")
if not ok then
    io.stderr:write("Erreur : impossible de charger nvim-treesitter.configs\n")
    vim.cmd("cq 1")
    return
end

-- sync_install = true : bloque jusqu'à ce que tous les parsers soient compilés
configs.setup({
    ensure_installed = parsers,
    sync_install = true,
    auto_install = false,
    highlight = { enable = false },
    indent = { enable = false },
})

print("Compilation terminée.")
vim.cmd("qa")
