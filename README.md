# postgres_xtm_docker

About the project: https://wiki.postgresql.org/wiki/DTM



To start a container run following commands:

```bash
> git clone https://github.com/kelvich/postgres_xtm_docker.git
> cd postgres_xtm_docker
> docker-compose build
> docker-compose up
```

That will start three containers with postgres: one for master, and two for shard connected by postgres_fdw. Also it creates two postgres_fdw tables connected to shards and inherited from table "t" on master. By default we turn off TSDTM, change TSDTM: 'yes' in Dockerfile to turn it on.

## Testing

Now we can connect to postgres and try to play around that setup. But it is hard to notice non-transactional behaviour in postgres_fdw from a single user session. So we are providing simple test for distributed transaction (requires libpqxx). This test fill database with users across two shard and then starts to concurrently transfers money between users in dufferent shards.

Money transfer transactions looks as following:

```sql
begin;
update t set v = v - 1 where u=%d; -- this is user from t_fdw1, first shard
update t set v = v + 1 where u=%d; -- this is user from t_fdw2, second shard
commit;
```

Also test simultaneously runs reader thread that counts all money in system:

```sql
select sum(v) from t;
```

So in transactional system we expect that sum should be always constant (zero in our case, as we initialize user with zero balance).

We can ran it over our installation with postgres_fdw.

```bash
> cd xtmbench
> make
> ./xtmbench -c 'host=192.168.99.100 user=xtm' -n 300
10000 accounts inserted
Total=-1
Total=0
Total=1
Total=0
Total=1
Total=0
Total=1
Total=0
...
{"tps":134.423409, "transactions":3300, "selects":62, "updates":6000,
"aborts":6, "abort_percent": 0, "readers":1, "writers":10, "update_percent":100,
"accounts":10000, "iterations":300 ,"shards":2}
```

Total amount of money is fluctuating because reading transaction can access state between commits over two shards. Total is printed every time it is changes from previous stored value.

Now let's uncomment "TSDTM: 'yes'" in environment section in docker-compose.yml and restart caontainers:

```bash
> docker-compose down && docker-compose build && docker-compose up
> cd xtmbench
> ./dtmbench -c 'host=192.168.99.100 user=xtm' -n 300
{"tps":121.694407, "transactions":3300, "selects":55, "updates":6000,
"aborts":7, "abort_percent": 0, "readers":1, "writers":10, "update_percent":100,
"accounts":10000, "iterations":300 ,"shards":2}
```

Now total value is not changing over time.
