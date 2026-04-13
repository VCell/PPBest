local _, PPBest = ...
local AI = PPBest.AI
local Bit = PPBest.Bit

local AuraProcessor = {}

function AuraProcessor.get_active_speed_modifier(state, team_index)
    local rate = 100.0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == AI.AuraType.SPEED then
            rate = rate + aura.value
        end
    end

    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.SPEED then
            rate = rate + aura.value
        end
    end
    return rate

end

function AuraProcessor.is_stunned(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.STUN then
            return true
        end
    end
    return false

end

function AuraProcessor.is_blind(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.id == AI.AuraID.BLIND then
            return true
        end
    end
    if AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_DARKNESS, state.round) then
        return true
    end
    return false
end

function AuraProcessor.get_active_accuracy_modifier(state, team_index)
    if team_index == nil then
        -- 没有来源时，预期是buff触发，返回100%
        return 100
    end
    local rate = 0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == AI.AuraType.ACCURACY then
            rate = rate + aura.value
        end
    end
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.ACCURACY then
            rate = rate + aura.value
        end
    end
    if AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_DARKNESS, state.round) or
        AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_SANDSTORM, state.round) then
        rate = rate - 10
    end
    return rate

end

function AuraProcessor.is_immune(state, team_index, pet_index, ignore_bit)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.FLYING and Bit.band(ignore_bit, AI.IgnoreBit.FLYING) == 0 then
            return true
        end
        if aura.type == AI.AuraType.BURROW and Bit.band(ignore_bit, AI.IgnoreBit.BURROW) == 0 then
            return true
        end
        if aura.type == AI.AuraType.BLOCK and Bit.band(ignore_bit, AI.IgnoreBit.BLOCK) == 0 then
            -- todo 计算格挡次数
            return true
        end
    end
    return false
end

function AuraProcessor.get_aura_by_id(state, team_index, pet_index, aura_id)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    if ps.auras[aura_id] then
        return ps.auras[aura_id]
    end
    return nil
end

function AuraProcessor.get_aura_by_type(state, team_index, pet_index, aura_type)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == aura_type then
            return aura
        end
    end
    return nil
end

function AuraProcessor.get_dodge_modifier(state, team_index, pet_index)
    local rate = 0
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.DODGE then
            rate = rate + 100
        end
    end
    return rate
end

function AuraProcessor.get_heal_modifier(state, team_index, pet_index)
    local rate = 0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == AI.AuraType.HEALING then
            rate = rate + aura.value
        end
    end
    if AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_SUNLIGHT, state.round) then
        rate = rate + 25
    elseif AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_DARKNESS, state.round) then
        rate = rate - 50
    end
    return rate
end

function AuraProcessor.get_active_modifier_by_type(state, team_index, aura_type)
    if team_index == nil then
        -- 没有来源时，预期是buff触发，返回0%
        return 0
    end
    local rate = 0
    local team_state = state.team_states[team_index]
    for i, aura in pairs(team_state.active_auras) do
        if aura.type == aura_type then
            rate = rate + aura.value
        end
    end
    local ps = team_state.pets[team_state.active_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == aura_type then
            rate = rate + aura.value
        end
    end
    return rate

end

function AuraProcessor.get_defand(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    local defend = 0
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.DEFEND then
            defend = defend + aura.value
        end
    end
    if AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_SANDSTORM, state.round) then
        defend = defend + state.weather.value
    end
    return defend
end

function AuraProcessor.process_block(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.BLOCK then
            aura.value = aura.value - 1
            if aura.value <= 0 then
                ps.auras[i] = nil
            end
            return true
        end
    end
    return false
end

function AuraProcessor.get_max_health_modifier(state, team_index, pet_index)
    local team_state = state.team_states[team_index]
    local ps = team_state.pets[pet_index]
    local rate = 0
    for i, aura in pairs(ps.auras) do
        if aura.type == AI.AuraType.MAX_HEALTH then
            rate = rate + aura.value
        end
    end
    if AI.Aura.is_weather(state.weather, AI.AuraID.WEATHER_SUNLIGHT, state.round) then
        rate = rate + 50
    end
    return rate
end

AI.AuraProcessor = AuraProcessor
