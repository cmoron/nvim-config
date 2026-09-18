-- Run after loading the installed config:
-- nvim --headless -c 'luafile /path/to/scripts/check-runtime.lua'
local ok, err = xpcall(function()
    assert(vim.g.ts_parsers and #vim.g.ts_parsers > 0, "Configured parser list missing")
    for _, lang in ipairs(vim.g.ts_parsers) do
        local loaded, load_error = vim.treesitter.language.add(lang)
        assert(loaded, load_error or ("Cannot load parser: " .. lang))
        assert(vim.treesitter.query.get(lang, "highlights"), "Missing highlights: " .. lang)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "example = 1" })
        assert(#vim.treesitter.get_parser(buf, lang):parse() > 0, "Cannot parse: " .. lang)
        vim.treesitter.start(buf, lang)
    end
    assert(
        vim.wait(10000, function()
            return require("blink.cmp.fuzzy").implementation_type == "rust"
        end),
        "Rust fuzzy engine unavailable"
    )
    assert(vim.v.errmsg == "", vim.v.errmsg)
    print("PASS native smoke: " .. #vim.g.ts_parsers .. " parsers + highlight queries + Rust fuzzy")
end, debug.traceback)

if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
