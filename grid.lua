local rout = {}

local _obj_ = _obj_ or setmetatable({}, { __call = function(_, o) return o end })

local edge = { rising = 1, falling = 0, both = 2 }

local lvl = function(s, i, x, y)
    local x = s.p_('lvl', x, y)
    -- come back later and understand or not understand ? :)
    return (type(x) ~= 'table') and ((i > 0) and x or 0) or x[i + 1] or 15
end

rout.binary = {}

rout.binary.input = {
    point = function(s, x, y, z, min, max, wrap)
        if z > 0 then 
            s.tlast = s.tdown
            s.tdown = util.time()
        else s.theld = util.time() - s.tdown end
        return z, s.theld
    end,
    line = function(s, i, y, z, min, max, wrap)
        --local i = x - s.p_.x[1] + 1
        local add
        local rem

        if z > 0 then
            add = i
            s.tlast[i] = s.tdown[i]
            s.tdown[i] = util.time()
            table.insert(s.list, i)
            if wrap and #s.list > wrap then rem = table.remove(s.list, 1) end
        else
            -- rem = i ----- negative concequences  ?
            local k = tab.key(s.list, i)
            if k then
                rem = table.remove(s.list, k)
            end
            s.theld[i] = util.time() - s.tdown[i]
        end
        
        if add then s.held[add] = 1 end
        if rem then s.held[rem] = 0 end

        return (#s.list >= min and (max == nil or #s.list <= max)) and s.held or nil, s.theld, nil, add, rem, s.list
    end,
    plane = function(s, x, y, z, min, max, wrap)
        --local i = { x = x - s.p_.x[1] + 1, y = y - s.p_.y[1] + 1 }
        local i = { x = x, y = y }
        local add
        local rem

        if z > 0 then
            add = i
            s.tlast[i.x][i.y] = s.tdown[i.x][i.y]
            s.tdown[i.x][i.y] = util.time()
            table.insert(s.list, i)
            if wrap and (#s.list > wrap) then rem = table.remove(s.list, 1) end
        else
            rem = i
            for j,w in ipairs(s.list) do
                if w.x == i.x and w.y == i.y then 
                    rem = table.remove(s.list, j)
                end
            end
            s.theld[i.x][i.y] = util.time() - s.tdown[i.x][i.y]
        end

        if add then s.held[add.x][add.y] = 1 end
        if rem then s.held[rem.x][rem.y] = 0 end

        --[[
        if (#s.list >= min and (max == nil or #s.list <= max)) then
            return s.held, s.theld, nil, add, rem, s.list
        end
        ]]

        return (#s.list >= min and (max == nil or #s.list <= max)) and s.held or nil, s.theld, nil, add, rem, s.list
    end
}

rout.binary.change = {
    point = function(s, v) 
        local lvl = lvl(s, v)
        local d = s.devs.g

        if s.lvl_clock then clock.cancel(s.lvl_clock) end

        if type(lvl) == 'function' then
            s.lvl_clock = clock.run(function()
                lvl(s, function(l)
                    s.lvl_frame = l
                    d.dirty = true
                end)
            end)
        end
    end,
    line_x = function(s, v) 
        local d = s.devs.g
        for x,w in ipairs(v) do 
            local lvl = lvl(s, w, x)
            if s.lvl_clock[x] then clock.cancel(s.lvl_clock[x]) end

            if type(lvl) == 'function' then
                s.lvl_clock[x] = clock.run(function()
                    lvl(s, function(l)
                        s.lvl_frame[x] = l
                        d.dirty = true
                    end)
                end)
            end
        end
    end,
    plane = function(s, v) 
        local d = s.devs.g
        for x,r in ipairs(v) do 
            for y,w in ipairs(r) do 
                local lvl = lvl(s, w, x, y)
                if s.lvl_clock[x][y] then clock.cancel(s.lvl_clock[x][y]) end

                if type(lvl) == 'function' then
                    s.lvl_clock[x][y] = clock.run(function()
                        lvl(s, function(l)
                            s.lvl_frame[x][y] = l
                            d.dirty = true
                        end)
                    end)
                end
            end
        end
    end
}
rout.binary.change.line_y = rout.binary.change.line_x

rout.binary.redraw = {
    point = function(s, v, g)
        local lvl = lvl(s, v)

        if type(lvl) == 'function' then lvl = s.lvl_frame end
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, v, g)
        for x,l in ipairs(v) do 
            local lvl = lvl(s, l, x)
            if type(lvl) == 'function' then lvl = s.lvl_frame[x] end
            if lvl > 0 then g:led(x + s.p_.x[1] - 1, s.p_.y, lvl) end
        end
    end,
    line_y = function(s, v, g)
        for y,l in ipairs(v) do 
            local lvl = lvl(s, l, y)
            if type(lvl) == 'function' then lvl = s.lvl_frame[y] end
            if lvl > 0 then g:led(s.p_.x, s.p_.y[2] - y + 1, lvl) end
        end
    end,
    plane = function(s, v, g)
        for x,r in ipairs(v) do 
            for y,l in ipairs(r) do 
                local lvl = lvl(s, l, x, y)
                if type(lvl) == 'function' then lvl = s.lvl_frame[x][y] end
                if lvl > 0 then g:led(x + s.p_.x[1] - 1, s.p_.y[2] - y + 1, lvl) end
            end
        end
    end
}

local function count(s) 
    local min = 0
    local max = nil

    if type(s.p_.count) == "table" then 
        max = s.p_.count[#s.p_.count]
        min = #s.p_.count > 1 and s.p_.count[1] or 0
    else max = s.p_.count end

    return min, max
end

local function fingers(s)
    local min = 0
    local max = math.huge

    if type(s.p_.fingers) == "table" then 
        max = s.p_.fingers[#s.p_.fingers]
        min = #s.p_.fingers > 1 and s.p_.fingers[1] or 0
    else max = s.p_.fingers or max end

    return min, max
end

rout.momentary = {}

rout.momentary.input = {
    point = function(s, x, y, z)
        return rout.binary.input.point(s, x, y, z)
    end,
    line = function(s, x, y, z)
        local max
        local min, wrap = count(s)
        if s.fingers then
            min, max = fingers(s)
        end        

        local v,t,last,add,rem,list = rout.binary.input.line(s, x, y, z, min, max, wrap)
        if v then
            return v,t,last,add,rem,list
        else
            return s.vinit, s.vinit, nil, nil, nil, s.blank
        end
    end,
    plane = function(s, x, y, z)
        local max
        local min, wrap = count(s)
        if s.fingers then
            min, max = fingers(s)
        end        

        local v,t,last,add,rem,list = rout.binary.input.plane(s, x, y, z, min, max, wrap)
        if v then
            return v,t,last,add,rem,list
        else
            return s.vinit, s.vinit, nil, nil, nil, s.blank
        end
    end
}

rout.momentary.redraw = rout.binary.redraw
rout.momentary.change = rout.binary.change

local function toggle(s, value, lvl, range, include)
    local function delta(vvv)
        local v = (vvv + 1) % (((type(lvl) == 'table') and #lvl > 1) and (#lvl) or 2)

        if range[1] and range[2] then
            while v > range[2] do
                v = v - (range[2] - range[1]) - 1
            end
            while v < range[1] do
                v = v + (range[2] - range[1]) + 1
            end
        end

        return v
    end

    local vv = delta(value)

    if include then
        local i = 0
        while not tab.contains(include, vv) do
            vv = delta(vv)
            i = i + 1
            if i > 64 then break end -- seat belt
        end
    end

    return vv
end

local function togglelow(s, range, include)
    if range[1] and range[2] and include then
        return math.max(range[1], include[1])
    elseif (range[1] and range[2]) or include then
        return range[1] or include[1]
    else return 0 end
end

local function toggleset(s, v, lvl, range, include)      
    if range[1] and range[2] then
        while v > range[2] do
            v = v - (range[2] - range[1]) - 1
        end
        while v < range[1] do
            v = v + (range[2] - range[1]) + 1
        end
    end

    if include then
        local i = 0
        while not tab.contains(include, v) do
            v = toggle(s, v, lvl, range, include)
            i = i + 1
            if i > 64 then break end -- seat belt
        end
    end

    return v
end

rout.toggle = {}

rout.toggle.input = {
    point = function(s, x, y, z)
        local held = rout.binary.input.point(s, x, y, z)
        local e = edge[s.p_.edge]

        if e == held or (held == 1 and e == 2) then
            return toggle(s, s.p_.v, s.p_.lvl,  { s.p_.min, s.p_.max }, s.p_.include),
                s.theld,
                util.time() - s.tlast
        elseif e == 2 then
            return s.p_.v, s.theld, util.time() - s.tlast
        end
    end,
    line = function(s, x, y, z)
        local held, theld, _, hadd, hrem, hlist = rout.binary.input.line(s, x, y, z, 0, nil)
        local min, max = count(s)
        local i
        local add
        local rem
        local e = edge[s.p_.edge]
       
        if e > 0 and hadd then i = hadd end
        if e == 0 and hrem then i = hrem end

        if fingers and e == 0 then
            local fmin, fmax = fingers(s)

            if hrem then
                if #hlist+1 >= fmin and #hlist+1 <= fmax then
                    local function tog(ii)
                        local range = { s.p_('min', ii), s.p_('max', ii) }
                        local include = s.p_('include', ii)
                        local low = togglelow(s, range, include)

                        s.p_.v[ii] = toggle(
                            s, 
                            s.p_.v[ii], 
                            s.p_('lvl', ii),
                            range,
                            include
                        ) 
                        s.ttog[ii] = util.time() - s.tlast[ii]

                        if s.p_.v[ii] > low then
                            if not tab.contains(s.toglist, ii) then table.insert(s.toglist, ii) end
                            if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                        else 
                            rem = ii
                            local k = tab.key(s.toglist, ii)
                            if k then
                                rem = table.remove(s.toglist, k)
                            end
                        end
                    end

                    add = hrem
                    tog(hrem)
                    
                    if rem then s.p_.v[rem] = togglelow(s, { s.p_('min', rem), s.p_('max', rem) }, s.p_('include', rem)) end

                    for j,w in ipairs(hlist) do tog(w) end
                    
                    s:replace('list', {})

                    return s.p_.v, theld, s.ttog, add, rem, s.toglist
                else
                    s:replace('list', {})
                end
            end
        else
            if i then   
                if #s.toglist >= min then
                    local range = { s.p_('min', i), s.p_('max', i) }
                    local include = s.p_('include', i)
                    local v = toggle(
                        s, 
                        s.p_.v[i], 
                        lvl,
                        range,
                        include
                    )
                    local low = togglelow(s, range, include)
                    
                    if v > low then
                        add = i
                        
                        if not tab.contains(s.toglist, i) then table.insert(s.toglist, i) end
                        if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                    else 
                        rem = i
                        local k = tab.key(s.toglist, i)
                        if k then
                            rem = table.remove(s.toglist, k)
                        end
                    end
                
                    s.ttog[i] = util.time() - s.tlast[i]

                    if add then s.p_.v[add] = v end
                    if rem then s.p_.v[rem] = togglelow(s, { s.p_('min', rem), s.p_('max', rem) }, s.p_('include', rem)) end

                else
                    local hhlist = _obj_ {}
                    if hrem then
                        for j, w in ipairs(hlist) do hhlist[j] = w end
                        table.insert(hhlist, hrem)
                    else hhlist = hlist end

                    if #hhlist >= min then
                        for j,w in ipairs(hhlist) do
                            s.toglist[j] = w
                            s.p_.v[w] = toggleset(s, 1, s.p_('lvl', w), { s.p_('min', w), s.p_('max', w) }, s.p_('include', w))
                        end
                    end
                end
                
                if #s.toglist < min then
                    for j,w in ipairs(s.p_.v) do s.p_.v[j] = togglelow(s, { s.p_('min', j), s.p_('max', j) }, s.p_('include', j)) end
                    --s.toglist = {}
                    s:replace('toglist', {})
                end

                return s.p_.v, theld, s.ttog, add, rem, s.toglist
            elseif e == 2 then
                return s.p_.v, theld, s.ttog, nil, nil, s.toglist
            end
        end
    end,
    --TODO: copy over changes in line
    plane = function(s, x, y, z)
        local held, theld, _, hadd, hrem, hlist = rout.binary.input.plane(s, x, y, z, 0, nil)
        local min, max = count(s)
        local i
        local add
        local rem
        local e = edge[s.p_.edge]
       
        if e > 0 and hadd then i = hadd end
        if e == 0 and hrem then i = hrem end
        
        if i and held then   
            if #s.toglist >= min then
                local lvl = s.p_('lvl', i.x, i.y)
                local range = { s.p_('min', i.x, i.y), s.p_('max', i.x, i.y) }
                local include = s.p_('include', i.x, i.y)
                local v = toggle(
                    s, 
                    s.p_.v[i.x][i.y], 
                    lvl,
                    range,
                    include
                )
                local low = togglelow(s, range, include)
                
                if v > low then
                    add = i
                    
                    local contains = false
                    for j,w in ipairs(s.toglist) do
                        if w.x == i.x and w.y == i.y then 
                            contains = true
                            break
                        end
                    end
                    if not contains then table.insert(s.toglist, i) end
                    if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                else 
                    rem = i
                    for j,w in ipairs(s.toglist) do
                        if w.x == i.x and w.y == i.y then 
                            rem = table.remove(s.toglist, j)
                        end
                    end
                end
            
                s.ttog[i.x][i.y] = util.time() - s.tlast[i.x][i.y]

                if add then s.p_.v[add.x][add.y] = v end
                if rem then s.p_.v[rem.x][rem.y] = togglelow(s, { s.p_('min', rem.x, rem.y), s.p_('max', rem.x, rem.y) }, s.p_('include', rem.x, rem.y)) end

            elseif #hlist >= min then
                for j,w in ipairs(hlist) do
                    s.toglist[j] = w
                    s.p_.v[w.x][w.y] = toggleset(s, 1, s.p_('lvl', w.x, w.y), { s.p_('min', w.x, w.y), s.p_('max', w.x, w.y) }, s.p_('include', w.x, w.y))
                end
            end

            if #s.toglist < min then
                for x,w in ipairs(s.p_.v) do 
                    for y,_ in ipairs(w) do
                        s.p_.v[x][y] = low
                    end
                end
                --s.toglist = {}
                s:replace('toglist', {})
            end

            return s.p_.v, theld, s.ttog, add, rem, s.toglist
        elseif e == 2 then
            return s.p_.v, theld, s.ttog, nil, nil, s.toglist
        end
    end
}

rout.toggle.redraw = rout.binary.redraw
rout.toggle.change = rout.binary.change

rout.trigger = {}

rout.trigger.input = {
    point = function(s, x, y, z)
        local held = rout.binary.input.point(s, x, y, z)
        local e = edge[s.p_.edge]
        
        if e == held then
            return 1, s.theld, util.time() - s.tlast
        end
    end,
    line = function(s, x, y, z)
        local min, max = count(s)
        local held, theld, _, hadd, hrem, hlist = rout.binary.input.line(s, x, y, z, 0, nil)
        local ret = false
        local lret, add
        local e = edge[s.p_.edge]

        if fingers and e == 0 then
            local fmin, fmax = fingers(s)
            fmin = math.max(fmin, min)

            if hrem then
                if #hlist+1 >= fmin and #hlist+1 <= fmax then
                    s:replace('triglist', {})

                    if s.p_.v[hrem] <= 0 then
                        add = hrem
                        s.p_.v[hrem] = 1 
                        s.tdelta[hrem] = util.time() - s.tlast[hrem]
                        table.insert(s.triglist, hrem)
                    end

                    --this is gonna kinda remove indicies randomly when getting over max
                    --oh well
                    for i,w in ipairs(hlist) do if max and (i+1 <= max) then
                        if s.p_.v[w] <= 0 then
                            s.p_.v[w] = 1
                            s.tdelta[w] = util.time() - s.tlast[w]
                            table.insert(s.triglist, w)
                        end
                    end end
                    
                    s:replace('list', {})

                    return s.p_.v, s.theld, s.tdelta, add, nil, s.triglist
                else
                    s:replace('list', {})
                end
            end
        else
            if e == 1 and #hlist > min and (max == nil or #hlist <= max) and hadd then
                s.p_.v[hadd] = 1
                s.tdelta[hadd] = util.time() - s.tlast[hadd]

                ret = true
                add = hadd
                lret = hlist
            elseif e == 1 and #hlist == min and hadd then
                for i,w in ipairs(hlist) do 
                    s.p_.v[w] = 1

                    s.tdelta[w] = util.time() - s.tlast[w]
                end

                ret = true
                lret = hlist
                add = hlist[#hlist]

            elseif e == 0 and #hlist >= min - 1 and (max == nil or #hlist <= max - 1)and hrem and not hadd then
                --s.triglist = {}
                s:replace('triglist', {})

                for i,w in ipairs(hlist) do 
                    if s.p_.v[w] <= 0 then
                        s.p_.v[w] = 1
                        s.tdelta[w] = util.time() - s.tlast[w]
                        table.insert(s.triglist, w)
                    end
                end
                
                if s.p_.v[hrem] <= 0 then
                    ret = true
                    lret = s.triglist
                    add = hrem
                    s.p_.v[hrem] = 1 
                    s.tdelta[hrem] = util.time() - s.tlast[hrem]
                    table.insert(s.triglist, hrem)
                end
            end
                
            if ret then return s.p_.v, s.theld, s.tdelta, add, nil, lret end
        end
    end,
    --TODO: copy new changes from line
    plane = function(s, x, y, z)
        local max
        local min, max = count(s)
        if s.fingers then
            min, max = fingers(s)
        end        
        local held, theld, _, hadd, hrem, hlist = rout.binary.input.plane(s, x, y, z, 0, nil)
        local ret = false
        local lret, add
        local e = edge[s.p_.edge]

        if e == 1 and #hlist > min and (max == nil or #hlist <= max) and hadd then
            s.p_.v[hadd.x][hadd.y] = 1
            s.tdelta[hadd.x][hadd.y] = util.time() - s.tlast[hadd.x][hadd.y]

            ret = true
            add = hadd
            lret = hlist
        elseif e == 1 and #hlist == min and hadd then
            for i,w in ipairs(hlist) do 
                s.p_.v[w.x][w.y] = 1

                s.tdelta[w.x][w.y] = util.time() - s.tlast[w.x][w.y]
            end

            ret = true
            add = hlist[#hlist]
            lret = hlist
        elseif e == 0 and #hlist >= min - 1 and (max == nil or #hlist <= max - 1)and hrem and not hadd then
            --s.triglist = {}
            s:replace('triglist', {})

            for i,w in ipairs(hlist) do 
                if s.p_.v[w.x][w.y] <= 0 then
                    s.p_.v[w.x][w.y] = 1
                    s.tdelta[w.x][w.y] = util.time() - s.tlast[w.x][w.y]
                    table.insert(s.triglist, w)
                end
            end
            
            if s.p_.v[hrem.x][hrem.y] <= 0 then
                ret = true
                lret = s.triglist
                add = hrem
                s.p_.v[hrem.x][hrem.y] = 1 
                s.tdelta[hrem.x][hrem.y] = util.time() - s.tlast[hrem.x][hrem.y]
                table.insert(s.triglist, hrem)
            end
        end
            
        if ret then return s.p_.v, s.theld, s.tdelta, add, nil, lret end
    end
}

rout.trigger.change = {
    point = function(s, v) 
        local lvl = lvl(s, v)
        local d = s.devs.g

        if s.lvl_clock then clock.cancel(s.lvl_clock) end

        if type(lvl) == 'function' then
            s.lvl_clock = clock.run(function()
                lvl(s, function(l)
                    s.lvl_frame = l
                    d.dirty = true
                end)

                --if type(s.p_.v) ~= 'function' then s.p_.v = 0 end -------------------
            end)
        end
    end,
    line_x = function(s, v) 
        local d = s.devs.g
        for x,w in ipairs(v) do 
            local lvl = lvl(s, w, x)
            if s.lvl_clock[x] then clock.cancel(s.lvl_clock[x]) end

            if type(lvl) == 'function' then
                s.lvl_clock[x] = clock.run(function()
                    lvl(s, function(l)
                        s.lvl_frame[x] = l
                        d.dirty = true
                    end)
                        
                    s.p_.v[x] = 0
                end)
            end
        end
    end,
    plane = function(s, v) 
        local d = s.devs.g
        for x,r in ipairs(v) do 
            for y,w in ipairs(r) do 
                local lvl = lvl(s, w, x, y)
                if s.lvl_clock[x][y] then clock.cancel(s.lvl_clock[x][y]) end

                if type(lvl) == 'function' then
                    s.lvl_clock[x][y] = clock.run(function()
                        lvl(s, function(l)
                            s.lvl_frame[x][y] = l
                            d.dirty = true
                        end)
                                
                        s.p_.v[x][y] = 0
                    end)
                end
            end
        end
    end
}
rout.trigger.redraw = rout.binary.redraw

rout.fill = {}
rout.fill.redraw = rout.binary.redraw

rout.number = {}

rout.number.input = {
    point = function(s, x, y, z) 
        if z > 0 then return 0 end
    end,
    line = function(s, i, _, z) 
        --local i = x - s.p_.x[1] + 1
        local min, max = fingers(s)
        local m = ((s.p_.controlspec and s.p_.controlspec.minval) or s.p_.min or 1) - 1
        local e = edge[s.p_.edge]

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e > 0 then 
                if (i+m) ~= s.p_.v or (not s.p_.filtersame) then 
                    local len = #s.hlist
                    --s.hlist = {}
                    s:replace('hlist', {})

                    if max == nil or len <= max then
                        s.vlast = s.p_.v
                        return i+m, len > 1 and util.time() - s.tdown or 0, i+m - s.vlast, i+m
                    end
                elseif e == 2 then
                    return i+m, 0, i+m - s.vlast, i+m
                end
            end
        else
            if e == 0 then
                if #s.hlist >= min then
                    i = s.hlist[#s.hlist]
                    local len = #s.hlist
                    --s.hlist = {}
                    s:replace('hlist', {})

                    if max == nil or len <= max then
                        if (i+m) ~= s.p_.v or (not s.p_.filtersame) then 
                            s.vlast = s.p_.v
                            return i+m, util.time() - s.tdown, i - s.vlast-m
                        end
                    end
                else
                    local k = tab.key(s.hlist, i)
                    if k then
                        table.remove(s.hlist, k)
                    end
                end
            elseif e == 2 then
                --if i ~= s.p_.v or (not s.filtersame) then 
                s:replace('hlist', {})
                    --if i ~= s.p_.v then 
                return i+m, 0, i+m - s.vlast, nil, i+m
                    --end
                --end
            end
        end
    end,
    plane = function(s, x, y, z) 
        --local i = { x = x - s.p_.x[1] + 1, y = y - s.p_.y[1] + 1 }
        local i = _obj_ { x = x, y = y }
        local e = edge[s.p_.edge]

        local min, max = fingers(s)
        local m = ((s.p_.controlspec and s.p_.controlspec.minval) or s.p_.min or 1) - 1
        m = type(m) ~= 'table' and { m, m } or m
        for i,v in ipairs(m) do m[i] = v - 1 end

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e > 0 then 
                local len = #s.hlist
                if (
                    not ((i.x+m[1]) == s.p_.v.x and (i.y+m[2]) == s.p_.v.y)
                    ) or (not s.p_.filtersame) 
                then 
                    --s.hlist = {}
                    s:replace('hlist', {})
                    s.vlast.x = s.p_.v.x
                    s.vlast.y = s.p_.v.y
                    s.p_.v.x = i.x + m[1]
                    s.p_.v.y = i.y + m[2]

                    if max == nil or len <= max then
                        return s.p_.v, len > 1 and util.time() - s.tdown or 0, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }, i
                    end
                elseif e == 2 then
                    -- if max == nil or len <= max then
                        return s.p_.v, 0, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }, i
                    -- end
                end
            end
        else
            if e == 0 then
                if #s.hlist >= min then
                    --i = s.hlist[#s.hlist] or i
                    local len = #s.hlist
                    --s.hlist = {}
                    s:replace('hlist', {})

                    if max == nil or len <= max then
                        if (
                            not ((i.x+m[1]) == s.p_.v.x and (i.y+m[2]) == s.p_.v.y)
                            ) or (not s.p_.filtersame) 
                        then 
                            s.vlast.x = s.p_.v.x
                            s.vlast.y = s.p_.v.y
                            s.p_.v.x = i.x + m[1]
                            s.p_.v.y = i.y + m[2]
                            return s.p_.v, util.time() - s.tdown, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }
                        end
                    end
                else
                    for j,w in ipairs(s.hlist) do
                        if w.x == i.x and w.y == i.y then 
                            table.remove(s.hlist, j)
                        end
                    end
                end
            elseif e == 2 then
                s:replace('hlist', {})
                -- if (i.x == s.p_.v.x and i.y == s.p_.v.y) then
                    return s.p_.v, util.time() - s.tdown, _obj_ { s.p_.v.x - s.vlast.x, s.p_.v.y - s.vlast.y }, nil, i
                -- end
            end
        end
    end
}

rout.number.redraw = {
    point = function(s, v, g)
        local lvl = lvl(s, 1)
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, v, g)
        for i = 1, s.p_.x[2] - s.p_.x[1] + 1 do
            local lvl = lvl(s, s.p_.v - s.p_.min + 1 == i and 1 or 0, i)
            local x,y,w = i, 1, s.p_.wrap
            if s.p_.wrap then
                x = (i-1)%w + 1
                y = (i-1)//w + 1
            end
            if lvl > 0 then g:led(x + s.p_.x[1] - 1, y + s.p_.y - 1, lvl) end
        end
    end,
    --TODO: wrap
    line_y = function(s, v, g)
        for i = 1, s.p_.y[2] - s.p_.y[1] + 1 do
            local lvl = lvl(s, (s.p_.v - s.p_.min + 1 == i) and 1 or 0, i)
            if lvl > 0 then g:led(s.p_.x, s.p_.y[2] - i + 1, lvl) end
        end
    end,
    plane = function(s, v, g)
        local m = ((s.p_.controlspec and s.p_.controlspec.minval) or s.p_.min or 1) - 1
        m = type(m) ~= 'table' and { m, m } or m
        for i = s.p_.x[1], s.p_.x[2] do
            for j = s.p_.y[1], s.p_.y[2] do
                local li, lj = i - s.p_.x[1] + 1, s.p_.y[2] - j + 1
                local l = lvl(s, ((s.p_.v.x+m[1] == li) and (s.p_.v.y+m[2] == lj)) and 1 or 0, li, lj)
                if l > 0 then g:led(i, j, l) end
            end
        end
    end
}

rout.control = {}

rout.control.input = {
    point = function(s, x, y, z) 
        return rout.number.input.point(s, x, y, z)
    end,
    line = function(s, x, y, z) 
        local v,t,d = rout.number.input.line(s, x, y, z)
        if v then
            local r = type(s.p_.x) == 'table' and s.p_.x or s.p_.y
            local vv = (v - s.p_.controlspec.minval) / (r[2] - r[1])

            local c = s.p_.controlspec:map(vv)
            if s.p_.v ~= c then
                return c, t, d
            end
        end
    end,
    plane = function(s, x, y, z) 
        local v,t,d = rout.number.input.plane(s, x, y, z)
        if v then
            local ret = false
            for _,k in ipairs { 'x', 'y' } do
                local r = s[k]
                local vv = (v[k] - s.p_.controlspec.minval) / (r[2] - r[1])

                local c = s.p_.controlspec:map(vv)
                if s.p_.v[k] ~= c then
                    ret = true
                    s.p_.v[k] = c
                end
            end

            if ret then return s.p_.v, t, d end
        end
    end
}

rout.control.redraw = {
    point = function(s, v, g)
        local lvl = lvl(s, 1)
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, v, g)
        for i = s.p_.x[1], s.p_.x[2] do
            local l = lvl(s, 0)
            local vv = (i - s.p_.x[1]) / (s.p_.x[2] - s.p_.x[1])
            local m = s.p_.controlspec:map(vv)
            if m == v then l = lvl(s, 2)
            elseif m > v and m <= 0 then l = lvl(s, 1)
            elseif m < v and m >= 0 then l = lvl(s, 1) end
            if l > 0 then g:led(i, s.p_.y, l) end
        end
    end,
    line_y = function(s, v, g)
        for i = s.p_.y[1], s.p_.y[2] do
            local l = lvl(s, 0)
            local vv = (i - s.p_.y[1]) / (s.p_.y[2] - s.p_.y[1])
            local m = s.p_.controlspec:map(vv)
            if m == v then l = lvl(s, 2)
            elseif m > v and m <= 0 then l = lvl(s, 1)
            elseif m < v and m >= 0 then l = lvl(s, 1) end
            if l > 0 then g:led(s.p_.x, s.p_.y[2] - i + s.p_.y[1], l) end
        end
    end,
    plane = function(s, v, g)
        local cs = s.p_.controlspec
        for i = s.p_.x[1], s.p_.x[2] do
            for j = s.p_.y[1], s.p_.y[2] do
                local l = lvl(s, 0)
                local m = {
                    x = cs:map((i - s.p_.x[1]) / (s.p_.x[2] - s.p_.x[1])),
                    y = cs:map(((s.p_.y[2] - j + 2) - s.p_.y[1]) / (s.p_.y[2] - s.p_.y[1])),
                }
                if m.x == v.x and m.y == v.y then l = lvl(s, 2)
                --[[

                alt draw method:

                elseif m.x >= v.x and m.y >= v.y and m.x <= 0 and m.y <= 0 then l = lvl(s, 1)
                elseif m.x >= v.x and m.y <= v.y and m.x <= 0 and m.y >= 0 then l = lvl(s, 1)
                elseif m.x <= v.x and m.y <= v.y and m.x >= 0 and m.y >= 0 then l = lvl(s, 1)
                elseif m.x <= v.x and m.y >= v.y and m.x >= 0 and m.y <= 0 then l = lvl(s, 1)

                ]]
                elseif m.x == cs.minval or m.y == cs.minval or m.x == cs.maxval or m.y == cs.maxval then l = lvl(s, 1)
                elseif m.x == 0 or m.y == 0 then l = lvl(s, 1)
                end
                if l > 0 then g:led(i, j, l) end
            end
        end
    end
}

rout.range = {}

rout.range.input = {
    point = function(s, x, y, z) 
        if z > 0 then return 0 end
    end,
    line = function(s, i, _, z) 
        local e = edge[s.p_.edge]
        --local i = x - s.p_.x[1]

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e == 1 then 
                if #s.hlist >= 2 then 
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            end
        else
            if #s.hlist >= 2 then 
                if e == 0 then
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            else
                local k = tab.key(s.hlist, i)
                if k then
                    table.remove(s.hlist, k)
                end
            end
        end
    end,
    plane = function(s, x, y, z) 
        --local i = { x = x - s.p_.x[1], y = y - s.p_.y[1] }
        i = { x = x, y = y }
        local e = edge[s.p_.edge]

        if z > 0 then
            if #s.hlist == 0 then s.tdown = util.time() end
            table.insert(s.hlist, i)
           
            if e == 1 then 
                if #s.hlist >= 2 then 
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v, function(a, b) 
                        return a.x < b.x
                    end)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            end
        else
            if #s.hlist >= 2 then 
                if e == 0 then
                    local v = _obj_ { s.hlist[1], s.hlist[#s.hlist] }
                    table.sort(v, function(a, b) 
                        return a.x < b.x
                    end)
                    --s.hlist = {}
                    s:replace('hlist', {})
                    return v, util.time() - s.tdown 
                end
            else
                for j,w in ipairs(s.hlist) do
                    if w.x == i.x and w.y == i.y then 
                        table.remove(s.hlist, j)
                    end
                end
            end
        end
    end
}

rout.range.redraw = {
    point = function(s, v, g)
        local lvl = lvl(s, 1)
        if lvl > 0 then g:led(s.p_.x, s.p_.y, lvl) end
    end,
    line_x = function(s, v, g)
        for i = 1, s.p_.x[2] - s.p_.x[1] + 1 do
            local l = lvl(s, 0)
            if i >= v[1] and i <= v[2] then l = lvl(s, 1) end
            if l > 0 then g:led(i + s.p_.x[1] - 1, s.p_.y, l) end
        end
    end,
    line_y = function(s, v, g)
        for i = 1, s.p_.y[2] - s.p_.y[1] + 1 do
            local l = lvl(s, 0)
            if i >= v[1] and i <= v[2] then l = lvl(s, 1) end
            if l > 0 then g:led(s.p_.x, s.p_.y[2] - i + 1, l) end
        end
    end,
    plane = function(s, v, g)
        for i = 1, s.p_.x[2] - s.p_.x[1] + 1 do
            for j = 1, s.p_.y[2] - s.p_.y[1] + 1 do
                local l = lvl(s, 0)
                if (i == v[1].x or i == v[2].x) and j >= v[1].y and j <= v[2].y then l = lvl(s, 1)
                elseif (j == v[1].y or j == v[2].y) and i >= v[1].x and i <= v[2].x then l = lvl(s, 1)
                elseif v[2].y < v[1].y and (i == v[1].x or i == v[2].x) and j >= v[2].y and j <= v[1].y then l = lvl(s, 1)
                end
                if l > 0 then g:led(i + s.p_.x[1] - 1, s.p_.y[2] - j + 1, l) end
            end
        end
    end
}

for k,v in pairs(rout) do
    for kk, vv in pairs(v) do
        if vv.line then
            vv.line_x = vv.line
            vv.line_y = vv.line
        end
    end
end

return rout
