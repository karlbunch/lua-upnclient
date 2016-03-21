Name
====

lua-upnpclient - Lua uPnP client for discovering uPnP routers and other devices and managing port forwarding

Table of Contents
=================

* [Name](#name)
* [Description](#description)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [discoverIGD](#discoverigd)
    * [discoverBasicDevice](#discoverbasicdevice)
    * [AddPortMapping](#addportmapping)
    * [DeletePortMapping](#deleteportmapping)
    * [GetExternalIPAddress](#getexternalipaddress)
    * [GetListOfPortMappings](#getlistofportmappings)
    * [GetCommonLinkProperties](#getcommonlinkproperties)
* [Debugging](#debugging)
* [Installation](#installation)
* [TODO](#todo)
* [Bugs and Patches](#bugs-and-patches)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Description
===========

The goal of this library is to make it easy to interface lua programs with [uPnP](http://upnp.org/) capable devices on a LAN.

[Back to TOC](#table-of-contents)

Synopsis
========

```lua
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
```

[Back to TOC](#table-of-contents)

Methods
=======

new
---
`syntax: uc, err = uPnPclient:new()`

Creates a new uPnPclient object, returns nil and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

discoverIGD
-----------
`syntax: uc:discoverIGD()`

Discover the Internet Gateway Device (typically the local router)

This method returns `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

discoverBasicDevice
-------------------
`syntax: uc:discoverBasicDevice()`

Discover a "Basic Device" (e.g. Philips Hue)

This method returns the deviceProfile or `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

AddPortMapping
--------------
`syntax: uc:AddPortMapping(protocol, externalPort, internalPort, description, duration)`

This method returns `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

DeletePortMapping
-----------------
`syntax: uc:DeletePortMapping(protocol, externalPort, internalPort)`

This method returns `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

GetExternalIPAddress
--------------------
`syntax: uc:GetExternalIPAddress()`

This method returns the external IP as a Lua string or `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

GetListOfPortMappings
---------------------
`syntax: uc:GetListOfPortMappings()`

This method returns the response from the IGD as a tree of tables or `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

GetCommonLinkProperties
-----------------------
`syntax: uc:GetCommonLinkProperties()`

This method returns the response from the IGD as a tree of tables or `nil` and a Lua string describing the error upon failure.

[Back to TOC](#table-of-contents)

Debugging
=========

You can set a number of parameters when you call the [new](#new) method to create the client object:

* debug_level - Number from 0 to 9, higher values produce more output
* debug_prefix - String to prepend to each message
* debug_print - Function that emulates the print() behavior for debug output

Installation
============

The simplest way to install is using [luarocks](http://luarocks.org/):

```bash
    luarocks install lua-upnpclient
```

[Back to TOC](#table-of-contents)

TODO
====

[Back to TOC](#table-of-contents)

Bugs and Patches
================

Please report bugs or submit patches by creating a ticket on the [GitHub Issue Tracker](http://github.com/karlbunch/lua-upnpclient/issues),

[Back to TOC](#table-of-contents)

Author
======

Karl Bunch (karlbunch at karlbunch.com)

[Back to TOC](#table-of-contents)

Copyright and License
=====================

The MIT License (MIT)

Copyright (c) 2016 Karl Bunch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[Back to TOC](#table-of-contents)

See Also
========

* http://miniupnp.free.fr/
* http://openconnectivity.org/upnp/specifications
* https://en.wikipedia.org/wiki/Universal_Plug_and_Play

[Back to TOC](#table-of-contents)
