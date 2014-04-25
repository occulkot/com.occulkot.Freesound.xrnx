----
-- Renoise freesound integration
-- v 0.4
-- by occulkot[@]gmail.com
----


local vb = ""
require 'renoise.http'

-- ~useful
function debugg(value)
   local vb = renoise.ViewBuilder()
   local dialog_title = "Debugger...."
   local dialog_content = vb:text {
      text = value
   }
   local dialog_buttons = {"OK"}
   renoise.app():show_custom_prompt(
      dialog_title, dialog_content, dialog_buttons)
end

-- options
local options = renoise.Document.create("FreesoundSettings") {}
options:add_property("SavePath", "/")
options:add_property("ExecutableInfo", "")
options:add_property("Executable", "")
options:add_property("Executableparams", "")

-- menu
renoise.tool():add_menu_entry {
   name = "Main Menu:Tools:Freesound:Browse samples...",
   invoke = function() 
      check_settings() 
   end
                              }

renoise.tool():add_menu_entry {
   name = "Main Menu:Tools:Freesound:Settings",
   invoke = function() 
      show_settings() 
   end
                              }

-- variables
local main_url = "http://freesound.org/api/"
local api_key = "b79e90926df54fa98a5759d77eb55a29"
local status = nil

local sort_orders = {
   "Sort by the number of downloads, most downloaded sounds first.",
   "Same as above, but least downloaded sounds first.",
   "Sort by the duration of the sounds, longest sounds first.",
   "Same as above, but shortest sounds first.",
   "Sort by the date of when the sound was added. newest sounds first.",
   "Same as above, but oldest sounds first.",
   "Sort by the average rating given to the sounds, highest rated first.",
   "Same as above, but lowest rated sounds first."
}

local sort_pars = {
   "downloads_desc",
   "downloads_asc",
   "duration_desc",
   "duration_asc",
   "created_desc",
   "created_asc",
   "rating_desc",
   "rating_asc"
}
local page = 1

-- sample manipulation
function download_sample(sample)
   local download_info = nil
   local sample_name = string.format("%d-%s.%s", sample['id'], sample['name'], sample['type'])
   local sample_name = string.gsub(string.gsub(sample_name, ' ', ''), '"', '')
   local final_name = ''
   if options.SavePath.value ~= '' then
     final_name = options.SavePath.value .. sample_name
   else
     final_name = os.tmpname()  ..'.'.. sample['type']
   end
   local suc = function (fname, costam, costam)
      os.move(fname, final_name)
      status.text = 'success'
      if renoise.song().selected_sample then
         renoise.song().selected_sample:clear()
         renoise.song().selected_sample.sample_buffer:load_from(final_name)
         renoise.song().selected_sample.name = sample['name']
         if renoise.song().selected_instrument.name == '' then
           renoise.song().selected_instrument.name = sample['name']
         end
      else
         renoise.song().selected_instrument:insert_sample_at(1)
         renoise.song().selected_instrument.samples[1].sample_buffer:load_from(final_name)
         renoise.song().selected_instrument.name = sample['name']
         renoise.song().selected_instrument.samples[1].name = sample['name']
      end
   end
   local erro = function (error)
      status.text="Error while downloading " .. sample_name
   end
   local id = sample['id']
   status.text = "downloading " .. sample_name .. ' please wait'
   local uri = main_url .. 'sounds/' .. id .. '/serve/?api_key=' .. api_key
   Request({
              url=uri, 
              method=Request.GET, 
              save_file=true,
              default_download_folder=false,
              error=erro,
              success=suc})
end


function preview_sample(sample)
   
   if options.Executable.value == '' and options.ExecutableInfo.value == '' then
      local war = vb:multiline_text{width=200, height=100, text= [[ You dont have sample player configured
Renoise will use default player provided by system ]]}
      local sf = renoise.tool().bundle_path .. 'settings.xml'
      renoise.app():show_custom_dialog("Warning!", vb:column{war})
      options.ExecutableInfo.value = 'showed'
      options:save_as(sf)
   end
   local download_info = nil
   local suc = function (fname, costam, costam)
      status.text = 'playing preview ...'
      if options.Executable.value == '' then
         renoise.app():open_url('file://' .. fname)
      else
         local osa = io.popen("uname -s"):read("*l")
         if  osa == nil or osa:match("^Windows") then
            os.execute('start "" "' .. options.Executable.value .. '" "' .. options.Executableparams.value .. '" "' .. fname .. '"')
         else
            os.execute('"' .. options.Executable.value .. '" ' .. options.Executableparams.value .. ' "' .. fname .. '"&')
         end
      end
   end
   local erro = function (error)
      status.text="Error while downloading " .. sample['name']
   end
   status.text = "previewing " .. sample['name'] .. ' please wait'
   local uri = sample['preview']
   Request({
              url=uri, 
              method=Request.GET, 
              save_file=true,
              default_download_folder=false,
              error=erro,
              success=suc})
end


-- freesound api
function search(name, tag, author, sort, page)
   local url = main_url  .. 'sounds/search/?api_key=' .. api_key .. "&"
   local pars = {['tag']='',}
   pars['name'] = 'q=' .. name .. ''
   local filtr = ''
   if tag ~= "" then
      filtr = filtr .. ' tag:' .. tag .. ''
   end
   if author ~= "" then
      filtr = filtr .. ' username:' .. author .. ''
   end
   if filtr ~= "" then
      pars['filtr'] = 'f=' .. filtr
   end
   
   pars['sort'] = 's=' .. sort_pars[sort] .. ''
   for i, filtr in pairs(pars) do
      url = url .. filtr .. '&'
   end
   url = url .. 'p=' .. page
   HTTP:get(url, {}, parse_results)
end

local samples = {}
local function download_img(url, icon, sample)
   local suc = function (fname, custam, costam)
      if samples[sample['id']] then
         if samples[sample['id']]['icon'] then
            samples[sample['id']]['icon'].bitmap = fname
         else
            samples[sample['id']]['img'] = fname
         end
      end
   end
   Request({
              url=url ,
              method=Request.GET, 
              save_file=true,
              success=suc})
end

local sample_table= ""
function parse_results(data, status, xml)
   local data = json.decode(data)
   samples = {}
   for i, sampl in pairs(data['sounds']) do
      local icon = 'fetching.png'
      samples[sampl['id']] = {
         id = sampl['id'],
         type = sampl['type'],
         duration = string.format("%.3f", sampl['duration']),
         preview = sampl['preview-lq-ogg'],
         name = sampl['original_filename'],
         author = sampl['user']['username'],
         preview = sampl['preview-lq-ogg'],
         url = sampl['ref'],
         img = icon,
      }
      download_img(sampl['waveform_m'], icon, samples[sampl['id']])
   end
   vb.views.sample_list:add_child(show_sample_table(samples))
   vb.views.results.text = string.format("%d results", data['num_results'])
   vb.views.pages.text = string.format("%d/%d pages", page, data['num_pages'])
   if page > 1 then
      vb.views.prev_button.active = true
   else
      vb.views.prev_button.active = false
   end
   
   if data['next'] then
      vb.views.next_button.active = true
   else
      vb.views.next_button.active = false
   end
   
end

-- rendering results
local function render_sample_row(sample)
   local vb = renoise.ViewBuilder()
   local icon = 
      vb:bitmap {
         height=30,
         bitmap=sample['img'],
         tooltip = sample['name'] .. ' by: ' .. sample['author'],
      }
   samples[sample['id']]['icon'] = icon
   return vb:column{
      width=124,
      margin=2,
      style='border',
      vb:row{ icon },
      
      vb:row{
         vb:button { bitmap='play.bmp', 
                     pressed = function()
                        preview_sample(sample)
                     end
         },
         vb:button { bitmap='download.bmp', 
                     pressed = function()
                        download_sample(sample)
                     end
         },
         vb:text{ text = sample['duration'], align='right', width=80 }
      },
   }
end

function show_sample_table(samples)
   hide_sample_list()

   local st = vb:column{spacing=2, style='invisible'}
   local cr = vb:row{spacing=2}
   st:add_child(cr)
   local count = 1
   for k, sample in pairs(samples) do
      cr:add_child(render_sample_row(sample))
      if count > 4 then
         cr = vb:row{spacing=2}         
         st:add_child(cr)
         count = 0
      end
      count = count + 1
   end
   sample_table = st
   return st
end


function hide_sample_list()
   if type(sample_table) == 'Rack' then
      vb.views.sample_list:remove_child(sample_table)
   end
end



function find_results ()
   search(vb.views.query.value, vb.views.tag.value, vb.views.author.value, vb.views.order.value, page)
end

-- windows
function show_settings()
   vb = renoise.ViewBuilder()
   local sf = renoise.tool().bundle_path .. 'settings.xml'
   options:load_from(sf)
   local ss = nil
   local ff = vb:textfield{value = options.Executable.value, width=300}
   local fp = vb:textfield{value = options.Executableparams.value, width=300}
   local fs = vb:textfield{value = options.SavePath.value, width=300}
   ss = renoise.app():show_custom_dialog("Freesound settings", vb:column{
                                            vb:row{
                                               vb:text{text="Program for playing sample "}
                                            },
                                            vb:row{
                                               ff,
                                               vb:button{text="Browse for program",
                                                         pressed = function ()
                                                            local t = renoise.app():prompt_for_filename_to_read({"*"}, 'Select sample player')
                                                            ff.value = t
                                               end},
                                            },
                                            vb:row{
                                               vb:text{text="Program parameters "}
                                            },
                                            vb:row{
                                               fp,
                                               vb:text{text=""}
                                            },
                                            vb:row{
                                               vb:text{text="Save Directory "}
                                            },
                                            vb:row{
                                               fs,
                                               vb:button{text="Browse for folder",
                                                         pressed = function ()
                                                            local t = renoise.app():prompt_for_path('Browse for download folder')
                                                            fs.value = t
                                               end},
                                            },
                                            vb:row{
                                               vb:button{text="Save",
                                                         pressed = function ()
                                                            options.Executable.value = ff.value
                                                            options.Executableparams.value = fp.value
                                                            options.SavePath.value = fs.value
                                                            options:save_as(sf)
                                                            ss:close()
                                               end}
                                            }
                                        })
   
end

-- check for future ability of saving samples in defined directory
function check_settings()
   local sf = renoise.tool().bundle_path .. 'settings.xml'
   options:load_from(sf)
   if options.SavePath.value == '' then
      local t = ''
      while t == '' do
         t = renoise.app():prompt_for_path('Select samples directory')
      end
      options.SavePath.value = t
      options:save_as(sf)
   end
   show_search_dialog()
end
-- search dialog
function show_search_dialog()
   vb = renoise.ViewBuilder()
   local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
   local DIALOG_SPACING = renoise.ViewBuilder.DEFAULT_DIALOG_SPACING
   local CONTROL_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

   local name_field = vb:textfield{
      id = "query",
      width = 180
   }

   local tag_field = vb:textfield{
      id = "tag",
      width = 60
   }

   local sort_field = vb:popup {
      id = "order",
      width = 60,
      items = sort_orders,
   }
   
   local author_field = vb:textfield {
      id = "author",
      width = 120,
   }
   
   local search_button = vb:horizontal_aligner{
      mode="right",
      vb:button{
         width = 60,
         text = "search",
         notifier = function ()
            page = 1
            find_results()
         end
      }
   }
   
   local search_bar = vb:row {
      vb:text{
         text = "name"
      },
      name_field,
      vb:text{
         text = "tag"
      },
      tag_field,
      vb:text{
         text = "author"
      },
      author_field, 
      vb:text{
         text = "order by"
      },
      sort_field,
      search_button
   }

   sample_table = vb:column {width=640,height=600, vb:text{text="search for something..."}}
   local sample_list = vb:row {
      height=600,
      style="invisible",
      id="sample_list",
      
      sample_table
   }

   local pagination = vb:horizontal_aligner {
      mode="center",
      vb:text{
         width=40,
         align="center",
         text="",
         id="results",
      },
      vb:button {
         id="prev_button",
         text="< prev <",
         active = false,
         width = 40,
         pressed = function()
            page = page - 1
            find_results() end
      },
      vb:text{
         width=200,
         align="center",
         text="...",
         id="pages",
      },
      vb:button {
         id="next_button",
         text="> next >",
         active = false,
         width = 40,
         pressed = function()
            page = page + 1
            find_results()
         end
      },
      vb:text{
         width=40,
         align="center",
         text="",
         id="results_pad",
      },
   }
      status = vb:text{
         align="center",
         text = "",
         
      }
   local status_bar = vb:horizontal_aligner {
      mode="center",
      status
   }
   
   renoise.app():show_custom_dialog(
      "Search freesound.org samples",
      vb:column {
         margin = CONTROL_MARGIN,
         spacing = DIALOG_SPACING,
         search_bar,
         sample_list,
         pagination,
         status_bar
      }
                                   )
end
