#!/bin/bash
open -a /Applications/Utilities/Terminal.app/ ~/sfm/server_sfm/termScreenGL.sh
sleep 5; 
#	screen -S spawner_GL -X 'command'` ~/sfm/server_sfm/launch_sh_server.sh'\015'`
#screen -r spawner_GL bash -c '~/sfm/server_sfm/launch_sh_server.sh' 
#screen -dmS spawner_GL bash -c '~/sfm/server_sfm/launch_sh_server.sh; exec bash'
screen -r spawner_GL

