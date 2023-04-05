local window_width_limit = 100
local hide_in_width = function()
    return vim.o.columns > window_width_limit
end
local env_cleanup = function(venv)
    if string.find(venv, "/") then
        local final_venv = venv
        for w in venv:gmatch("([^/]+)") do
            final_venv = w
        end
        venv = final_venv
    end
    return venv
end

local pyenv = {
    function()
        if vim.bo.filetype == "python" then
            local venv = os.getenv("CONDA_DEFAULT_ENV") or os.getenv("VIRTUAL_ENV")
            if venv then
                local icons = require("nvim-web-devicons")
                local py_icon, _ = icons.get_icon(".py")
                return string.format(" " .. py_icon .. " (%s)", env_cleanup(venv))
            end
        end
        return ""
    end,
    cond = hide_in_width,
    color = {fg = "#98be65"},
}
local space = {
    function()
        local shiftwidth = vim.api.nvim_buf_get_option(0, "shiftwidth")
        return "" .. " " .. shiftwidth
    end,
    padding = 1,
}

local lsp = {
    function(msg)
        msg = msg or "LS Inactive"

        local buf_clients = vim.lsp.get_active_clients()
        if next(buf_clients) == nil then
            if type(msg) == "boolean" or #msg == 0 then
                return "LS Inactive"
            end
            return msg
        end
        local buf_ft = vim.bo.filetype
        local buf_client_names = {}

        -- add client
        for _, client in pairs(buf_clients) do
            if client.name ~= "null-ls" and client.name ~= "copilot" then
                table.insert(buf_client_names, client.name)
            end
        end

        -- add formatter
        -- local formatters = require("null-ls.sources").get_available(buf_ft, "NULL_LS_FORMATTING")
        -- for _, client in pairs(formatters) do
        --     table.insert(buf_client_names, client.name)
        -- end
        local linters = require("null-ls.sources").get_available(buf_ft, "NULL_LS_DIAGNOSTICS")
        for _, client in pairs(linters) do
            table.insert(buf_client_names, client.name)
        end
  -- local have_nls = #require("null-ls.sources").get_available(ft, "NULL_LS_FORMATTING") > 0
        -- local formatters = nls.formatters
        -- local supported_formatters = formatters.list_registered(buf_ft)
        -- vim.list_extend(buf_client_names, supported_formatters)
        --
        -- -- add linter
        -- local linters = nls.linters
        -- local supported_linters = linters.list_registered(buf_ft)
        -- vim.list_extend(buf_client_names, supported_linters)

        local unique_client_names = vim.fn.uniq(buf_client_names)

        local language_servers = "[" .. table.concat(unique_client_names, ", ") .. "]"

        return language_servers
    end,
    color = { gui = "bold" },
    cond = hide_in_width,
}

return {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(plugin)
        local icons = require("lazyvim.config").icons

        local function fg(name)
            return function()
                ---@type {foreground?:number}?
                local hl = vim.api.nvim_get_hl_by_name(name, true)
                return hl and hl.foreground and { fg = string.format("#%06x", hl.foreground) }
            end
        end

        return {
            options = {
                theme = "auto",
                globalstatus = false,
                disabled_filetypes = { statusline = { "dashboard", "lazy", "alpha", "toggleterm", "neo-tree" } },
                component_separators = { left = "", right = "" },
                section_separators = { left = "", right = "" },
            },
            sections = {
                lualine_a = {
                    {
                        function()
                            return "  "
                        end,
                        padding = { left = 0, right = 0 },
                        color = {},
                        cond = nil,
                    },
                },
                lualine_b = { "branch" },
                lualine_c = {
                    pyenv,
                    -- {
                    --     "filetype",
                    --     icon_only = true,
                    --     separator = "",
                    --     padding = {
                    --         left = 1,
                    --         right = 0,
                    --     },
                    -- },
                    { "filename", path = 1, symbols = { modified = "  ", readonly = "", unnamed = "" } },
                    {
                        function()
                            return require("nvim-navic").get_location()
                        end,
                        cond = function()
                            return package.loaded["nvim-navic"] and require("nvim-navic").is_available()
                        end,
                    },
                },
                lualine_x = {
                    {
                        "diagnostics",
                        symbols = {
                            error = icons.diagnostics.Error,
                            warn = icons.diagnostics.Warn,
                            info = icons.diagnostics.Info,
                            hint = icons.diagnostics.Hint,
                        },
                    },
                    lsp,
                    -- stylua: ignore
                    -- {
                    --     function() return require("noice").api.status.command.get() end,
                    --     cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
                    --     color = fg("Statement")
                    -- },
                    -- -- stylua: ignore
                    -- {
                    --     function() return require("noice").api.status.mode.get() end,
                    --     cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
                    --     color = fg("Constant"),
                    -- },
                    { require("lazy.status").updates, cond = require("lazy.status").has_updates, color = fg("Special") },
                    space,
                    {
                        "filetype",
                        cond = nil,
                        padding = { left = 1, right = 1 },
                    },
                    -- {
                    --   "diff",
                    --   symbols = {
                    --     added = icons.git.added,
                    --     modified = icons.git.modified,
                    --     removed = icons.git.removed,
                    --   },
                    -- },
                },
                lualine_y = { { "location" } },
                lualine_z = {
                    {
                        "progress",
                        fmt = function()
                            return "%P/%L"
                        end,
                        color = {},
                    },
                },
            },
            extensions = { "neo-tree" },
        }
    end,
}
