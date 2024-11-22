-- Function to parse the query string into components
function parse_query(query)
  pandoc.log.info("Parsing query: " .. query)
  local components = {}
  for component in string.gmatch(query, '([^/]+)') do
    local name, predicates = string.match(component, '(%w+)(%b[])')
    if not name then
      name = component
      predicates = nil
    end
    local predicate_table = {}
    if predicates then
      predicates = string.sub(predicates, 2, -2)
      -- Handle predicates with single or double quotes
      for key, value in string.gmatch(predicates, "(%w+)%s*=%s*['\"]([^'\"]+)['\"]") do
        predicate_table[key] = value
      end
      -- Handle numerical predicates
      for key, value in string.gmatch(predicates, "(%w+)%s*=%s*(%d+%.?%d*)") do
        predicate_table[key] = tonumber(value)
      end
    end
    table.insert(components, {name = name, predicates = predicate_table})
    -- pandoc.log.info("Parsed component: " .. name)
  end
  pandoc.log.info("Finished parsing query. Structure: " .. pandoc.json.encode(components))
  return components
end

-- Function to generate the filter function based on the query
function generate_filter_function(query_components)
  pandoc.log.info("Generating filter function.")
  local function filter(elem)
    local element_type = pandoc.utils.type(elem)
    local matches = true
    local component = query_components[1]
    local node_type = component.name
    local predicates = component.predicates

    -- pandoc.log.info("Element type matches: " .. node_type)

    -- Check predicates
    if predicates then
      for key, value in pairs(predicates) do
        local elem_value
        if key == 'id' and elem.attr then
          elem_value = elem.attr.identifier
        elseif key == 'class' and elem.attr then
          elem_value = table.concat(elem.attr.classes, ' ')
        else
          elem_value = elem[key]
        end
        -- pandoc.log.info(string.format("Checking predicate %s=%s (element value: %s)", key, tostring(value), tostring(elem_value)))
        if tostring(elem_value) ~= tostring(value) then
        --   pandoc.log.info("Predicate does not match.")
          matches = false
          break
        else
        --   pandoc.log.info("Predicate matches.")
        end
      end
    end

    if matches then
      pandoc.log.info("Element matches query component.")
      -- If there's more components in the query, we need to check children
      if #query_components > 1 then
        -- pandoc.log.info("Processing child components.")
        -- Remove the first component and recurse
        local sub_query = {table.unpack(query_components, 2)}
        local sub_filter = generate_filter_function(sub_query)
        -- Collect matching children
        local results = {}
        local walker = {}
        walker[sub_query[1].name] = function(child_elem)
          local res = sub_filter(child_elem)
          if res then
            if type(res) == 'table' and #res > 0 then
              for _, r in ipairs(res) do
                table.insert(results, r)
              end
            else
              table.insert(results, res)
            end
          end
          return nil
        end
        -- Walk the appropriate content (blocks or inlines)
        if elem.content then
          pandoc.walk_block(elem, walker)
        elseif elem.c then
          pandoc.walk_inline(elem, walker)
        end
        return results
      else
        -- If this is the last component, return the element
        pandoc.log.info("Returning matching element.")
        return elem
      end
    else
    --   pandoc.log.info("Element does not match query component.")
    end

    return nil
  end

  return filter
end

-- Function to query the document using walk
function query_document(doc, query)
  pandoc.log.info("Querying document with query: " .. query)
  local query_components = parse_query(query)
  local results = {}

  -- Generate the filter function based on the query
  local filter_function = generate_filter_function(query_components)
  pandoc.log.info("Filter function generated.")

  -- Determine whether to use walk_block or walk_inline
  local element_type = query_components[1].name
  local walker = {}

  walker[element_type] = function(elem)
    local res = filter_function(elem)
    if res then
      pandoc.log.info("Element added to results: " .. pandoc.utils.type(elem))
      if type(res) == 'table' and #res > 0 then
        for _, r in ipairs(res) do
          table.insert(results, r)
        end
      else
        table.insert(results, res)
      end
    end
    if elem.walk then
        elem:walk(walker)
    end
    return nil
  end

  -- Apply the walker to the document
  pandoc.log.info("Walking through document blocks.")
  doc:walk(walker)

  pandoc.log.info("Querying complete. Number of results: " .. #results)
  return results
end

-- Pandoc filter function
function Pandoc(doc)
  pandoc.log.info("Starting Pandoc filter.")
  -- Example query: all headers of level 2
  local query = "Str[text='pandoc']"
  local _, results = pandoc.log.silence(query_document, doc, query)
  -- Process the results (e.g., print headers of level 2)
  if 0 < #results and pandoc.utils.type(results[1]) == 'Block' then
    doc.blocks = results
  else
    doc.blocks = pandoc.Para(results)
  end
  return doc
end
