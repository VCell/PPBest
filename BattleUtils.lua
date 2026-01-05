-- BattleUtils.lua
local BattleUtils = {
    WEATHER_ID_ARCANE_STORM = 590, 
    WEATHER_ID_DARKNESS = 257, 
    
    AURA_ID_UNDEAD = 242,

    TYPE_HUMANOID = 1,
    TYPE_DRAGONKIN = 2,
    TYPE_FLYING = 3,
    TYPE_UNDEAD = 4,
    TYPE_CRITTER = 5,
    TYPE_MAGIC = 6,
    TYPE_ELEMENTAL = 7,
    TYPE_BEAST = 8,
    TYPE_AQUATIC = 9,
    TYPE_MECHANICAL = 10,

    debug = false,
}

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
    --print("SwitchToHighestHealthPet ", bestPetIndex)
    C_PetBattles.ChangePet(bestPetIndex)
end

-- 按默认顺序切换宠物
function BattleUtils:SwitchPetByOrder()
    if not C_PetBattles.IsInBattle() then
        return false
    end
    
    -- 检查所有友方宠物
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ALLY) do
        local health = C_PetBattles.GetHealth(LE_BATTLE_PET_ALLY, petIndex) 
        
        if C_PetBattles.CanPetSwapIn(petIndex) then
            C_PetBattles.ChangePet(petIndex)
        end
    end 
end

-- 切换到血量最高的宠物
function BattleUtils:GetWeatherDuration(weatherId)
    local id, _, duration = C_PetBattles.GetAuraInfo(LE_BATTLE_PET_WEATHER, 0, 1)
    --print("GetAuraInfo", id, duration)
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

function BattleUtils:UseSkillByPriority(priorityArray)

    petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
    
    if petIndex == 0 then
        print("GetActivePet == 0")
        return false
    end
    
    -- 按照优先级顺序检查技能是否可用
    for _, skillSlot in ipairs(priorityArray) do
        local abilityID, abilityName = C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, skillSlot)
        
        if abilityID then
            local isUsable, currentCooldown, currentLockdown = 
                C_PetBattles.GetAbilityState(LE_BATTLE_PET_ALLY, petIndex, skillSlot)
            
            if isUsable then
                -- 执行技能
                C_PetBattles.UseAbility(skillSlot)
                return true
            end
        end
    end
    C_PetBattles.SkipTurn()
    return false
end


function BattleUtils:IsUndeadRound()
    petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ENEMY)
    
    if petIndex == 0 then
        print("GetActivePet == 0")
        return false
    end
    
    -- 获取宠物的所有光环效果
    for auraIndex = 1, C_PetBattles.GetNumAuras(LE_BATTLE_PET_ENEMY, petIndex) do
        local auraId = C_PetBattles.GetAuraInfo(LE_BATTLE_PET_ENEMY, petIndex, auraIndex)
        if auraId == self.AURA_ID_UNDEAD then
            return true
        end
    end
    return false
end

function BattleUtils:GetEnemyPetType()
    petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ENEMY)
    if petIndex == 0 then
        print("GetActivePet == 0")
        return false
    end
    return C_PetBattles.GetPetType(LE_BATTLE_PET_ENEMY, petIndex)
end

function BattleUtils:GetAliveNum(owner)
    local count = 0

    for petIndex = 1, C_PetBattles.GetNumPets(owner) do
        local health = C_PetBattles.GetHealth(LE_BATTLE_PET_ALLY, petIndex) 
        if health > 0 then
            count = count + 1
        end
    end

    return count
end

function BattleUtils:IsSameTeam(petIdList1, petIdList2)
    if #petIdList1 ~= #petIdList2 then
        return false
    end

    local idSet = {}
    for _, id in ipairs(petIdList1) do
        idSet[id] = (idSet[id] or 0) + 1
    end

    for _, id in ipairs(petIdList2) do
        if not idSet[id] then
            return false
        end
        idSet[id] = idSet[id] - 1
        if idSet[id] < 0 then
            return false
        end
    end
    return true
end

function BattleUtils:EnemyTeamIs(petIdList)
    local enemyPetIds = {}
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ENEMY) do
        local id = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ENEMY, petIndex)
        table.insert(enemyPetIds, id)
    end

    return self:IsSameTeam(enemyPetIds, petIdList)
end

function BattleUtils:AllyTeamIs(petIdList)
    local allyPetIds = {}
    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ALLY) do
        local id = C_PetBattles.GetPetSpeciesID(LE_BATTLE_PET_ALLY, petIndex)
        table.insert(allyPetIds, id)
    end
    print(allyPetIds[1],allyPetIds[2], allyPetIds[3])
    return self:IsSameTeam(allyPetIds, petIdList)
end

-- 在PET_BATTLE_FINAL_ROUND时根据双方宠物生命情况判断胜负
function BattleUtils:DetermineWinner()
    local allyAlive = 0
    local enemyAlive = 0

    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ALLY) do
        local health = C_PetBattles.GetHealth(LE_BATTLE_PET_ALLY, petIndex) 
        if health > 0 then
            allyAlive = allyAlive + 1
        end
    end

    for petIndex = 1, C_PetBattles.GetNumPets(LE_BATTLE_PET_ENEMY) do
        local health = C_PetBattles.GetHealth(LE_BATTLE_PET_ENEMY, petIndex) 
        if health > 0 then
            enemyAlive = enemyAlive + 1
        end
    end

    if allyAlive > enemyAlive then
        return 1 -- 我方胜利
    elseif enemyAlive > allyAlive then
        return -1 -- 敌方胜利
    else
        return 0 -- 未知，要看我方是否投降
    end
end

function BattleUtils:Debug(message)
    if self.debug then
        print("PPBest Debug: ", message)
    end
end

_G.PPBestBattleUtils = BattleUtils