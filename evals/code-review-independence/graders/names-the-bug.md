---
type: regex
pattern: "(page_count[\\s\\S]{0,800}(floor|//|ceil|partial|remainder|leftover|truncat|off-by-one|last page|25))|((floor|//|ceil|partial|remainder|leftover|truncat|off-by-one|last page)[\\s\\S]{0,800}page_count)"
match: contains
---
The report identifies the planted defect: `page_count` floors (`//`) and drops the partial last page (25 items / 10 per page gives 2, AC1 says 3).
