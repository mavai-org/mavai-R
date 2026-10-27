-- wrap-tables.lua
-- Pandoc filter that assigns each table column a relative width
-- proportional to its content length, so that long-content columns
-- (e.g. a Milestone description) get more horizontal space than short
-- ones (e.g. a single-digit row number).
--
-- Pipe tables in GFM/markdown do not carry width hints through pandoc's
-- AST (colspecs come out as ColWidthDefault), so pandoc emits
-- longtable{@{}lll@{}} with natural-width left-aligned columns that do
-- not wrap. Setting widths here forces pandoc to emit p{...} columns
-- that do wrap.
--
-- Width assignment is two-stage:
--   1. Each column gets a *minimum* fraction sized to its longest
--      unbreakable token. Long monospace tokens like
--      `TEST_LARGER_THAN_BASELINE` contain no LaTeX break
--      points (underscores are not break points by default), so the
--      column must be wide enough to fit the whole token or the text
--      overflows into adjacent columns.
--   2. The remaining width is distributed by sqrt(total cell text
--      length) so long-prose columns still get more room than short
--      ones, with the square root dampening extreme ratios.

local MIN_FRAC = 0.04      -- every column gets at least 4% of \linewidth
local CHAR_FRAC = 0.016    -- fraction of \linewidth per monospace char at 11pt
                           -- (DejaVu Sans Mono ~6.6pt char on a ~468pt textwidth;
                           --  slight overshoot ensures no overflow)
local stringify = pandoc.utils.stringify

-- Longest substring with no break opportunities. Whitespace, hyphens,
-- and underscores all act as break points: whitespace and hyphens
-- are LaTeX defaults; underscores are inserted as break points by
-- the breakable-code.lua filter for inline Code elements.
local function max_word_len(s)
  local m = 0
  for w in s:gmatch("[^%s%-_]+") do
    if #w > m then m = #w end
  end
  return m
end

local function add_row(row, lengths, maxtok)
  for i, cell in ipairs(row.cells) do
    local s = stringify(cell.contents)
    lengths[i] = (lengths[i] or 0) + #s
    local mt = max_word_len(s)
    if mt > (maxtok[i] or 0) then maxtok[i] = mt end
  end
end

function Table(tbl)
  local ncols = #tbl.colspecs
  if ncols == 0 then return nil end

  local lengths, maxtok = {}, {}
  for i = 1, ncols do lengths[i] = 0; maxtok[i] = 0 end

  if tbl.head and tbl.head.rows then
    for _, row in ipairs(tbl.head.rows) do add_row(row, lengths, maxtok) end
  end
  for _, body in ipairs(tbl.bodies) do
    if body.body then
      for _, row in ipairs(body.body) do add_row(row, lengths, maxtok) end
    end
    if body.head then
      for _, row in ipairs(body.head) do add_row(row, lengths, maxtok) end
    end
  end
  if tbl.foot and tbl.foot.rows then
    for _, row in ipairs(tbl.foot.rows) do add_row(row, lengths, maxtok) end
  end

  -- Stage 1: per-column minimum sized to the longest unbreakable token.
  local mins = {}
  local sum_min = 0
  for i = 1, ncols do
    mins[i] = math.max(MIN_FRAC, maxtok[i] * CHAR_FRAC)
    sum_min = sum_min + mins[i]
  end
  -- If minimums alone exceed full width, scale them down proportionally
  -- so the table still fits the page (some overflow may then occur,
  -- but no column is starved entirely).
  if sum_min > 1 then
    for i = 1, ncols do mins[i] = mins[i] / sum_min end
    sum_min = 1
  end

  -- Stage 2: distribute remaining width by sqrt-dampened content weight.
  local remaining = 1 - sum_min
  local weights, total_w = {}, 0
  for i = 1, ncols do
    weights[i] = math.sqrt(lengths[i] + 1)
    total_w = total_w + weights[i]
  end

  for i = 1, ncols do
    tbl.colspecs[i][2] = mins[i] + remaining * (weights[i] / total_w)
  end

  return tbl
end
