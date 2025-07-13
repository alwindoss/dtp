-- lua/datetime-plugin/simple.lua
-- Simple JSON-RPC based wrapper for Go plugin

local M = {}

-- Plugin state
local state = {
  job_id = nil,
  request_id = 0,
  pending_requests = {},
}

-- Find the plugin binary
local function find_binary()
  local possible_paths = {
    vim.fn.stdpath('config') .. '/bin/dtp',
    vim.fn.stdpath('config') .. '/bin/dtp.exe',
    './dtp',
    './dtp.exe'
  }
  
  for _, path in ipairs(possible_paths) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  
  return nil
end

-- Start the plugin process
local function start_plugin()
  if state.job_id then
    -- Check if job is still running
    local job_info = vim.fn.jobwait({state.job_id}, 0)
    if job_info[1] == -1 then
      return state.job_id
    else
      state.job_id = nil
    end
  end
  
  local binary = find_binary()
  if not binary then
    vim.notify("DateTime plugin binary not found", vim.log.levels.ERROR)
    return nil
  end
  
  state.job_id = vim.fn.jobstart({binary}, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line and line ~= "" then
          -- Parse JSON response
          local ok, response = pcall(vim.fn.json_decode, line)
          if ok and response.id then
            local callback = state.pending_requests[response.id]
            if callback then
              state.pending_requests[response.id] = nil
              callback(response.result, response.error)
            end
          end
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line and line ~= "" then
          vim.notify("Plugin error: " .. line, vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code)
      vim.notify("Plugin exited with code: " .. code, vim.log.levels.WARN)
      state.job_id = nil
      state.pending_requests = {}
    end
  })
  
  if state.job_id <= 0 then
    vim.notify("Failed to start plugin", vim.log.levels.ERROR)
    state.job_id = nil
    return nil
  end
  
  return state.job_id
end

-- Send a request to the plugin
local function send_request(method, params, callback)
  local job_id = start_plugin()
  if not job_id then
    if callback then callback(nil, "Failed to start plugin") end
    return
  end
  
  state.request_id = state.request_id + 1
  local request = {
    method = method,
    params = params or {},
    id = state.request_id
  }
  
  if callback then
    state.pending_requests[state.request_id] = callback
  end
  
  local request_json = vim.fn.json_encode(request)
  vim.fn.chansend(job_id, request_json .. "\n")
end

-- Insert datetime at cursor
function M.insert_datetime()
  send_request("InsertDateTime", {}, function(result, error)
    if error then
      vim.notify("Error: " .. error, vim.log.levels.ERROR)
      return
    end
    
    if result then
      -- Get cursor position and insert text
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, {result})
      vim.api.nvim_win_set_cursor(0, {row, col + #result})
    end
  end)
end

-- Insert date at cursor
function M.insert_date()
  send_request("InsertDate", {}, function(result, error)
    if error then
      vim.notify("Error: " .. error, vim.log.levels.ERROR)
      return
    end
    
    if result then
      -- Get cursor position and insert text
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, {result})
      vim.api.nvim_win_set_cursor(0, {row, col + #result})
    end
  end)
end

-- Get current time
function M.get_current_time(callback)
  send_request("GetCurrentTime", {}, function(result, error)
    if callback then
      callback(result, error)
    elseif error then
      vim.notify("Error: " .. error, vim.log.levels.ERROR)
    elseif result then
      vim.notify("Current time: " .. result, vim.log.levels.INFO)
    end
  end)
end

-- Test the plugin
function M.test_plugin()
  local job_id = start_plugin()
  if job_id then
    vim.notify("Plugin started with job ID: " .. job_id, vim.log.levels.INFO)
    
    -- Test getting current time
    M.get_current_time(function(result, error)
      if error then
        vim.notify("Test failed: " .. error, vim.log.levels.ERROR)
      else
        vim.notify("Test successful. Current time: " .. result, vim.log.levels.INFO)
      end
    end)
  else
    vim.notify("Failed to start plugin", vim.log.levels.ERROR)
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}
  
  -- Create user commands
  vim.api.nvim_create_user_command('InsertDateTime', M.insert_datetime, {
    desc = 'Insert current date and time at cursor position'
  })
  
  vim.api.nvim_create_user_command('InsertDate', M.insert_date, {
    desc = 'Insert current date at cursor position'
  })
  
  vim.api.nvim_create_user_command('GetCurrentTime', function()
    M.get_current_time()
  end, {
    desc = 'Get current time'
  })
  
  vim.api.nvim_create_user_command('TestDateTimePlugin', M.test_plugin, {
    desc = 'Test DateTime plugin connection'
  })
  
  -- Set up keymaps if provided
  if opts.keymaps then
    if opts.keymaps.datetime then
      vim.keymap.set('n', opts.keymaps.datetime, M.insert_datetime, {
        desc = 'Insert date and time'
      })
    end
    if opts.keymaps.date then
      vim.keymap.set('n', opts.keymaps.date, M.insert_date, {
        desc = 'Insert date'
      })
    end
  end
  
  vim.notify("DateTime simple plugin setup complete", vim.log.levels.INFO)
end

-- Cleanup function
function M.cleanup()
  if state.job_id then
    vim.fn.jobstop(state.job_id)
    state.job_id = nil
    state.pending_requests = {}
  end
end

return M