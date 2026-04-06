with tickets as (

    select * from {{ ref('stg_ret_tickets') }}

),

customers as (

    select * from {{ ref('stg_ret_customers') }}

),

enriched as (

    select
        t.ticket_id,
        t.customer_id,
        c.name                                                         as customer_name,
        c.company_name,
        c.region,
        t.created_at,
        t.issue_type,
        t.status,
        case
            when t.status in ('open', 'in_progress') then true
            else false
        end                                                            as is_open

    from tickets t
    left join customers c
        on t.customer_id = c.customer_id

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['ticket_id']) }}          as ticket_key,
        ticket_id,
        customer_id,
        customer_name,
        company_name,
        region,
        created_at,
        issue_type,
        status,
        is_open

    from enriched

)

select * from final
