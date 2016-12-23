#!/bin/bash
set -e

# prints usage
# $1 exit value
usage() {
cat <<EOF

	Command show memory statistics of Memcached

    mslabStats [ -h ] -n HOST_NAME -p PORT

    where options are:

  	-h, prints help
	-n, name of the host or IP address
	-p, port

EOF
exit $1
}

OPTERR=0
while getopts ":n:p:h" options
do
    case $options in
			n) HOST_NAME=$OPTARG
			;;
      p) PORT=$OPTARG
      ;;
			h) usage 0
			;;
    esac
done
# getopts will take his params, but rest of them ara available after shifting is done.
shift $(($OPTIND - 1))

if [ -z "$HOST_NAME" ]; then
	echo ""
	echo "Hostname or IP is not set"
	usage 1
fi

if [ -z "$PORT" ]; then
	echo ""
	echo "Port is not set"
	usage 1
fi

# get slabStats
slabStats=$( mktemp )
echo "stats slabs" | nc $HOST_NAME $PORT > $slabStats

# get stats
stats=$( mktemp )
echo "stats" |  nc $HOST_NAME $PORT > $stats

function getLimitMaxBytes() {
	cat $stats | grep "STAT limit_maxbytes" | awk '{ print $3}' | tr -d '\r'
}

#
# $1 - slab number
# $2 - stat info you want to get
# e.g. getStatInfo 1 chunk_size will return chunk size of slab 1
#
function getSlabInfo() {
	cat $slabStats | grep "STAT $1:$2" | awk '{ print $3}' | tr -d '\r'
}

#
# Gets total amount of memory that is used by all items.
#
function getTotalMemory() {
	cat $slabStats | grep "STAT total_malloced" | awk '{ print $3}' | tr -d '\r'
}

# How much memory is realy used by this slab
# $1 - slab id
function getSlabMemoryUsed() {
		getSlabInfo $1 "mem_requested"
}

# How much memory is wasted by this slab
# $1 - slab id
function getSlabMemoryWasted() {
		totalChunks=$( getSlabInfo $1 "total_chunks")
		usedChunks=$( getSlabInfo $1 "used_chunks")
		chunkSize=$( getSlabInfo $1 "chunk_size")
		memRequested=$( getSlabMemoryUsed $1 )

		totalChunksSize=$( echo "$totalChunks * $chunkSize" | bc)
		if [ "$totalChunksSize" -lt "$memRequested" ]; then
			memoryWasted=$( echo "($totalChunks - $usedChunks) * $chunkSize" | bc )
		else
			memoryWasted=$( echo "$totalChunks * $chunkSize - $memRequested" | bc )
		fi
		echo $memoryWasted
}

# Gets total amount of memory used (doesn't include wasted memory)
function getTotalMemoryUsed() {
		numberOfSlabs=$( cat $slabStats | grep "STAT active_slabs" | awk '{ print $3}' | tr -d '\r' )
		totalMemoryUsed=0
		for i in $(seq 1 $numberOfSlabs); do
			memoryUsed=$( getSlabMemoryUsed $i )
			totalMemoryUsed=$( echo "$totalMemoryUsed + $memoryUsed" | bc )
		done
		echo $totalMemoryUsed
}

function getTotalMemoryWasted() {
	numberOfSlabs=$( cat $slabStats | grep "STAT active_slabs" | awk '{ print $3}' | tr -d '\r' )
	totalMemoryWasted=0
	for i in $(seq 1 $numberOfSlabs); do
		memoryWasted=$( getSlabMemoryWasted $i )
		totalMemoryWasted=$( echo "$totalMemoryWasted + $memoryWasted" | bc )
	done
	echo $totalMemoryWasted
}

maxMemory=$( getLimitMaxBytes )
totalMemory=$( getTotalMemory )
totalMemoryUsed=$( getTotalMemoryUsed )
totalMemoryWasted=$( getTotalMemoryWasted )
echo "Total memory allocated (used+wasted): $totalMemory"
echo "Total memory used: $totalMemoryUsed"
echo "Total memory wasted: $totalMemoryWasted"

echo "Max memory: $maxMemory"
freeMemory=$( echo "$maxMemory - ($totalMemoryUsed + $totalMemoryWasted)" | bc )
echo "Free: $freeMemory"
