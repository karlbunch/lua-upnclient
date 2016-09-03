--
-- uPnPclient - Simple client to support uPnP packets to devices on the network
--
-- Author: Karl Bunch <karlbunch@karlbunch.com>
--
-- Created: Fri Mar 18 05:22:03 EDT 2016
--
local socket = require('socket')
local http = require('httpclient').new()
local urlparser = require('httpclient.neturl')
local inspect = require("inspect")

local uPnPclient = { }
local _M = {
    VERSION = "v0.3"
}

function _M.new(self, init)
    if type(init) == "table" then
	for k,v in pairs(init) do
	    self[k] = v
	end
    end
    self.debug_level = self.debug_level or 0
    return setmetatable(self, { __index = uPnPclient })
end

function uPnPclient:debug(lvl, ...)
    if lvl > self.debug_level then
	return
    end

    local args = { ... }
    local msg = { }

    for _, v in ipairs(args) do
	if type(v) == "table" then
	    msg[#msg+1] = (inspect and inspect(v)) or (cjson and cjson.encode(v)) or "*table*"
	else
	    msg[#msg+1] = v
	end
    end

    (self.debug_print or print)((self.debug_prefix or "") .. table.concat(msg))
end

local function simple_xml_parse(xml)
  local idx_cur = 1
  local root = { }
  local node_cur = root
  local nodes = { }

  while true do
    local idx_start, idx_end, end_tag, label, args, empty = string.find(xml, "<(%/?)([%w:]+)(.-)(%/?)>", idx_cur)

    if not idx_start then break end

    if end_tag == "" then -- start tag
      node_cur[label] = { }
      nodes[#nodes+1] = node_cur[label]
      node_cur = nodes[#nodes]
    else -- end tag
      table.remove(nodes)
      node_cur = nodes[#nodes]

      local value = string.sub(xml, idx_cur, idx_start - 1)

      if not string.find(value, "^%s*$") then
	  node_cur[label] = value
      end
    end
    idx_cur = idx_end + 1
  end

  return root
end

local function findNodes(t, name, found)
    if found == nil then
	found = { }
    end

    if type(t) == "table" then
	for k,v in pairs(t) do
	    if type(v) == "table" then
		if k == name then
		    found[#found+1] = v
		end
		findNodes(v, name, found)
	    end
	end
    end

    return found
end

function uPnPclient:discoverIGD()
    local ok, err = self:discover("urn:schemas-upnp-org:device:InternetGatewayDevice:1")

    if err then
	return nil, err
    end

    -- Find all the "service" nodes
    local services = findNodes(self.deviceProfile, "service")

    if #services == 0 then
	return nil, "ERROR: Unable to find service nodes in: " .. dev_http_response.body
    end

    self:debug(9, "Services: ", services)

    -- Search for the WAN.*Connection serviceType
    for _,v in pairs(services) do
	if v.serviceType ~= nil then
	    self.schema = string.match(v.serviceType, "(.*:WANP*[IP]PConnection:%d+)")

	    if self.schema then
		self.url.path = v.controlURL
		self.controlURL = tostring(self.url)
		break
	    end
	end
    end

    if self.schema == nil then
	return nil, "ERROR: Unable to find serviceType WANIPConnection or WANPPPConnection in: " .. dev_http_response.body
    end

    if self.controlURL == nil then
	return nil, "ERROR: Unable to find controlURL in object for serviceType: " .. self.schema
    end

    -- connect location's host quickly to get our LAN ip
    local skt, err = socket.connect(self.url.host, self.url.port)

    if err then
	return nil, "ERROR: failed to open tcp socket to " .. self.url.host .. ':' .. self.url.port .. " - " .. err
    end

    self.internalClient = skt:getsockname()

    skt:close()

    self.readyIGD = true

    return self.deviceProfile, nil
end

function uPnPclient:discoverBasicDevice()
    local ok, err = self:discover("urn:schemas-upnp-org:device:basic:1")

    if err then
	return nil, err
    end

    return self.deviceProfile, nil
end

function uPnPclient:discover(search_target)
    -- Send sspd discover packet
    local udp = assert(socket.udp())

    udp:settimeout(10)

    local pkt_ssdp_discover = table.concat({
      'M-SEARCH * HTTP/1.1\r\n',
    	'HOST: 239.255.255.250:1900\r\n',
    	'MAN: "ssdp:discover"\r\n',
    	'MX: 2\r\n',
    	'ST: ', search_target, '\r\n',
    	'\r\n'
    })

    assert(udp:sendto(pkt_ssdp_discover, "239.255.255.250", 1900))

    -- Wait for reply
    -- TODO handle multiple replies
    local discover_response, err = udp:receive()

    if err then
	return nil, "ERROR: No response to discovery packet: " .. err
    end

    local location = string.match(discover_response,"LOCATION:%s+(http://%S+)")

    if location == nil or location == "" then
	return nil, "ERROR: Unable to parse location from discover response: " .. discover_response
    end

    self:debug(1, "Location: " .. location)

    local url = urlparser.parse(location)

    self.url = url

    -- Ask gateway for it's profile
    local dev_http_response = http:get(location)

    if dev_http_response.err then
	return nil, "ERROR: GET " .. location .. " FAILED: " .. dev_http_response.err
    end

    -- Parse into a simple table tree
    self.deviceProfile = simple_xml_parse(dev_http_response.body)

    self:debug(9, "deviceProfile: ", self.deviceProfile)

    return true, nil
end

function uPnPclient:SendSoapRequest(soap_body, action)
    local soap_headers = { 
	['SOAPAction'] = '"' .. self.schema .. '#' .. action .. '"',
	['Content-Type'] = "text/xml"
    }

    self:debug(8, "Soap Headers:\n", soap_headers, "\nSoap Body:\n", soap_body);

    -- Send request to IGD
    local dev_http_response = http:post(self.controlURL, soap_body, { headers = soap_headers })

    if dev_http_response.err then
	if dev_http_response.err:match('^<s:Envelope') then
	    local err = simple_xml_parse(dev_http_response.err)

	    for k,v in pairs({ "s:Envelope", "s:Body", "s:Fault", 'detail', 'UPnPError' }) do
		if err[v] == nil then
		    break
		end

		err = err[v]
	    end

	    if err.errorCode then
		return nil, err.errorCode .. " - " .. err.errorDescription, err
	    end
	end

	return nil, "GET " .. self.controlURL .. " ACTION: " .. action .. " FAILED: " .. dev_http_response.err
    end

    self:debug(9, "dev_response.body: ", dev_http_response.body)

    -- Parse into a simple table tree
    local r = simple_xml_parse(dev_http_response.body)

    self:debug(7, "dev_response: ", r)

    return true, nil, r
end

function uPnPclient:AddPortMapping(protocol, external_port, internal_port, description, duration)
    if not self.readyIGD then
	return nil, "ERROR: Not ready to send commands, did you run discoverIGD()?"
    end

    if internal_port == nil then
	internal_port = external_port
    end

    if description == nil then
	description = 'Port ' .. external_port .. '->' .. self.internalClient .. ':' .. internal_port
    end

    if duration == nil then
	duration = 0
    end

    protocol = string.upper(protocol)

    self:debug(1, "AddPortMapping " .. protocol .. ' ' .. external_port .. " -> " .. self.internalClient .. ':' .. internal_port .. " (" .. description .. ")")

    local soap_body = table.concat({
	'<?xml version="1.0"?>\r\n',
	'<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n',
	'        <s:Body>\r\n',
	'                <u:AddPortMapping xmlns:u="', self.schema, '">\r\n',
	'                        <NewRemoteHost></NewRemoteHost>\r\n',
	'                        <NewExternalPort>', external_port, '</NewExternalPort>\r\n',
	'                        <NewProtocol>', protocol, '</NewProtocol>\r\n',
	'                        <NewInternalPort>', internal_port, '</NewInternalPort>\r\n',
	'                        <NewInternalClient>', self.internalClient, '</NewInternalClient>\r\n',
	'                        <NewEnabled>1</NewEnabled>\r\n',
	'                        <NewPortMappingDescription>', description, '</NewPortMappingDescription>\r\n',
	'                        <NewLeaseDuration>', tonumber(duration),'</NewLeaseDuration>\r\n',
	'                </u:AddPortMapping>\r\n',
	'        </s:Body>\r\n',
	'</s:Envelope>\r\n\r\n',
    })

    return self:SendSoapRequest(soap_body, 'AddPortMapping')
end

function uPnPclient:DeletePortMapping(protocol, external_port, internal_port)
    if not self.readyIGD then
	return nil, "ERROR: Not ready to send commands, did you run discoverIGD()?"
    end

    if internal_port == nil then
	internal_port = external_port
    end

    if description == nil then
	description = 'Port ' .. external_port .. '->' .. self.internalClient .. ':' .. internal_port
    end

    if duration == nil then
	duration = 0
    end

    protocol = string.upper(protocol)

    self:debug(1, "DeletePortMapping " .. protocol .. ' ' .. external_port .. " -> " .. self.internalClient .. ':' .. internal_port .. " (" .. description .. ")")

    local soap_body = table.concat({
	'<?xml version="1.0"?>\r\n',
	'<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n',
	'        <s:Body>\r\n',
	'                <u:DeletePortMapping xmlns:u="', self.schema, '">\r\n',
	'                        <NewExternalPort>', external_port, '</NewExternalPort>\r\n',
	'                        <NewProtocol>', string.upper(protocol), '</NewProtocol>\r\n',
	'                        <NewInternalPort>', internal_port, '</NewInternalPort>\r\n',
	'                        <NewInternalClient>', self.internalClient, '</NewInternalClient>\r\n',
	'                </u:DeletePortMapping>\r\n',
	'        </s:Body>\r\n',
	'</s:Envelope>\r\n\r\n',
    })

    return self:SendSoapRequest(soap_body, 'DeletePortMapping')
end

function uPnPclient:GetExternalIPAddress()
    if not self.readyIGD then
	return nil, "ERROR: Not ready to send commands, did you run discoverIGD()?"
    end

    self:debug(1, "GetExternalIPAddress()")

    local soap_body = table.concat({
	'<?xml version="1.0"?>\r\n',
	'<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n',
	'        <s:Body>\r\n',
	'                <u:GetExternalIPAddress xmlns:u="', self.schema, '">\r\n',
	'                </u:GetExternalIPAddress>\r\n',
	'        </s:Body>\r\n',
	'</s:Envelope>\r\n\r\n',
    })

    local status, err, ret = self:SendSoapRequest(soap_body, 'GetExternalIPAddress')

    for _,k in pairs({ "s:Envelope", "s:Body", "u:GetExternalIPAddressResponse", "NewExternalIPAddress" }) do
	if ret[k] == nil then
	    return nil
	end
	ret = ret[k]
    end

    return ret
end

function uPnPclient:GetListOfPortMappings()
    if not self.readyIGD then
	return nil, "ERROR: Not ready to send commands, did you run discoverIGD()?"
    end

    self:debug(1, "GetListOfPortMappings()")

    local soap_body = table.concat({
	'<?xml version="1.0"?>\r\n',
	'<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n',
	'        <s:Body>\r\n',
	'                <u:GetListOfPortMappings xmlns:u="', self.schema, '">\r\n',
	'                        <NewStartPort>0</NewStartPort>\r\n',
	'                        <NewEndPort>65535</NewEndPort>\r\n',
	'                        <NewProtocol>TCP</NewProtocol>\r\n',
	'                        <NewNumberOfPorts>65535</NewNumberOfPorts>\r\n',
	'                </u:GetListOfPortMappings>\r\n',
	'        </s:Body>\r\n',
	'</s:Envelope>\r\n\r\n',
    })

    local status, err, ret = self:SendSoapRequest(soap_body, 'GetListOfPortMappings')

    if err then
	return nil, err
    end

    return ret
end

function uPnPclient:GetCommonLinkProperties()
    if not self.readyIGD then
	return nil, "ERROR: Not ready to send commands, did you run discoverIGD()?"
    end

    self:debug(1, "GetCommonLinkProperties()")

    local soap_body = table.concat({
	'<?xml version="1.0"?>\r\n',
	'<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\r\n',
	'        <s:Body>\r\n',
	'                <u:GetCommonLinkProperties xmlns:u="', self.schema, '">\r\n',
	'                </u:GetCommonLinkProperties>\r\n',
	'        </s:Body>\r\n',
	'</s:Envelope>\r\n\r\n',
    })

    local status, err, ret = self:SendSoapRequest(soap_body, 'GetCommonLinkProperties')

    if err then
	return nil, err
    end

    return ret
end

return _M
