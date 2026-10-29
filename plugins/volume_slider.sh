#!/bin/bash
# Volume popup slider: set the volume to the clicked or dragged position.
# The island gauge follows at once instead of waiting for volume_change.
. "${0%/*}/../lib/env.sh"
[ "$SENDER" = mouse.clicked ] && [ -n "$PERCENTAGE" ] || exit 0
SENDER=volume_change INFO=$PERCENTAGE /bin/bash "$SBD_PLUGINS/volume.sh" &
osascript -e "set volume output volume $PERCENTAGE"
