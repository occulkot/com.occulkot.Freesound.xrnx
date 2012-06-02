require 'renoise.http'
require 'renoise.http.json'

class "Freesound"

local main_url = "http://freesound.org/api/"
local api_key = "b79e90926df54fa98a5759d77eb55a29"

function Freesound:download_url(id)
   return main_url .. 'sounds/' .. id .. '/serve/?api_key=' .. api_key
end

local orders = {
'downloads_desc',
'downloads_asc',
'duration_desc',
'duration_asc',
'created_desc',
'created_asc',
'rating_desc',
'rating_asc',
}


function Freesound:generate_url(name, tag, sort)
  local url = main_url  .. 'sounds/search/?api_key=' .. api_key .. "&"
  local pars = {}
  pars['name'] = 'q=' .. name .. ''
  if tag ~= "" then
     pars['tag'] = 'f=tag:' .. tag .. ''
  end
  pars['sort'] = 's=' .. orders[sort] .. ''
  for i, filtr in pairs(pars) do
     url = url .. filtr .. '&'
  end

  
   local vb = renoise.ViewBuilder()
--   renoise.app():show_custom_dialog("next", vb:column{vb:text{text=url}})

  return url
end


local search_url = ""
function Freesound:new_search(name, tag, licence, page, odp)
   search_url = Freesound:generate_url(name, tag, licence) .. "p=" .. page
   local success = function(data, status, xml)
      odp(Freesound:parse_results(data))
   end
   HTTP:get(search_url, {}, success)
end


function Freesound:parse_results(data)
   local data = json.decode(data)
   local samples = {}
   
   for i, sampl in pairs(data['sounds']) do
      samples[sampl['id']] = {
	 id = sampl['id'],
	 type = sampl['type'],
	 duration = sampl['duration'],
	 name = sampl['original_filename'],
	 author = sampl['user']['username'],
	 preview = sampl['preview-lq-ogg'],
	 url = sampl['ref']
      }
   end
   return {
      results= data['num_results'],
      pages= data['num_pages'],
      next= data['next'],
      prev= data['prev'],
      samples= samples
	  }
end
