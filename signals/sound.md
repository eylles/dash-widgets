# Sound Signal

This sound signal is a shell script that monitors the line by line output from pactl with the
subscribe argument, there are some things of notice about the program:

It has the expectation that `#!/bin/sh` is a posix compliant shell interpreter.

It expects BOTH an `XDG_SESSION_ID` env var as well as a `XDG_RUNTIME_DIR` env var.

The `XDG_SESSION_ID` var is used to namespace the pactl process as well as the status file with a
unique identifier, in specific the pactl call is
`pactl --client-name=awesome-sound-id-$XDG_SESSION_ID subscribe` and the status file is named as
`$XDG_SESSION_ID.status`

The `XDG_RUNTIME_DIR` var is used for the directory that will contain the status file, the directory
is created as follows `${XDG_RUNTIME_DIR}/awesome/sound`

The subdir inside XDG_RUNTIME_DIR is created however neither the file nor the subdir are cleared
upon this program terminating, instead that is left for the XDG_RUNTIME_DIR provider to handle, the
expectation being that once every single login session of the user terminates the runtime dir
provider will clean up every state file and every subdir within the runtime dir.
