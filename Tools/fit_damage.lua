#!/usr/bin/env lua

-- 技能伤害参数拟合工具
-- 使用最小二乘法拟合 damage = a * power + b

print("==================================================")
print("技能伤害参数拟合工具")
print("==================================================")
print("请输入数据，每行两个数：power damage")
print("输入 0 0 结束")
print("==================================================")

-- 读取数据点
local powers = {}
local damages = {}
local count = 0

while true do
    local line = io.read()
    if not line then
        break
    end
    
    -- 解析一行数据
    local power, damage = line:match("(%S+)%s+(%S+)")
    if power and damage then
        power = tonumber(power)
        damage = tonumber(damage)
        
        -- 检查是否结束
        if power == 0 and damage == 0 then
            break
        end
        
        if power and damage then
            count = count + 1
            table.insert(powers, power)
            table.insert(damages, damage)
            print(string.format("已读取: power = %.2f, damage = %.2f", power, damage))
        end
    end
end

-- 检查数据点数量
if count < 2 then
    print("\n错误：至少需要2个数据点！")
    os.exit(1)
end

-- 显示输入的数据
print("\n==================================================")
print(string.format("共读取 %d 个数据点:", count))
print("==================================================")
for i = 1, count do
    print(string.format("数据点 %d: power = %.2f, damage = %.2f", i, powers[i], damages[i]))
end

-- 最小二乘法拟合
-- y = ax + b
-- a = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
-- b = (Σy - a*Σx) / n

local sum_x = 0  -- Σx
local sum_y = 0  -- Σy
local sum_xy = 0 -- Σxy
local sum_x2 = 0 -- Σx²

for i = 1, count do
    sum_x = sum_x + powers[i]
    sum_y = sum_y + damages[i]
    sum_xy = sum_xy + powers[i] * damages[i]
    sum_x2 = sum_x2 + powers[i] * powers[i]
end

local a = (count * sum_xy - sum_x * sum_y) / (count * sum_x2 - sum_x * sum_x)
local b = (sum_y - a * sum_x) / count

-- 计算拟合优度 R²
local y_mean = sum_y / count
local ss_tot = 0  -- 总平方和
local ss_res = 0  -- 残差平方和

for i = 1, count do
    local y_pred = a * powers[i] + b
    ss_tot = ss_tot + (damages[i] - y_mean) ^ 2
    ss_res = ss_res + (damages[i] - y_pred) ^ 2
end

local r_squared = 1 - (ss_res / ss_tot)

-- 显示结果
print("\n==================================================")
print("拟合结果:")
print("==================================================")
print(string.format("damage = %.6f * power + %.6f", a, b))
print(string.format("或: damage = %.6f * (power + %.6f)", a, b/a))
print(string.format("\n拟合优度 R² = %.6f", r_squared))

-- 显示拟合值与实际值的对比
print("\n==================================================")
print("拟合值与实际值对比:")
print("==================================================")
print("Power\t实际Damage\t拟合Damage\t误差")
print("--------------------------------------------------")
for i = 1, count do
    local fitted_damage = a * powers[i] + b
    local error = damages[i] - fitted_damage
    print(string.format("%.2f\t%.2f\t\t%.2f\t\t%.2f", 
        powers[i], damages[i], fitted_damage, error))
end

-- 生成Lua代码
print("\n==================================================")
print("生成的Lua代码:")
print("==================================================")
print(string.format("local ef = Effect.new_damage(TypeID.XXX, %.6f * (self.power + %.6f))", a, b/a))
print("或")
print(string.format("local ef = Effect.new_damage(TypeID.XXX, %.6f * self.power + %.6f)", a, b))

print("\n==================================================")
print("拟合完成！")
print("==================================================")
