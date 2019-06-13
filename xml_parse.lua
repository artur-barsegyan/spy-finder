local function handle_flights(node)
    local flights = {}
    for _, current_flight in ipairs(node) do
        local flight = {}
        for _, parameter in ipairs(current_flight) do
            flight[parameter.tag:lower()] = parameter[1]:upper()
        end

        table.insert(flights, flight)
    end

    return flights
end

local function handle_loyalty(node)
    local loyalty = {}
    for _, card in ipairs(node) do
        local flights = handle_flights(card[2])
        table.insert(loyalty, { name = card.attr.number, flights = flights })
    end

    return loyalty
end

local function handle_user(node)
    local record = {}
    record['first_name'] = node[1].attr.first
    record['last_name'] = node[1].attr.last
    record['loyalty'] = handle_loyalty(node[2])

    return record
end

local function parse(xml)
    local records = {}
    for _, transaction in ipairs(xml) do -- parsed_xml is a outer tag - 'PointzAggregatorUsers'
        local user = handle_user(transaction)
        table.insert(records, user)
    end

    return records
end

return {
    parse = parse
}
