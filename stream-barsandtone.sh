#!/bin/bash

# Streams a low-latency 720p@60 video MPEG-TS test stream:
# * a moving color bars test pattern and a seconds counter
# * a 1kHz sine wave on the first frame of every second (otherwise silence), perfectly aligned with a 100x100 white
#   flashing box in the top left corner of the screen (for AV sync testing)
# * a timecode overlay (for cross-device sync testing)
# All video is sent to the multicast address 239.99.1.3:1234
# UDP packets are a maximum of 1316 bytes in size (6 x 188 byte MPEG-TS packets)
# Stream is configured for minimal encoding latency, no B-frames
# MUX delay (PCR-PTS offset) is set at 0.5 seconds

ffmpeg -re \
       -f lavfi -i testsrc=size=1280x720:rate=60 \
	    -f lavfi -i "sine=frequency=1000:sample_rate=48000" \
       -f lavfi -i "aevalsrc='if(lt(mod(t*1000,1000),17),1,0)':s=48000" \
       -filter_complex "\
          [0:v]drawbox=x=500:y=80:w=480:h=70:color=darkred@0.7:t=fill,\
               drawbox=enable='lt(mod(n\,60)\,1)':x=0:y=0:w=100:h=100:color=white@1.0:t=fill,\
               drawtext=fontfile=/path/to/font.ttf:text='%{pts\\:hms}':x=560:y=100:fontsize=48:fontcolor=white[v]; \
          [1:a][2:a]amultiply[aout] \
       " \
       -map "[v]" -map "[aout]" \
       -c:v libx264 -pix_fmt yuv420p -preset ultrafast -tune zerolatency \
       -c:a ac3 -ar 48000 -ac 2 \
       -f mpegts \
       -fflags nobuffer \
       -mpegts_copyts 1 -flags -global_header -bsf:v h264_metadata=aud=1 \
       -muxpreload 0.5 \
       -muxdelay 0.5 \
       "udp://239.99.1.3:1234?pkt_size=1316&ttl=1"
