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