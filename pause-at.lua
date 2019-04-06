-- PauseAt (C)by Pawel Stolowski
-- Released under the terms of GNU GPL License v3.
--
-- PauseAt is a FlyWithLua script for X-Plane 11 that pauses X-Plane at given distance from
-- an airport, or under abnormal circumstances (not implemented yet).

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("PauseAt requires a newer version of FlyWithLua. Your version of FlyWithLua doesn't support imgui, please upgrade.")
    return
end

pauseAt_airportICAO = ""
pauseAt_airportName = ""
pauseAt_distance = 90
pauseAt_lat = 0
pauseAt_lon = 0
pauseAt_enabled = false
pauseAt_hit_once = false

-- intermediate (temporary) values
t_pauseAt_airportICAO = ""
t_pauseAt_airportName = ""
t_pauseAt_distance = 90

pauseAt_mainWnd = nil

function pauseAt_show_window()
    pauseAt_mainWnd = float_wnd_create(500, 140, 1, true)
    float_wnd_set_title(pauseAt_mainWnd, "Pause At v1.0")
    float_wnd_set_imgui_builder(pauseAt_mainWnd, "build_pauseAtWindow")
end

function pauseAt_hide_window()
    if pauseAt_mainWnd then
        float_wnd_destroy(pauseAt_mainWnd)
    end
end

function airportNameFromICAO(icao)
    local navtype, _, _, _, _, _, _, name = XPLMGetNavAidInfo(XPLMFindNavAid(nil, icao, LATITUDE, LONGITUDE, nil, xplm_Nav_Airport))
    if string.len(name) > 0 and navtype == xplm_Nav_Airport then
        return name
    end
    return ""
end

function build_pauseAtWindow(wnd, x, y)
    local apt_changed, apt = imgui.InputText("Airport ICAO", t_pauseAt_airportICAO, 5)
    imgui.TextUnformatted(t_pauseAt_airportName)
    local dist_changed, dist = imgui.InputInt("Distance", t_pauseAt_distance, 10)
    
    imgui.Separator()

    if pauseAt_enabled then
        if pauseAt_hit_once then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF0000FF)
            imgui.TextUnformatted(string.format("X-Plane was paused at %f nm from %s (%s)", pauseAt_distance, pauseAt_airportName, pauseAt_airportICAO))
            imgui.PopStyleColor()
        else
            imgui.TextUnformatted(string.format("X-Plane will be paused %d nm from %s (%s)", pauseAt_distance, pauseAt_airportName, pauseAt_airportICAO))
        end
    else
        imgui.TextUnformatted("Pause is currently disabled")
    end

    imgui.Separator()
    
    if apt_changed then
        t_pauseAt_airportICAO = string.upper(apt)
        t_pauseAt_airportName = ""
        if string.len(t_pauseAt_airportICAO) == 4 then
            t_pauseAt_airportName = airportNameFromICAO(t_pauseAt_airportICAO)
        end
    end

    if dist_changed then
        t_pauseAt_distance = dist
    end

    if imgui.Button("Reset") then
        pauseAt_airportName = ""
        pauseAt_enabled = false
        pauseAt_hit_once = false
        t_pauseAt_airportICAO = ""
        t_pauseAt_distance = 90
    end
    imgui.SameLine()
    if imgui.Button("Apply") then
        valid = false
        if string.len(t_pauseAt_airportICAO) == 4 and t_pauseAt_distance > 0 then
            pauseAt_airportICAO = t_pauseAt_airportICAO
            pauseAt_distance = t_pauseAt_distance
            local navtype, lat, lon, _, _, _, _, name = XPLMGetNavAidInfo(XPLMFindNavAid(nil, t_pauseAt_airportICAO, LATITUDE, LONGITUDE, nil, xplm_Nav_Airport))
            if string.len(name) > 0 and navtype == xplm_Nav_Airport then
                pauseAt_airportName = name
                pauseAt_lat = lat
                pauseAt_lon = lon
                valid = true
            end
        end
        pauseAt_hit_once = false
        pauseAt_enabled = false
        if valid then
            pauseAt_enabled = true
        else
            t_pauseAt_airportICAO = ""
        end
    end
end

-- Haversine formula taken (and adjusted) from:
-- https://stackoverflow.com/questions/27928/calculate-distance-between-two-latitude-longitude-points-haversine-formula
function distanceInNM(lat1, lon1, lat2, lon2)
    local R = 6371 -- Radius of the earth in km
    local dLat = deg2rad(lat2-lat1)
    local dLon = deg2rad(lon2-lon1);
    local a = math.sin(dLat/2) * math.sin(dLat/2) +
        math.cos(deg2rad(lat1)) * math.cos(deg2rad(lat2)) * 
        math.sin(dLon/2) * math.sin(dLon/2)
    local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    local d = R * c * 0.539956803 -- distance in nm
    return d
end

function deg2rad(deg)
    return deg * (math.pi/180)
end

function check_pauseAt()
    if pauseAt_enabled and not pauseAt_hit_once then
        local dist = distanceInNM(LATITUDE, LONGITUDE, pauseAt_lat, pauseAt_lon)
        if dist <= pauseAt_distance then
                pauseAt_hit_once = true
                print(string.format("pauseAt: paused at %f nm from %s", dist, pauseAt_airportICAO))
                -- just in case check if not paused already
                if get("sim/time/paused") == 0 then
                    command_once("sim/operation/pause_toggle")
                end
        end
    end
end

add_macro("PauseAt", "pauseAt_show_window()")

do_often([[
    check_pauseAt()
]])
