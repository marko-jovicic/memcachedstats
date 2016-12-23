# memcachedstats
Memcached stats - Linux, Bash

Use **mstats** to get used, wasted, allocated (used+wasted) and free memory of memcached. It gives you basic info about memory so you don't need to do math.

# Usage

mstats [ -h ] -n HOST_NAME -p PORT

Output example:

```
Total memory allocated (used+wasted): 1122008112
Total memory used: 400947981
Total memory wasted: 721060131
Max memory: 2147483648
Free: 1025475536
```
