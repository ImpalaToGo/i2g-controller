mkdir -p /dbcache/cache 
chown -R impala /dbcache/cache 
mkdir -p /dbcache/tmp 
mkdir -p /dbcache/tmp-tachyon/workers 
mkdir -p /dbcache/tmp-tachyon/data 
chown -R impala /dbcache/ 
chmod -R a+rw /dbcache/ 
 
