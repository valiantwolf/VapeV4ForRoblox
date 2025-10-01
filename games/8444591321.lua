local vape = shared.vape

local function safeLoadstring(code, name)
    local func, err = loadstring(code, name)
    if not func then
        if vape then
            vape:CreateNotification('Vape', 'Failed to load '..name..' : '..err, 30, 'alert')
        else
            warn('Failed to load '..name..' : '..err)
        end
        return nil
    end
    return func
end

local isfile = isfile or function(file)
    local suc, res = pcall(function() 
        return readfile(file) 
    end)
    return suc and res ~= nil and res ~= ''
end

local function downloadFile(path, func)
    if not isfile(path) then
        local suc, res = pcall(function() 
            return game:HttpGet(
                'https://raw.githubusercontent.com/valiantwolf/VapeV4ForRoblox/'..
                readfile('newvape/profiles/commit.txt')..'/'..
                select(1, path:gsub('newvape/', '')), true
            )
        end)
        if not suc or res == '404: Not Found' then 
            error(res or 'Failed to download '..path)
        end
        if path:find('.lua') then 
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res 
        end
        writefile(path, res)
    end
    return (func or readfile)(path)
end

vape.Place = 6872274481

local gamePath = 'newvape/games/'..vape.Place..'.lua'
if isfile(gamePath) then
    local func = safeLoadstring(readfile(gamePath), 'bedwars')
    if func then func() end
else
    if not shared.VapeDeveloper then
        local suc, res = pcall(function() 
            return game:HttpGet(
                'https://raw.githubusercontent.com/valiantwolf/VapeV4ForRoblox/'..
                readfile('newvape/profiles/commit.txt')..'/games/'..vape.Place..'.lua', true
            )
        end)
        if suc and res ~= '404: Not Found' then
            local func = safeLoadstring(downloadFile('newvape/games/'..vape.Place..'.lua'), 'bedwars')
            if func then func() end
        end
    end
end
