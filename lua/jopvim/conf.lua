
conf = {
  config = {
    token_path = nil,
    token = nil,
    url = 'localhost',
    port = '41184'
  }
}

conf.setup = function(cfg)
  cfg = cfg or {}
  if type(cfg) == "table" then
    conf.config = vim.tbl_extend("keep", cfg, conf.config)
  end

  if conf.config.token == nil and conf.config.token_path ~= nil then
    local f = io.open(conf.config.token_path, "r")
    if f ~= nil then
      conf.config.token = f:read("*line")
    end
  end
end

return conf
