-- mod_security alike in LUA for mod_magnet
-- rd

LOG = true
DROP = true
 
function returnError(e)
        if (lighty.env["request.remote-ip"]) then
                remoteip = lighty.env["request.remote-ip"]
        else
                remoteip = "UNKNOWN_IP"
        end
        if (LOG == true) then
                print ( remoteip .. " blocked due to ".. e .. " --- " ..
                                lighty.env["request.method"] .. " " .. lighty.request["Host"] .. " " .. lighty.env["request.uri"])
        end
        if (DROP == true) then
                return 405
        end
end
 
function SQLInjection(content)
        if (string.find(content, "UNION")) then
                return returnError('UNION in uri')
        end
end
 
function UserAgent(UA)
        UA = UA:gsub("%a", string.lower, 1)
        if (string.find(UA, "libwhisker")) then
                return returnError('UserAgent - libwhisker')
        elseif (string.find(UA, "paros")) then
                return returnError('UserAgent - paros')
--        elseif (string.find(UA, "wget")) then
--                return returnError('UserAgent - wget')
        elseif (string.find(UA, "libwww")) then
                return returnError('UserAgent - libwww')
        elseif (string.find(UA, "perl")) then
                return returnError('UserAgent - perl')
        elseif (string.find(UA, "java")) then
                return returnError('UserAgent - java')
        end
end
 
-- URI = lighty.env["request.uri"]
-- POST = lighty.request
if ( SQLInjection(lighty.env["request.uri"]) == 405) then
       ret = 405
end
if ( UserAgent(lighty.request["User-Agent"]) == 405) then
       ret = 405
end
return ret
