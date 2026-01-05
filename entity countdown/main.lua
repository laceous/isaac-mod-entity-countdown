local mod = RegisterMod('Entity Countdown', 1)
local json = require('json')
local game = Game()

mod.font = Font()
mod.font:Load('font/upheavalmini.fnt') -- font/luaminioutlined.fnt
mod.kcolor = KColor(1,1,1,1) -- white
mod.colors = {}
mod.selectedColor = 0
mod.sampleText = '0123456789'

mod.state = {}
mod.state.bombCountdown = true
mod.state.epicFetusCountdown = true
mod.state.effectCountdown = true
mod.state.pickupCountdown = true
mod.state.spikeCountdown = true
mod.state.hostCountdown = true
mod.state.portalCountdown = true
mod.state.deliriumCountdown = true
mod.state.henryCountdown = true
mod.state.r = 255
mod.state.g = 255
mod.state.b = 255
mod.state.a = 10

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      for _, v in ipairs({ 'bombCountdown', 'epicFetusCountdown', 'effectCountdown', 'pickupCountdown', 'spikeCountdown', 'hostCountdown', 'portalCountdown', 'deliriumCountdown', 'henryCountdown' }) do
        if type(state[v]) == 'boolean' then
          mod.state[v] = state[v]
        end
      end
      for _, v in ipairs({ 'r', 'g', 'b' }) do
        if math.type(state[v]) == 'integer' and state[v] >= 0 and state[v] <= 255 then
          mod.state[v] = state[v]
        end
      end
      if math.type(state.a) == 'integer' and state.a >= 0 and state.a <= 10 then
        mod.state.a = state.a
      end
      mod:updateColors()
    end
  end
end

function mod:onGameExit()
  mod:save()
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

-- MC_POST_PICKUP_RENDER has weird water reflection behavior
-- it's also harder to read in the mirror world
function mod:onRender()
  for _, v in ipairs(Isaac.GetRoomEntities()) do
    local pos = nil
    local txt = nil
    
    if v.Type == EntityType.ENTITY_BOMB then
      if REPENTOGON and mod.state.bombCountdown then
        local bomb = v:ToBomb()
        
        if bomb.FrameCount > 0 and bomb:GetExplosionCountdown() > 0 then
          if bomb.SpawnerEntity and bomb.SpawnerEntity.Type == EntityType.ENTITY_PLAYER then
            local player = bomb.SpawnerEntity:ToPlayer()
            if player:HasCollectible(CollectibleType.COLLECTIBLE_REMOTE_DETONATOR, false) then
              goto continue
            end
          end
          
          pos = Isaac.WorldToScreen(bomb.Position)
          txt = tostring(bomb:GetExplosionCountdown())
        end
      end
    elseif v.Type == EntityType.ENTITY_EFFECT then
      if (mod.state.epicFetusCountdown and (v.Variant == EffectVariant.TARGET or v.Variant == EffectVariant.ROCKET)) or
         (mod.state.effectCountdown and not (v.Variant == EffectVariant.TARGET or v.Variant == EffectVariant.ROCKET))
      then
        local effect = v:ToEffect()
        
        -- epic fetus: LifeSpan=50,Timeout=50-0,State=1
        -- marked: LifeSpan=0,Timeout=0,State=0
        if effect.FrameCount > 0 and effect.Timeout > 0 then
          pos = Isaac.WorldToScreen(effect.Position)
          txt = tostring(effect.Timeout)
        end
      end
    elseif v.Type == EntityType.ENTITY_PICKUP then
      if mod.state.pickupCountdown then
        local pickup = v:ToPickup()
        
        if pickup.FrameCount > 0 then
          local seeds = game:GetSeeds()
          local timeout = -1
          
          if pickup.Timeout > -1 then
            timeout = pickup.Timeout
          elseif seeds:HasSeedEffect(SeedEffect.SEED_PICKUPS_TIMEOUT) then
            timeout = 211 - pickup.FrameCount -- 210 + 1
          end
          
          if timeout > 0 then
            pos = Isaac.WorldToScreen(pickup.Position)
            txt = tostring(timeout)
          end
        end
      end
    elseif v.Type == EntityType.ENTITY_DELIRIUM then
      if REPENTOGON and mod.state.deliriumCountdown then
        local delirium = v:ToDelirium()
        
        if delirium.FrameCount > 0 and (delirium.TransformationTimer > 0 or delirium.RemainingAttacks > 0) then
          pos = Isaac.WorldToScreen(delirium.Position)
          txt = delirium.TransformationTimer .. '(' .. delirium.RemainingAttacks .. ')' -- GetTeleportationTimer
        end
      end
    elseif v.Type == EntityType.ENTITY_HOST or v.Type == EntityType.ENTITY_MOBILE_HOST or v.Type == EntityType.ENTITY_FLESH_MOBILE_HOST or v.Type == EntityType.ENTITY_FLOATING_HOST or
           v.Type == EntityType.ENTITY_STONEHEAD
    then
      if mod.state.hostCountdown then
        local npc = v:ToNPC()
        
        if npc.FrameCount > 0 and npc.ProjectileCooldown >= 0 and npc.State ~= NpcState.STATE_ATTACK and npc.State ~= NpcState.STATE_SPECIAL then
          pos = Isaac.WorldToScreen(npc.Position)
          txt = tostring(npc.ProjectileCooldown)
        end
      end
    elseif v.Type == EntityType.ENTITY_PORTAL then
      if mod.state.portalCountdown then
        local npc = v:ToNPC()
        
        if npc.FrameCount > 0 and npc.I2 >= 0 then
          pos = Isaac.WorldToScreen(npc.Position)
          txt = tostring(npc.I2)
        end
      end
    elseif v.Type == EntityType.ENTITY_HENRY then
      if mod.state.henryCountdown then
        local npc = v:ToNPC()
        
        if npc.FrameCount > 0 then
          local timeout = 50 - npc.FrameCount -- 49 + 1
          
          if timeout > 0 then
            pos = Isaac.WorldToScreen(npc.Position)
            txt = tostring(timeout)
          end
        end
      end
    end
    
    if pos and txt then
      mod:drawToScreen(pos, txt)
    end
    
    ::continue::
  end
  if mod.state.spikeCountdown then
    local room = game:GetRoom()
    
    if room:GetFrameCount() > 0 then
      for i = 0, room:GetGridSize() - 1 do
        local gridEntity = room:GetGridEntity(i)
        if gridEntity and gridEntity:GetType() == GridEntityType.GRID_SPIKES_ONOFF then -- GRID_SPIKES
          local spikes = gridEntity:ToSpikes()
          
          if spikes.Timeout > 0 then
            local pos = Isaac.WorldToScreen(spikes.Position)
            local txt = tostring(spikes.Timeout)
            
            mod:drawToScreen(pos, txt)
          end
        end
      end
    end
  end
end

function mod:drawToScreen(pos, txt)
  local room = game:GetRoom()
  
  if room:IsMirrorWorld() then
    local wtrp320x280 = Isaac.WorldToRenderPosition(Vector(320, 280)) -- center pos normal room, WorldToRenderPosition makes this work in large rooms too
    mod.font:DrawString(txt, wtrp320x280.X*2 - pos.X - mod.font:GetStringWidth(txt)/2, pos.Y, mod.kcolor, 0, true)
  else
    mod.font:DrawString(txt, pos.X - mod.font:GetStringWidth(txt)/2, pos.Y, mod.kcolor, 0, true)
  end
end

function mod:populateColorsTable()
  mod.colors[0] = { 'custom', -1, -1, -1 }
  table.insert(mod.colors, { 'white', 255, 255, 255 })
  table.insert(mod.colors, { 'silver', 192, 192, 192 })
  table.insert(mod.colors, { 'gray', 128, 128, 128 })
  table.insert(mod.colors, { 'black', 0, 0, 0 })
  table.insert(mod.colors, { 'red', 255, 0, 0 })
  table.insert(mod.colors, { 'maroon', 128, 0, 0 })
  table.insert(mod.colors, { 'yellow', 255, 255, 0 })
  table.insert(mod.colors, { 'olive', 128, 128, 0 })
  table.insert(mod.colors, { 'lime', 0, 255, 0 })
  table.insert(mod.colors, { 'green', 0, 128, 0 })
  table.insert(mod.colors, { 'aqua', 0, 255, 255 })
  table.insert(mod.colors, { 'teal', 0, 128, 128 })
  table.insert(mod.colors, { 'blue', 0, 0, 255 })
  table.insert(mod.colors, { 'navy', 0, 0, 128 })
  table.insert(mod.colors, { 'fuchsia', 255, 0, 255 })
  table.insert(mod.colors, { 'purple', 128, 0, 128 })
end

function mod:updateColors()
  mod.kcolor.Red = mod.state.r / 255
  mod.kcolor.Green = mod.state.g / 255
  mod.kcolor.Blue = mod.state.b / 255
  mod.kcolor.Alpha = mod.state.a / 10
  
  if ModConfigMenu then
    ModConfigMenu.RemoveSetting(mod.Name, 'Color', mod.sampleText)
    ModConfigMenu.AddText(mod.Name, 'Color', mod.sampleText, { mod.kcolor.Red, mod.kcolor.Green, mod.kcolor.Blue })
  end
  
  local foundMatch = false
  for i, v in ipairs(mod.colors) do
    if mod.state.r == v[2] and mod.state.g == v[3] and mod.state.b == v[4] then
      mod.selectedColor = i
      foundMatch = true
      break
    end
  end
  if not foundMatch then
    mod.selectedColor = 0
  end
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  for _, v in ipairs({ 'Settings', 'Color' }) do
    ModConfigMenu.RemoveSubcategory(mod.Name, v)
  end
  for _, v in ipairs({
                      { field = 'bombCountdown'     , prefix = 'Bomb countdown'      , info = { 'Display bomb explosion countdown?', '(Requires repentogon)' } },
                      { field = 'epicFetusCountdown', prefix = 'Epic fetus countdown', info = { 'Display epic fetus countdown?' } },
                      { field = 'effectCountdown'   , prefix = 'Effect countdown'    , info = { 'Display effect countdown?', '(Fireplace, etc)' } },
                      { field = 'pickupCountdown'   , prefix = 'Pickup countdown'    , info = { 'Display pickup disappearance countdown?' } },
                      { field = 'spikeCountdown'    , prefix = 'Spike countdown'     , info = { 'Display spike on/off countdown?' } },
                      { field = 'hostCountdown'     , prefix = 'Host countdown'      , info = { 'Display host popup countdown?', '(+Grimace)' } },
                      { field = 'portalCountdown'   , prefix = 'Portal countdown'    , info = { 'Display portal spawn cycle countdown?' } },
                      { field = 'deliriumCountdown' , prefix = 'Delirium countdown'  , info = { 'Display delirium transformation countdown?', '(Requires repentogon)' } },
                      { field = 'henryCountdown'    , prefix = 'Henry countdown'     , info = { 'Display henry countdown?', '(LOL)' } },
                    })
  do
    ModConfigMenu.AddSetting(
      mod.Name,
      'Settings',
      {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
          return mod.state[v.field]
        end,
        Display = function()
          return v.prefix .. ': ' .. (mod.state[v.field] and 'on' or 'off')
        end,
        OnChange = function(b)
          mod.state[v.field] = b
          mod:save()
        end,
        Info = v.info
      }
    )
  end
  ModConfigMenu.AddSetting(
    mod.Name,
    'Color',
    {
      Type = ModConfigMenu.OptionType.NUMBER,
      CurrentSetting = function()
        return mod.selectedColor
      end,
      Minimum = 1,
      Maximum = #mod.colors,
      Display = function()
        return 'Preset: ' .. mod.colors[mod.selectedColor][1]
      end,
      OnChange = function(n)
        mod.selectedColor = n
        mod.state.r = mod.colors[n][2]
        mod.state.g = mod.colors[n][3]
        mod.state.b = mod.colors[n][4]
        mod:updateColors()
        mod:save()
      end,
      Info = { 'Select a color preset', 'Or choose rgb values below' }
    }
  )
  for _, v in ipairs({
                      { field = 'r', prefix = 'Red' },
                      { field = 'g', prefix = 'Green' },
                      { field = 'b', prefix = 'Blue' },
                    })
  do
    ModConfigMenu.AddSetting(
      mod.Name,
      'Color',
      {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
          return mod.state[v.field]
        end,
        Minimum = 0,
        Maximum = 255,
        Display = function()
          return v.prefix .. ': ' .. mod.state[v.field]
        end,
        OnChange = function(n)
          mod.state[v.field] = n
          mod:updateColors()
          mod:save()
        end,
        Info = { '0 - 255' }
      }
    )
  end
  ModConfigMenu.AddSetting(
    mod.Name,
    'Color',
    {
      Type = ModConfigMenu.OptionType.SCROLL, -- shows 10 bars, you can select 0-10 for a total of 11 options
      CurrentSetting = function()
        return mod.state.a
      end,
      Display = function()
        return 'Alpha: $scroll' .. mod.state.a
      end,
      OnChange = function(n)
        mod.state.a = n
        mod:updateColors()
        mod:save()
      end,
      Info = { '0 - 10' }
    }
  )
  ModConfigMenu.AddSpace(mod.Name, 'Color')
  mod:updateColors()
end
-- end ModConfigMenu --

mod:populateColorsTable()
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddPriorityCallback(ModCallbacks.MC_POST_RENDER, CallbackPriority.EARLY, mod.onRender) -- display under mcm

if ModConfigMenu then
  mod:setupModConfigMenu()
end