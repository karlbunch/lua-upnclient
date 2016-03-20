--
-- simple.lua - Simple example of adding a port forward using uPnPclient library
--

-- Simple hack allow testing from the examples/.. directory w/o installing
if io.open("../lua/uPnPclient.lua") then
    package.path = '../lua/?.lua;' .. package.path
end

local uPnPclient = assert(require('uPnPclient'))

-- Get client object
local uc = uPnPclient:new{ debug_level = 1 }

-- Find the InternetGatewayDevice
local ret, err = uc:discoverIGD()

if err then
    print("FAILED: " .. err)
    return 1
end

-- Port forward internetIP:80 -> thisHostIP:8080
local ok, err = uc:AddPortMapping('tcp', 80, 8080, "HTTP:80 to this host on port 8080 for an hour", 3600)

if ok then
    print("Add SUCCESS!")
elseif err then
    print("Add FAILURE: " .. err .. "\n")
end

-- Delete port forward internetIP:80 -> thisHostIP:8080
local ok, err = uc:DeletePortMapping('tcp', 80, 8080, "HTTP:80 to this host on port 8080 for an hour", 3600)

if ok then
    print("Delete SUCCESS!")
elseif err then
    print("Delete FAILURE: " .. err .. "\n")
end
