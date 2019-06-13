#!/usr/bin/env tarantool

local fio = require('fio')
local connectors = require('connectors')
local xml_parser = require('xml_parse')
local log = require('log')
local json = require('json')
-- local date = require('icu-date')

box.cfg({
    log = 'log.txt',
    log_level = 6
})

local _ = require('schema')

--[[
    Add person/flight to DB
    0. Transorm data
    1. Try to find person in DB (create if needed)
    2. Add new data or verify
        * update profile
        * add flights:
            ** try to find flight (update or create)
            ** relate with person
]]

--[[ Pattern search
    List all persons:
    ....Pass all flights through filter: (
                 time gap between flights,
                 routes (length, specified countries..),
                 loyalty cards,
                 flight class)
    ....
--]]
local persons = box.space.PERSON
local flights = box.space.FLIGHTS

local DEFAULT_PERSON_FILTER = function(person)
    if person.first_name then
        person.first_name = person.first_name:gsub("'", "")
    end

    if person.second_name then
        person.second_name = person.second_name:gsub("'", "")
    end

    if person.last_name then
        person.last_name = person.last_name:gsub("'", "")
    end
end

local function map_record(mapping, record)
    local result = {}
    for k,v in pairs(mapping) do
        if type(v) == 'table' then
            local temp = record[v[1]]
            for i = 2, #v do
                if temp ~= nil then
                    temp = temp[v[i]]
                end
            end

            result[k] = temp
        else
            result[k] = record[v]
        end
    end

    return result
end

local function __find_person_by_flights(person_brief, flights_history)
    local function __find_max(any_kv_table)
        local max = { val = -1, key = {} }
        for k, v in pairs(any_kv_table) do
            if v >= max.val then
                max.val = v

                if v > max.val then
                    max.key = {}
                end
                table.insert(max.key, k)
            end
        end

        return max.key
    end

    local persons_match = {}

    for _, current_flight in ipairs(flights_history) do
        log.info("Flight: %s", json.encode(current_flight))
        local res = flights.index.date_flight:select({current_flight['code'], current_flight['date']}, { iterator = "EQ" })
        for _, matched_flight in ipairs(res) do
            matched_flight = matched_flight:tomap({ names_only = true })
            log.info("matched: %s", json.encode(matched_flight))
            if matched_flight.person_id ~= nil then
                if not persons_match[matched_flight.person_id] then
                    persons_match[matched_flight.person_id] = 1
                else
                    persons_match[matched_flight.person_id] = persons_match[matched_flight.person_id] + 1
                end
            end
        end
    end

    local function __concat_name(first_name, last_name)
        first_name = first_name or ''
        last_name = last_name or ''

        return first_name .. last_name
    end

    local result = __find_max(persons_match)
    -- log.info("RESOLVING BY FLIGHTS %s", json.encode(result))
    local results_with_name = {}
    for _, person_id in ipairs(result) do
        local passenger = persons.index.id:select(person_id)[1]:tomap({ names_only = true })
        local passenger_name = __concat_name(passenger.first_name, passenger.last_name)

        -- TODO: Support last name with 'G.'
        if passenger_name == __concat_name(person_brief.first_name, person_brief.last_name) then
            table.insert(results_with_name, person_id)
        end
    end

    if #results_with_name > 0 then
        result = results_with_name
    end

    return result[1] and persons.index.id:select(result[1])
end

local function find_person(record, flights_history)
    local res

    if record['document'] then
        res = persons.index.document:select(record['document'], { iterator = "EQ" })
    else
        if record['first_name'] and record['last_name'] then
            res = persons.index.name:select({record['first_name'], record['last_name']}, { iterator = "EQ" })
        end

        if not res or #res > 1 then
            -- Not determined yet
            res = __find_person_by_flights(record, flights_history)
            if res and #res >= 1 then
                log.info("find via flights: %s", json.encode(record))
            end
        end
    end

    return res and res[1]
end

local function create_person(record)
    record.id = box.sequence.seq_person_id:next()
    local person = persons:insert(persons:frommap(record))

    return person
end

local function update_person(person, new_record, filters)
    for k,v in pairs(new_record) do
        -- Apply filters
        for _, func in ipairs(filters) do
            func(person, new_record, k)
        end

        if not person[k] then
            person[k] = v
        end
    end

    persons:replace(persons:frommap(person))
end

local function find_flight(person, flight_record)
    local res = flights.index.same_flight:select({person['id'], flight_record['code'], flight_record['date']}, { iterator = "EQ" })
    assert(#res < 2, ("More than one flight: %s"):format(json.encode(record)))

    return res[1]
end

local function create_flight(person, flight_record)
    flight_record.id = box.sequence.seq_flight_id:next()
    flight_record.person_id = person.id
    local flight = flights:insert(flights:frommap(flight_record))

    return flight
end

local function update_flight(flight, flight_record, filters)
    for k,v in pairs(flight_record) do
        for _, func in ipairs(filters) do
            func(flight, flight_record, k)
        end

        if not flight[k] then
            flight[k] = v
        end
    end

    flights:replace(flights:frommap(flight))
end

local function process_csv()
    local source1 = connectors.csv(fio.pathjoin('data', 'BoardingData.csv'), ';')
    for row, val in ipairs(source1) do
        local record = map_record({
            first_name = 'PassengerFirstName',
            second_name = 'PassengerSecondName',
            last_name = 'PassengerLastName',
            sex = 'PassengerSex',
            birth_date = 'PassengerBirthDate',
            document = 'PassengerDocument',
        }, val)

        DEFAULT_PERSON_FILTER(record)

        local person = find_person(record)
        if not person then
            person = create_person(record)
        end

        person = person:tomap({ names_only = true })
        update_person(person, record, {
            function(_, new_data, key)
                if type(new_data[key]) == 'string' then
                    new_data[key] = new_data[key]:upper()
                end
            end,
            function (old_data, new_data, key)
                if type(old_data[key]) == 'string' then
                    if old_data[key] and old_data[key]:match('^[A-Z].$') then
                        if new_data[key] and not new_data[key]:match('^[A-Z].$') then
                            old_data[key] = new_data[key]
                        end
                    end
                end
            end
        })

        local flight_record = map_record({
            arrival = 'Destination',
            code = 'FlightNumber',
            flight_time = 'FlightTime',
            date = 'FlightDate',
            ticket_number = 'TicketNumber',
            booking_code = 'BookingCode'
        }, val)

        local flight = find_flight(person, flight_record)
        if not flight then
            flight = create_flight(person, flight_record)
        end

        flight = flight:tomap({ names_only = true })
        update_flight(flight, flight_record, {
            function(_, new_data, key)
                if type(new_data[key]) == 'string' then
                    new_data[key] = new_data[key]:upper()
                end
            end
        })
    end
end

local function process_xml()
    local loyalty_source = connectors.xml(fio.pathjoin('data', 'PointzAggregator-AirlinesData.xml'))
    local loyalty_data = xml_parser.parse(loyalty_source)

    for _, user in ipairs(loyalty_data) do
        local all_flights_by_loyalty = {}
        local all_loyalty_cards = {}

        for _, loyalty in ipairs(user.loyalty) do
            for _, flight in ipairs(loyalty.flights) do
                table.insert(all_flights_by_loyalty, flight)
            end

            table.insert(all_loyalty_cards, loyalty.name)
        end


        local person_brief = { first_name = user.first_name, last_name = user.last_name, loyalty = all_loyalty_cards }
        DEFAULT_PERSON_FILTER(person_brief)

        local person = find_person(person_brief, all_flights_by_loyalty)
        if not person then
            person = create_person(person_brief)
        end

        person = person:tomap({ names_only = true })
        for _, flight in ipairs(all_flights_by_loyalty) do
            flight = map_record({
                date = 'date',
                code = 'code',
                departure = 'departure',
                arrival = 'arrival',
            }, flight)

            local flight_from_db = find_flight(person, flight)
            if not flight_from_db then
                flight_from_db = create_flight(person, flight)
                -- flight_from_db = flight_from_db:tomap({ names_only = true })
            end

            -- update_flight()
        end
    end
end

local function process_json()
    local source2 = connectors.json(fio.pathjoin('data', 'FrequentFlyerForum-Profiles.json'))
    for id, user in ipairs(source2['Forum Profiles']) do
        local user_flights = {}
        for _, flight in ipairs(user["Registered Flights"]) do
            local flight_record = map_record({
                arrival = {'Arrival', 'Airport'},
                departure = {'Departure', 'Airport'},
                code = 'Flight',
                date = 'Date',
            }, flight)

            table.insert(user_flights, flight_record)
        end

        local person_brief = user["Real Name"]
        person_brief['Sex'] = user['Sex']

        -- Too little info about person in this source -> try to find person with flights scope
        local person_record = map_record({
            first_name = {'Real Name', 'First Name'},
            second_name = {'Real Name', 'Last Name'},
            sex = 'Sex',
        }, person_brief)

        DEFAULT_PERSON_FILTER(person_record)

        local loyalties = {}
        for _, loyalty in ipairs(person_brief['Loyality Programm']) do
            table.insert(loyalties, loyalty["programm"] .. loyalty["Number"])
        end
        person_record.loyalty = loyalties

        local person = find_person(person_record, user_flights)
        if not person then
            person = create_person(person_record)
        end

        -- TODO: Update loyalties
        -- update_person()
    end
end

process_csv()
-- TODO: add Male
process_xml() -- Have FIRST/LAST name for each loyalty information
process_json() -- Called after XML for matching by loyalty
