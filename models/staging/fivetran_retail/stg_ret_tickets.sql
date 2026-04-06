with source as (

    select * from {{ source('fivetran_retail', 'ret_tickets') }}
    where _fivetran_deleted is null or _fivetran_deleted = false

),

renamed as (

    select
        id                                         as ticket_id,
        ticket_user_id                             as customer_id,
        created_at,
        issue_type,
        status,
        _fivetran_synced

    from source

)

select * from renamed
