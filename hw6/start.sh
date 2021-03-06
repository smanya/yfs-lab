#!/usr/bin/env bash

ulimit -c unlimited

LOSSY=$1
NUM_LS=$2

if [ -z $NUM_LS ]; then
    NUM_LS=0
fi

if [ -z $MOUNTDIR ]; then
    MOUNTDIR=$PWD
fi

BASE_PORT=$RANDOM
BASE_PORT=$[BASE_PORT+2000]
EXTENT_PORT=$BASE_PORT
YFS1_PORT=$[BASE_PORT+2]
YFS2_PORT=$[BASE_PORT+4]
LOCK_PORT=$[BASE_PORT+6]

YFSDIR1=$MOUNTDIR/yfs1
YFSDIR2=$MOUNTDIR/yfs2

if [ "$LOSSY" ]; then
    export RPC_LOSSY=$LOSSY
fi

if [ $NUM_LS -gt 1 ]; then
    x=0
    rm config
    while [ $x -lt $NUM_LS ]; do
      port=$[LOCK_PORT+2*x]
      x=$[x+1]
      echo $port >> config
    done
    x=0
    while [ $x -lt $NUM_LS ]; do
      port=$[LOCK_PORT+2*x]
      x=$[x+1]
      echo "starting ./lock_server $LOCK_PORT $port > lock_server$x.log 2>&1 &"
      ./lock_server $LOCK_PORT $port > lock_server$x.log 2>&1 &
      sleep 1
    done
else
    echo "starting ./lock_server $LOCK_PORT > lock_server.log 2>&1 &"
    ./lock_server $LOCK_PORT > lock_server.log 2>&1 &
    sleep 1
fi

unset RPC_LOSSY

echo "starting ./extent_server $EXTENT_PORT > extent_server.log 2>&1 &"
./extent_server $EXTENT_PORT > extent_server.log 2>&1 &
sleep 1

mkdir -p $YFSDIR1
sleep 1
echo "starting ./yfs_client $YFSDIR1 $EXTENT_PORT $LOCK_PORT > yfs_client1.log 2>&1 &"
./yfs_client $YFSDIR1 $EXTENT_PORT $LOCK_PORT > yfs_client1.log 2>&1 &
sleep 1

mkdir -p $YFSDIR2
sleep 1
echo "./yfs_client $YFSDIR2 $EXTENT_PORT $LOCK_PORT > yfs_client2.log 2>&1 &"
./yfs_client $YFSDIR2 $EXTENT_PORT $LOCK_PORT > yfs_client2.log 2>&1 &

sleep 2

# make sure FUSE is mounted where we expect
if [ `mount | grep "$YFSDIR1" | grep -v grep | wc -l` -ne 1 ]; then
    sh stop.sh
    echo "Failed to mount YFS properly at ./yfs1"
    exit -1
fi

# make sure FUSE is mounted where we expect
if [ `mount | grep "$YFSDIR2" | grep -v grep | wc -l` -ne 1 ]; then
    sh stop.sh
    echo "Failed to mount YFS properly at ./yfs2"
    exit -1
fi
