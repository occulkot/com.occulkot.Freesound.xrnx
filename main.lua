--[[============================================================================
com.renoise.Freesound.xrnx/main.lua
============================================================================]]--

-- XRNX Bundle Layout:

-- Tool scripts must describe themself through a manifest XML, to let Renoise
-- know which API version it relies on, what "it can do" and so on, without 
-- actually loading it. See "manifest.xml" in this exampel tool for more info 
-- please
--
-- When the manifest loads and looks OK, the main file of the tool will be 
-- loaded. This  is this file -> "main.lua".
--
-- You can load other files from here via LUAs 'require', or simply put
-- all the code in here. This file simply is the main entry point of your tool. 
-- While initializing, you can register your tool with Renoise, by creating 
-- keybindings, menu entries or listening to events from the application. 
-- We will describe all this below now:

 
--------------------------------------------------------------------------------
-- preferences
--------------------------------------------------------------------------------

-- tools can have preferences, just like Renoise. To use them we first need 
-- to create a renoise.Document object which holds the options that we want to 
-- store/restore
require 'freesound'
local vb = ""
require 'renoise.http'
require 'renoise.http.request'
  
--------------------------------------------------------------------------------
-- menu entries
--------------------------------------------------------------------------------

-- you can add new menu entries into any existing context menues or the global 
-- menu in Renoise. to do so, we are using the tool's add_menu_entry function.
-- Please have a look at "Renoise.ScriptingTool.API.txt" i nthe documentation 
-- folder for a complete reference.
--
-- Note: all "invoke" functions here are wrapped into a local function(), 
-- because the functions, variables that are used are not yet know here. 
-- They are defined below, later in this file...

renoise.tool():add_menu_entry {
  name = "--- Main Menu:Tools:Freesound:Browse samples...",
  invoke = function() 
    show_search_dialog() 
  end
}



--------------------------------------------------------------------------------
-- functions
--------------------------------------------------------------------------------

-- show_dialog

local function short(value, length)
   if string.len(value) > length - 3 then
      return string.sub(value, 0, length) .. "..."
   end
   return value
end

local function render_sample_row(sample)
  local vb = renoise.ViewBuilder()
  local row = vb:row{
     
     vb:button {
	bitmap="download.bmp",
	pressed = function()
	   download_sample(sample)
	end
	},
     vb:text{
	width=50,
	text = string.format("%d", sample['id'])
	    },
     vb:text{
	width=240,
	text = short(sample['name'], 40)
	    },
     vb:text{
	width=100,
	text = short(sample['author'], 15)
	    },
     vb:text{
	width=30,
	text = sample['type']
	    },
     vb:text{
	width=30,
	text = string.format("%.3f", sample['duration'])
	    },
    }
  return row
end

local function _get_default_download_folder()
  local dir = "Downloads"
  
  if (os.platform() == "WINDOWS") then
    
    if (os.getenv("HOMEPATH"):find("\\Users\\", 1)) then
      -- Windows Vista/7: \Users\<username>\Downloads
      dir = os.getenv("USERPROFILE")..'\\Downloads\\Renoise\\'
    elseif (os.getenv("HOMEPATH"):find("\\Documents")) then  
      -- Windows XP: \Documents and Settings\<username>\My Documents\Downloads
      -- TODO International location of Windows XP My Documents
      --"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" > "Personal"
      local MYDOCUMENTS = "MY DOCUMENTS"
      dir = os.getenv("USERPROFILE")..MYDOCUMENTS..'\\Downloads\\Renoise\\'
    end    
  elseif (os.platform() == "MACINTOSH") then
    -- Mac: /Users/<username>/Downloads
    dir = os.getenv('HOME').."/Downloads/Renoise/"
    
  elseif (os.platform() == "LINUX") then
    -- Linux: home\<username>\Downloads  
    dir = os.getenv('HOME').."/Downloads/Renoise/"
  end  
  return dir
end

function load_sample(filename)
--   renoise.song().instruments[].samples[].sample_buffer:load_from(filename)
end

local checked_dir = false
function download_sample(sample)
   local download_info = nil
   local sample_name = string.format("%s.%s", sample['name'], sample['type'])
   local final_name = _get_default_download_folder()  .. sample_name
   local suc = function (fname, costam, costam)
      os.rename(fname, final_name)
      renoise.song().selected_instrument:clear()
      download_info:close()
      renoise.song().selected_instrument.samples[1].sample_buffer:load_from(final_name)
      renoise.song().selected_instrument.name = sample['name']
   end
   local erro = function (error)
      download_info:close()
      renoise.app():show_custom_dialog("error", vb:column{vb:text{text="Error while downloading " .. sample_name}})
   end
   local id = sample['id']
   download_info = renoise.app():show_custom_dialog("...", vb:column{vb:text{text="downloading " .. sample_name .. ' please wait'}})
   if not checked_dir then
      os.mkdir(_get_default_download_folder())
      checked_dir = True
   end
   Request({
    url=Freesound:download_url(id), 
    method=Request.GET, 
    save_file=true,
    default_download_folder=true,
    error=erro,
    success=suc})
end

--renoise.song().instruments:insert_sample_at(100)
--sampler = renoise.song().instruments:sample(100)

local sample_table= ""
function show_sample_table(samples)
   hide_sample_list()

   local st = vb:column{
	 width = 390,
	 margin = 2,
	 vb:row{
     vb:text{
	    font="bold",
	width=20,
	text = '..'
	    },
     vb:text{
	    font="bold",
	width=50,
	text = 'id',
	    },
     vb:text{
	    font="bold",
	width=240,
	text = 'name',
	    },
     vb:text{
	    font="bold",
	width=100,
	text = 'author'
	    },
     vb:text{
	    font="bold",
	width=30,
	text = 'type'
	    },
     vb:text{
	    font="bold",
	width=30,
	text = 'secs'
	    },
	       },
   }
   for k, sample in pairs(samples) do
     st:add_child(render_sample_row(sample))
   end
   sample_table = st
   return st
end

function hide_sample_list()
   if type(sample_table) == 'Rack' then
     vb.views.sample_list:remove_child(sample_table)
   end
end

local page = 1
function display_results(results)
   vb.views.sample_list:add_child(show_sample_table(results['samples']))
   vb.views.pages.text = string.format("%d results on %d pages", results['results'], results['pages'])
   if page > 1 then
      vb.views.prev_button.active = true
   else
      vb.views.prev_button.active = false
   end
   
   if results.next then
      vb.views.next_button.active = true
   else
      vb.views.next_button.active = false
   end
end


function load_results ()
Freesound:new_search(vb.views.name.value, vb.views.tag.value, vb.views.licence.value,page, 
			      display_results)
end


local orders = {
"Sort by the number of downloads, most downloaded sounds first.",
"Same as above, but least downloaded sounds first.",
"Sort by the duration of the sounds, longest sounds first.",
"Same as above, but shortest sounds first.",
"Sort by the date of when the sound was added. newest sounds first.",
"Same as above, but oldest sounds first.",
"Sort by the average rating given to the sounds, highest rated first.",
"Same as above, but lowest rated sounds first.",
}

function show_search_dialog()
   vb = renoise.ViewBuilder()
   local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
   local DIALOG_SPACING = renoise.ViewBuilder.DEFAULT_DIALOG_SPACING
   local CONTROL_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

   local name_field = vb:textfield{
      id = "name",
      width = 120
   }

   local tag_field = vb:textfield{
      id = "tag",
      width = 60
   }

   local licence_field = vb:popup {
      id = "licence",
      width = 60,
      items = orders,
    }
  


   local search_button = vb:horizontal_aligner{
      mode="right",
      vb:button{
      width = 60,
      text = "search",
      notifier = function ()
	 page = 1
	 load_results()
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
	 text = "licence"
      },
      licence_field,
      search_button
   }

   sample_table = vb:column {width=390, margin = 2, vb:text{text="search for something..."}}
   local sample_list = vb:row {
      style="border",
      id="sample_list",
      sample_table
   }

   local pagination = vb:horizontal_aligner {
      mode="center",
      vb:button {
	 id="prev_button",
	 text="< prev <",
	 active = false,
	 width = 40,
	 pressed = function()
	    page = page - 1
	    load_results() end
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
	    load_results()
	 end
		}
   }
   
   renoise.app():show_custom_dialog(
      "Search freesound.org samples",
      vb:column {
	 margin = CONTROL_MARGIN,
	 spacing = DIALOG_SPACING,
	 search_bar,
	 sample_list,
	 pagination
      }
   )
end


