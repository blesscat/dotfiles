create temp view ul_spend_sessions_v2 as
select id, time_updated, 'current' as storage,
  exists(select 1 from session_message m where m.session_id = session_v2.id) as populated
from session_v2;

create temp view ul_spend_messages_v2 as
select session_id, time_created as at, data, 'current' as storage
from session_message where time_created >= (select week_start from ul_clock)
  and json_valid(data) and type in ('assistant', 'compaction');

