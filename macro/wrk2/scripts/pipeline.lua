-- example script demonstrating HTTP pipelining
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

init = function(args)
   local r = {}
   r[1] = wrk.format(nil, "/?foo")
   r[2] = wrk.format(nil, "/?bar")
   r[3] = wrk.format(nil, "/?baz")

   req = table.concat(r)
   print(dump(wrk))
end

request = function()
   return req
end
