-- Spending includes paid compaction requests and subagents, unlike session context.
with ranked as (
  select *, row_number() over (partition by id order by populated desc, time_updated desc, storage asc) as n
  from ul_spend_sessions
),
usage as (
  select m.at, m.data from ul_spend_messages m join ranked s
    on s.id = m.session_id and s.storage = m.storage and s.n = 1
  where m.at <= (select now_ms from ul_clock)
),
periods as (
  select 'today' as name, today_start as since from ul_clock
  union all select 'week', week_start from ul_clock
),
totals as (
  select p.name,
    coalesce(sum(max(0, coalesce(json_extract(u.data, '$.tokens.input'), 0))), 0) as input,
    coalesce(sum(max(0, coalesce(json_extract(u.data, '$.tokens.output'), 0))), 0) as output,
    coalesce(sum(max(0, coalesce(json_extract(u.data, '$.tokens.reasoning'), 0))), 0) as reasoning,
    coalesce(sum(max(0, coalesce(json_extract(u.data, '$.tokens.cache.read'), 0))), 0) as cache_read,
    coalesce(sum(max(0, coalesce(json_extract(u.data, '$.tokens.cache.write'), 0))), 0) as cache_write
  from periods p left join usage u on u.at >= p.since group by p.name
)
select json_group_object(name, json_object('tokens', json_object(
  'input', input, 'output', output, 'reasoning', reasoning,
  'cache', json_object('read', cache_read, 'write', cache_write)))) from totals;

