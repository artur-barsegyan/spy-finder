local json = require('json')
local fio = require('fio')
local icu_date = require('icu-date')

local date, icu_date_err = icu_date.new()
if not date then
    error(icu_date_err)
end

local f = fio.open('airports.json')
local airports = json.decode(f:read())

box.cfg{}

local FLIGHTS = box.space.FLIGHTS

local function most_freq_flights_passengers()
    return box.execute([[SELECT * FROM (
                                             SELECT "person_id", COUNT(*) AS flights_count
                                             FROM "FLIGHTS"
                                             JOIN "PERSON" ON "PERSON"."id" = "FLIGHTS"."person_id"
                                             GROUP BY "person_id"
                                             ORDER BY flights_count DESC)
                                WHERE flights_count > 10")]])
end

-- local function persons_who_freq_flight_together()
--     -- local freq_flights_passengers = most_freq_flights_passengers()

--     -- local query = [[SELECT * FROM "FLIGHTS" WHERE "person_id" IN ]]

--     -- local persons_id = "("
--     -- for _, row in ipairs(freq_flights_passengers.rows) do
--     --     persons_id = persons_id .. tostring(row[1]) .. ','
--     -- end

--     -- local is = persons_id:find(',', -1)
--     -- if is then
--     --     persons_id = persons_id:sub(1, is - 1)
--     -- end
--     -- persons_id = persons_id .. ')'
--     local flights_active_passengers = box.execute([[SELECT * FROM "FLIGHTS"
--         WHERE "person_id" IN
--             (SELECT "person_id" FROM
--                 (SELECT "person_id", COUNT(*) AS flights_count
--                 FROM "FLIGHTS"
--                 JOIN "PERSON" ON "PERSON"."id" = "FLIGHTS"."person_id"
--                 GROUP BY "person_id"
--                 ORDER BY flights_count DESC)
--             WHERE flights_count > 10)
--     ]])

--     local result = box.execute(query .. persons_id)
--     local freq_table = {}
--     for _, flight in ipairs(result.rows) do
--         if not freq_table[flight[1]] then
--             freq_table[flight[1]] = {}
--         end

--         table.insert(freq_table[flight[1]], flight[2])
--     end


-- end

local UK_TOP_AIRPORTS = {  "'LHR'", "'LGW'", "'MAN'", "'STN'", "'BHX'", "'GLA'", "'EDI'", "'LTN'" }
local RUS_TOP_AIRPORTS = { "'SVO'", "'DME'", "'VKO'", "'LED'", "'AER'", "'SVX'", "'OVB'", "'SIP'", "'KRR'", "'ROV'", "'UFA'",
"'KZN'", "'KUF'", "'VVO'", "'KJA'", "'MRV'", "'IKT'", "'KGD'", "'KHV'", "'TJM'", "'SGC'", "'CEK'", "'PEE'", "'AAQ'", "'MCX'",
"'ZIA'", "'VOG'", "'GOJ'", "'OMS'", "'UUS'", "'NUX'", "'ARH'", "'MMK'", "'YKS'", "'REN'", "'NBC'", "'VOZ'", "'PKC'", "'NJC'",
"'TOF'", "'ASF'", "'SCW'", "'BAX'", "'NSK'", "'KEJ'", "'EGO'", "'GRV'", "'OGZ'", "'RTW'", "'BQS'", "'STW'", "'HTA'", "'GDX'",
"'SBT'", "'UUD'", "'IJK'", "'MJZ'", "'SLY'", "'GDZ'", "'HMA'", "'IAA'", "'TLK'", "'CSY'", "'ULY'", "'NOZ'", "'IGT'", "'ABA'",
"'NOJ'", "'MQF'", "'NNM'", "'NYM'", "'PEZ'", "'USK'", "'CEE'", "'KGP'", "'BTK'", "'NAL'", "'KVX'", "'NER'", "'DYR'", "'KLF'" }

-- часто летающие пассажиры, которые хоть раз летали в Британию из России
local query = [[
        SELECT DISTINCT "person_id"
        FROM
          (SELECT *
           FROM "FLIGHTS"
           WHERE "arrival" IN (]] .. table.concat(UK_TOP_AIRPORTS, ', ') .. [[)
           AND "departure" IN (]] .. table.concat(RUS_TOP_AIRPORTS, ', ') .. [[))
        WHERE "person_id" IN
             (SELECT "person_id"
              FROM
                (SELECT "person_id",
                        COUNT(*) AS flights_count
                 FROM "FLIGHTS"
                 GROUP BY "person_id"
                 ORDER BY flights_count DESC)
              WHERE flights_count > 10)
]]

print(query)

-- local DEFAULT_DATE_PATTERN = icu_date.formats.pattern("yyyy-MM-dd")

-- date:parse(DEFAULT_DATE_PATTERN, "1999-01-01")
-- local AGE_LOW_BORDER = date:get_millis()

local result = box.execute(query)
print(#result.rows)

-- local age_filter = {}
-- for _, fl in ipairs(result.rows) do
--     local rc, err = date:parse(DEFAULT_DATE_PATTERN, fl[3])
--     assert(err == nil, "Date parsing error")

--     if date:get_millis() > AGE_LOW_BORDER then
--         table.insert(age_filter, fl)
--     end
-- end
-- print(#age_filter)
