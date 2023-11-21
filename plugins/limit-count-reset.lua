local core = require("apisix.core")
local apisix_plugin = require("apisix.plugin")
local limit_count = require("resty.limit.count")
local tab_insert = table.insert
local ipairs = ipairs
local pairs = pairs

local lrucache = core.lrucache.new({
    type = 'plugin', serial_creating = true,
})

local schema = {
    type = "object",
    properties = {
        count = {type = "integer", exclusiveMinimum = 0},
        init_date = {type = "string"},
        rejected_code = {
            type = "integer", minimum = 200, maximum = 599, default = 503
        },
        rejected_msg = {
            type = "string", minLength = 1
        }
    }
}

local plugin_name = "limit-count-reset"

local _M = {
    version = 0.1,
    priority = 1,
    name = plugin_name,
    schema = schema
}

local function gen_limit_key(conf, ctx, key)
    local new_key = ctx.conf_type .. ctx.conf_id .. ':' .. apisix_plugin.conf_version(conf)
            .. ':' .. key
    if conf._vid then
        -- conf has _vid means it's from workflow plugin, add _vid to the key
        -- so that the counter is unique per action.
        return new_key .. ':' .. conf._vid
    end

    return new_key
end

function _M.check_schema(conf)
    local ok, err = core.schema.check(schema, conf)

    if not ok then
        return false, err
    end

    return true
end

--function _M.access(conf, ctx)
--    core.log.warn("test--------")
--    core.log.warn(conf.init_date .. " "  .. gen_limit_key(conf, ctx, "monthly_reset"))
--end

function _M.access(conf, ctx)
    core.log.warn("Before assert: " .. conf.count .. " " .. conf.init_date)
    assert(conf.count > 0 and conf.init_date)

    core.log.warn("LimitCountReset: " .. os.date("%Y-%m-%d"))
    local year, month, day = string.match(conf.init_date, "(%d%d%d%d)-(%d%d)-(%d%d)")
    if os.date("*t").yday > tonumber(day) then
        core.log.warn("RESET")
    end
end

return _M