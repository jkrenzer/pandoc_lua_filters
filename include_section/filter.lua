local target_level = 0

function Pandoc(doc)
    sections = pandoc.structure.make_sections(doc.blocks)
    doc.blocks = sections
    return doc
end

function replace_block(elem)
    replacement_id = elem.attr.replacement
    return
end
