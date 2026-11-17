-- Current session_v2/session_message storage, same contract as legacy.sql.
create temp view ul_sessions_v2 as
select id, parent_id, directory, time_updated, json_extract(model, '$.id') as model,
  'current' as storage from session_v2;

create temp view ul_messages_v2 as
select session_id, seq as pos, type as kind, data, null as model,
  type = 'compaction' and json_extract(data, '$.status') = 'completed' as completed,
  type = 'user' as is_call, 'current' as storage
from session_message where session_id in (
  select s.id from ul_sessions_v2 s, ul_target t
  where s.parent_id is null and s.directory = t.directory and s.time_updated >= t.since
) and json_valid(data);

