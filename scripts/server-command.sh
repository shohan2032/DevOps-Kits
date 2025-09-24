# 1. see current folder size
sudo du -h --max-depth=1 --exclude=/proc . | sort -rh

# 2. check the partitions
df -h

# 3. Check memory usage 
free -mt

# 4. See os built-in init system
ps --no-headers -o comm 1

# 5. redis-cli
info memory # see memory usage
flushall # flush all db
flushdb # flush current db