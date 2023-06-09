local filetype = require("mason-lspconfig.mappings.filetype")
return {
    -- lspconfig
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            { "folke/neoconf.nvim", cmd = "Neoconf", config = true },
            { "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
            "mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            {
                "hrsh7th/cmp-nvim-lsp",
                cond = function()
                    return require("lazyvim.util").has("nvim-cmp")
                end,
            },
        },
        ---@class PluginLspOpts
        opts = {
            -- options for vim.diagnostic.config()
            diagnostics = {
                underline = true,
                update_in_insert = false,
                virtual_text = true,
                severity_sort = true,
                float = {
                    focusable = false,
                    style = "minimal",
                    border = "rounded",
                    source = "always",
                    header = "",
                    prefix = "",
                    format = function(d)
                        local code = d.code or (d.user_data and d.user_data.lsp.code)
                        if code then
                            return string.format("%s [%s]", d.message, code):gsub("1. ", "")
                        end
                        return d.message
                    end,
                },
            },
            document_highlight = false,
            code_lens_refresh = true,
            float = {
                focusable = true,
                style = "minimal",
                border = "rounded",
            },
            on_attach_callback = nil,
            on_init_callback = nil,
            -- Automatically format on save
            autoformat = false,
            -- options for vim.lsp.buf.format
            -- `bufnr` and `filter` is handled by the LazyVim formatter,
            -- but can be also overridden when specified
            format = {
                formatting_options = nil,
                timeout_ms = nil,
            },
            -- LSP Server Settings
            ---@type lspconfig.options
            servers = {
                jsonls = {},
                lua_ls = {
                    -- mason = false, -- set to false if you don't want this server to be installed with mason
                    settings = {
                        Lua = {
                            workspace = {
                                checkThirdParty = false,
                            },
                            completion = {
                                callSnippet = "Replace",
                            },
                        },
                    },
                },
                pyright = {
                    enabled = true,
                    settings = {
                        pyright = { autoImportCompletion = true },
                        python = {
                            analysis = {
                                autoSearchPaths = false,
                                diagnosticMode = "workspace",
                                useLibraryCodeForTypes = true,
                                typeCheckingMode = "basic",
                                diagnosticSeverityOverrides = {
                                    reportGeneralTypeIssues = "none",
                                    reportOptionalSubscript = "none",
                                    reportUnboundVariable = "none",
                                    reportOptionalMemberAccess = "none",
                                    reportInvalidStringEscapeSequence = "none",
                                    reportOptionalOperand = "none",
                                },
                            },
                        },
                        single_file_support = true,
                    },
                },
                pylsp = {
                    enabled = false,
                    filetypes = { "python" },
                    settings = {
                        pylsp = {
                            plugins = {
                                pycodestyle = {
                                    enabled = false,
                                    ignore = { "E501" },
                                },
                                autopep8 = {
                                    enabled = false,
                                },
                                pyflakes = {
                                    enabled = false,
                                },
                            },
                        },
                    },
                },
                clangd = {
                    capabilities = {
                        offsetEncoding = "utf-8",
                    },
                },
                texlab = {
                    filetypes = { "tex" },
                },
                fortls = {},
            },
            -- you can do any additional lsp server setup here
            -- return true if you don't want this server to be setup with lspconfig
            ---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
            setup = {
                -- example to setup with typescript.nvim
                -- tsserver = function(_, opts)
                --   require("typescript").setup({ server = opts })
                --   return true
                -- end,
                -- Specify * to use this function as a fallback for any server
                -- ["*"] = function(server, opts) end,
            },
        },
        ---@param opts PluginLspOpts
        config = function(_, opts)
            -- setup autoformat
            require("lazyvim.plugins.lsp.format").autoformat = opts.autoformat
            -- setup formatting and keymaps
            require("lazyvim.util").on_attach(function(client, buffer)
                require("lazyvim.plugins.lsp.format").on_attach(client, buffer)
                require("lazyvim.plugins.lsp.keymaps").on_attach(client, buffer)
            end)

            -- diagnostics
            for name, icon in pairs(require("lazyvim.config").icons.diagnostics) do
                name = "DiagnosticSign" .. name
                vim.fn.sign_define(name, { text = icon, texthl = name, numhl = name })
            end
            vim.diagnostic.config(opts.diagnostics)

            local servers = opts.servers
            local capabilities =
                require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())

            local function setup(server)
                local server_opts = vim.tbl_deep_extend("force", {
                    capabilities = vim.deepcopy(capabilities),
                }, servers[server] or {})

                if opts.setup[server] then
                    if opts.setup[server](server, server_opts) then
                        return
                    end
                elseif opts.setup["*"] then
                    if opts.setup["*"](server, server_opts) then
                        return
                    end
                end
                require("lspconfig")[server].setup(server_opts)
            end

            local have_mason, mlsp = pcall(require, "mason-lspconfig")
            local available = have_mason and mlsp.get_available_servers() or {}

            local ensure_installed = {} ---@type string[]
            for server, server_opts in pairs(servers) do
                if server_opts then
                    server_opts = server_opts == true and {} or server_opts
                    -- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
                    if server_opts.mason == false or not vim.tbl_contains(available, server) then
                        setup(server)
                    else
                        ensure_installed[#ensure_installed + 1] = server
                    end
                end
            end

            if have_mason then
                mlsp.setup({ ensure_installed = ensure_installed })
                mlsp.setup_handlers({ setup })
            end
        end,
    },

    -- formatters
    {
        "jose-elias-alvarez/null-ls.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "mason.nvim" },
        opts = function()
            local nls = require("null-ls")
            return {
                root_dir = require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json", "Makefile", ".git"),
                sources = {
                    nls.builtins.formatting.fish_indent,
                    nls.builtins.diagnostics.fish,
                    nls.builtins.formatting.stylua,
                    nls.builtins.formatting.shfmt,
                    nls.builtins.formatting.isort,
                    nls.builtins.diagnostics.codespell.with({
                        filetypes = { "python", "lua", "js", "html" },
                        extra_args = { "--ignore-words=/Users/wzx/software/codespell/words" },
                    }),
                    nls.builtins.diagnostics.flake8.with({
                        extra_args = {
                            "--max-line-length=128",
                            "--extend-ignore=E501,E203,E402,E741,W605,F841,E714,E731,E713",
                        },
                    }),
                    nls.builtins.formatting.black.with({
                        extra_args = { "--line-length=120", "--skip-string-normalization" },
                    }),
                },
            }
        end,
    },

    -- cmdline tools and lsp servers
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
        opts = {
            ensure_installed = {
                "stylua",
                "shfmt",
                "flake8",
            },
        },
        ---@param opts MasonSettings | {ensure_installed: string[]}
        config = function(_, opts)
            require("mason").setup(opts)
            local mr = require("mason-registry")
            for _, tool in ipairs(opts.ensure_installed) do
                local p = mr.get_package(tool)
                if not p:is_installed() then
                    p:install()
                end
            end
        end,
    },
}
