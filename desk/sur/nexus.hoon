/+  sailbox, tarball
:: exploring the possibility of a directory-specific orchestrator agent
::
|%
+$  bowl     bowl:gall             :: to be replaced with local version
+$  card     card:agent:gall       :: to be replaced with local version
+$  proc     @tas                  :: like a mark but for a process
:: ++  process  process:fiber:sailbox :: to be replaced with local version
++  nexus
  $_  ^|
  |%
  :: top-down reconsideration of directory structure in +on-load
  ::
  ++  on-load
    |~  [bowl ball:tarball]
    *ball:tarball
  :: all pokes result in file/directory creation/deletion
  ::
  ++  on-poke
    |~  [bowl cage]
    *[(list card) path (unit ball:tarball)]
  :: all files have an associated running process
  :: all running processes should be able to recover proper
  ::   operation based on state alone, even when restarted.
  ::   this is not guaranteed and is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [path mark]
    :: define process separately in /pro? so /mar, /pro and /nex?
    proc :: *process :: define process corresponding to file
  :: can send effects when the state of a file/process changes
  ::
  ++  on-diff
    |~  [path cage]
    (list card)
  :: can send effects when a process has completed
  ::
  ++  on-done
    |~  [path cage ack=(unit tang)]
    (list card)
  --
--
