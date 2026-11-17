-- The only session selection and statistics query. Storage differences end in the adapters.
with candidates as (
  select s.*,
    row_number() over (partition by s.id order by
      exists(select 1 from ul_messages m where m.session_id = s.id and m.storage = s.storage) desc,
      s.time_updated desc, s.storage asc) as representation
  from ul_sessions s, ul_target t
  where s.parent_id is null and s.directory = t.directory and s.time_updated >= t.since
),
unique_sessions as (select * from candidates where representation = 1),
selected as (select * from unique_sessions where (select count(*) from unique_sessions) = 1),
messages as (
  select m.* from ul_messages m join selected s on s.id = m.session_id and s.storage = m.storage
),
compactions as (select pos from messages where kind = 'compaction' and completed),
replies as (
  select coalesce(json_extract(data, '$.tokens.input'), 0)
    + coalesce(json_extract(data, '$.tokens.output'), 0)
    + coalesce(json_extract(data, '$.tokens.reasoning'), 0)
    + coalesce(json_extract(data, '$.tokens.cache.read'), 0)
    + coalesce(json_extract(data, '$.tokens.cache.write'), 0) as tokens, pos, model
  from messages where kind = 'assistant'
),
latest as (
  select * from replies where tokens > 0
    and pos > coalesce((select max(pos) from compactions), 0)
  order by pos desc limit 1
)
select cast((select tokens from latest) as integer),
  (select count(*) from messages where is_call), (select count(*) from compactions),
  replace(replace(coalesce((select model from latest), selected.model, ''), char(10), ' '), char(13), ' ')
from selected;

