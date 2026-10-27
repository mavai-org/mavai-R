-- breakable-code.lua
-- Pandoc filter that inserts \allowbreak after each underscore inside
-- inline Code elements when targeting LaTeX. SCREAMING_SNAKE_CASE
-- identifiers like `TEST_LARGER_THAN_BASELINE` then have
-- break opportunities at every underscore, so they wrap inside narrow
-- table cells instead of overflowing.
--
-- The displayed text is unchanged: \allowbreak is a zero-width break
-- hint, and the underscore still renders as `_`. The implementation
-- string literal stays identical to what the R code, JSON fixtures,
-- and downstream frameworks (punit, feotest) use.

local function escape_for_texttt(s)
  -- Escape LaTeX specials inside \texttt, then insert \allowbreak
  -- after every underscore.
  s = s:gsub("\\", "\\textbackslash{}")
  s = s:gsub("([{}#%%&$])", "\\%1")
  s = s:gsub("%^", "\\^{}")
  s = s:gsub("~", "\\~{}")
  s = s:gsub("_", "\\_\\allowbreak ")
  return s
end

function Code(elem)
  if FORMAT:match("latex") then
    return pandoc.RawInline("latex", "\\texttt{" .. escape_for_texttt(elem.text) .. "}")
  end
  return elem
end
