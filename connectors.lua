local csv = require('csv')
local fio = require('fio')
local json = require('json')
local xml_reader = require('luarapidxml')

local function read_csv(file, delimiter)
    local f, err = fio.open(file, { 'O_RDONLY' })
    if not f then
        return nil, err
    end

    local format
    local data = {}
    for i, csv_row in csv.iterate(f, { chunk_size = 4096, delimiter = delimiter or ';' }) do
        if i == 1 then
            format = csv_row
        else
            local tuple = {}
            for k, val in ipairs(csv_row) do
                tuple[format[k]] = val
            end
            data[i-1] = tuple
        end

    end

    f:close()
    return data
end

local function read_json(file)
    local f, err = fio.open(file, { 'O_RDONLY' })
    if not f then
        return nil, err
    end

    local res = json.decode(f:read())
    f:close()
    return res
end

local function read_xml(file)
    local f, err = fio.open(file, { 'O_RDONLY' })
    if not f then
        return nil, err
    end

    local parsed_xml = xml_reader.decode(f:read())
    f:close()

    return parsed_xml
end

return {
    csv = read_csv,
    json = read_json,
    xml = read_xml
}
