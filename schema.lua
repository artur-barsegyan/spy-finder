box.once("schema", function()
    local person = box.schema.space.create('PERSON', { if_not_exists = true })
    person:format({
        { name = 'id', type = 'integer', is_nullable = false },
        { name = 'first_name', type = 'string', is_nullable = false },
        { name = 'last_name', type = 'string', is_nullable = false },
        { name = 'second_name', type = 'string', is_nullable = true }, -- Отчество
        { name = 'birth_date', type = 'string', is_nullable = true },
        { name = 'sex', type = 'string', is_nullable = true },
        { name = 'document', type = 'string', is_nullable = true }, -- Серия/Номер (формат различается)
        { name = 'loyalty', type = 'any', is_nullable = true },
        { name = 'other', type = 'any', is_nullable = true },
    })

    local _ = box.schema.sequence.create('seq_person_id', { start = 1 })
    person:create_index('id', { sequence = 'seq_person_id', parts = { 'id' } })
    person:create_index('unique_person', { parts = { 'first_name', 'second_name', 'birth_date' }, unique = false })
    person:create_index('name', { parts = {'first_name', 'last_name' }, unique = false })
    person:create_index('document', { parts = { 'document' }, unique = true })

    local flights = box.schema.space.create('FLIGHTS', { if_not_exists = true })
    flights:format({
        { name = 'id', type = 'integer', is_nullable = false },
        { name = 'person_id', type = 'integer', is_nullable = true }, -- Maybe unrecognized or missed
        { name = 'date', type = 'string', is_nullable = true },
        { name = 'booking_code', type = 'string', is_nullable = true },
        { name = 'ticket_number', type = 'string', is_nullable = true },
        { name = 'flight_time', type = 'string', is_nullable = true },
        { name = 'code', type = 'string', is_nullable = true }, -- SU1369
        { name = 'departure', type = 'string', is_nullable = true },
        { name = 'arrival', type = 'string', is_nullable = true },
    })

    local _ = box.schema.sequence.create('seq_flight_id', { start = 1 })
    flights:create_index('id', { sequence = 'seq_flight_id', parts = { 'id' } })
    flights:create_index('person', { parts = { 'person_id' }, unique = false })
    flights:create_index("date_flight", { parts = { 'code', 'date' }, unique = false })
    flights:create_index('same_flight', { parts = { 'person_id', 'code', 'date' }, unique = true }) -- TODO: UNIQUE (?)
end)
