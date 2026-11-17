create temp view ul_spend_sessions_v1 as
select id, time_updated, 'legacy' as storage,
  exists(select 1 from message m where m.session_id = session.id) as populated
from session;

create temp view ul_spend_messages_v1 as
select session_id, time_created as at, data, 'legacy' as storage
from message where time_created >= (select week_start from ul_clock)
  and json_valid(data) and json_extract(data, '$.role') = 'assistant';

