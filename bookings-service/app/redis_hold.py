import uuid
from redis import Redis
import os

# realizez conexiunea cu Reids
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
r = Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

# script lua pentru start hold
# un singur thread redis poate executa un script lua
# => atomicitate (fara race conditions)
# daca exista deja hold pe teren: return 0
# altfel, hold_key => token; token_key => username + field_id, ambele cu TTL
_START_HOLD_LUA = """
local hold_key = KEYS[1]
local token_key = KEYS[2]
local token = ARGV[1]
local owner = ARGV[2]
local ttl = tonumber(ARGV[3])

if redis.call("exists", hold_key) == 1 then
  return 0
end

redis.call("set", hold_key, token, "EX", ttl)
redis.call("set", token_key, owner, "EX", ttl)
return 1
"""

# lua pentru cancel hold doar daca token-ul corespunde
_CANCEL_HOLD_LUA = """
local hold_key = KEYS[1]
local token_key = KEYS[2]
local token = ARGV[1]

if redis.call("get", hold_key) == token then
  redis.call("del", hold_key)
  redis.call("del", token_key)
  return 1
end
return 0
"""

# 2 chei pentru design robust:
# 1. token_key = am token si vreau sa stiu username + field_id
# 2. hold_key = am terenul si vreau sa stiu care e / daca exista token-ul curent de hold

def start_hold(field_id: int, username: str, ttl_seconds: int = 180) -> str | None:
    token = str(uuid.uuid4()) # token unic pentru hold
    hold_key = f"hold:field:{field_id}"
    token_key = f"hold:token:{token}"
    owner = f"{username}|{field_id}"

    ok = r.eval(_START_HOLD_LUA, 2, hold_key, token_key, token, owner, str(ttl_seconds))
    # daca s-a putut seta hold-ul, returnez token-ul
    if ok == 1:
        return token
    return None

def validate_hold(field_id: int, username: str, token: str) -> bool:
    hold_key = f"hold:field:{field_id}"
    token_key = f"hold:token:{token}"

    # verific doua conditii:
    # 1. pe terenul respectiv exista hold cu token-ul dat
    if r.get(hold_key) != token:
        return False

    # 2. owner-ul token-ului dat este cel asteptat
    owner = f"{username}|{field_id}"
    if r.get(token_key) != owner:
        return False

    return True

def cancel_hold(field_id: int, token: str) -> bool:
    hold_key = f"hold:field:{field_id}"
    token_key = f"hold:token:{token}"
    ok = r.eval(_CANCEL_HOLD_LUA, 2, hold_key, token_key, token)
    return ok == 1
