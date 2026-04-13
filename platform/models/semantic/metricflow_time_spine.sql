-- Time spine model required by MetricFlow for time-series metrics.
-- Provides a contiguous daily date series from 2022-01-01 to 2030-01-01.
-- Configure in dbt_project.yml under semantic-layer.time-spine.

{{
    config(
        materialized = 'table',
        meta = {
            'metricflow_time_spine': True
        }
    )
}}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart   = "day",
        start_date = "cast('2022-01-01' as date)",
        end_date   = "cast('2030-01-01' as date)"
    ) }}
)

select
    cast(date_day as date) as date_day
from date_spine
