::  lib/nex/tools: types + built-in tool fibers for the tools nexus
::
::  A $tool is a self-contained unit: metadata (name, description, schema)
::  plus a fiber handler. Built-ins live here; user tools are .hoon files
::  in /tools/tools/ that compile to the same $tool type.
::
/+  nexus, tarball, io=fiberio
|%
::  Tool execution result
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
  ==
::  Parameter schema for tool discovery (MCP, Claude API, etc.)
::
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
::
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
::  Tool definition: everything needed to advertise + execute a tool.
::  Built-in tools produce this directly. .hoon files must compile to this type.
::
+$  tool
  $_  ^?
  |%
  ++  name         *@t
  ++  description  *@t
  ++  parameters   *(map @t parameter-def)
  ++  required     *(list @t)
  ++  handler      *tool-handler
  --
::
+$  tool-handler
  $-  (map @t json)
  _*form:(fiber:fiber:nexus ,tool-result)
::  Built-in tool registry
::
::  Maps API name (@t) to tool core.
::
++  built-ins
  ^-  (map @t tool)
  %-  ~(gas by *(map @t tool))
  :~  ['get_ship' get-ship]
  ==
::  Built-in tool implementations
::
++  get-ship
  ^-  tool
  |%
  ++  name  'get_ship'
  ++  description  'Get the current ship name'
  ++  parameters  *(map @t parameter-def)
  ++  required  *(list @t)
  ++  handler
    ^-  tool-handler
    |=  args=(map @t json)
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    (pure:m [%text (scot %p our.bowl)])
  --
--
