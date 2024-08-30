function split (inputstr, sep)
  if sep == nil then
          sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
          table.insert(t, str)
  end
  return t
end


function isMulti()
  PalUtility = StaticFindObject("/Script/Pal.PalUtility"):GetCDO()
  if PalUtility == nil then return false end

  local PalPlayerController = GetPlayerController()
  if PalPlayerController == nil then return false end
  local Pawn = PalPlayerController.Pawn
  if Pawn == nil then return false end

  if PalUtility:IsMultiplayer(Pawn:GetWorld()) then return true end
  return false

end
function isReady()
  local PalPlayerController = GetPlayerController()
  if PalPlayerController == nil then return false end
  local Character = PalPlayerController.Character
  if Character == nil then return false end
  local CharacterParameterComponent = Character.CharacterParameterComponent
  if CharacterParameterComponent == nil then return false end

  if CharacterParameterComponent:IsDying() then return false end
  if CharacterParameterComponent:IsDead() then return false end

  --local bosses = FindAllOf("PalBossTower")
  --local inside = false
  --for Index,boss in pairs(bosses) do
  --  if boss:IsValid() then
  --    if boss:IsEntered(Character) then
  --      inside = true
  --      print("in boss")
  --    end
  --  end
  --end
  --if not inside then print("no boss") end

  return true
end

function isBoss()
  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn
  local Location = Pawn:K2_GetActorLocation()
  --print("z pls: " .. Location["Z"])
  if Location["Z"] <= -10000 then return true end
  return false
end

timed = {}
hidden = false


LoopAsync(10000, function()
  checkConn()

  local status, ready = pcall(isReady)
  if status and ready then
    local multi = isMulti()
  
    if multi then
      if not hidden then
        print("hiding effects")
        hidden = true
        showEffects(false)
      end
    else
      if hidden then
        print("showing effects")
        hidden = false
        showEffects(true)
      end
    end
  end

end)

iterations = 0
cammode = false
spinmode = false

function dospin()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then 
    return
  end

    iterations = iterations + 1
    CharacterCamera.RelativeRotation = {
        Pitch = 0,
        Yaw = 0,
        Roll = iterations * 1.5
    }

    if iterations >= 720 * 2/3 then
        iterations = 0
        cammode = false
        spinmode = false
        CharacterCamera.RelativeRotation = {
            Pitch = 0,
            Yaw = 0,
            Roll = 0
        }
    end
end

LoopAsync(50, function()

  if not connected() then return end

  if spinmode then
    dospin()
  end

  id, code, dur = getEffect()

  if code == "" then
    return
  end

  local status, ready = pcall(isReady)

  if not status or not ready then
    ccRespond(id, 3)
    return
  end

  if code == "fire" then
    res = fire()
  
    if res then
      ccRespond(id, 0)
    else
      ccRespond(id, 3)
    end
    return
  end
    
  if dur > 0 then
    local rec = timed[code]
    if rec ~= nil then 
      ccRespond(id, 3)
      return
    end
  end

  local arg=nil

  if string.find(code, '_') ~= nil then
    local parts = split(code, '_')
    code = parts[0]
    arg = parts[1]
  end

  print(code)
  local func =_G[code]

  if pcall(function()
    if func ~= nil then
      local res = nil
      if arg~=nil then
        res = func(arg)
      else
        res = func()
      end
      if res then

        if dur > 0 then
          ccRespondTimed(id, 0, dur)

          local entry = {}
          entry["id"] = id
          entry["dur"] = dur
          entry["code"] = code
          timed[code] = entry

        else
          ccRespond(id, 0)
        end

      else
        ccRespond(id, 3)
      end
    end
  end) then

  else
    ccRespond(id, 3)
  end

end
)

LoopAsync(250, function()
  for code,entry in pairs(timed) do
    entry["dur"] = entry["dur"] - 250
    if entry["dur"] <= 0 then
      local code = entry["code"] .. "_end"
      --print("ending " .. code)
      local func =_G[code]

      if func == nil or pcall(func) then
        ccRespondTimed(entry["id"], 8, 0)
        timed[entry["code"]]=nil
      end
    end
  end
end)

function dump(o)

     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '

end

function GetPlayerController()
  local PlayerControllers = FindAllOf("Controller")
  if not PlayerControllers then error("No PlayerController found\n") end
  local PlayerController = nil
  for Index,Controller in pairs(PlayerControllers) do
      if Controller.Pawn:IsValid() and Controller.Pawn:IsPlayerControlled() and Controller.Pawn:IsLocallyControlled() then
          PlayerController = Controller
      end
  end
  if PlayerController and PlayerController:IsValid() then
      return PlayerController
  else
      error("No PlayerController found\n")
  end
end

function updateScale(Character)
  local Location = Character:K2_GetActorLocation()
  local Rotation = Character:K2_GetActorRotation()

  Location.X = Location.X + 0.1
  Character:K2_TeleportTo(Location,Rotation)
end

function poop()
  local PalPlayerController = GetPlayerController()

  local PalUtility = StaticFindObject("/Script/Pal.PalUtility"):GetCDO()

  local Characters = FindAllOf("PalCharacter")
  if not Characters then return false end

  for Index,Character in pairs(Characters) do
      PalUtility:CreateUNKO(Character, 1)    
  end

  return true
end

function ragdoll()
  local PalPlayerController = GetPlayerController()
  local PalUtility = StaticFindObject("/Script/Pal.PalUtility"):GetCDO()
  PalUtility:SetCharacterRagdoll(PalPlayerController.Character, true, true)
  ExecuteWithDelay(5000, function()
    PalUtility:ClearCharacterRagdoll(PalPlayerController.Character)
  end)
  return true
end


tele = false

function death()
  if isBoss() then return end
  if tele then return end
  
  local WBP_IngameCompass_DeathMark_C = FindFirstOf("WBP_IngameCompass_DeathMark_C")
  if WBP_IngameCompass_DeathMark_C == nil then return false end
  local pos = WBP_IngameCompass_DeathMark_C["Target Location"]

  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn

  local Rotation = Pawn:K2_GetActorRotation()

  local Location = {}
  Location["X"] = pos.X
  Location["Y"] = pos.Y
  Location["Z"] = pos.Z + 100
  tele=true

  PalPlayerController.Character:K2_TeleportTo(Location,Rotation)

  ExecuteWithDelay(2500, function()
    PalPlayerController.Character:K2_TeleportTo(Location,Rotation)
  end)

  ExecuteWithDelay(3000, function()
    tele = false
  end) 

  return true
end

function base()
  if isBoss() then return end
  if tele then return end
  
  local PalBaseCampManager = FindFirstOf("PalBaseCampManager")

  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn
  local Location = Pawn:K2_GetActorLocation()

  local base = PalBaseCampManager:GetNearestBaseCamp(Location)
  if base == nil then return end
  tele=true

  local baseloc = base["Transform"]
  baseloc = baseloc["Translation"]
  --print(tostring(baseloc))


  Location["X"] = baseloc.X
  Location["Y"] = baseloc.Y
  Location["Z"] = baseloc.Z + 100
  --print(dump(Location))

  --

  local Rotation = Pawn:K2_GetActorRotation()

  PalPlayerController.Character:K2_TeleportTo(Location,Rotation)

  ExecuteWithDelay(2500, function()
    PalPlayerController.Character:K2_TeleportTo(Location,Rotation)
  end)

  ExecuteWithDelay(3000, function()
    tele = false
  end)    

  return true
end

function telereef()
  if isBoss() then return end
  if tele then return end
  tele=true

  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn

  local Location = {}
  Location["X"] = -403628.40377455
  Location["Y"] = 134336.66516554
  Location["Z"] = -1920.1501482452

  local Rotation = Pawn:K2_GetActorRotation()

  PalPlayerController.Character:K2_TeleportTo(Location,Rotation)

  ExecuteWithDelay(2500, function()
    PalPlayerController.Character:K2_TeleportTo(Location,Rotation)
  end)

  ExecuteWithDelay(3000, function()
    tele = false
  end)  

  return true
end

function teleeast()
  if isBoss() then return end
  if tele then return end
  tele=true

  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn

  local Location = {}
  Location["X"] = -171294.954746
  Location["Y"] = 411000.71783999
  Location["Z"] = 4145.3934797501

  local Rotation = Pawn:K2_GetActorRotation()

  PalPlayerController.Character:K2_TeleportTo(Location,Rotation)

  ExecuteWithDelay(2500, function()
    PalPlayerController.Character:K2_TeleportTo(Location,Rotation)
  end)

  ExecuteWithDelay(3000, function()
    tele = false
  end)  

  return true
end


function teleforgot()
  if isBoss() then return end
  if tele then return end
  tele=true

  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn

  local Location = {}
  Location["X"] = -137110.01516314
  Location["Y"] = -91910.026263327
  Location["Z"] = -1989.4553503837

  local Rotation = Pawn:K2_GetActorRotation()

  PalPlayerController.Character:K2_TeleportTo(Location,Rotation)

  ExecuteWithDelay(2500, function()
    PalPlayerController.Character:K2_TeleportTo(Location,Rotation)
  end)

  ExecuteWithDelay(3000, function()
    tele = false
  end)  

  return true
end

function telebegin()
  if isBoss() then return end
  if tele then return end
  tele=true

  local PalPlayerController = GetPlayerController()
  local Pawn = PalPlayerController.Pawn

  local Location = {}
  Location["X"] = -358857.84476836
  Location["Y"] = 268157.65770683
  Location["Z"] = 7998.4061659416

  local Rotation = Pawn:K2_GetActorRotation()

  PalPlayerController.Character:K2_TeleportTo(Location,Rotation)

  ExecuteWithDelay(2500, function()
    PalPlayerController.Character:K2_TeleportTo(Location,Rotation)
  end)

  ExecuteWithDelay(3000, function()
    tele = false
  end)  

  return true
end

function getpos()
    local PalPlayerController = GetPlayerController()
    local Pawn = PalPlayerController.Pawn
    local Location = Pawn:K2_GetActorLocation()
    print("x: " .. Location.X)
    print("y: " .. Location.Y)
    print("z: " .. Location.Z)
    return true
end

speedmode = false

function freeze()
  if speedmode then return false end
  local PalPlayerController = GetPlayerController()

  PalPlayerController.CheatManager:SloMo(0)

  speedmode = true

  return true
end

function freeze_end()
  local PalPlayerController = GetPlayerController()
  PalPlayerController.CheatManager:SloMo(1)
  speedmode = false
end

function fast()
  if speedmode then return false end
  local PalPlayerController = GetPlayerController()

  PalPlayerController.CheatManager:SloMo(2.0)

  speedmode = true

  return true
end

function fast_end()
  local PalPlayerController = GetPlayerController()
  PalPlayerController.CheatManager:SloMo(1)
  speedmode = false
end

function slow()
  if speedmode then return false end
  local PalPlayerController = GetPlayerController()

  PalPlayerController.CheatManager:SloMo(0.5)

  speedmode = true

  return true
end

function slow_end()
  local PalPlayerController = GetPlayerController()
  PalPlayerController.CheatManager:SloMo(1)
  speedmode = false
end

function hyper()
  if speedmode then return false end
  local PalPlayerController = GetPlayerController()

  PalPlayerController.CheatManager:SloMo(4.0)

  speedmode = true

  return true
end

function hyper_end()
  local PalPlayerController = GetPlayerController()
  PalPlayerController.CheatManager:SloMo(1)
  speedmode = false
end

sizemode = false


function tiny()
    CharacterCamera = nil
    CharacterCameras = FindAllOf("PalCharacterCameraComponent")
    for _, _CharacterCamera in ipairs(CharacterCameras) do
        if _CharacterCamera.bIsActive then
            CharacterCamera = _CharacterCamera
        end
    end
    if CharacterCamera == nil then return false end

  if sizemode then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh

  mesh.RelativeScale3D = {
    X = 0.25,
    Y = 0.25,
    Z = 0.25
  }

  updateScale(Character)

  sizemode = true


  sizerestorex = mesh.RelativeLocation.X
  sizerestorey = mesh.RelativeLocation.Y
  sizerestorez = mesh.RelativeLocation.Z
  sizecamrestorex = CharacterCamera.RelativeLocation.X
  sizecamrestorey = CharacterCamera.RelativeLocation.Y
  sizecamrestorez = CharacterCamera.RelativeLocation.Z

  mesh.RelativeLocation = {
    X = 0,
    Y = 0,
    Z = -90
  }

  
  CharacterCamera.RelativeLocation = {
    X = 0,
    Y = -50,
    Z = -100
  }



  return true
end


function tiny_end()

  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh

  mesh.RelativeLocation.X = sizerestorex
  mesh.RelativeLocation.Y = sizerestorey
  mesh.RelativeLocation.Z = sizerestorez

  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false

  CharacterCamera.RelativeLocation.X = sizecamrestorex
  CharacterCamera.RelativeLocation.Y = sizecamrestorey
  CharacterCamera.RelativeLocation.Z = sizecamrestorez

end

function small()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

if sizemode then return false end
local PalPlayerController = GetPlayerController()
local Character = PalPlayerController.Character

local pawn = PalPlayerController.Pawn
local mesh = pawn.Mesh

mesh.RelativeScale3D = {
  X = 0.5,
  Y = 0.5,
  Z = 0.5
}
updateScale(Character)

sizemode = true


sizerestorex = mesh.RelativeLocation.X
sizerestorey = mesh.RelativeLocation.Y
sizerestorez = mesh.RelativeLocation.Z
sizecamrestorex = CharacterCamera.RelativeLocation.X
sizecamrestorey = CharacterCamera.RelativeLocation.Y
sizecamrestorez = CharacterCamera.RelativeLocation.Z

mesh.RelativeLocation = {
  X = 0,
  Y = 0,
  Z = -90
}


CharacterCamera.RelativeLocation = {
  X = 0,
  Y = -25,
  Z = -75
}

return true
end

function small_end()

  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh

  mesh.RelativeLocation.X = sizerestorex
  mesh.RelativeLocation.Y = sizerestorey
  mesh.RelativeLocation.Z = sizerestorez

  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false

  CharacterCamera.RelativeLocation.X = sizecamrestorex
  CharacterCamera.RelativeLocation.Y = sizecamrestorey
  CharacterCamera.RelativeLocation.Z = sizecamrestorez

end

function large()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

if sizemode then return false end
local PalPlayerController = GetPlayerController()
local Character = PalPlayerController.Character

local pawn = PalPlayerController.Pawn
local mesh = pawn.Mesh

mesh.RelativeScale3D = {
  X = 2.0,
  Y = 2.0,
  Z = 2.0
}
updateScale(Character)

sizemode = true


sizerestorex = mesh.RelativeLocation.X
sizerestorey = mesh.RelativeLocation.Y
sizerestorez = mesh.RelativeLocation.Z
sizecamrestorex = CharacterCamera.RelativeLocation.X
sizecamrestorey = CharacterCamera.RelativeLocation.Y
sizecamrestorez = CharacterCamera.RelativeLocation.Z

mesh.RelativeLocation = {
  X = 0,
  Y = 0,
  Z = -95
}


CharacterCamera.RelativeLocation = {
  X = 0,
  Y = 25,
  Z = 50
}

return true
end

function large_end()

  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh

  mesh.RelativeLocation.X = sizerestorex
  mesh.RelativeLocation.Y = sizerestorey
  mesh.RelativeLocation.Z = sizerestorez

  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false

  CharacterCamera.RelativeLocation.X = sizecamrestorex
  CharacterCamera.RelativeLocation.Y = sizecamrestorey
  CharacterCamera.RelativeLocation.Z = sizecamrestorez

end

function giant()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

if sizemode then return false end
local PalPlayerController = GetPlayerController()
local Character = PalPlayerController.Character

local pawn = PalPlayerController.Pawn
local mesh = pawn.Mesh

mesh.RelativeScale3D = {
  X = 4.0,
  Y = 4.0,
  Z = 4.0
}
updateScale(Character)

sizemode = true


sizerestorex = mesh.RelativeLocation.X
sizerestorey = mesh.RelativeLocation.Y
sizerestorez = mesh.RelativeLocation.Z
sizecamrestorex = CharacterCamera.RelativeLocation.X
sizecamrestorey = CharacterCamera.RelativeLocation.Y
sizecamrestorez = CharacterCamera.RelativeLocation.Z

mesh.RelativeLocation = {
  X = 0,
  Y = 0,
  Z = -140
}


CharacterCamera.RelativeLocation = {
  X = -350,
  Y = 50,
  Z = 300
}

return true
end

function giant_end()

  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh

  mesh.RelativeLocation.X = sizerestorex
  mesh.RelativeLocation.Y = sizerestorey
  mesh.RelativeLocation.Z = sizerestorez

  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false

  CharacterCamera.RelativeLocation.X = sizecamrestorex
  CharacterCamera.RelativeLocation.Y = sizecamrestorey
  CharacterCamera.RelativeLocation.Z = sizecamrestorez

end

function wide()

if sizemode then return false end
local PalPlayerController = GetPlayerController()
local Character = PalPlayerController.Character

local pawn = PalPlayerController.Pawn
local mesh = pawn.Mesh

mesh.RelativeScale3D = {
  X = 3.0,
  Y = 1.0,
  Z = 1.0
}
updateScale(Character)

sizemode = true

return true
end

function wide_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false
end

palsizemode = false

function giantpals()
  if isBoss() then return end
  if palsizemode then return false end

  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 10,
              Y = 10,
              Z = 10
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function giantpals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function largepals()
  if isBoss() then return end
  if palsizemode then return false end



  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 4,
              Y = 4,
              Z = 4
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function largepals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function smallpals()
  if isBoss() then return end
  if palsizemode then return false end


  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 0.5,
              Y = 0.5,
              Z = 0.5
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function smallpals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function tinypals()
  if isBoss() then return end
  if palsizemode then return false end

  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 0.25,
              Y = 0.25,
              Z = 0.25
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function tinypals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function tallpals()
  if isBoss() then return end
  if palsizemode then return false end

  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 3
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function tallpals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function shortpals()
  if isBoss() then return end
  if palsizemode then return false end

  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 0.33
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function shortpals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function widepals()
  if isBoss() then return end
  if palsizemode then return false end

  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 3,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

   return true
end

function widepals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function narrowpals()
  if isBoss() then return end
  if palsizemode then return false end

  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 0.33,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end

  palsizemode = true

  return true
end

function narrowpals_end()
  local monsters = FindAllOf("PalMonsterCharacter")
  for _, monster in ipairs(monsters) do
      local pal = monster:GetMainMesh()
      local name = pal:GetFullName()
      if name~=nil and not string.find(name, "_Player_") and not string.find(name, "_TreasureBox_") then
          pal.RelativeScale3D = {
              X = 1,
              Y = 1,
              Z = 1
          }
          updateScale(monster)
      end
      
  end
      
  palsizemode = false
end

function narrow()

  if sizemode then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  
  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh
  
  mesh.RelativeScale3D = {
    X = 0.33,
    Y = 1.0,
    Z = 1.0
  }
  updateScale(Character)
  sizemode = true

  
  return true
  end

  function narrow_end()
    local PalPlayerController = GetPlayerController()
    local Character = PalPlayerController.Character
    PalPlayerController.CheatManager:ChangeSize(1)
    updateScale(Character)
        
    sizemode = false
  end  

function tall()

    if sizemode then return false end
    local PalPlayerController = GetPlayerController()
    local Character = PalPlayerController.Character
    
    local pawn = PalPlayerController.Pawn
    local mesh = pawn.Mesh
    
    mesh.RelativeScale3D = {
      X = 1.0,
      Y = 1.0,
      Z = 3.0
    }
    updateScale(Character)
    sizemode = true
        
    return true
end

function tall_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false
end

function short()

  if sizemode then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  
  local pawn = PalPlayerController.Pawn
  local mesh = pawn.Mesh
  
  mesh.RelativeScale3D = {
    X = 1.0,
    Y = 1.0,
    Z = 0.33
  }
  updateScale(Character)
  sizemode = true
  
  return true
end

function short_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  PalPlayerController.CheatManager:ChangeSize(1)
  updateScale(Character)
      
  sizemode = false
end

function fullheal()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent

  local max = CharacterParameterComponent:GetMaxHP()
  local cur = CharacterParameterComponent:GetHP()

  if cur.Value > max.Value * 90 / 100 then return false end

  CharacterParameterComponent:SetHP(max)

  return true
end

function damage()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent

  local max = CharacterParameterComponent:GetMaxHP()
  local cur = CharacterParameterComponent:GetHP()

  if cur.Value < max.Value * 10 / 100 then return false end

  cur.Value = cur.Value - (max.Value / 4)
  if cur.Value < 1000 then cur.Value = 1000 end

  CharacterParameterComponent:SetHP(cur)

  return true
end

function kill()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent

  local wait = false

  if PalPlayerController:IsRidingFlyPal() then
    PalPlayerController:EndFlyToServer()
    PalPlayerController:GetOffToServer()
    wait = true
  end
  
  if PalPlayerController:IsRiding() then
    PalPlayerController:GetOffToServer()
    wait = true
  end

  if wait then
    ExecuteWithDelay(2000, function()
      local PalPlayerController = GetPlayerController()
      local Character = PalPlayerController.Character
      local CharacterParameterComponent = Character.CharacterParameterComponent
    
      PalStatusComponent = Character.StatusComponent
  
      PalStatusComponent:AddStatus(15)
      CharacterParameterComponent:ZeroDyingHP()
      CharacterParameterComponent:ZeroDyingHP_ToServer()
    end)  
    return true
  end

  PalStatusComponent = Character.StatusComponent
  
  PalStatusComponent:AddStatus(15)
  CharacterParameterComponent:ZeroDyingHP()
  CharacterParameterComponent:ZeroDyingHP_ToServer()

  return true
end

function heal()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent

  local max = CharacterParameterComponent:GetMaxHP()
  local cur = CharacterParameterComponent:GetHP()

  if cur.Value > max.Value * 90 / 100 then return false end

  cur.Value = cur.Value + (max.Value / 4)
  if cur.Value > max.Value then cur.Value = max.Value end

  CharacterParameterComponent:SetHP(cur)

  return true
end

function fillstam()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent

  local max = CharacterParameterComponent:GetMaxSP()
  local cur = CharacterParameterComponent:GetSP()

  if cur.Value > max.Value * 90 / 100 then return false end

  CharacterParameterComponent:SetSP(max)


  return true
end

function emptystam()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent

  local max = CharacterParameterComponent:GetMaxSP()
  local cur = CharacterParameterComponent:GetSP()

  if cur.Value < max.Value * 10 / 100 then return false end
  cur.Value = 0

  CharacterParameterComponent:SetSP(cur)


  return true
end

function poison()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(5)

  return true
end

function stun()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(7)

  return true
end

function coma()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(8)

  return true
end

function sleep()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(9)

  return true
end

function burn()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(19)

  return true
end

function wet()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(20)

  return true
end

function frozen()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(21)

  return true
end

function electrified()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(22)

  return true
end

function muddy()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(23)

  return true
end

function ivy()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
 
  PalStatusComponent = Character.StatusComponent

  PalStatusComponent:AddStatus(24)

  return true
end

function midnight()

  local PalTimeManager = FindFirstOf("PalTimeManager")
  PalTimeManager:SetGameTime_FixDay(0)

  return true
end

function morning()

  local PalTimeManager = FindFirstOf("PalTimeManager")
  PalTimeManager:SetGameTime_FixDay(6)

  return true
end

function noon()

  local PalTimeManager = FindFirstOf("PalTimeManager")
  PalTimeManager:SetGameTime_FixDay(12)

  return true
end

function evening()

  local PalTimeManager = FindFirstOf("PalTimeManager")
  PalTimeManager:SetGameTime_FixDay(18)

  return true
end

function hours()

  local PalTimeManager = FindFirstOf("PalTimeManager")
  local hour = PalTimeManager:GetCurrentPalWorldTime_Hour()
  hour = hour + 2
  if hour > 23 then hour = hour - 24 end
  PalTimeManager:SetGameTime_FixDay(hour)

  return true
end

function respawn()
  if isBoss() then return end
  local PlayerState = FindFirstOf("PlayerState")
  PlayerState:RequestRespawn()
  return true
end



function rollcam()
  if iterations > 0 then return false end
  if cammode then return false end
  
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  cammode = true
  spinmode = true
  
  return true
end



function invert()
  if cammode then return false end
  
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  cammode = true

  CharacterCamera.RelativeRotation = {
      Pitch = 0,
      Yaw = 0,
      Roll = 180
  }



  return true
end

function invert_end()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then error('') end

  cammode = false

  CharacterCamera.RelativeRotation = {
      Pitch = 0,
      Yaw = 0,
      Roll = 0
  }  

end

function widecam()
  if cammode then return false end
  
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  cammode = true

  CharacterCamera.SprintFOV = CharacterCamera.SprintFOV * 1.5
  CharacterCamera.WalkFOV = CharacterCamera.WalkFOV * 1.5


  return true
end

function widecam_end()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then error('') end

  cammode = false

  CharacterCamera.SprintFOV = CharacterCamera.SprintFOV / 1.5
  CharacterCamera.WalkFOV = CharacterCamera.WalkFOV / 1.5

end

function narrowcam()
  if cammode then return false end
  
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then return false end

  cammode = true

  CharacterCamera.SprintFOV = CharacterCamera.SprintFOV / 1.5
  CharacterCamera.WalkFOV = CharacterCamera.WalkFOV / 1.5


  return true
end

function narrowcam_end()
  CharacterCamera = nil
  CharacterCameras = FindAllOf("PalCharacterCameraComponent")
  for _, _CharacterCamera in ipairs(CharacterCameras) do
      if _CharacterCamera.bIsActive then
          CharacterCamera = _CharacterCamera
      end
  end
  if CharacterCamera == nil then error('') end

  cammode = false

  CharacterCamera.SprintFOV = CharacterCamera.SprintFOV * 1.5
  CharacterCamera.WalkFOV = CharacterCamera.WalkFOV * 1.5

end

colormode = false

function red()
  if colormode then return false end

  colormode = true

  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")


  PlayerCameraManager:StartCameraFade(0, 0.40, 6, {
      R = 1,
      G = 0,
      B = 0
  }, false, true)


  return true
end

function red_end()
  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")
  colormode = false
  PlayerCameraManager:StartCameraFade(0.40, 0, 6, {
    R = 1,
    G = 0,
    B = 0
  }, false, true)
end

function green()
  if colormode then return false end

  colormode = true

  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")


  PlayerCameraManager:StartCameraFade(0, 0.40, 6, {
      R = 0,
      G = 1,
      B = 0
  }, false, true)

  return true
end

function green_end()
  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")
  colormode = false
  PlayerCameraManager:StartCameraFade(0.40, 0, 6, {
    R = 0,
    G = 1,
    B = 0
  }, false, true)
end

function blue()
  if colormode then return false end

  colormode = true

  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")


  PlayerCameraManager:StartCameraFade(0, 0.40, 6, {
      R = 0,
      G = 0,
      B = 1
  }, false, true)


  return true
end

function blue_end()
  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")
  colormode = false
  PlayerCameraManager:StartCameraFade(0.40, 0, 6, {
    R = 0,
    G = 0,
    B = 1
  }, false, true)
end

function dark()
  if colormode then return false end

  colormode = true

  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")


  PlayerCameraManager:StartCameraFade(0, 0.95, 2, {
      R = 0,
      G = 0,
      B = 0
  }, false, true)


  return true
end

function dark_end()
  local PlayerCameraManager = FindFirstOf("PlayerCameraManager")
  colormode = false
  PlayerCameraManager:StartCameraFade(0.40, 0, 6, {
    R = 0,
    G = 0,
    B = 0
  }, false, true)
end

jumps = 0

function launch()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  jumps = CharacterMovement.JumpZVelocity 

  CharacterMovement.JumpZVelocity = 1500
  Character:Jump()

  ExecuteWithDelay(1000, function()
    CharacterMovement.JumpZVelocity = jumps
    jumps = 0
  end)  

  return true
end

function megalaunch()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  jumps = CharacterMovement.JumpZVelocity 

  CharacterMovement.JumpZVelocity = 2500
  Character:Jump()

  ExecuteWithDelay(1000, function()
    CharacterMovement.JumpZVelocity = jumps
    jumps = 0
  end)  

  return true
end

function jump()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  if Character:CanJump() ~= true then return false end

  Character:Jump()

  return true
end

function nojump()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  jumps = CharacterMovement.JumpZVelocity 

  CharacterMovement.JumpZVelocity = 0

  return true
end

function nojump_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  CharacterMovement.JumpZVelocity = jumps
  jumps = 0
end

function lowjump()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  jumps = CharacterMovement.JumpZVelocity 

  CharacterMovement.JumpZVelocity = 350

  return true
end

function lowjump_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  CharacterMovement.JumpZVelocity = jumps
  jumps = 0
end

function highjump()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  jumps = CharacterMovement.JumpZVelocity 

  CharacterMovement.JumpZVelocity = 1100

  return true
end

function highjump_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement
  CharacterMovement.JumpZVelocity = jumps
  jumps = 0
end

function ultrajump()
  if jumps > 0 then return false end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement

  jumps = CharacterMovement.JumpZVelocity 

  CharacterMovement.JumpZVelocity = 1500

  return true
end

function ultrajump_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character

  local CharacterMovement = Character.CharacterMovement
  
  CharacterMovement.JumpZVelocity = jumps
  jumps = 0
end

gravity = false
function antigrav()
  if isBoss() then return end
  if gravity then return false end
  local movements = FindAllOf("CharacterMovementComponent")
  if not movements then return false end

  for Index,CharacterMovement in pairs(movements) do
    CharacterMovement.GravityScale = -0.5
    local Character = CharacterMovement.CharacterOwner
    Character:Jump()
  end

  gravity = true

  return true
end

function antigrav_end()
  gravity = false
  local movements = FindAllOf("CharacterMovementComponent")
  if not movements then return false end

  for Index,CharacterMovement in pairs(movements) do
    CharacterMovement.GravityScale = 1.0
  end
end

function highgrav()
  if gravity then return false end
  local movements = FindAllOf("CharacterMovementComponent")
  if not movements then return false end

  for Index,CharacterMovement in pairs(movements) do
    CharacterMovement.GravityScale = 4.0
    local Character = CharacterMovement.CharacterOwner
  end

  gravity = true
  return true
end

function highgrav_end()
  gravity = false
  local movements = FindAllOf("CharacterMovementComponent")
  if not movements then return false end

  for Index,CharacterMovement in pairs(movements) do
    CharacterMovement.GravityScale = 1.0
  end
end

function lowgrav()
  if gravity then return false end
  local movements = FindAllOf("CharacterMovementComponent")
  if not movements then return false end

  for Index,CharacterMovement in pairs(movements) do
    CharacterMovement.GravityScale = 0.3
    local Character = CharacterMovement.CharacterOwner
  end

  gravity = true

  return true
end

function lowgrav_end()
  gravity = false
  local movements = FindAllOf("CharacterMovementComponent")
  if not movements then return false end

  for Index,CharacterMovement in pairs(movements) do
    CharacterMovement.GravityScale = 1.0
  end
end

temp = false
function heat()
  if temp then return end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local PalBodyTemperature = Character.PalBodyTemperature

  PalBodyTemperature:AddHeatSource(FName("CrowdControl"), 256)
  temp = true
  return true
end
  
function heat_end()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local PalBodyTemperature = Character.PalBodyTemperature

  PalBodyTemperature:RemoveHeatSource(FName("CrowdControl"))
  temp = false
end

function cold()
  if temp then return end
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local PalBodyTemperature = Character.PalBodyTemperature

  PalBodyTemperature:AddHeatSource(FName("CrowdControl"), -256)
  temp = true
  return true
end
  
function cold_end()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local PalBodyTemperature = Character.PalBodyTemperature

  PalBodyTemperature:RemoveHeatSource(FName("CrowdControl"))
  temp = false
end

catch = false
function autocatch()
  if catch then return false end
  if isBoss() then return end

  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] - 1.0
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] - 1.5
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] - 1.5
  catch = true
  return true
end

function autocatch_end()
  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] + 1.0
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] + 1.5
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] + 1.5
  catch = false
end


function catchup()
  if catch then return false end
  if isBoss() then return end

  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] - 0.25
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] - 0.25
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] - 0.25
  catch = true
  return true
end

function catchup_end()
  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] + 0.25
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] + 0.25
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] + 0.25
  catch = false
end

function catchdown()
  if catch then return false end
  if isBoss() then return end

  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] + 0.25
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] + 0.25
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] + 0.25
  catch = true
  return true
end

function catchdown_end()
  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] - 0.25
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] - 0.25
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] - 0.25
  catch = false
end

function failcatch()
  if catch then return false end
  if isBoss() then return end

  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] + 3.0
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] + 3.0
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] + 3.0
  catch = true
  return true
end

function failcatch_end()
  local PalGameSetting = FindFirstOf("BP_PalGameSetting_C")
  local CaptureJudgeRateArray = PalGameSetting.CaptureJudgeRateArray

  local size = CaptureJudgeRateArray:GetArrayNum()

  CaptureJudgeRateArray[0] = CaptureJudgeRateArray[0] - 3.0
  CaptureJudgeRateArray[1] = CaptureJudgeRateArray[1] - 3.0
  CaptureJudgeRateArray[2] = CaptureJudgeRateArray[2] - 3.0
  catch = false
end


function fillhunger()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 
  local FullStomach = SaveParameter.FullStomach
  local HungerType = IndividualParameter:GetHungerType()

  if FullStomach == SaveParameter.MaxFullStomach then return false end

  SaveParameter.FullStomach = SaveParameter.MaxFullStomach 
  SaveParameter.HungerType = 0


  IndividualParameter:UpdateFullStomachDelegate__DelegateSignature(SaveParameter.MaxFullStomach, FullStomach )

  
  IndividualParameter:UpdateHungerTypeDelegate__DelegateSignature(0, HungerType)


  local gauges = FindAllOf("WBP_IngameHungerGauge_C")
  if not gauges then return false end

  for Index,IngameHungerGauge in pairs(gauges) do
    IngameHungerGauge:SetHunger({ Value = SaveParameter.FullStomach * 1000 }, { Value = SaveParameter.MaxFullStomach * 1000 } )
  end

  return true
end

function emptyhunger()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 
  local FullStomach = SaveParameter.FullStomach
  local HungerType = IndividualParameter:GetHungerType()

  if FullStomach == 0 then return false end

  SaveParameter.FullStomach = 0 
  SaveParameter.HungerType = 2
  IndividualParameter:UpdateFullStomachDelegate__DelegateSignature(0, FullStomach )

  
  IndividualParameter:UpdateHungerTypeDelegate__DelegateSignature(2, HungerType)


  local gauges = FindAllOf("WBP_IngameHungerGauge_C")
  if not gauges then return false end

  for Index,IngameHungerGauge in pairs(gauges) do
    IngameHungerGauge:SetHunger({ Value = SaveParameter.FullStomach * 1000 }, { Value = SaveParameter.MaxFullStomach * 1000 } )
  end

  return true
end

function takehunger()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 
  local FullStomach = SaveParameter.FullStomach
  local HungerType = IndividualParameter:GetHungerType()

  if FullStomach < SaveParameter.MaxFullStomach / 20 then return false end

  SaveParameter.FullStomach = SaveParameter.FullStomach - SaveParameter.MaxFullStomach / 5
  if SaveParameter.FullStomach < 0 then SaveParameter.FullStomach = 0 end

  if SaveParameter.FullStomach == 0 then
    SaveParameter.HungerType = 2
  else
    if FullStomach < SaveParameter.MaxFullStomach * 0.3  then
      SaveParameter.HungerType = 1
    else
      SaveParameter.HungerType = 0
    end
  end
  
  IndividualParameter:UpdateFullStomachDelegate__DelegateSignature(SaveParameter.FullStomach, FullStomach )

  
  IndividualParameter:UpdateHungerTypeDelegate__DelegateSignature(SaveParameter.HungerType, HungerType)


  local gauges = FindAllOf("WBP_IngameHungerGauge_C")
  if not gauges then return false end

  for Index,IngameHungerGauge in pairs(gauges) do
    IngameHungerGauge:SetHunger({ Value = SaveParameter.FullStomach * 1000 }, { Value = SaveParameter.MaxFullStomach * 1000 } )
  end

  return true
end

function givehunger()

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 
  local FullStomach = SaveParameter.FullStomach
  local HungerType = IndividualParameter:GetHungerType()

  if FullStomach > SaveParameter.MaxFullStomach * 0.95 then return false end

  SaveParameter.FullStomach = SaveParameter.FullStomach + SaveParameter.MaxFullStomach / 5
  if SaveParameter.FullStomach > SaveParameter.MaxFullStomach then SaveParameter.FullStomach = SaveParameter.MaxFullStomach end

  if SaveParameter.FullStomach == 0 then
    SaveParameter.HungerType = 2
  else
    if FullStomach < SaveParameter.MaxFullStomach * 0.3  then
      SaveParameter.HungerType = 1
    else
      SaveParameter.HungerType = 0
    end
  end
  
  IndividualParameter:UpdateFullStomachDelegate__DelegateSignature(SaveParameter.FullStomach, FullStomach )

  
  IndividualParameter:UpdateHungerTypeDelegate__DelegateSignature(SaveParameter.HungerType, HungerType)


  local gauges = FindAllOf("WBP_IngameHungerGauge_C")
  if not gauges then return false end

  for Index,IngameHungerGauge in pairs(gauges) do
    IngameHungerGauge:SetHunger({ Value = SaveParameter.FullStomach * 1000 }, { Value = SaveParameter.MaxFullStomach * 1000 } )
  end

  return true
end

attmod = -1

function attup()
  if attmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  attmod = CharacterParameterComponent.AttackUp

  CharacterParameterComponent.AttackUp = CharacterParameterComponent.AttackUp + 200
  
  return true
end

function attup_end()
   local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  CharacterParameterComponent.AttackUp = attmod
  attmod = -1
  
  return true
end

function attupbig()
  if attmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  attmod = CharacterParameterComponent.AttackUp

  CharacterParameterComponent.AttackUp = CharacterParameterComponent.AttackUp + 800
  
  return true
end

function attupbig_end()
   local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  CharacterParameterComponent.AttackUp = attmod
  attmod = -1
  
  return true
end

function attdown()
  if attmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  attmod = CharacterParameterComponent.AttackUp

  CharacterParameterComponent.AttackUp = CharacterParameterComponent.AttackUp - 50
  
  return true
end

function attdown_end()
   local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  CharacterParameterComponent.AttackUp = attmod
  attmod = -1
  
  return true
end

function attdownbig()
  if attmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  attmod = CharacterParameterComponent.AttackUp

  CharacterParameterComponent.AttackUp = CharacterParameterComponent.AttackUp - 100
  
  return true
end

function attdownbig_end()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  CharacterParameterComponent.AttackUp = attmod
  attmod = -1
  
  return true
end

defmod = -1

function defup()
  if defmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  defmod = CharacterParameterComponent.DefenseUp

  CharacterParameterComponent.DefenseUp = CharacterParameterComponent.DefenseUp + 200
  
  return true
end

function defup_end()
 local PalPlayerController = GetPlayerController()
 local Character = PalPlayerController.Character
 local CharacterParameterComponent = Character.CharacterParameterComponent

 CharacterParameterComponent.DefenseUp = defmod
 defmod = -1
 
 return true
end

function defupbig()
  if defmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  defmod = CharacterParameterComponent.DefenseUp

  CharacterParameterComponent.DefenseUp = CharacterParameterComponent.DefenseUp + 200
  
  return true
end

function defupbig_end()
 local PalPlayerController = GetPlayerController()
 local Character = PalPlayerController.Character
 local CharacterParameterComponent = Character.CharacterParameterComponent

 CharacterParameterComponent.DefenseUp = defmod
 defmod = -1
 
 return true
end

function defdown()
  if defmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  defmod = CharacterParameterComponent.DefenseUp

  CharacterParameterComponent.DefenseUp = CharacterParameterComponent.DefenseUp - 50
  
  return true
end

function defdown_end()
 local PalPlayerController = GetPlayerController()
 local Character = PalPlayerController.Character
 local CharacterParameterComponent = Character.CharacterParameterComponent

 CharacterParameterComponent.DefenseUp = defmod
 defmod = -1
 
 return true
end


function defdownbig()
  if defmod >= 0 then return false end

  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  
  defmod = CharacterParameterComponent.DefenseUp

  CharacterParameterComponent.DefenseUp = CharacterParameterComponent.DefenseUp - 100
  
  return true
end

function defdownbig_end()
 local PalPlayerController = GetPlayerController()
 local Character = PalPlayerController.Character
 local CharacterParameterComponent = Character.CharacterParameterComponent

 CharacterParameterComponent.DefenseUp = defmod
 defmod = -1
 
 return true
end

exps = { 0, 8, 38, 136, 316, 594, 988, 1524, 2229, 3137, 4290, 5734, 7529, 9745, 12466, 15795, 19850, 24778, 30754, 37987, 46730, 57282, 70007, 85339, 103798, 126013, 152732, 184857, 223468, 269864, 325601, 392548, 472946, 569486, 685394, 824548, 991594, 1192111, 1432794, 1721675, 2068394, 2484519, 2983932, 3583289, 4302579, 5165789, 6201703, 7444862, 8936715, 10727000, -1 }

function expup()
    local PalPlayerController = GetPlayerController()
    local Character = PalPlayerController.Character
    local CharacterParameterComponent = Character.CharacterParameterComponent
    local IndividualParameter = CharacterParameterComponent.IndividualParameter 
    local SaveParameter = IndividualParameter.SaveParameter 
  
    local WBP_PLLvExp_C = FindFirstOf("WBP_PLLvExp_C")
    if WBP_PLLvExp_C == nil then return false end
  
    local oldexp = SaveParameter.Exp

    local last = -1
    local next = -1

    for i=1, 50 do
      if exps[i+1] > oldexp then
          last = exps[i]
          next = exps[i+1]
          break
      end
    end

    if last==-1 then return false end
    if next==-1 then return false end

    local del = next - last
    del = del // 10
    local progress = oldexp - last

    if del + oldexp > next then
      del = next - oldexp
    end

    if del < 2 then return false end

    WBP_PLLvExp_C:UpdateExp(del, oldexp, 1.0)
    SaveParameter.Exp = SaveParameter.Exp + del

  return true
end
 
function expdown()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 

  local WBP_PLLvExp_C = FindFirstOf("WBP_PLLvExp_C")
  if WBP_PLLvExp_C == nil then return false end

  local oldexp = SaveParameter.Exp

  local last = -1
  local next = -1

  for i=1, 50 do
    if exps[i+1] > oldexp then
        last = exps[i]
        next = exps[i+1]
        break
    end
  end

  if last==-1 then return false end
  if next==-1 then return false end

  local del = next - last
  del = del // 10
  del = -1 * del
  local progress = oldexp - last

  if del + oldexp < last then
    del = last - oldexp
  end

  if del > -2 then return false end

  WBP_PLLvExp_C:UpdateExp(del, oldexp, 1.0)
  SaveParameter.Exp = SaveParameter.Exp + del

return true
end


function expzero()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 

  local WBP_PLLvExp_C = FindFirstOf("WBP_PLLvExp_C")
  if WBP_PLLvExp_C == nil then return false end

  local oldexp = SaveParameter.Exp

  local last = -1
  local next = -1

  for i=1, 50 do
    if exps[i+1] > oldexp then
        last = exps[i]
        next = exps[i+1]
        break
    end
  end

  if last==-1 then return false end
  if next==-1 then return false end

  local progress = oldexp - last
  local del = -1 * progress
  if del > -2 then return false end

  WBP_PLLvExp_C:UpdateExp(del, oldexp, 1.0)
  SaveParameter.Exp = SaveParameter.Exp + del

return true
end


function expfull()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 

  local WBP_PLLvExp_C = FindFirstOf("WBP_PLLvExp_C")
  if WBP_PLLvExp_C == nil then return false end

  local oldexp = SaveParameter.Exp

  local last = -1
  local next = -1

  for i=1, 50 do
    if exps[i+1] > oldexp then
        last = exps[i]
        next = exps[i+1]
        break
    end
  end

  if last==-1 then return false end
  if next==-1 then return false end

  local progress = next - oldexp
  local del = progress
  if del < 2 then return false end

  WBP_PLLvExp_C:UpdateExp(del, oldexp, 1.0)
  SaveParameter.Exp = SaveParameter.Exp + del

return true
end

function fire()
  local PalPlayerController = GetPlayerController()
  local Character = PalPlayerController.Character
  local CharacterParameterComponent = Character.CharacterParameterComponent
  local IndividualParameter = CharacterParameterComponent.IndividualParameter 
  local SaveParameter = IndividualParameter.SaveParameter 

  local WBP_PLLvExp_C = FindFirstOf("WBP_PLLvExp_C")
  if WBP_PLLvExp_C == nil then return false end

  local oldexp = SaveParameter.Exp

  local last = -1
  local next = -1

  for i=1, 50 do
    if exps[i+1] > oldexp then
        last = exps[i]
        next = exps[i+1]
        break
    end
  end

  if last==-1 then return false end
  if next==-1 then return false end

  local progress = oldexp - last
  local del = -1 * progress
  if del > -2 then return false end

  WBP_PLLvExp_C:UpdateExp(del, oldexp, 1.0)
  SaveParameter.Exp = SaveParameter.Exp + del

return true
end

