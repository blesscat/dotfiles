-- Legacy session/message/part storage. Never expose message text to the mod.
create temp view ul_sessions_v1 as
select id, parent_id, directory, time_updated, null as model, 'legacy' as storage
from session;

create temp view ul_legacy_messages as
select m.*,
  json_extract(m.data, '$.role') as role,
  coalesce(json_extract(m.data, '$.summary') = 1, 0) as summary,
  exists(select 1 from part p where p.session_id = m.session_id and p.message_id = m.id
    and json_valid(p.data) and json_extract(p.data, '$.type') = 'compaction') as request,
  exists(select 1 from part p where p.session_id = m.session_id and p.message_id = m.id
    and json_valid(p.data) and json_extract(p.data, '$.synthetic') = 1)
  and not exists(select 1 from part p where p.session_id = m.session_id and p.message_id = m.id
    and json_valid(p.data) and json_extract(p.data, '$.type') in ('text', 'file')
    and coalesce(json_extract(p.data, '$.synthetic'), 0) = 0
    and coalesce(json_extract(p.data, '$.ignored'), 0) = 0) as synthetic
from message m where m.session_id in (
  select s.id from ul_sessions_v1 s, ul_target t
  where s.parent_id is null and s.directory = t.directory and s.time_updated >= t.since
) and json_valid(m.data);

create temp view ul_messages_v1 as
select session_id,
  row_number() over (partition by session_id order by time_created, id) as pos,
  case when role = 'assistant' and summary then 'compaction' else role end as kind,
  data, json_extract(data, '$.modelID') as model,
  role = 'assistant' and summary and nullif(json_extract(data, '$.finish'), '') is not null
    and json_extract(data, '$.error') is null
    and exists(select 1 from part p where p.session_id = ul_legacy_messages.session_id
      and p.message_id = json_extract(ul_legacy_messages.data, '$.parentID')
      and json_valid(p.data) and json_extract(p.data, '$.type') = 'compaction') as completed,
  role = 'user' and not request and not synthetic as is_call,
  'legacy' as storage
from ul_legacy_messages;

