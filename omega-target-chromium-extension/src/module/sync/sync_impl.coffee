GistSyncImpl = require('./sync_impl_gist')
WebDavSyncImpl = require('./sync_impl_webdav')

class SyncImpl

  # Initialize the backend with configuration.
  # @param {Object} config
  #   config.uri - the remote URI (stored in gistId state field)
  #   config.token - the auth token (stored in gistToken state field)
  #   config.username - optional, for WebDAV
  # @returns {Promise<void>}
  init: (config) -> throw new Error("not implemented")

  # Get the latest commit identifier from the remote.
  # @returns {Promise<string|null>} the commit id, or null if no commits exist
  getLastCommit: -> throw new Error("not implemented")

  # Download the options data for a given commit.
  # @param {string} commitId
  # @returns {Promise<{options: Object, commitId: string}>}
  getOptions: (commitId) -> throw new Error("not implemented")

  # Upload new options data to the remote.
  # @param {Object} options - the options object to upload
  # @param {string|null} previousCommitId - the commit id being replaced
  # @returns {Promise<{commitId: string}>}
  pushOptions: (options, previousCommitId) -> throw new Error("not implemented")

loadSyncImpl = (type, config) ->
  if type is 'webdav'
    backend = new WebDavSyncImpl()
  else
    backend = new GistSyncImpl()
  backend.init(config)
  return backend

module.exports = { SyncImpl, loadSyncImpl }
