local _, PPBest = ...

PPBestConfig = PPBestConfig or {
    hotkey = "F8",
    mode = "default", --default,ai
    assistTarget = "",
    enableLogWindow = false,
}

local Const = {
    MODE_DEFAULT = "default",
    MODE_AI = "AI",
    MODE_ASSIST = "assist",
    MODE_WANT_EXP = "want_exp",
    MODE_WANT_WIN = "want_win",
    MODE_WANT_PET_LEVEL = "want_pet_level"
}

-- 传入mode是否是互刷的主要方
function Const.isCooperateMainMode(mode)
    return mode == Const.MODE_WANT_EXP or mode == Const.MODE_WANT_WIN or mode == Const.MODE_WANT_PET_LEVEL
end

PPBest.Const = Const

local Bit = {}

function Bit.band(x, y)
    local result = 0
    local bitval = 1
    if x == nil or y == nil then
        return 0
    end
    while x > 0 and y > 0 do
        if x % 2 == 1 and y % 2 == 1 then
            result = result + bitval
        end
        bitval = bitval * 2
        x = math.floor(x / 2)
        y = math.floor(y / 2)
    end
    return result
end

function Bit.bor(...)  
    local args = {...}
    local count = #args
    if count == 0 then
        return 0
    elseif count == 1 then
        return args[1]
    end
    
    local result = args[1]
    for i = 2, count do
        local y = args[i]
        local x = result
        local temp = 0
        local bitval = 1
        while x > 0 or y > 0 do
            if x % 2 == 1 or y % 2 == 1 then
                temp = temp + bitval
            end
            bitval = bitval * 2
            x = math.floor(x / 2)
            y = math.floor(y / 2)
        end
        result = temp
    end
    return result
end

function Bit.bxor(x, y)
    local result = 0
    local bitval = 1
    while x > 0 or y > 0 do
        if (x % 2) ~= (y % 2) then
            result = result + bitval
        end
        bitval = bitval * 2
        x = math.floor(x / 2)
        y = math.floor(y / 2)
    end
    return result
end

function Bit.lshift(x, n)
    return x * (2 ^ n)
end

function Bit.rshift(x, n)
    return math.floor(x / (2 ^ n))
end

function Bit.bnot(x)
    return Bit.bxor(x, 0xFFFFFFFF)  -- 32位取反 
end

PPBest.Bit = Bit

local Utils = {}

-- 辅助函数：深拷贝表
function Utils.deepcopy(object)
    local lookup_table = {} -- 用于记录已复制的表，防止循环引用
    
    local function _copy(obj)
        if type(obj) ~= "table" then
            return obj -- 非表类型直接返回
        elseif lookup_table[obj] then
            return lookup_table[obj] -- 如果已复制过，直接返回副本
        end
        
        local new_table = {}
        lookup_table[obj] = new_table -- 记录已复制的表
        
        for k, v in pairs(obj) do
            new_table[_copy(k)] = _copy(v) -- 递归复制键和值
        end
        
        return setmetatable(new_table, getmetatable(obj)) -- 复制元表
    end
    
    return _copy(object)
end

PPBest.Utils = Utils