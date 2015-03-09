#!/bin/sh
#os x - terminal launcher for screen connect.
#screen -dmS spawner_GL
#screen -r spawner_
screen -dmS spawner_GL bash -c '~/sfm/server_sfm/launch_sh_server.sh; exec bash'
