module.exports =
  Storage: require('./storage')
  SyncStorage: require('./sync_storage')
  SyncBackend: require('./sync_backend')
  GistBackend: require('./gist_backend')
  WebDAVBackend: require('./webdav_backend')
  Options: require('./options')
  ChromeTabs: require('./tabs')
  SwitchySharp: require('./switchysharp')
  ExternalApi: require('./external_api')
  WebRequestMonitor: require('./web_request_monitor')
  Inspect: require('./inspect')
  Url: require('url')
  proxy: require('./proxy')

for name, value of require('omega-target')
  module.exports[name] ?= value
