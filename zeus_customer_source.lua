-- ============================================================================
--  Zeus Menu v1.1  —  YARI 框架 GTA V Lua 菜单脚本（修复版）
--  严格参考 example.lua 使用正确的 API 调用
--  安装: Documents\yari\Grand Theft Auto V\lua\zeus.lua
-- ============================================================================

local licenseVerifyUrl = "https://api.gtaonline.cn/v1/license/verify"
local licenseHeartbeatUrl = "https://api.gtaonline.cn/v1/license/heartbeat"
local licenseToken = ""
local licenseExpires = 0
local licenseAuthorized = false
local nextHeartbeatAt = 0
local welcomeStartedAt = 0
local licenseRequestPending = false
local licenseErrorMessage = ""
local licenseInputKey = ""
local licenseInputQQ = ""
local licenseInputField = 1

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function readLicenseConfig()
    local content = filesystem.read_file("zeus_license.txt")
    if not content then
        return nil, nil, nil, nil
    end
    local licenseKey = trim(content:match("license_key=([^\r\n]+)"))
    local qq = trim(content:match("qq=([^\r\n]+)"))
    local buildId = trim(content:match("build_id=([^\r\n]+)"))
    local watermark = trim(content:match("watermark=([^\r\n]+)"))
    if licenseKey == "" or qq == "" or buildId == "" or watermark == "" or licenseKey:find("请填写", 1, true) then
        return nil, nil, nil, nil
    end
    return licenseKey, qq, buildId, watermark
end

local function readLoginConfig()
    local content = filesystem.read_file("zeus_login.txt")
    if not content then
        return nil, nil
    end
    local licenseKey = trim(content:match("license_key=([^\r\n]+)"))
    local qq = trim(content:match("qq=([^\r\n]+)"))
    if licenseKey == "" or qq == "" or licenseKey:find("完整卡密", 1, true) or qq:find("自己的QQ", 1, true) then
        return nil, nil
    end
    return licenseKey, qq
end

local function parseLicenseResponse(body)
    local token = tostring(body or ""):match('"token"%s*:%s*"([^"]+)"')
    local expires = tonumber(tostring(body or ""):match('"expires"%s*:%s*(%d+)'))
    local buildId = tostring(body or ""):match('"build_id"%s*:%s*"([^"]+)"')
    local watermark = tostring(body or ""):match('"watermark"%s*:%s*"([^"]+)"')
    return token, expires, buildId, watermark
end

local function saveLicenseConfig(licenseKey, qq, buildId, watermark)
    local content = "license_key=" .. licenseKey
        .. "\nqq=" .. qq
        .. "\nbuild_id=" .. buildId
        .. "\nwatermark=" .. watermark
    return filesystem.write_file("zeus_license.txt", content)
end

local function getLicenseErrorMessage(response)
    local body = tostring(response and response.body or "")
    if body:find("QQ_MISMATCH", 1, true) then return "QQ 与卡密绑定信息不一致" end
    if body:find("BUILD_MISMATCH", 1, true) then return "授权身份不匹配" end
    if body:find("INVALID_KEY", 1, true) then return "卡密无效或已被封禁" end
    return "授权服务器连接失败"
end

local function verifyZeusLicense(licenseKey, qq, buildId, watermark)
    if licenseRequestPending then
        return
    end
    licenseKey = trim(licenseKey)
    qq = trim(qq)
    buildId = trim(buildId)
    watermark = trim(watermark)
    if licenseKey == "" or qq == "" then
        licenseErrorMessage = "请输入完整卡密和绑定 QQ"
        return
    end
    licenseRequestPending = true
    licenseErrorMessage = ""
    local body = "license_key=" .. util.curl.escape(licenseKey)
        .. "&qq=" .. util.curl.escape(qq)
        .. "&version=1.1.0"
        .. "&build_id=" .. util.curl.escape(buildId)
        .. "&watermark=" .. util.curl.escape(watermark)
    util.curl.post(licenseVerifyUrl, body, {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["User-Agent"] = "Zeus-Yari/1.1"
    }, function(response)
        licenseRequestPending = false
        if type(response) ~= "table" then
            licenseErrorMessage = "授权服务器连接失败"
            return
        end
        local token, expires, responseBuildId, responseWatermark = parseLicenseResponse(response.body)
        if response.status_code ~= 200 or not token or not expires or not responseBuildId or not responseWatermark then
            licenseErrorMessage = getLicenseErrorMessage(response)
            return
        end
        licenseToken = token
        licenseExpires = expires
        licenseAuthorized = true
        nextHeartbeatAt = util.get_tick_count() + 300000
        welcomeStartedAt = util.get_tick_count()
        licenseInputKey = ""
        local saveResult = saveLicenseConfig(licenseKey, qq, responseBuildId, responseWatermark)
        if not saveResult then
            util.notify.error("Zeus 授权已通过，但自动保存失败")
            util.log_error("[Zeus License] Failed to save zeus_license.txt")
        end
        util.notify.success("Zeus 授权成功")
    end)
end

local function isLicenseAuthorized()
    return licenseAuthorized and licenseToken ~= "" and licenseExpires > 0
end

local function setAuthorizedRender(menuId, callback)
    menu.set_render(menuId, function()
        if not isLicenseAuthorized() then
            ui.add_separator("授权已失效，请重新加载脚本")
            return
        end
        callback()
    end)
end

local function clearZeusWantedLevel()
    native.clear_player_wanted_level(player.id())
    native.set_fake_wanted_level(0)
    util.data.set_int("zeus_fakewanted", 0)
end

local function registerAuthorizedLoop(name, callback)
    util.loop.register(name, function()
        if not isLicenseAuthorized() then
            return
        end
        callback()
    end)
end

local savedLicenseKey, savedQQ, savedBuildId, savedWatermark = readLicenseConfig()
if savedLicenseKey then
    licenseInputQQ = savedQQ
    verifyZeusLicense(savedLicenseKey, savedQQ, savedBuildId, savedWatermark)
else
    local loginKey, loginQQ = readLoginConfig()
    if loginKey then
        licenseInputKey = loginKey
        licenseInputQQ = loginQQ
        verifyZeusLicense(loginKey, loginQQ, "", "")
    end
end

-- ============================================================================
--  1. 菜单结构创建（注入 MISC_MENU）
-- ============================================================================
local function addToggle(text, key, onCallback, offCallback, description)
    ui.add_option(text, function()
        local nextState = not util.data.get_bool(key, false)
        util.data.set_bool(key, nextState)
        if nextState then
            if onCallback then onCallback() end
        elseif offCallback then
            offCallback()
        end
    end, nil, description)
end

local zeus_root    = menu.add_submenu("Zeus Menu",        MISC_MENU)
local zeus_player  = menu.add_submenu("玩家功能",          zeus_root)
local zeus_veh    = menu.add_submenu("载具功能",          zeus_root)
local zeus_world  = menu.add_submenu("世界功能",          zeus_root)
local zeus_about  = menu.add_submenu("关于 Zeus",       zeus_root)

-- 玩家子菜单
local sub_protect   = menu.add_submenu("防护与通缉",       zeus_player)
local sub_heal      = menu.add_submenu("治疗与护甲",     zeus_player)
local sub_tp         = menu.add_submenu("传送功能",         zeus_player)
local sub_weapons   = menu.add_submenu("武器管理",         zeus_player)
local sub_movement  = menu.add_submenu("移动与状态",       zeus_player)

-- 载具子菜单
local sub_veh_spawn = menu.add_submenu("载具生成器",     zeus_veh)
local sub_veh_mod   = menu.add_submenu("载具修改",         zeus_veh)

-- 世界子菜单
local sub_weather   = menu.add_submenu("天气控制",       zeus_world)
local sub_time      = menu.add_submenu("时间控制",         zeus_world)
local sub_env       = menu.add_submenu("环境清除",         zeus_world)

-- ============================================================================
--  2. 玩家 - 防护与通缉 (sub_protect)
-- ============================================================================
setAuthorizedRender(sub_protect, function()
    ui.add_separator("防护选项")

    addToggle("无敌模式", "zeus_godmode", function()
        native.set_entity_invincible(player.ped_id(), true)
        util.notify.success("无敌模式 已开启")
    end, function()
        native.set_entity_invincible(player.ped_id(), false)
        util.notify.info("无敌模式 已关闭")
    end, "免疫所有伤害。")

    addToggle("隐身模式", "zeus_invisible", function()
        native.set_entity_visible(player.ped_id(), false, false)
        util.notify.success("隐身模式 已开启")
    end, function()
        native.set_entity_visible(player.ped_id(), true, false)
        util.notify.info("隐身模式 已关闭")
    end, "隐藏角色模型。")

    addToggle("防摔倒布娃娃", "zeus_noragdoll", function()
        native.set_ped_can_ragdoll(player.ped_id(), false)
        util.notify.success("防摔倒 已开启")
    end, function()
        native.set_ped_can_ragdoll(player.ped_id(), true)
        util.notify.info("防摔倒 已关闭")
    end, "防止角色跌倒。")

    ui.add_separator("警察与通缉")

    addToggle("永不通缉", "zeus_neverwanted", function()
        clearZeusWantedLevel()
        native.set_max_wanted_level(0)
        util.notify.success("永不通缉 已开启")
    end, function()
        native.set_max_wanted_level(5)
        util.notify.info("永不通缉 已关闭")
    end, "永远不会被通缉。")

    ui.add_option("伪造通缉等级 +1", function()
        local level = util.data.get_int("zeus_fakewanted", 0) + 1
        if level > 5 then level = 0 end
        util.data.set_int("zeus_fakewanted", level)
        native.set_fake_wanted_level(level)
        util.notify.info("伪造通缉: " .. tostring(level) .. " 星")
    end, nil, "每次点击增加一级，超过五星后归零。")

    ui.add_option("清除当前通缉", function()
        clearZeusWantedLevel()
        util.notify.success("通缉已清除！")
    end, nil, "立即清除所有通缉星。")

end)

-- ============================================================================
--  3. 玩家 - 治疗与护甲 (sub_heal)
-- ============================================================================
setAuthorizedRender(sub_heal, function()
    ui.add_separator("一键恢复")

    ui.add_option("完全恢复 (血量+护甲)", function()
        local ped = player.ped_id()
        native.set_entity_health(ped, player.get_max_health(), 0)
        native.set_ped_armour(ped, 100)
        util.notify.success("已完全恢复！")
    end, nil, "满血满护甲。")

    ui.add_option("满血", function()
        native.set_entity_health(player.ped_id(), player.get_max_health(), 0)
        util.notify.success("血量恢复满！")
    end)

    ui.add_option("满护甲", function()
        native.set_ped_armour(player.ped_id(), 100)
        util.notify.success("护甲已回满！")
    end)

end)

-- ============================================================================
--  4. 玩家 - 传送功能 (sub_tp)
-- ============================================================================
setAuthorizedRender(sub_tp, function()
    ui.add_separator("传送选项")

    ui.add_option("传送到地图标记点", function()
        if player.teleport_to_waypoint() then
            util.notify.success("已传送到标记点！")
        elseif native.is_waypoint_active() then
            local blip = native.get_first_blip_info_id(8)
            local coords = native.get_blip_coords(blip)
            if coords.x ~= 0.0 or coords.y ~= 0.0 then
                local ent = player.is_in_vehicle() and player.get_vehicle() or player.ped_id()
                native.set_entity_coords(ent, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
                util.notify.success("已传送到标记点！")
            else
                util.notify.error("无法获取标记点坐标！")
            end
        else
            util.notify.error("请先在地图上设置标记点！")
        end
    end, nil, "传送到黄色地图标记。")

    ui.add_option("向前传送 10 米", function()
        local pos = player.get_coords()
        local heading = player.get_heading()
        local rad = heading * 3.14159265 / 180.0
        player.set_coords(
            pos.x - math.sin(rad) * 10.0,
            pos.y + math.cos(rad) * 10.0,
            pos.z
        )
        util.notify.success("向前传送！")
    end)

    ui.add_option("向上传送 10 米", function()
        local pos = player.get_coords()
        player.set_coords(pos.x, pos.y, pos.z + 10.0)
        util.notify.success("向上传送！")
    end)

    ui.add_separator("常用地点")

    ui.add_option("国际机场", function()
        player.set_coords(-1036.0, -2735.0, 13.8)
        util.notify.success("已到机场！")
    end)

    ui.add_option("军事基地", function()
        player.set_coords(-2064.0, 3160.0, 32.8)
        util.notify.success("已到军事基地！")
    end)

    ui.add_option("市中心花园银行", function()
        player.set_coords(-75.0, -806.0, 326.0)
        util.notify.success("已到市中心！")
    end)

    ui.add_option("好麦坞山", function()
        player.set_coords(-570.0, 880.0, 237.0)
        util.notify.success("已到好麦坞山！")
    end)

    ui.add_option("名钻赌场", function()
        player.set_coords(918.0, 43.0, 80.0)
        util.notify.success("已到赌场！")
    end)

    ui.add_option("本尼改装工坊", function()
        player.set_coords(-205.0, -1307.0, 31.0)
        util.notify.success("已到改装店！")
    end)

    ui.add_separator("坐标工具")

    ui.add_option("查看当前坐标", function()
        local pos = player.get_coords()
        local info = string.format("X: %.1f  Y: %.1f  Z: %.1f", pos.x, pos.y, pos.z)
        util.notify.info(info, 4000)
    end)

    ui.add_option("保存坐标到日志", function()
        local pos = player.get_coords()
        local heading = player.get_heading()
        local line = string.format("X=%.2f, Y=%.2f, Z=%.2f, H=%.1f", pos.x, pos.y, pos.z, heading)
        print("[Zeus 坐标] " .. line)
        util.notify.success("坐标已写入日志！")
    end)
end)

-- ============================================================================
--  5. 玩家 - 武器管理 (sub_weapons)
-- ============================================================================
local ZeusWeapons = {
    { name = "手枪",          hash = "WEAPON_PISTOL" },
    { name = "战斗手枪",      hash = "WEAPON_COMBATPISTOL" },
    { name = "AP 手枪",       hash = "WEAPON_APPISTOL" },
    { name = "沙漠之鹰",      hash = "WEAPON_DEAGLE" },
    { name = "微型冲锋枪",    hash = "WEAPON_MICROSMG" },
    { name = "冲锋枪",        hash = "WEAPON_SMG" },
    { name = "突击冲锋枪",    hash = "WEAPON_ASSAULTSMG" },
    { name = "突击步枪",      hash = "WEAPON_ASSAULTRIFLE" },
    { name = "卡宾步枪",      hash = "WEAPON_CARBINERIFLE" },
    { name = "高级步枪",      hash = "WEAPON_ADVANCEDRIFLE" },
    { name = "特种卡宾",      hash = "WEAPON_SPECIALCARBINE" },
    { name = "泵动霰弹枪",    hash = "WEAPON_PUMPSHOTGUN" },
    { name = "突击霰弹枪",    hash = "WEAPON_ASSAULTSHOTGUN" },
    { name = "重型霰弹枪",    hash = "WEAPON_HEAVYSHOTGUN" },
    { name = "狙击枪",        hash = "WEAPON_SNIPERRIFLE" },
    { name = "重型狙击",      hash = "WEAPON_HEAVYSNIPER" },
    { name = "精准步枪",      hash = "WEAPON_MARKSMANRIFLE" },
    { name = "火箭炮",        hash = "WEAPON_RPG" },
    { name = "制导火箭",      hash = "WEAPON_HOMINGLAUNCHER" },
    { name = "榴弹发射器",    hash = "WEAPON_GRENADELAUNCHER" },
    { name = "火神机枪",      hash = "WEAPON_MINIGUN" },
    { name = "电磁轨道炮",    hash = "WEAPON_RAILGUN" },
    { name = "手雷",          hash = "WEAPON_GRENADE" },
    { name = "催泪瓦斯",      hash = "WEAPON_BZGAS" },
    { name = "粘弹 C4",       hash = "WEAPON_STICKYBOMB" },
    { name = "感应地雷",      hash = "WEAPON_PROXMINE" },
    { name = "小刀",          hash = "WEAPON_KNIFE" },
    { name = "警棍",          hash = "WEAPON_NIGHTSTICK" },
    { name = "武士刀",        hash = "WEAPON_KATANA" }
}

setAuthorizedRender(sub_weapons, function()
    ui.add_separator("快速操作")

    ui.add_option("全部武器 + 满弹药", function()
        for _, w in ipairs(ZeusWeapons) do
            if w.hash ~= "WEAPON_UNARMED" then
                weapon.give(util.joaat(w.hash), 9999)
            end
        end
        util.notify.success("已获得全部武器！")
    end)

    ui.add_option("常用战斗套装", function()
        local set = {
            "WEAPON_APPISTOL", "WEAPON_SMG", "WEAPON_ASSAULTRIFLE",
            "WEAPON_CARBINERIFLE", "WEAPON_PUMPSHOTGUN", "WEAPON_HEAVYSNIPER",
            "WEAPON_RPG", "WEAPON_GRENADE", "WEAPON_STICKYBOMB"
        }
        for _, w in ipairs(set) do weapon.give(util.joaat(w), 9999) end
        util.notify.success("常用套装已获得！")
    end)

    ui.add_option("清除所有武器", function()
        weapon.remove_all()
        util.notify.info("所有武器已清除！")
    end)

    addToggle("无限弹药", "zeus_ammo", function()
        util.notify.success("无限弹药 已开启")
    end, function()
        local ped = player.ped_id()
        native.set_ped_infinite_ammo_clip(ped, false)
        native.set_ped_infinite_ammo(ped, false, weapon.get_current())
        util.notify.info("无限弹药 已关闭")
    end)

    ui.add_separator("全部武器列表")
    for _, w in ipairs(ZeusWeapons) do
        local item = w
        ui.add_option(item.name, function()
            weapon.give(util.joaat(item.hash), 9999)
            util.notify.success("获得: " .. item.name)
        end)
    end
end)

-- ============================================================================
--  6. 玩家 - 移动与状态 (sub_movement)
-- ============================================================================
setAuthorizedRender(sub_movement, function()
    ui.add_separator("状态选项")

    addToggle("无限耐力", "zeus_stamina", function()
        util.notify.success("无限耐力 已开启")
    end, function()
        util.notify.info("无限耐力 已关闭")
    end, "跑步不消耗耐力。")

    addToggle("超级跳跃", "zeus_superjump", function()
        util.notify.success("超级跳跃 已开启")
    end, function()
        util.notify.info("超级跳跃 已关闭")
    end, "跳跃高度大幅增加。")

    addToggle("快速奔跑", "zeus_runfast", function()
        util.notify.success("快速奔跑 已开启")
    end, function()
        util.notify.info("快速奔跑 已关闭")
    end)

    addToggle("飞行模式", "zeus_flymode", function()
        util.notify.success("飞行模式 已开启 (SHIFT升/CTRL降)")
    end, function()
        local ped = player.ped_id()
        native.set_entity_collision(ped, true, true)
        util.notify.info("飞行模式 已关闭")
    end)

    addToggle("穿墙模式 (NoClip)", "zeus_noclip", function()
        util.notify.success("穿墙模式 已开启")
    end, function()
        local ped = player.ped_id()
        native.set_entity_collision(ped, true, true)
        util.notify.info("穿墙模式 已关闭")
    end)

    ui.add_separator("其他操作")

    ui.add_option("自杀", function()
        native.set_entity_health(player.ped_id(), 0, 0)
    end)

    ui.add_option("清理角色状态", function()
        local ped = player.ped_id()
        native.clear_ped_tasks_immediately(ped)
        native.clear_ped_blood_damage(ped)
        native.clear_ped_env_dirt(ped)
        native.clear_ped_decorations(ped)
        util.notify.success("角色已清理！")
    end)
end)

-- ============================================================================
--  7. 载具 - 载具生成器 (sub_veh_spawn)
-- ============================================================================
local ZeusVehicles = {
    { name = "[超跑] 灵蛇 Adder",       model = "adder" },
    { name = "[超跑] 桑托劳 Zentorno",  model = "zentorno" },
    { name = "[超跑] T20",               model = "t20" },
    { name = "[超跑] 奥西里斯 Osiris",   model = "osiris" },
    { name = "[超跑] 死神 Reaper",       model = "reaper" },
    { name = "[超跑] 泰泽拉克 Tezeract", model = "tezeract" },
    { name = "[超跑] 811 原型 Prototipo", model = "prototipo" },
    { name = "[跑车] 飓风 Jester",       model = "jester" },
    { name = "[跑车] 披治 R Turismo R",  model = "turismor" },
    { name = "[跑车] 猎豹 Cheetah",      model = "cheetah" },
    { name = "[跑车] 子弹 GT Bullet",    model = "bullet" },
    { name = "[跑车] 实体 GT Entity XF", model = "entityxf" },
    { name = "[摩托] 正太郎 Shotaro",    model = "shotaro" },
    { name = "[摩托] Bati 801",          model = "bati" },
    { name = "[越野] 叛乱分子 Insurgent", model = "insurgent" },
    { name = "[装甲] 骷髅马 Kuruma",     model = "kuruma2" },
    { name = "[装甲] 夜鲨 Nightshark",   model = "nightshark" },
    { name = "[飞机] 战斗机 Lazer",      model = "lazer" },
    { name = "[飞机] 九头蛇 Hydra",      model = "hydra" },
    { name = "[飞机] 运兵直升机 Cargobob", model = "cargobob" },
    { name = "[直升机] 秃鹰 Buzzard",    model = "buzzard" },
    { name = "[直升机] 歼灭者 Annihilator", model = "annihilator" },
    { name = "[坦克] 犀牛 Rhino",        model = "rhino" },
    { name = "[船] 快艇 Seashark",       model = "seashark" },
    { name = "[自行车] BMX",              model = "bmx" },
    { name = "[服务] 警车 Police",        model = "police" },
    { name = "[服务] 救护车 Ambulance",   model = "ambulance" },
    { name = "[服务] 消防车 Firetruk",    model = "firetruk" },
    { name = "[服务] 出租车 Taxi",        model = "taxi" }
}

setAuthorizedRender(sub_veh_spawn, function()
    ui.add_separator("载具操作")

    addToggle("新载具自动无敌", "zeus_spawn_god", function()
        util.notify.success("新载具默认无敌 已开启")
    end, function()
        util.notify.info("已关闭")
    end)

    ui.add_option("修复当前载具", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.set_vehicle_fixed(veh)
            native.set_vehicle_dirt_level(veh, 0.0)
            util.notify.success("载具已修复！")
        else
            util.notify.error("请先进入载具！")
        end
    end)

    ui.add_option("翻正当前载具", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.set_vehicle_on_ground_properly(veh, 5.0)
            util.notify.success("载具已翻正！")
        else
            util.notify.error("请先进入载具！")
        end
    end)

    ui.add_option("删除当前载具", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.set_entity_as_mission_entity(veh, true, true)
            local tmp = veh
            native.delete_entity(tmp)
            util.notify.success("载具已删除！")
        else
            util.notify.error("请先进入载具！")
        end
    end)

    ui.add_separator("载具列表（点击生成）")
    for _, v in ipairs(ZeusVehicles) do
        local item = v
        ui.add_option(item.name, function()
            local hash = util.joaat(item.model)
            vehicle.spawn(hash, true)
            if util.data.get_bool("zeus_spawn_god", true) then
                local veh = vehicle.get_current()
                if veh ~= 0 then
                    native.set_entity_invincible(veh, true)
                    native.set_vehicle_fixed(veh)
                    native.set_vehicle_dirt_level(veh, 0.0)
                end
            end
            util.notify.success("已生成: " .. item.name)
        end)
    end
end)

-- ============================================================================
--  8. 载具 - 载具修改 (sub_veh_mod)
-- ============================================================================
setAuthorizedRender(sub_veh_mod, function()
    ui.add_separator("当前载具")

    addToggle("载具无敌", "zeus_veh_god", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then native.set_entity_invincible(veh, true) end
        util.notify.success("载具无敌 已开启")
    end, function()
        local veh = vehicle.get_current()
        if veh ~= 0 then native.set_entity_invincible(veh, false) end
        util.notify.info("载具无敌 已关闭")
    end)

    addToggle("无限燃料", "zeus_veh_fuel", function()
        util.notify.success("无限燃料 已开启")
    end, function()
        util.notify.info("无限燃料 已关闭")
    end)

    addToggle("防刺轮胎", "zeus_veh_bullet", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then native.set_vehicle_tyres_can_burst(veh, false) end
        util.notify.success("防刺轮胎 已开启")
    end, function()
        local veh = vehicle.get_current()
        if veh ~= 0 then native.set_vehicle_tyres_can_burst(veh, true) end
        util.notify.info("防刺轮胎 已关闭")
    end)

    ui.add_option("满油", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.set_vehicle_fuel_tank_health(veh, 100.0)
            util.notify.success("已加满！")
        else
            util.notify.error("请先进入载具！")
        end
    end)

    ui.add_separator("性能升级")

    ui.add_option("一键满改 (所有配件MAX)", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            for modType = 0, 16 do
                local maxMod = native.get_num_vehicle_mods(veh, modType) - 1
                if maxMod >= 0 then
                    native.set_vehicle_mod(veh, modType, maxMod, false)
                end
            end
            native.set_vehicle_window_tint(veh, 2)
            native.toggle_vehicle_mod(veh, 18, true)
            util.notify.success("已改到最高级！")
        else
            util.notify.error("请先进入载具！")
        end
    end, nil, "引擎/传动/刹车/悬挂/涡轮 全部MAX。")

    ui.add_option("安装涡轮", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.toggle_vehicle_mod(veh, 18, true)
            util.notify.success("涡轮已安装！")
        else
            util.notify.error("请先进入载具！")
        end
    end)

    ui.add_option("切换车窗贴膜", function()
        local veh = vehicle.get_current()
        if veh ~= 0 then
            local tint = util.data.get_int("zeus_veh_tint", 0) + 1
            if tint > 3 then tint = 0 end
            util.data.set_int("zeus_veh_tint", tint)
            native.set_vehicle_window_tint(veh, tint)
            util.notify.info("车窗贴膜等级: " .. tostring(tint))
        else
            util.notify.error("请先进入载具！")
        end
    end, nil, "每次点击切换：透明、深色、黑色、纯黑。")

    ui.add_separator("喷漆颜色")
    local paintColors = {
        { name = "纯黑",   index = 0 },
        { name = "白色",   index = 111 },
        { name = "方程式红", index = 29 },
        { name = "日落橙", index = 35 },
        { name = "赛车黄", index = 89 },
        { name = "亮蓝色", index = 64 },
        { name = "绿色",   index = 53 },
        { name = "军绿色", index = 55 },
        { name = "午夜紫", index = 70 },
        { name = "亮粉色", index = 136 },
        { name = "金色",   index = 98 },
        { name = "铬合金", index = 120 },
        { name = "哑光黑", index = 147 },
        { name = "哑光红", index = 154 }
    }
    for _, c in ipairs(paintColors) do
        local col = c
        ui.add_option(col.name, function()
            local veh = vehicle.get_current()
            if veh ~= 0 then
                native.set_vehicle_colours(veh, col.index, col.index)
                util.notify.success("喷漆: " .. col.name)
            else
                util.notify.error("请先进入载具！")
            end
        end)
    end
end)

-- ============================================================================
--  9. 世界 - 天气控制 (sub_weather)
-- ============================================================================
local WeatherList = {
    "EXTRASUNNY", "CLEAR", "CLOUDS", "OVERCAST", "FOGGY", "SMOG",
    "RAIN", "THUNDER", "SNOWLIGHT", "SNOW", "BLIZZARD", "XMAS", "HALLOWEEN"
}
local WeatherNames = {
    "大晴天", "晴天", "少云", "阴天", "有雾", "大雾",
    "小雨", "雷暴", "小雪", "大雪", "暴风雪", "圣诞节", "万圣节"
}

setAuthorizedRender(sub_weather, function()
    ui.add_separator("天气切换")
    for i = 1, #WeatherList do
        local name = WeatherNames[i]
        local val = WeatherList[i]
        ui.add_option(name, function()
            native.set_weather_type_now_persist(val)
            util.notify.success("天气: " .. name)
        end)
    end

    ui.add_separator("设置")
    addToggle("锁定天气", "zeus_lockweather", function()
        util.notify.success("天气已锁定")
    end, function()
        util.notify.info("天气已解锁")
    end)
end)

-- ============================================================================
--  10. 世界 - 时间控制 (sub_time)
-- ============================================================================
local function setZeusClock(hour, minute)
    util.data.set_int("zeus_hr", hour)
    util.data.set_int("zeus_min", minute)
    native.set_clock_time(hour, minute, 0)
    native.network_override_clock_time(hour, minute, 0)
    util.notify.success(string.format("时间: %02d:%02d", hour, minute))
end

setAuthorizedRender(sub_time, function()
    ui.add_separator("快速设置时间")
    ui.add_option("00:00 深夜",   function() setZeusClock(0, 0) end)
    ui.add_option("06:00 日出",   function() setZeusClock(6, 0) end)
    ui.add_option("12:00 中午",   function() setZeusClock(12, 0) end)
    ui.add_option("18:00 日落",   function() setZeusClock(18, 0) end)
    ui.add_option("21:00 夜晚",   function() setZeusClock(21, 0) end)

    ui.add_separator("自定义")
    ui.add_option("小时 +1", function()
        local hour = util.data.get_int("zeus_hr", 12) + 1
        if hour > 23 then hour = 0 end
        util.data.set_int("zeus_hr", hour)
        util.notify.info("小时: " .. tostring(hour))
    end)
    ui.add_option("分钟 +5", function()
        local minute = util.data.get_int("zeus_min", 0) + 5
        if minute > 59 then minute = 0 end
        util.data.set_int("zeus_min", minute)
        util.notify.info("分钟: " .. tostring(minute))
    end)
    ui.add_option("应用自定义时间", function()
        local h = util.data.get_int("zeus_hr", 12)
        local m = util.data.get_int("zeus_min", 0)
        setZeusClock(h, m)
    end)

    ui.add_separator("冻结")
    addToggle("冻结时间", "zeus_freeze_time", function()
        native.pause_clock(true)
        util.notify.success("时间已冻结")
    end, function()
        native.pause_clock(false)
        util.notify.info("时间已解冻")
    end)
end)

registerAuthorizedLoop("zeus_loop_clock", function()
    if util.data.get_bool("zeus_freeze_time", false) then
        local h = util.data.get_int("zeus_hr", 12)
        local m = util.data.get_int("zeus_min", 0)
        native.network_override_clock_time(h, m, 0)
        native.set_clock_time(h, m, 0)
    end
end)

-- ============================================================================
--  11. 世界 - 环境清除 (sub_env)
-- ============================================================================
setAuthorizedRender(sub_env, function()
    ui.add_separator("半径清除")

    ui.add_option("清除附近车辆 (150m)", function()
        local pos = player.get_coords()
        native.clear_area_of_vehicles(pos.x, pos.y, pos.z, 150.0, true, true, true, true, true, 0)
        util.notify.success("附近车辆已清除！")
    end)

    ui.add_option("清除附近 NPC (150m)", function()
        local pos = player.get_coords()
        native.clear_area_of_peds(pos.x, pos.y, pos.z, 150.0, 0)
        util.notify.success("附近 NPC 已清除！")
    end)

    ui.add_option("清除附近警察 (200m)", function()
        local pos = player.get_coords()
        native.clear_area_of_cops(pos.x, pos.y, pos.z, 200.0, 0)
        util.notify.success("附近警察已清除！")
    end)

    ui.add_option("清除附近爆炸物 (200m)", function()
        local pos = player.get_coords()
        native.clear_area_of_projectiles(pos.x, pos.y, pos.z, 200.0, 0)
        util.notify.success("附近爆炸物已清除！")
    end)

    ui.add_option("清除一切 (300m)", function()
        local pos = player.get_coords()
        native.clear_area_of_everything(pos.x, pos.y, pos.z, 300.0, true, true, true, true)
        util.notify.success("300m 内全部清除！")
    end)

    ui.add_separator("其他")
    ui.add_option("制造大爆炸", function()
        local pos = player.get_coords()
        native.add_explosion(pos.x, pos.y, pos.z, 0, 10.0, true, false, 1.0, false)
        util.notify.success("BOOM!")
    end)

    addToggle("重力 - 月球", "zeus_lowgrav", function()
        native.set_gravity_level(1)
        util.notify.success("月球重力 已开启")
    end, function()
        native.set_gravity_level(9.81)
        util.notify.info("重力已恢复正常")
    end)

    addToggle("慢动作", "zeus_slowmo", function()
        native.set_time_scale(0.3)
        util.notify.success("慢动作 已开启")
    end, function()
        native.set_time_scale(1.0)
        util.notify.info("慢动作 已关闭")
    end)
end)

ui.on_render("zeus_license_panel", function()
    if isLicenseAuthorized() then return end
    local size = ui.draw.get_display_size()
    local mouse = ui.draw.get_mouse_pos()
    local width = math.min(520.0, size.w - 40.0)
    local height = 330.0
    local left = (size.w - width) / 2.0
    local top = (size.h - height) / 2.0
    local inputLeft = left + 40.0
    local inputRight = left + width - 40.0
    ui.draw.show_cursor(false, 235, 235, 240, 255, 1.0)
    ui.draw.rect_filled(left, top, left + width, top + height, 18, 19, 23, 248, 10)
    ui.draw.rect_filled(left, top, left + 5.0, top + height, 218, 35, 58, 255, 5)
    ui.draw.text_sz(left + 40.0, top + 30.0, "ZEUS 授权", 26, 245, 245, 248, 255)
    ui.draw.text_sz(left + 40.0, top + 68.0, "输入购买时获得的卡密和绑定 QQ", 15, 155, 162, 174, 255)

    local keyTop = top + 106.0
    local qqTop = top + 174.0
    local function drawLicenseInput(field, y, label, value)
        local active = licenseInputField == field
        local border = active and 218 or 65
        ui.draw.text_sz(inputLeft, y - 22.0, label, 14, 185, 190, 200, 255)
        ui.draw.rect_filled(inputLeft, y, inputRight, y + 44.0, 37, 38, 44, 255, 5)
        ui.draw.rect(inputLeft, y, inputRight, y + 44.0, border, active and 35 or 65, active and 58 or 70, 255, 5, 1.0)
        ui.draw.text_sz(inputLeft + 14.0, y + 12.0, value, 16, 235, 235, 240, 255)
        if mouse.x >= inputLeft and mouse.x <= inputRight and mouse.y >= y and mouse.y <= y + 44.0 and ui.draw.is_mouse_clicked(0) then
            licenseInputField = field
        end
    end

    local maskedKey = licenseInputKey == "" and "请输入完整卡密" or string.rep("*", math.min(#licenseInputKey, 36))
    local qqDisplay = licenseInputQQ == "" and "请输入绑定 QQ" or licenseInputQQ
    drawLicenseInput(1, keyTop, "卡密", maskedKey)
    drawLicenseInput(2, qqTop, "QQ", qqDisplay)

    if ui.draw.is_key_pressed(0x09) then
        licenseInputField = licenseInputField == 1 and 2 or 1
    end
    if ui.draw.is_key_pressed(0x08) then
        if licenseInputField == 1 then
            licenseInputKey = licenseInputKey:sub(1, -2)
        else
            licenseInputQQ = licenseInputQQ:sub(1, -2)
        end
    end
    local characters = ui.draw.get_input_characters()
    if type(characters) == "string" and characters ~= "" then
        if licenseInputField == 1 then
            local filtered = characters:upper():gsub("[^A-Z0-9%-]", "")
            licenseInputKey = (licenseInputKey .. filtered):sub(1, 80)
        else
            local filtered = characters:gsub("[^0-9]", "")
            licenseInputQQ = (licenseInputQQ .. filtered):sub(1, 20)
        end
    end

    local buttonTop = top + 246.0
    local hovered = mouse.x >= inputLeft and mouse.x <= inputRight and mouse.y >= buttonTop and mouse.y <= buttonTop + 46.0
    local buttonRed = licenseRequestPending and 90 or (hovered and 235 or 218)
    ui.draw.rect_filled(inputLeft, buttonTop, inputRight, buttonTop + 46.0, buttonRed, 35, 58, 255, 5)
    local buttonText = licenseRequestPending and "正在验证..." or "验证并进入"
    local buttonSize = ui.draw.calc_text_size(buttonText, 17)
    ui.draw.text_sz(left + (width - buttonSize.w) / 2.0, buttonTop + 13.0, buttonText, 17, 255, 255, 255, 255)
    if not licenseRequestPending and ((hovered and ui.draw.is_mouse_clicked(0)) or ui.draw.is_key_pressed(0x0D)) then
        verifyZeusLicense(licenseInputKey, licenseInputQQ, "", "")
    end
    if licenseErrorMessage ~= "" then
        local errorSize = ui.draw.calc_text_size(licenseErrorMessage, 14)
        ui.draw.text_sz(left + (width - errorSize.w) / 2.0, top + 302.0, licenseErrorMessage, 14, 245, 95, 110, 255)
    end
end)

ui.on_render("zeus_welcome_ceremony", function()
    if not isLicenseAuthorized() or welcomeStartedAt <= 0 then return end
    local elapsed = util.get_tick_count() - welcomeStartedAt
    if elapsed >= 8000 then
        welcomeStartedAt = 0
        return
    end
    local size = ui.draw.get_display_size()
    local title = "欢迎使用"
    local subtitle = "ZEUS"
    local detail = ""
    local alpha = 255
    local progress = elapsed / 4000
    if elapsed >= 4000 then
        title = "授权成功"
        subtitle = "ZEUS"
        detail = "功能已就绪"
        progress = (elapsed - 4000) / 4000
        alpha = math.floor(255 * (1.0 - progress))
    end
    local red = math.floor(100 + 155 * math.min(progress, 1.0))
    local green = math.floor(180 + 60 * (1.0 - math.min(progress, 1.0)))
    local blue = math.floor(255 - 100 * math.min(progress, 1.0))
    local titleSize = ui.draw.calc_text_size(title, 30)
    local subtitleSize = ui.draw.calc_text_size(subtitle, 54)
    local titleX = (size.w - titleSize.w) / 2
    local subtitleX = (size.w - subtitleSize.w) / 2
    local baseY = size.h * 0.30
    ui.draw.text_sz(titleX + 2, baseY + 2, title, 30, 0, 0, 0, alpha)
    ui.draw.text_sz(titleX, baseY, title, 30, red, green, blue, alpha)
    ui.draw.text_sz(subtitleX + 2, baseY + 42, subtitle, 54, 0, 0, 0, alpha)
    ui.draw.text_sz(subtitleX, baseY + 40, subtitle, 54, 255, 255, 255, alpha)
    if detail ~= "" then
        local detailSize = ui.draw.calc_text_size(detail, 20)
        ui.draw.text_sz((size.w - detailSize.w) / 2, baseY + 106, detail, 20, red, green, blue, alpha)
    end
end)

local desktopUiOpen = false
local desktopUiTab = 1
local desktopUiTabs = { "玩家", "移动", "传送", "武器", "载具", "世界", "扫描/设置" }
local desktopUiPageByTab = {}
local desktopUiThemes = {
    {
        name = "Zeus 红",
        accent = { 218, 35, 58 },
        panel = { 18, 19, 23 },
        header = { 25, 26, 31 },
        sidebar = { 22, 23, 28 },
        control = { 43, 43, 48 },
        hover = { 75, 55, 68 },
        text = { 235, 235, 240 }
    },
    {
        name = "冰蓝",
        accent = { 45, 155, 220 },
        panel = { 16, 22, 28 },
        header = { 22, 31, 39 },
        sidebar = { 19, 28, 36 },
        control = { 38, 51, 62 },
        hover = { 52, 82, 105 },
        text = { 232, 242, 248 }
    }
}
local desktopUiThemeIndex = util.data.get_int("zeus_ui_theme", 1)
if desktopUiThemeIndex < 1 or desktopUiThemeIndex > #desktopUiThemes then desktopUiThemeIndex = 1 end
local function getDesktopUiFloat(key, defaultValue)
    local value = tonumber(util.data.get_float(key))
    if not value or value <= 0 then
        value = defaultValue
        util.data.set_float(key, value)
    end
    return value
end
local desktopUiConfig = {
    width = getDesktopUiFloat("zeus_ui_width", 720.0),
    height = getDesktopUiFloat("zeus_ui_height", 480.0),
    positionX = getDesktopUiFloat("zeus_ui_position_x", 0.5),
    positionY = getDesktopUiFloat("zeus_ui_position_y", 0.5),
    draggable = true
}
if not util.data.get_bool("zeus_ui_compact_layout_v2", false) then
    desktopUiConfig.width = 720.0
    desktopUiConfig.height = 480.0
    util.data.set_float("zeus_ui_width", desktopUiConfig.width)
    util.data.set_float("zeus_ui_height", desktopUiConfig.height)
    util.data.set_bool("zeus_ui_compact_layout_v2", true)
end
desktopUiConfig.width = math.max(720.0, math.min(1200.0, desktopUiConfig.width))
desktopUiConfig.height = math.max(480.0, math.min(760.0, desktopUiConfig.height))
desktopUiConfig.positionX = math.max(0.0, math.min(1.0, desktopUiConfig.positionX))
desktopUiConfig.positionY = math.max(0.0, math.min(1.0, desktopUiConfig.positionY))
local desktopUiDrag = {
    active = false,
    offsetX = 0.0,
    offsetY = 0.0,
    left = 0.0,
    top = 0.0
}
local scanTarget = 0
local scanTargetKind = "未选择"
local scanTargetName = "无目标"
local scanTargetDistance = 0.0
local scanTargetPosition = nil
local scanPulseStartedAt = 0

local function getEntityCoordsSafe(entity)
    if entity == 0 or not native.does_entity_exist(entity) then return nil end
    if type(gta) ~= "table" or type(gta.get_entity_coords) ~= "function" then return nil end
    local ok, coords = pcall(gta.get_entity_coords, entity)
    if not ok or type(coords) ~= "table" then return nil end
    return coords
end

local function getDistanceBetweenPoints(first, second)
    if not first or not second then return 0.0 end
    local x = first.x - second.x
    local y = first.y - second.y
    local z = first.z - second.z
    return math.sqrt(x * x + y * y + z * z)
end

local function validateScanTarget()
    if scanTarget == 0 or not native.does_entity_exist(scanTarget) then
        scanTarget = 0
        scanTargetKind = "未选择"
        scanTargetName = "无目标"
        scanTargetDistance = 0.0
        scanTargetPosition = nil
        return false
    end
    local entityType = native.get_entity_type(scanTarget)
    if entityType == 1 then
        if native.is_ped_a_player(scanTarget) then
            scanTarget = 0
            scanTargetKind = "已屏蔽玩家"
            scanTargetName = "不能选择玩家"
            scanTargetDistance = 0.0
            scanTargetPosition = nil
            return false
        end
        scanTargetKind = native.is_ped_human(scanTarget) and "NPC" or "动物"
        scanTargetName = native.is_ped_dead_or_dying(scanTarget, true) and "死亡目标" or "非玩家目标"
    elseif entityType == 2 then
        scanTargetKind = "载具"
        scanTargetName = "载具 #" .. tostring(native.get_entity_model(scanTarget))
    else
        scanTarget = 0
        scanTargetKind = "无效类型"
        scanTargetName = "仅支持 NPC、动物或载具"
        scanTargetDistance = 0.0
        scanTargetPosition = nil
        return false
    end
    scanTargetPosition = getEntityCoordsSafe(scanTarget)
    scanTargetDistance = getDistanceBetweenPoints(player.get_coords(), scanTargetPosition)
    return scanTargetPosition ~= nil
end

local function useAimedEntityIfAvailable()
    if type(gta) == "table" and type(gta.get_aimed_entity) == "function" then
        local ok, entity = pcall(gta.get_aimed_entity)
        if ok and type(entity) == "number" and entity ~= 0 then
            scanTarget = entity
            scanPulseStartedAt = util.get_tick_count()
            if validateScanTarget() then
                util.notify.success("已选择 " .. scanTargetKind)
                return true
            end
        end
    end
    util.notify.error("当前 YARI 版本没有结构化镜头射线接口")
    return false
end

local function requireNpcScanTarget()
    if not validateScanTarget() or native.get_entity_type(scanTarget) ~= 1 or native.is_ped_a_player(scanTarget) then
        util.notify.error("请先选择非玩家 NPC 或动物")
        return 0
    end
    return scanTarget
end

local function maximizeCurrentVehicle()
    local veh = vehicle.get_current()
    if veh == 0 or not native.does_entity_exist(veh) then
        util.notify.error("请先进入载具")
        return
    end
    native.set_vehicle_mod_kit(veh, 0)
    for modType = 0, 16 do
        local maxMod = native.get_num_vehicle_mods(veh, modType) - 1
        if maxMod >= 0 then native.set_vehicle_mod(veh, modType, maxMod, false) end
    end
    native.toggle_vehicle_mod(veh, 18, true)
    util.notify.success("当前载具已满改")
end

local function boostCurrentVehicle()
    local veh = vehicle.get_current()
    if veh == 0 or not native.does_entity_exist(veh) then
        util.notify.error("请先进入载具")
        return
    end
    native.set_vehicle_forward_speed(veh, 55.0)
    util.notify.success("短时推进已触发")
end

local function desktopUiPointIn(x, y, left, top, right, bottom)
    return x >= left and x <= right and y >= top and y <= bottom
end

local function desktopUiButton(mouseX, mouseY, x, y, width, height, label, active, callback)
    local theme = desktopUiThemes[desktopUiThemeIndex]
    local hovered = desktopUiPointIn(mouseX, mouseY, x, y, x + width, y + height)
    local buttonColor = active and theme.accent or (hovered and theme.hover or theme.control)
    local red, green, blue = buttonColor[1], buttonColor[2], buttonColor[3]
    ui.draw.rect_filled(x, y, x + width, y + height, red, green, blue, 235, 5)
    ui.draw.text_sz(x + 16, y + 10, label, 16, theme.text[1], theme.text[2], theme.text[3], 255)
    if hovered and ui.draw.is_mouse_clicked(0) then
        local ok, callbackError = pcall(callback)
        if not ok then
            util.notify.error("Zeus 操作失败")
            util.log_error("[Zeus UI] " .. tostring(callbackError))
        end
        return true
    end
    return false
end

local function desktopUiSection(x, y, width, title)
    local theme = desktopUiThemes[desktopUiThemeIndex]
    ui.draw.rect_filled(x, y, x + width, y + 34, theme.control[1], theme.control[2], theme.control[3], 255, 4)
    ui.draw.rect_filled(x, y, x + 4, y + 34, theme.accent[1], theme.accent[2], theme.accent[3], 255, 2)
    ui.draw.text_sz(x + 16, y + 8, title, 17, theme.text[1], theme.text[2], theme.text[3], 255)
end

local function desktopUiSetToggle(key, onCallback, offCallback)
    local enabled = not util.data.get_bool(key, false)
    util.data.set_bool(key, enabled)
    if enabled then
        onCallback()
    else
        offCallback()
    end
end

local function desktopUiDrawActions(mouse, x, y, width, buttonHeight, gap, title, actions)
    desktopUiSection(x, y - 52.0, width, title)
    local page = desktopUiPageByTab[desktopUiTab] or 1
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#actions / perPage))
    if page > totalPages then page = totalPages end
    desktopUiPageByTab[desktopUiTab] = page
    local buttonWidth = (width - gap) / 2.0
    local first = (page - 1) * perPage + 1
    for index = 0, perPage - 1 do
        local action = actions[first + index]
        if action then
            local column = index % 2
            local row = math.floor(index / 2)
            desktopUiButton(mouse.x, mouse.y, x + column * (buttonWidth + gap), y + row * (buttonHeight + gap), buttonWidth, buttonHeight, action.label, action.active and action.active() or false, action.callback)
        end
    end
    local navigationY = y + 4.0 * (buttonHeight + gap) + 4.0
    desktopUiButton(mouse.x, mouse.y, x, navigationY, 116.0, 34.0, "上一页", false, function()
        desktopUiPageByTab[desktopUiTab] = math.max(1, page - 1)
    end)
    desktopUiButton(mouse.x, mouse.y, x + width - 116.0, navigationY, 116.0, 34.0, "下一页", false, function()
        desktopUiPageByTab[desktopUiTab] = math.min(totalPages, page + 1)
    end)
    local theme = desktopUiThemes[desktopUiThemeIndex]
    local pageLabel = string.format("%d / %d", page, totalPages)
    local pageSize = ui.draw.calc_text_size(pageLabel, 14)
    ui.draw.text_sz(x + (width - pageSize.w) / 2.0, navigationY + 8.0, pageLabel, 14, theme.text[1], theme.text[2], theme.text[3], 255)
end

ui.on_render("zeus_desktop_ui", function()
    if not isLicenseAuthorized() then
        return
    end
    if ui.draw.is_key_pressed(0x76) then
        desktopUiOpen = not desktopUiOpen
    end
    if ui.draw.is_key_pressed(0x1B) then
        desktopUiOpen = false
        desktopUiDrag.active = false
    end
    if not desktopUiOpen then
        return
    end
    ui.draw.show_cursor(true, 218, 35, 58, 255, 1.0)

    local size = ui.draw.get_display_size()
    local mouse = ui.draw.get_mouse_pos()
    local scale = math.min(size.w / 1920.0, size.h / 1080.0)
    local panelWidth = desktopUiConfig.width * scale
    local panelHeight = desktopUiConfig.height * scale
    local left = (size.w - panelWidth) * desktopUiConfig.positionX
    local top = (size.h - panelHeight) * desktopUiConfig.positionY
    if desktopUiDrag.active then
        left = mouse.x - desktopUiDrag.offsetX
        top = mouse.y - desktopUiDrag.offsetY
        desktopUiConfig.positionX = math.max(0.0, math.min(1.0, left / math.max(size.w - panelWidth, 1.0)))
        desktopUiConfig.positionY = math.max(0.0, math.min(1.0, top / math.max(size.h - panelHeight, 1.0)))
    end
    left = math.max(0.0, math.min(size.w - panelWidth, left))
    top = math.max(0.0, math.min(size.h - panelHeight, top))
    local sidebar = 190.0 * scale
    local contentLeft = left + sidebar + 24.0 * scale
    local contentWidth = panelWidth - sidebar - 48.0 * scale
    local buttonWidth = (contentWidth - 16.0 * scale) / 2.0
    local buttonHeight = 48.0 * scale
    local gap = 12.0 * scale
    local theme = desktopUiThemes[desktopUiThemeIndex]

    ui.draw.rect_filled(left + 8.0 * scale, top + 10.0 * scale, left + panelWidth + 8.0 * scale, top + panelHeight + 10.0 * scale, 0, 0, 0, 120, 8)
    ui.draw.rect_filled(left, top, left + panelWidth, top + panelHeight, theme.panel[1], theme.panel[2], theme.panel[3], 248, 8)
    ui.draw.rect_filled(left, top, left + panelWidth, top + 64.0 * scale, theme.header[1], theme.header[2], theme.header[3], 255, 8)
    ui.draw.rect_filled(left + 20.0 * scale, top + 18.0 * scale, left + 25.0 * scale, top + 46.0 * scale, theme.accent[1], theme.accent[2], theme.accent[3], 255, 2)
    ui.draw.text_sz(left + 38.0 * scale, top + 16.0 * scale, "ZEUS", 24.0 * scale, theme.text[1], theme.text[2], theme.text[3], 255)
    ui.draw.text_sz(left + 118.0 * scale, top + 23.0 * scale, "CONTROL CENTER", 13.0 * scale, 148, 150, 158, 255)
    local closeLeft = left + panelWidth - 76.0 * scale
    local closeTop = top + 15.0 * scale
    local closeHovered = desktopUiPointIn(mouse.x, mouse.y, closeLeft, closeTop, left + panelWidth - 14.0 * scale, top + 50.0 * scale)
    ui.draw.rect_filled(closeLeft, closeTop, left + panelWidth - 14.0 * scale, top + 50.0 * scale, closeHovered and 90 or 45, 35, 48, 255, 4)
    ui.draw.text_sz(closeLeft + 14.0 * scale, closeTop + 8.0 * scale, "×", 22.0 * scale, 245, 245, 248, 255)
    if closeHovered and ui.draw.is_mouse_clicked(0) then
        desktopUiOpen = false
        desktopUiDrag.active = false
        return
    end

    local titleLeft = left
    local titleTop = top
    local titleRight = left + panelWidth - 84.0 * scale
    local titleBottom = top + 64.0 * scale
    if desktopUiConfig.draggable then
        if not desktopUiDrag.active and desktopUiPointIn(mouse.x, mouse.y, titleLeft, titleTop, titleRight, titleBottom)
            and ui.draw.is_mouse_clicked(0) then
            desktopUiDrag.active = true
            desktopUiDrag.offsetX = mouse.x - left
            desktopUiDrag.offsetY = mouse.y - top
        end
        if desktopUiDrag.active and not ui.draw.is_mouse_down(0) then
            desktopUiDrag.active = false
            util.data.set_float("zeus_ui_position_x", desktopUiConfig.positionX)
            util.data.set_float("zeus_ui_position_y", desktopUiConfig.positionY)
        end
    end

    ui.draw.rect_filled(left, top + 64.0 * scale, left + sidebar, top + panelHeight, theme.sidebar[1], theme.sidebar[2], theme.sidebar[3], 255, 0)
    ui.draw.text_sz(left + 24.0 * scale, top + 88.0 * scale, "功能分类", 13.0 * scale, 145, 148, 156, 255)
    for index, tab in ipairs(desktopUiTabs) do
        local tabY = top + (116.0 + (index - 1) * 52.0) * scale
        desktopUiButton(mouse.x, mouse.y, left + 16.0 * scale, tabY, sidebar - 32.0 * scale, 40.0 * scale, tab, desktopUiTab == index, function()
            desktopUiTab = index
        end)
    end
    ui.draw.text_sz(left + 24.0 * scale, top + panelHeight - 48.0 * scale, "授权状态: 正常", 13.0 * scale, 92, 205, 135, 255)

    if desktopUiTab == 1 then
        desktopUiDrawActions(mouse, contentLeft, top + 140.0 * scale, contentWidth, buttonHeight, gap, "玩家功能", {
            { label = "完全恢复", callback = function() native.set_entity_health(player.ped_id(), player.get_max_health(), 0); native.set_ped_armour(player.ped_id(), 100) end },
            { label = "清除通缉", callback = clearZeusWantedLevel },
            { label = "无敌模式", active = function() return util.data.get_bool("zeus_godmode", false) end, callback = function() desktopUiSetToggle("zeus_godmode", function() native.set_entity_invincible(player.ped_id(), true) end, function() native.set_entity_invincible(player.ped_id(), false) end) end },
            { label = "隐身模式", active = function() return util.data.get_bool("zeus_invisible", false) end, callback = function() desktopUiSetToggle("zeus_invisible", function() native.set_entity_visible(player.ped_id(), false, false) end, function() native.set_entity_visible(player.ped_id(), true, false) end) end },
            { label = "防摔倒", active = function() return util.data.get_bool("zeus_noragdoll", false) end, callback = function() desktopUiSetToggle("zeus_noragdoll", function() native.set_ped_can_ragdoll(player.ped_id(), false) end, function() native.set_ped_can_ragdoll(player.ped_id(), true) end) end },
            { label = "永不通缉", active = function() return util.data.get_bool("zeus_neverwanted", false) end, callback = function() desktopUiSetToggle("zeus_neverwanted", function() clearZeusWantedLevel(); native.set_max_wanted_level(0) end, function() native.set_max_wanted_level(5) end) end },
            { label = "满血", callback = function() native.set_entity_health(player.ped_id(), player.get_max_health(), 0) end },
            { label = "满护甲", callback = function() native.set_ped_armour(player.ped_id(), 100) end },
            { label = "伪造通缉 +1", callback = function() local level = util.data.get_int("zeus_fakewanted", 0) + 1; if level > 5 then level = 0 end; util.data.set_int("zeus_fakewanted", level); native.set_fake_wanted_level(level) end }
        })
    elseif desktopUiTab == 2 then
        desktopUiDrawActions(mouse, contentLeft, top + 140.0 * scale, contentWidth, buttonHeight, gap, "移动与状态", {
            { label = "无限耐力", active = function() return util.data.get_bool("zeus_stamina", false) end, callback = function() util.data.set_bool("zeus_stamina", not util.data.get_bool("zeus_stamina", false)) end },
            { label = "超级跳跃", active = function() return util.data.get_bool("zeus_superjump", false) end, callback = function() util.data.set_bool("zeus_superjump", not util.data.get_bool("zeus_superjump", false)) end },
            { label = "快速奔跑", active = function() return util.data.get_bool("zeus_runfast", false) end, callback = function() util.data.set_bool("zeus_runfast", not util.data.get_bool("zeus_runfast", false)) end },
            { label = "飞行模式", active = function() return util.data.get_bool("zeus_flymode", false) end, callback = function() desktopUiSetToggle("zeus_flymode", function() end, function() native.set_entity_collision(player.ped_id(), true, true) end) end },
            { label = "穿墙模式", active = function() return util.data.get_bool("zeus_noclip", false) end, callback = function() desktopUiSetToggle("zeus_noclip", function() end, function() native.set_entity_collision(player.ped_id(), true, true) end) end },
            { label = "向前移动 10 米", callback = function() local pos = player.get_coords(); local heading = player.get_heading() * 3.14159265 / 180.0; player.set_coords(pos.x - math.sin(heading) * 10.0, pos.y + math.cos(heading) * 10.0, pos.z) end },
            { label = "向上移动 10 米", callback = function() local pos = player.get_coords(); player.set_coords(pos.x, pos.y, pos.z + 10.0) end },
            { label = "清理角色状态", callback = function() local ped = player.ped_id(); native.clear_ped_tasks_immediately(ped); native.clear_ped_blood_damage(ped); native.clear_ped_env_dirt(ped); native.clear_ped_decorations(ped) end },
            { label = "自杀", callback = function() native.set_entity_health(player.ped_id(), 0, 0) end }
        })
    elseif desktopUiTab == 3 then
        local actions = {
            { label = "传送到路点", callback = function() if player.teleport_to_waypoint() then util.notify.success("已传送到路点") else util.notify.error("请先设置地图路点") end end },
            { label = "查看当前坐标", callback = function() local pos = player.get_coords(); util.notify.info(string.format("X: %.1f Y: %.1f Z: %.1f", pos.x, pos.y, pos.z), 4000) end },
            { label = "保存坐标到日志", callback = function() local pos = player.get_coords(); print(string.format("[Zeus 坐标] X=%.2f, Y=%.2f, Z=%.2f, H=%.1f", pos.x, pos.y, pos.z, player.get_heading())) end },
            { label = "国际机场", callback = function() player.set_coords(-1036.0, -2735.0, 13.8) end },
            { label = "军事基地", callback = function() player.set_coords(-2064.0, 3160.0, 32.8) end },
            { label = "市中心花园银行", callback = function() player.set_coords(-75.0, -806.0, 326.0) end },
            { label = "好麦坞山", callback = function() player.set_coords(-570.0, 880.0, 237.0) end },
            { label = "名钻赌场", callback = function() player.set_coords(918.0, 43.0, 80.0) end },
            { label = "本尼改装工坊", callback = function() player.set_coords(-205.0, -1307.0, 31.0) end }
        }
        desktopUiDrawActions(mouse, contentLeft, top + 140.0 * scale, contentWidth, buttonHeight, gap, "传送功能", actions)
    elseif desktopUiTab == 4 then
        local actions = {
            { label = "全部武器和弹药", callback = function() for _, item in ipairs(ZeusWeapons) do weapon.give(util.joaat(item.hash), 9999) end end },
            { label = "常用战斗套装", callback = function() for _, hash in ipairs({ "WEAPON_APPISTOL", "WEAPON_SMG", "WEAPON_ASSAULTRIFLE", "WEAPON_CARBINERIFLE", "WEAPON_PUMPSHOTGUN", "WEAPON_HEAVYSNIPER", "WEAPON_RPG", "WEAPON_GRENADE", "WEAPON_STICKYBOMB" }) do weapon.give(util.joaat(hash), 9999) end end },
            { label = "清除所有武器", callback = weapon.remove_all },
            { label = "无限弹药", active = function() return util.data.get_bool("zeus_ammo", false) end, callback = function() util.data.set_bool("zeus_ammo", not util.data.get_bool("zeus_ammo", false)) end }
        }
        for _, item in ipairs(ZeusWeapons) do
            local weaponItem = item
            table.insert(actions, { label = weaponItem.name, callback = function() weapon.give(util.joaat(weaponItem.hash), 9999) end })
        end
        desktopUiDrawActions(mouse, contentLeft, top + 140.0 * scale, contentWidth, buttonHeight, gap, "武器管理", actions)
    elseif desktopUiTab == 5 then
        local actions = {
            { label = "修复当前载具", callback = function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_vehicle_fixed(veh); native.set_vehicle_dirt_level(veh, 0.0) else util.notify.error("请先进入载具") end end },
            { label = "翻正当前载具", callback = function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_vehicle_on_ground_properly(veh, 5.0) else util.notify.error("请先进入载具") end end },
            { label = "一键载具满改", callback = maximizeCurrentVehicle },
            { label = "短时推进", callback = boostCurrentVehicle },
            { label = "载具无敌", active = function() return util.data.get_bool("zeus_veh_god", false) end, callback = function() desktopUiSetToggle("zeus_veh_god", function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_entity_invincible(veh, true) end end, function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_entity_invincible(veh, false) end end) end },
            { label = "无限燃料", active = function() return util.data.get_bool("zeus_veh_fuel", false) end, callback = function() util.data.set_bool("zeus_veh_fuel", not util.data.get_bool("zeus_veh_fuel", false)) end },
            { label = "防刺轮胎", active = function() return util.data.get_bool("zeus_veh_bullet", false) end, callback = function() desktopUiSetToggle("zeus_veh_bullet", function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_vehicle_tyres_can_burst(veh, false) end end, function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_vehicle_tyres_can_burst(veh, true) end end) end },
            { label = "满油", callback = function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_vehicle_fuel_tank_health(veh, 100.0) end end },
            { label = "安装涡轮", callback = function() local veh = vehicle.get_current(); if veh ~= 0 then native.toggle_vehicle_mod(veh, 18, true) end end },
            { label = "切换车窗贴膜", callback = function() local veh = vehicle.get_current(); if veh ~= 0 then local tint = util.data.get_int("zeus_veh_tint", 0) + 1; if tint > 3 then tint = 0 end; util.data.set_int("zeus_veh_tint", tint); native.set_vehicle_window_tint(veh, tint) end end },
            { label = "新载具自动无敌", active = function() return util.data.get_bool("zeus_spawn_god", false) end, callback = function() util.data.set_bool("zeus_spawn_god", not util.data.get_bool("zeus_spawn_god", false)) end },
            { label = "删除当前载具", callback = function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_entity_as_mission_entity(veh, true, true); native.delete_entity(veh) else util.notify.error("请先进入载具") end end }
        }
        for _, paint in ipairs({ { "纯黑", 0 }, { "白色", 111 }, { "方程式红", 29 }, { "日落橙", 35 }, { "赛车黄", 89 }, { "亮蓝色", 64 }, { "绿色", 53 }, { "军绿色", 55 }, { "午夜紫", 70 }, { "亮粉色", 136 }, { "金色", 98 }, { "铬合金", 120 }, { "哑光黑", 147 }, { "哑光红", 154 } }) do
            local paintName, paintIndex = paint[1], paint[2]
            table.insert(actions, { label = "喷漆: " .. paintName, callback = function() local veh = vehicle.get_current(); if veh ~= 0 then native.set_vehicle_colours(veh, paintIndex, paintIndex) end end })
        end
        for _, item in ipairs(ZeusVehicles) do
            local vehicleItem = item
            table.insert(actions, { label = vehicleItem.name, callback = function() vehicle.spawn(util.joaat(vehicleItem.model), true); local veh = vehicle.get_current(); if veh ~= 0 and util.data.get_bool("zeus_spawn_god", false) then native.set_entity_invincible(veh, true); native.set_vehicle_fixed(veh); native.set_vehicle_dirt_level(veh, 0.0) end end })
        end
        desktopUiDrawActions(mouse, contentLeft, top + 140.0 * scale, contentWidth, buttonHeight, gap, "载具功能与生成器", actions)
    elseif desktopUiTab == 6 then
        local actions = {
            { label = "冻结时间", active = function() return util.data.get_bool("zeus_freeze_time", false) end, callback = function() desktopUiSetToggle("zeus_freeze_time", function() native.pause_clock(true) end, function() native.pause_clock(false) end) end },
            { label = "锁定天气", active = function() return util.data.get_bool("zeus_lockweather", false) end, callback = function() util.data.set_bool("zeus_lockweather", not util.data.get_bool("zeus_lockweather", false)) end },
            { label = "00:00 深夜", callback = function() setZeusClock(0, 0) end },
            { label = "06:00 日出", callback = function() setZeusClock(6, 0) end },
            { label = "12:00 中午", callback = function() setZeusClock(12, 0) end },
            { label = "18:00 日落", callback = function() setZeusClock(18, 0) end },
            { label = "21:00 夜晚", callback = function() setZeusClock(21, 0) end },
            { label = "小时 +1", callback = function() local hour = util.data.get_int("zeus_hr", 12) + 1; if hour > 23 then hour = 0 end; util.data.set_int("zeus_hr", hour); setZeusClock(hour, util.data.get_int("zeus_min", 0)) end },
            { label = "分钟 +5", callback = function() local minute = util.data.get_int("zeus_min", 0) + 5; if minute > 59 then minute = 0 end; util.data.set_int("zeus_min", minute); setZeusClock(util.data.get_int("zeus_hr", 12), minute) end },
            { label = "城市停电", active = function() return util.data.get_bool("zeus_blackout", false) end, callback = function() desktopUiSetToggle("zeus_blackout", function() native.set_artificial_lights_state(true) end, function() native.set_artificial_lights_state(false) end) end },
            { label = "月球重力", active = function() return util.data.get_bool("zeus_lowgrav", false) end, callback = function() desktopUiSetToggle("zeus_lowgrav", function() native.set_gravity_level(1) end, function() native.set_gravity_level(9.81) end) end },
            { label = "慢动作", active = function() return util.data.get_bool("zeus_slowmo", false) end, callback = function() desktopUiSetToggle("zeus_slowmo", function() native.set_time_scale(0.3) end, function() native.set_time_scale(1.0) end) end },
            { label = "清除附近车辆", callback = function() local pos = player.get_coords(); native.clear_area_of_vehicles(pos.x, pos.y, pos.z, 150.0, true, true, true, true, true, 0) end },
            { label = "清除附近 NPC", callback = function() local pos = player.get_coords(); native.clear_area_of_peds(pos.x, pos.y, pos.z, 150.0, 0) end },
            { label = "清除附近警察", callback = function() local pos = player.get_coords(); native.clear_area_of_cops(pos.x, pos.y, pos.z, 200.0, 0) end },
            { label = "清除附近爆炸物", callback = function() local pos = player.get_coords(); native.clear_area_of_projectiles(pos.x, pos.y, pos.z, 200.0, 0) end },
            { label = "清除一切", callback = function() local pos = player.get_coords(); native.clear_area_of_everything(pos.x, pos.y, pos.z, 300.0, true, true, true, true) end },
            { label = "制造大爆炸", callback = function() local pos = player.get_coords(); native.add_explosion(pos.x, pos.y, pos.z, 0, 10.0, true, false, 1.0, false) end }
        }
        for index, weather in ipairs(WeatherList) do
            local weatherName, weatherValue = WeatherNames[index], weather
            table.insert(actions, { label = weatherName, callback = function() native.set_weather_type_now_persist(weatherValue) end })
        end
        desktopUiDrawActions(mouse, contentLeft, top + 140.0 * scale, contentWidth, buttonHeight, gap, "世界功能", actions)
    elseif desktopUiTab == 7 then
        desktopUiSection(contentLeft, top + 88.0 * scale, contentWidth, "扫描与界面设置")
        local y = top + 140.0 * scale
        desktopUiButton(mouse.x, mouse.y, contentLeft, y, buttonWidth, buttonHeight, "镜头选择目标", false, useAimedEntityIfAvailable)
        desktopUiButton(mouse.x, mouse.y, contentLeft + buttonWidth + gap, y, buttonWidth, buttonHeight, "清除目标", false, function()
            scanTarget = 0
            validateScanTarget()
        end)
        y = y + buttonHeight + gap
        desktopUiButton(mouse.x, mouse.y, contentLeft, y, buttonWidth, buttonHeight, "NPC 眩晕", false, function()
            local ped = requireNpcScanTarget()
            if ped ~= 0 then native.set_ped_to_ragdoll(ped, 3500, 3500, 0, false, false, false) end
        end)
        desktopUiButton(mouse.x, mouse.y, contentLeft + buttonWidth + gap, y, buttonWidth, buttonHeight, "NPC 逃跑", false, function()
            local ped = requireNpcScanTarget()
            if ped ~= 0 then native.task_smart_flee_ped(ped, player.ped_id(), 150.0, 15000, false, false) end
        end)
        y = y + buttonHeight + gap
        desktopUiButton(mouse.x, mouse.y, contentLeft, y, buttonWidth, buttonHeight, "冻结 NPC", false, function()
            local ped = requireNpcScanTarget()
            if ped ~= 0 then native.freeze_entity_position(ped, true) end
        end)
        desktopUiButton(mouse.x, mouse.y, contentLeft + buttonWidth + gap, y, buttonWidth, buttonHeight, "解除冻结", false, function()
            local ped = requireNpcScanTarget()
            if ped ~= 0 then native.freeze_entity_position(ped, false) end
        end)
        y = y + buttonHeight + gap
        desktopUiButton(mouse.x, mouse.y, contentLeft, y, buttonWidth, buttonHeight, "关闭全部开关", false, function()
            local keys = { "zeus_godmode", "zeus_invisible", "zeus_noragdoll", "zeus_neverwanted", "zeus_stamina", "zeus_superjump", "zeus_runfast", "zeus_flymode", "zeus_noclip", "zeus_ammo", "zeus_spawn_god", "zeus_veh_god", "zeus_veh_fuel", "zeus_veh_bullet", "zeus_lockweather", "zeus_freeze_time", "zeus_lowgrav", "zeus_slowmo", "zeus_blackout" }
            for _, key in ipairs(keys) do util.data.set_bool(key, false) end
            local ped = player.ped_id()
            native.set_entity_invincible(ped, false)
            native.set_entity_visible(ped, true, false)
            native.set_ped_can_ragdoll(ped, true)
            native.set_max_wanted_level(5)
            native.pause_clock(false)
            native.set_entity_collision(ped, true, true)
            native.set_gravity_level(9.81)
            native.set_time_scale(1.0)
            native.set_artificial_lights_state(false)
            util.notify.success("已关闭全部 Zeus 开关")
        end)
        desktopUiButton(mouse.x, mouse.y, contentLeft + buttonWidth + gap, y, buttonWidth, buttonHeight, "切换主题", false, function()
            desktopUiThemeIndex = desktopUiThemeIndex % #desktopUiThemes + 1
            util.data.set_int("zeus_ui_theme", desktopUiThemeIndex)
        end)
        validateScanTarget()
        ui.draw.text_sz(contentLeft, top + 350.0 * scale, "目标: " .. scanTargetName, 16.0 * scale, theme.text[1], theme.text[2], theme.text[3], 255)
        ui.draw.text_sz(contentLeft, top + 382.0 * scale, string.format("类型: %s    距离: %.1f m", scanTargetKind, scanTargetDistance), 15.0 * scale, 160, 168, 178, 255)
        ui.draw.text_sz(contentLeft, top + 430.0 * scale, "主题: " .. desktopUiThemes[desktopUiThemeIndex].name, 15.0 * scale, theme.text[1], theme.text[2], theme.text[3], 255)
        ui.draw.text_sz(contentLeft, top + 462.0 * scale, "拖动顶部标题栏调整位置", 14.0 * scale, 160, 168, 178, 255)
    else
        desktopUiSection(contentLeft, top + 88.0 * scale, contentWidth, "关于 Zeus")
        ui.draw.text_sz(contentLeft, top + 150.0 * scale, "Zeus Control Center", 24.0 * scale, 235, 235, 240, 255)
        ui.draw.text_sz(contentLeft, top + 198.0 * scale, "YARI Lua Engine", 16.0 * scale, 165, 168, 176, 255)
        ui.draw.text_sz(contentLeft, top + 232.0 * scale, "授权状态正常", 16.0 * scale, 95, 208, 138, 255)
        ui.draw.text_sz(contentLeft, top + 286.0 * scale, "按 F7 显示或隐藏控制面板", 15.0 * scale, 175, 178, 186, 255)
    end
end)

-- ============================================================================
--  12. 一级菜单渲染
-- ============================================================================
setAuthorizedRender(zeus_player, function()
    ui.add_submenu("防护与通缉", sub_protect, "无敌/隐身/通缉", false)
    ui.add_submenu("治疗与护甲", sub_heal,    "血量护甲恢复", false)
    ui.add_submenu("传送功能",   sub_tp,       "路点传送/常用地点", false)
    ui.add_submenu("武器管理",   sub_weapons,  "武器列表/套装", false)
    ui.add_submenu("移动与状态", sub_movement, "耐力/跳跃/飞行/穿墙", false)
end)

setAuthorizedRender(zeus_veh, function()
    ui.add_submenu("载具生成器", sub_veh_spawn, "29种载具一键生成", false)
    ui.add_submenu("载具修改",   sub_veh_mod,   "修复/改装/喷漆", false)
end)

setAuthorizedRender(zeus_world, function()
    ui.add_submenu("天气控制",   sub_weather, "13种天气切换", false)
    ui.add_submenu("时间控制",   sub_time,    "冻结/预设/自定义", false)
    ui.add_submenu("环境清除",   sub_env,     "清除NPC/车辆/爆炸", false)
end)

-- ============================================================================
--  13. 根菜单 (zeus_root)
-- ============================================================================
setAuthorizedRender(zeus_root, function()
    ui.add_separator("Zeus Menu v1.1")

    ui.add_option(desktopUiOpen and "关闭 Zeus 控制面板" or "打开 Zeus 控制面板", function()
        desktopUiOpen = not desktopUiOpen
    end, nil, "也可以按 F7 显示或隐藏。")

    ui.add_int_slider("控制面板宽度", "zeus_ui_width_slider", 720, 1200, 20, function(value)
        desktopUiConfig.width = value
        util.data.set_float("zeus_ui_width", value)
    end, "修改后立即生效并自动保存。")

    ui.add_int_slider("控制面板高度", "zeus_ui_height_slider", 480, 760, 20, function(value)
        desktopUiConfig.height = value
        util.data.set_float("zeus_ui_height", value)
    end, "修改后立即生效并自动保存。")

    ui.add_option("切换控制面板主题", function()
        desktopUiThemeIndex = desktopUiThemeIndex % #desktopUiThemes + 1
        util.data.set_int("zeus_ui_theme", desktopUiThemeIndex)
        util.notify.success("主题: " .. desktopUiThemes[desktopUiThemeIndex].name)
    end)

    ui.add_option("重置控制面板布局", function()
        desktopUiConfig.width = 900.0
        desktopUiConfig.height = 590.0
        desktopUiConfig.positionX = 0.5
        desktopUiConfig.positionY = 0.5
        util.data.set_float("zeus_ui_width", desktopUiConfig.width)
        util.data.set_float("zeus_ui_height", desktopUiConfig.height)
        util.data.set_float("zeus_ui_position_x", desktopUiConfig.positionX)
        util.data.set_float("zeus_ui_position_y", desktopUiConfig.positionY)
        util.notify.success("控制面板布局已重置")
    end)

    ui.add_submenu("玩家功能", zeus_player, "无敌/治疗/武器/传送/飞行", false)
    ui.add_submenu("载具功能", zeus_veh,    "生成器/修复/改装/喷漆", false)
    ui.add_submenu("世界功能", zeus_world,  "天气/时间/清除/重力", false)
    ui.add_submenu("关于 Zeus", zeus_about, "版本与帮助", false)

    ui.add_separator("快捷操作")

    ui.add_option("一键全能 (God+Heal+Armor+清通缉)", function()
        local ped = player.ped_id()
        native.set_entity_invincible(ped, true)
        native.set_entity_health(ped, player.get_max_health(), 0)
        native.set_ped_armour(ped, 100)
        native.clear_player_wanted_level(player.id())
        util.data.set_bool("zeus_godmode", true)
        util.notify.success("全能模式已激活！")
    end)

    ui.add_option("关闭所有 Zeus 开关", function()
        local keys = {
            "zeus_godmode","zeus_invisible","zeus_noragdoll","zeus_neverwanted",
            "zeus_stamina","zeus_superjump","zeus_runfast","zeus_flymode",
            "zeus_noclip","zeus_ammo",
            "zeus_spawn_god","zeus_veh_god",
            "zeus_veh_fuel","zeus_veh_bullet","zeus_lockweather","zeus_freeze_time",
            "zeus_lowgrav","zeus_slowmo","zeus_blackout"
        }
        for _, k in ipairs(keys) do util.data.set_bool(k, false) end
        local ped = player.ped_id()
        native.set_entity_invincible(ped, false)
        native.set_entity_visible(ped, true, false)
        native.set_ped_can_ragdoll(ped, true)
        native.set_max_wanted_level(5)
        native.pause_clock(false)
        native.set_entity_collision(ped, true, true)
        native.set_gravity_level(9.81)
        native.set_time_scale(1.0)
        native.set_artificial_lights_state(false)
        util.notify.success("已全部关闭！")
    end)
end)

-- ============================================================================
--  14. 关于页面
-- ============================================================================
setAuthorizedRender(zeus_about, function()
    ui.add_separator("Zeus Menu v1.1")
    ui.add_option("版本: 1.1.0 (修复版)", function() end)
    ui.add_option("框架: YARI Lua Engine", function() end)
    ui.add_option("平台: GTA V SP", function() end)
    ui.add_separator("操作")
    ui.add_option("打开: Miscellaneous -> Zeus Menu", function() end)
    ui.add_option("路径: Documents\\yari\\Grand Theft Auto V\\lua\\", function() end)
end)

-- ============================================================================
--  15. 后台循环 (util.loop.register)
-- ============================================================================

-- 永不通缉
registerAuthorizedLoop("zeus_loop_neverwanted", function()
    if util.data.get_bool("zeus_neverwanted", false) then
        native.clear_player_wanted_level(player.id())
        native.set_max_wanted_level(0)
    end
end)

-- 无限耐力
registerAuthorizedLoop("zeus_loop_stamina", function()
    if util.data.get_bool("zeus_stamina", false) then
        native.restore_player_stamina(player.id(), 100.0)
        native.reset_player_stamina(player.id())
    end
end)

-- 超级跳跃
registerAuthorizedLoop("zeus_loop_superjump", function()
    if util.data.get_bool("zeus_superjump", false) then
        native.set_super_jump_this_frame(player.id())
    end
end)

-- 快速奔跑（通过叠加实体速度模拟）
registerAuthorizedLoop("zeus_loop_runfast", function()
    if util.data.get_bool("zeus_runfast", false) then
        local ped = player.ped_id()
        if not native.is_ped_jumping(ped) and not native.is_ped_ragdoll(ped) then
            if native.is_control_pressed(0, 32) then
                local heading = player.get_heading()
                local rad = heading * 3.14159265 / 180.0
                local curSpeed = native.get_entity_speed(ped)
                if curSpeed < 25.0 then
                    native.set_entity_velocity(
                        ped,
                        -math.sin(rad) * (curSpeed + 0.5),
                         math.cos(rad) * (curSpeed + 0.5),
                        0
                    )
                end
            end
        end
    end
end)

-- 无限弹药
registerAuthorizedLoop("zeus_loop_ammo", function()
    if util.data.get_bool("zeus_ammo", false) then
        local ped = player.ped_id()
        local curWep = weapon.get_current()
        native.set_ped_infinite_ammo_clip(ped, true)
        native.set_ped_infinite_ammo(ped, true, curWep)
    end
end)

-- 载具无限燃料
registerAuthorizedLoop("zeus_loop_veh_fuel", function()
    if util.data.get_bool("zeus_veh_fuel", false) then
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.set_vehicle_fuel_tank_health(veh, 100.0)
        end
    end
end)

-- 飞行模式
registerAuthorizedLoop("zeus_loop_fly", function()
    if util.data.get_bool("zeus_flymode", false) then
        local ped = player.ped_id()
        if native.is_control_pressed(0, 21) then
            local pos = player.get_coords()
            player.set_coords(pos.x, pos.y, pos.z + 0.8)
        end
        if native.is_control_pressed(0, 36) then
            local pos = player.get_coords()
            player.set_coords(pos.x, pos.y, pos.z - 0.5)
        end
        if native.is_control_pressed(0, 32) then
            local pos = player.get_coords()
            local heading = player.get_heading()
            local rad = heading * 3.14159265 / 180.0
            player.set_coords(
                pos.x - math.sin(rad) * 0.6,
                pos.y + math.cos(rad) * 0.6,
                pos.z
            )
        end
        native.set_entity_velocity(ped, 0, 0, 0)
        native.set_entity_collision(ped, false, false)
    end
end)

-- 穿墙 NoClip
registerAuthorizedLoop("zeus_loop_noclip", function()
    if util.data.get_bool("zeus_noclip", false) then
        local ped = player.ped_id()
        native.set_entity_collision(ped, false, false)
    elseif not util.data.get_bool("zeus_flymode", false) then
        local ped = player.ped_id()
        native.set_entity_collision(ped, true, true)
    end
end)

-- 载具无敌持续生效
registerAuthorizedLoop("zeus_loop_veh_god", function()
    if util.data.get_bool("zeus_veh_god", false) then
        local veh = vehicle.get_current()
        if veh ~= 0 then
            native.set_entity_invincible(veh, true)
        end
    end
end)

local function disableZeusFeatures()
    local keys = {
        "zeus_godmode", "zeus_invisible", "zeus_noragdoll", "zeus_neverwanted",
        "zeus_stamina", "zeus_superjump", "zeus_runfast", "zeus_ammo",
        "zeus_veh_fuel", "zeus_flymode", "zeus_noclip", "zeus_veh_god",
        "zeus_veh_bullet", "zeus_freeze_time", "zeus_lowgrav", "zeus_slowmo",
        "zeus_blackout"
    }
    for _, key in ipairs(keys) do
        util.data.set_bool(key, false)
    end
    local ped = player.ped_id()
    if ped and ped ~= 0 then
        native.set_entity_invincible(ped, false)
        native.set_entity_visible(ped, true, false)
        native.set_ped_can_ragdoll(ped, true)
        native.set_entity_collision(ped, true, true)
        native.set_ped_infinite_ammo_clip(ped, false)
        native.set_ped_infinite_ammo(ped, false, weapon.get_current())
    end
    local veh = vehicle.get_current()
    if veh and veh ~= 0 then
        native.set_entity_invincible(veh, false)
        native.set_vehicle_tyres_can_burst(veh, true)
    end
    native.set_max_wanted_level(5)
    native.pause_clock(false)
    native.set_gravity_level(9.81)
    native.set_time_scale(1.0)
    native.set_artificial_lights_state(false)
    desktopUiOpen = false
end

util.loop.register("zeus_license_heartbeat", function()
    if not licenseAuthorized or util.get_tick_count() < nextHeartbeatAt then
        return
    end
    nextHeartbeatAt = util.get_tick_count() + 300000
    util.curl.post(licenseHeartbeatUrl, "", {
        ["Authorization"] = "Bearer " .. licenseToken,
        ["User-Agent"] = "Zeus-Yari/1.1"
    }, function(response)
        if type(response) ~= "table" then
            licenseAuthorized = false
            licenseToken = ""
            licenseExpires = 0
            disableZeusFeatures()
            util.notify.error("Zeus 授权服务器连接失败，功能已关闭")
            util.log_error("[Zeus License] Heartbeat connection failed")
            return
        end
        local body = tostring(response.body or "")
        local expires = tonumber(body:match('"expires"%s*:%s*(%d+)'))
        if response.status_code == 200 and expires then
            licenseExpires = expires
            util.log_info("[Zeus License] Heartbeat OK")
            return
        end
        licenseAuthorized = false
        licenseToken = ""
        licenseExpires = 0
        disableZeusFeatures()
        util.notify.error("Zeus 授权已失效，功能已关闭")
        util.log_error("[Zeus License] Heartbeat denied: " .. tostring(response.status_code))
    end)
end)

-- ============================================================================
--  完成
-- ============================================================================
util.notify.success("Zeus Menu v1.1 已加载！")
util.log("[Zeus Menu] v1.1 修复版初始化完成")
print("[Zeus Menu] v1.1 加载成功")
