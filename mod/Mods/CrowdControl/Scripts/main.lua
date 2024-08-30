function isReady()

  --this function will reject effects and pause timed effects if it returns false
  --can add checks for things like being in the menu or paused or dead etc here

  return true
end


--add functions for your effects here
--if you have an effect with the code of 'kill' in your cs file then when that effect
--is received the function kill() will be called

--if you put an underscore in you effect id the part after the underscore will be
--used as an argument
-- for example the effect id 'givemoney_100' will call givemoney(100)

--if an effect has a duration, additionally the function with _end added will be
--called when the time is up to do cleanup etc
--so if you have a timed effect with id 'spin' then spin_end() will be called
--if it exists when the timer ends


timed = {}

LoopAsync(10000, function()
  checkConn()
end)

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


LoopAsync(50, function()

  if not connected() then return end

  id, code, dur = getEffect()

  if code == "" then
    return
  end

  local status, ready = pcall(isReady)

  if not status or not ready then
    ccRespond(id, 3)
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

      local func =_G[code]

      if func == nil or pcall(func) then
        ccRespondTimed(entry["id"], 8, 0)
        timed[entry["code"]]=nil
      end
    end
  end
end)