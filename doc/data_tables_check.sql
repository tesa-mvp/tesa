select
  required.table_name,
  case when existing.tablename is null then 'missing' else 'ok' end as status
from (
  values
    ('data_makes'),
    ('data_model_groups'),
    ('data_models'),
    ('data_torque_items'),
    ('data_torque_steps'),
    ('data_torque_images'),
    ('data_torque_notes'),
    ('data_service_topics'),
    ('data_service_groups'),
    ('data_service_rows'),
    ('data_lexicon_entries')
) as required(table_name)
left join pg_tables existing
  on existing.schemaname = 'public'
 and existing.tablename = required.table_name
order by required.table_name;
