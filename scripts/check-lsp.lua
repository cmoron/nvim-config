-- Run after the offline installer, with the installed configuration loaded:
-- nvim --headless -c 'luafile /path/to/check-lsp.lua'
--
-- The projects are deliberately plain Eclipse and Python projects.  Maven and
-- Gradle would turn an offline LSP smoke test into a dependency-cache test.
local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    assert(vim.fn.writefile(lines, path) == 0, "Cannot write " .. path)
end

local function client_diagnostics(buf, client)
    local result = {}
    -- Pull providers use an identifier (e.g. Pyright/Ruff), including dynamic
    -- registrations; the default push namespace alone misses those results.
    local prefix = "nvim.lsp." .. client.name .. "." .. client.id
    for namespace, metadata in pairs(vim.diagnostic.get_namespaces()) do
        if metadata.name == prefix or vim.startswith(metadata.name, prefix .. ".") then
            vim.list_extend(result, vim.diagnostic.get(buf, { namespace = namespace }))
        end
    end
    return result
end

local function diagnostics(buf, client, needle)
    for _, diagnostic in ipairs(client_diagnostics(buf, client)) do
        if diagnostic.code == needle or diagnostic.message:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function diagnostic_summary(buf, client)
    local values = {}
    for _, diagnostic in ipairs(client_diagnostics(buf, client)) do
        table.insert(values, string.format("[%s] %s", diagnostic.source or "?", diagnostic.message))
    end
    return #values == 0 and "(none)" or table.concat(values, " | ")
end

local function client_for(buf, name)
    local found
    assert(
        vim.wait(30000, function()
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
                if client.name == name and not client:is_stopped() then
                    found = client
                    return true
                end
            end
            return false
        end, 100),
        string.format("%s did not attach; LSP log: %s", name, vim.lsp.get_log_path())
    )
    return found
end

local function hover(client, buf, uri, position, name)
    local reply, request_error = client:request_sync("textDocument/hover", {
        textDocument = { uri = uri },
        position = position,
    }, 10000, buf)
    assert(not request_error, name .. " hover request failed: " .. vim.inspect(request_error))
    local contents = reply and reply.result and reply.result.contents
    assert(
        (type(contents) == "string" and contents ~= "")
            or (type(contents) == "table" and ((contents.value and contents.value ~= "") or #contents > 0)),
        name .. " returned an empty hover response"
    )
end

local function edit(path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf(), vim.uri_from_fname(path)
end

local function wait_for_diagnostic(buf, client, needle)
    assert(
        vim.wait(30000, function()
            return diagnostics(buf, client, needle)
        end, 100),
        string.format("Missing %s diagnostic %q: %s", client.name, needle, diagnostic_summary(buf, client))
    )
end

local ok, err = xpcall(function()
    vim.lsp.set_log_level("debug")
    local root = vim.fn.tempname()

    if not vim.env.NVIM_TEST_JAVA_VERSION then
        local python_root = root .. "/python-smoke-" .. vim.fn.fnamemodify(root, ":t")
        write(python_root .. "/pyproject.toml", { "[project]", 'name = "nvim-lsp-smoke"', 'version = "0.0.0"' })
        local python_file = python_root .. "/example.py"
        write(python_file, {
            "import os",
            "",
            "def count() -> int:",
            "    return missing_name",
        })
        local python_buf, python_uri = edit(python_file)
        local pyright = client_for(python_buf, "pyright")
        assert(pyright.config.init_options.disablePullDiagnostics, "Pyright pull race workaround missing")
        local ruff = client_for(python_buf, "ruff")
        wait_for_diagnostic(python_buf, pyright, "missing_name")
        wait_for_diagnostic(python_buf, ruff, "F401")
        hover(pyright, python_buf, python_uri, { line = 0, character = 8 }, "pyright")

        print("PASS Python LSP: pyright hover + undefined-name diagnostic, Ruff F401")
    end

    local java_version = tonumber(vim.env.NVIM_TEST_JAVA_VERSION or "25")
    assert(java_version and java_version >= 8 and java_version <= 25, "Unsupported Java test version")
    local compliance = java_version == 8 and "1.8" or tostring(java_version)
    local java_name = "JavaSE-" .. compliance
    local java_home = assert(vim.env["JAVA" .. java_version .. "_HOME"], "Missing project JDK")
    if vim.env.NVIM_TEST_JAVA_VERSION then
        assert(vim.env.JAVA_HOME == java_home, "Project JAVA_HOME was overwritten")
        assert(vim.fn.exepath("java") == java_home .. "/bin/java", "Project java in PATH was overwritten")
    end
    local java_root = root .. "/java-smoke-" .. java_version .. "-" .. vim.fn.fnamemodify(root, ":h:t")
    write(java_root .. "/.project", {
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<projectDescription><name>nvim-lsp-smoke</name><buildSpec><buildCommand><name>org.eclipse.jdt.core.javabuilder</name><arguments></arguments></buildCommand></buildSpec><natures><nature>org.eclipse.jdt.core.javanature</nature></natures></projectDescription>",
    })
    write(java_root .. "/.classpath", {
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<classpath><classpathentry kind="src" path="src"/><classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER/org.eclipse.jdt.internal.debug.ui.launcher.StandardVMType/'
            .. java_name
            .. '"/><classpathentry kind="output" path="bin"/></classpath>',
    })
    write(java_root .. "/.settings/org.eclipse.jdt.core.prefs", {
        "eclipse.preferences.version=1",
        "org.eclipse.jdt.core.compiler.compliance=" .. compliance,
        "org.eclipse.jdt.core.compiler.source=" .. compliance,
        "org.eclipse.jdt.core.compiler.codegen.targetPlatform=" .. compliance,
    })
    local java_file = java_root .. "/src/Example.java"
    write(java_file, {
        "public class Example {",
        "    String greeting = 42;",
        java_version == 8 and "    String legacy = javax.xml.bind.DatatypeConverter.printInt(1);"
            or "    String current = String.valueOf(1);",
        "}",
    })
    local java_buf, java_uri = edit(java_file)
    local jdtls = client_for(java_buf, "jdtls")
    assert(jdtls.config.cmd[1] == vim.env.JDTLS_JAVA_HOME .. "/bin/java", "Wrong JVM selected for jdtls")
    local selected = false
    for _, runtime in ipairs(jdtls.settings.java.configuration.runtimes) do
        selected = selected or (runtime.name == java_name and runtime.path == java_home)
    end
    assert(selected, "Project JDK was not registered: " .. java_name)
    wait_for_diagnostic(java_buf, jdtls, "Type mismatch")
    hover(jdtls, java_buf, java_uri, { line = 1, character = 5 }, "jdtls")
    vim.api.nvim_buf_set_lines(java_buf, 1, 2, false, { '    String greeting = "ok";' })
    assert(
        vim.wait(30000, function()
            for _, diagnostic in ipairs(client_diagnostics(java_buf, jdtls)) do
                if diagnostic.severity == vim.diagnostic.severity.ERROR then
                    return false
                end
            end
            return true
        end, 100),
        "Java project errors remain: " .. diagnostic_summary(java_buf, jdtls)
    )
    print("PASS Java LSP: server JDK25, project " .. java_name .. ", hover + diagnostic + correction")

    print("PASS LSP smoke")
end, debug.traceback)

if not ok then
    vim.api.nvim_err_writeln(err)
    vim.api.nvim_err_writeln("LSP log: " .. vim.lsp.get_log_path())
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
