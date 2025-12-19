-- BattleUtils.lua
local BattleUtils = {}

-- 切换到血量最高的宠物
function BattleUtils:SwitchToHighestHealthPet()
    if not C_PetBattles.IsInBattle() then
        return false
    end
    
    local maxHealth = 0
    local bestPetIndex = 0
    
    -- 检查所有友方宠物
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ALLY) do
        local health = C_PetBattles.GetHealth(LE_BATTLE_PET_ALLY, petIndex) 
        
        if health > maxHealth then
            maxHealth = health
            bestPetIndex = petIndex
        end
    end
    print("SwitchToHighestHealthPet ", bestPetIndex)
    C_PetBattles.ChangePet(bestPetIndex)
end

-- 切换到血量最高的宠物
function BattleUtils:GetWeatherDuration(weatherId)
    local id, _, duration = C_PetBattles.GetAuraInfo(LE_BATTLE_PET_WEATHER, 0, 1)
    print("GetAuraInfo", id, duration)
    if weatherId and id and (id == weatherId) then
        return duration
    end
    return 0
end

-- 获取宠物品质名称
function BattleUtils:GetPetQualityName(quality)
    local names = {
        [0] = "粗糙",
        [1] = "普通",
        [2] = "优秀",
        [3] = "精良",
        [4] = "史诗",
        [5] = "传奇",
    }
    return names[quality] or "未知"
end

_G.PPBestBattleUtils = BattleUtils