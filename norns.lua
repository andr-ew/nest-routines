local rout = { key = {}, enc = {} }

local function minit(n)
    if type(n) == 'table' then
        local ret = {}
        for i = 1, #n do ret[i] = 0 end
        return ret
    else return 0 end
end

rout.enc.delta = {
    input = {
        point = function(s, n, d) 
            return d
        end,
        line = function(s, n, d) 
            local i = tab.key(s.p_.n, n)
            return d, i
        end
    }
}

local function delta_number(self, value, d)
    local range = { self.p_.min, self.p_.max }

    local v = value + (d * self.p_.inc)

    if self.p_.wrap then
        while v > range[2] do
            v = v - (range[2] - range[1]) - 1
        end
        while v < range[1] do
            v = v + (range[2] - range[1]) + 1
        end
    end

    local c = util.clamp(v, range[1], range[2])
    if value ~= c then
        return c
    end
end

rout.enc.number = {
    input = {
        point = function(s, n, d) 
            return delta_number(s, s.p_.v, d), d * s.p_.inc
        end,
        line = function(s, n, d) 
            local i = tab.key(s.p_.n, n)
            local v = delta_number(s, s.p_.v[i], d * s.p_.inc)
            if v then
                local del = minit(s.p_.n)
                del[i] = d
                s.p_.v[i] = v
                return s.p_.v, del
            end
        end
    }
}

local function delta_control(self, v, d)
    local value = self.p_.controlspec:unmap(v) + (d * self.p_.controlspec.quantum)

    if self.p_.controlspec.wrap then
        while value > 1 do
            value = value - 1
        end
        while value < 0 do
            value = value + 1
        end
    end
    
    local c = self.p_.controlspec:map(util.clamp(value, 0, 1))
    if v ~= c then
        return c
    end
end

rout.enc.control = {
    input = {
        point = function(s, n, d) 
            local last = s.p_.v
            return delta_control(s, s.p_.v, d), s.p_.v - last 
        end,
        line = function(s, n, d) 
            local i = tab.key(s.p_.n, n)
            local v = delta_control(s, s.p_.v[i], d)
            if v then
                local last = s.p_.v[i]
                local del = minit(s.p_.n)
                s.p_.v[i] = v
                del[i] = v - last
                return s.p_.v, del
            end
        end
    }
}

local tab = require 'tabutil'

local function delta_option_point(self, value, d, wrap_scoot)
    local i = value or 0
    local v = i + d
    local size = #self.p_.options + 1 - (self.p_.sens or 1)

    if self.wrap then
        while v > size do
            v = v - size + (wrap_scoot and 1 or 0)
        end
        while v < 1 do
            v = v + size + 1
        end
    end

    local c = util.clamp(v, 1, size)
    if i ~= c then
        return c
    end
end

local function delta_option_line(self, value, dx, dy, wrap_scoot)
    local i = value.x
    local j = value.y
    local sizey = #self.p_.options + 1 - self.p_.sens

    vx = i + (dx or 0)
    vy = j + (dy or 0)

    if self.wrap then
        while vy > sizey do
            vy = vy - sizey + (wrap_scoot and 1 or 0)
        end
        while vy < 1 do
            vy = vy + sizey + 1
        end
    end

    local cy = util.clamp(vy, 1, sizey)
    local sizex = #self.p_.options[cy] + 1 - self.p_.sens

    if self.wrap then
        while vx > sizex do
            vx = vx - sizex
        end
        while vx < 1 do
            vx = vx + sizex + 1
        end
    end

    local cx = util.clamp(vx, 1, sizex)

    if i ~= cx or j ~= cy then
        value.x = cx
        value.y = cy
        return value
    end
end

rout.enc.option = {
    input = {
        point = function(s, n, d) 
            local v = delta_option_point(s, s.p_.v, d, true)
            return v, s.p_.options[v], d
        end,
        line = function(s, n, d) 
            local i = tab.key(s.p_.n, n)
            local dd = { 0, 0 }
            dd[i] = d
            local v = delta_option_line(s, s.p_.v, dd[2], dd[1], true)
            if v then
                local del = minit(s.p_.n)
                del[i] = d
                return v, s.p_.options[v.y][v.x], del
            end
        end
    }
}

local edge = { rising = 1, falling = 0, both = 2 }

rout.key.number = {
    input = {
        point = function(s, n, z) 
            if z == edge[s.p_.edge] then
                s.p_.wrap = true
                return delta_number(s, s.p_.v, s.p_.inc), util.time() - s.tdown, s.p_.inc
            else s.tdown = util.time()
            end
        end,
        line = function(s, n, z) 
            if z == edge[s.p_.edge] then
                local i = tab.key(s.p_.n, n)
                local d = i == 2 and s.p_.inc or -s.p_.inc
                return delta_number(s, s.p_.v, d), util.time() - s.tdown, d
            else s.tdown = util.time()
            end
        end
    }
}

rout.key.option = {
    input = {
        point = function(s, n, z) 
            if z == edge[s.p_.edge] then 
                s.wrap = true
                local v = delta_option_point(s, s.p_.v, s.p_.inc)
                return v, s.p_.options[v], util.time() - s.tdown, s.p_.inc
            else s.tdown = util.time()
            end
        end,
        line = function(s, n, z) 
            if z == edge[s.p_.edge] then 
                local i = tab.key(s.p_.n, n)
                local d = i == 2 and s.p_.inc or -s.p_.inc
                local v = delta_option_point(s, s.p_.v, d)
                return v, s.p_.options[v], util.time() - s.tdown, d
            else s.tdown = util.time()
            end
        end
    }
}

rout.key.binary = {
    input = {
        point = function(s, n, z, min, max, wrap)
            if z > 0 then 
                s.tlast = s.tdown
                s.tdown = util.time()
            else s.theld = util.time() - s.tdown end
            return z, s.theld
        end,
        line = function(s, n, z, min, max, wrap)
            local i = tab.key(s.p_.n, n)
            local add
            local rem

            if z > 0 then
                add = i
                s.tlast[i] = s.tdown[i]
                s.tdown[i] = util.time()
                table.insert(s.list, i)
                if wrap and #s.list > wrap then rem = table.remove(s.list, 1) end
            else
                local k = tab.key(s.list, i)
                if k then
                    rem = table.remove(s.list, k)
                end
                s.theld[i] = util.time() - s.tdown[i]
            end
            
            if add then s.held[add] = 1 end
            if rem then s.held[rem] = 0 end

            return (#s.list >= min and (max == nil or #s.list <= max)) and s.held or nil, s.theld, nil, add, rem, s.list
        end
    }
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
    local max = nil

    if type(s.p_.fingers) == "table" then 
        max = s.p_.fingers[#s.p_.fingers]
        min = #s.p_.fingers > 1 and s.p_.fingers[1] or 0
    else max = s.p_.fingers end

    return min, max
end

rout.key.momentary = {
    input = {
        point = function(s, n, z)
            return rout.key.binary.input.point(s, n, z)
        end,
        line = function(s, n, z)
            local max
            local min, wrap = count(s)
            if s.fingers then
                min, max = fingers(s)
            end        

            local v,t,last,add,rem,list = rout.key.binary.input.line(s, n, z, min, max, wrap)
            if v then
                return v,t,last,add,rem,list
            else
                return s.vinit, s.vinit, nil, nil, nil, s.blank
            end
        end
    }
}

local function toggle(s, v)
    return (v + 1) % (((type(s.p_.lvl) == 'table') and #s.p_.lvl > 1) and (#s.p_.lvl) or 2)
end

rout.key.toggle = {
    input = {
        point = function(s, n, z)
            local held = rout.key.binary.input.point(s, n, z)

            if edge[s.p_.edge] == held then
                return toggle(s, s.p_.v), s.theld, util.time() - s.tlast 
            end
        end,
        line = function(s, n, z)
            local held, theld, _, hadd, hrem, hlist = rout.key.binary.input.line(s, n, z, 0, nil)
            local min, max = count(s)
            local i
            local add
            local rem
           
            if edge[s.p_.edge] == 1 and hadd then i = hadd end
            if edge[s.p_.edge] == 0 and hrem then i = hrem end
     
            if i then   
                if #s.toglist >= min then
                    local v = toggle(s, s.p_.v[i])
                    
                    if v > 0 then
                        add = i
                        
                        if v == 1 then table.insert(s.toglist, i) end
                        if max and #s.toglist > max then rem = table.remove(s.toglist, 1) end
                    else 
                        local k = tab.key(s.toglist, i)
                        if k then
                            rem = table.remove(s.toglist, k)
                        end
                    end
                
                    s.ttog[i] = util.time() - s.tlast[i]

                    if add then s.p_.v[add] = v end
                    if rem then s.p_.v[rem] = 0 end

                elseif #hlist >= min then
                    for j,w in ipairs(hlist) do
                        s.toglist[j] = w
                        s.p_.v[w] = 1
                    end
                end
                
                if #s.toglist < min then
                    for j,w in ipairs(s.p_.v) do s.p_.v[j] = 0 end
                    s.toglist = {}
                end

                return s.p_.v, theld, s.ttog, add, rem, s.toglist
            end
        end
    }
}

rout.key.trigger = {
    input = {
        point = function(s, n, z)
            local held = rout.key.binary.input.point(s, n, z)
            
            if edge[s.p_.edge] == held then
                return 1, s.theld, util.time() - s.tlast
            end
        end,
        line = function(s, n, z)
            local e = edge[s.p_.edge]
            local max
            local min, wrap = count(s)
            if s.fingers then
                min, max = fingers(s)
            end        
            local held, theld, _, hadd, hrem, hlist = rout.key.binary.input.line(s, n, z, 0, nil)
            local ret = false
            local lret, add

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
                s.triglist = {}

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
                    s.p_.v[hrem] = 1 
                    add = hrem
                    s.tdelta[hrem] = util.time() - s.tlast[hrem]
                    table.insert(s.triglist, hrem)
                end
            end
                
            if ret then return s.p_.v, s.theld, s.tdelta, add, nil, lret end
        end
    }
}

return rout
