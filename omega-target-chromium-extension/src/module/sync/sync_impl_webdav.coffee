SyncImpl = require('./sync_impl')

COMMIT_FILENAME = 'zeroomega-commit.txt'
OPTION_FILE_PREFIX = 'zeroomega-'
OPTION_FILE_SUFFIX = '.json'

class WebDavSyncImpl extends SyncImpl
  constructor: ->
    @baseUri = ''
    @token = ''
    @username = ''
    @_authHeader = null
    @_authResolved = false

  init: (config) ->
    uri = (config.uri || '').replace(/\/+$/, '')
    @baseUri = uri + '/zeroomega/'
    @token = config.token || ''
    @username = config.username || ''
    @_authHeader = null
    @_authResolved = false
    @_ensureDir()

  _fetch: (url, options = {}) ->
    doFetch = =>
      if @_authHeader
        options.headers ?= {}
        Object.assign(options.headers, @_authHeader)
      fetch(url, options)

    doFetch().then (res) =>
      if res.status == 401
        @_negotiateAuth(url, options.method || 'GET').then (authHeader) =>
          if authHeader
            @_authHeader = authHeader
            @_authResolved = true
            newOpts = JSON.parse(JSON.stringify(options))
            newOpts.headers ?= {}
            Object.assign(newOpts.headers, authHeader)
            fetch(url, newOpts)
          else
            res
      else
        res

  _negotiateAuth: (url, method) ->
    fetch(url, method: method).then (res) =>
      if res.status != 401
        @_authResolved = true
        return null
      wwwAuth = res.headers.get('WWW-Authenticate')
      if not wwwAuth
        return @_basicAuthHeader()
      basicMatch = wwwAuth.match(/Basic\s+(?:realm=)?([^,]*)/i)
      if basicMatch
        return @_basicAuthHeader()
      bearerMatch = wwwAuth.match(/Bearer\s+(.+?)(?:,|$)/i)
      if bearerMatch
        return @_bearerAuthHeader()
      if wwwAuth.match(/Digest\s+/i)
        throw new Error(
          "Digest authentication is not supported. " +
          "Change a remote sync provider.")
      return @_basicAuthHeader()

  _basicAuthHeader: ->
    if @username and @token
      enc = btoa(@username + ':' + @token)
      return {"Authorization": "Basic " + enc}
    else if @token
      enc = btoa(':' + @token)
      return {"Authorization": "Basic " + enc}
    return null

  _bearerAuthHeader: ->
    if @token
      return {"Authorization": "Bearer " + @token}
    return null

  _optionFilename: (commitId) ->
    OPTION_FILE_PREFIX + commitId + OPTION_FILE_SUFFIX

  _ensureDir: ->
    @_fetch(@baseUri, method: "MKCOL").catch(-> return)

  getLastCommit: ->
    @_fetch(@baseUri + COMMIT_FILENAME).then((res) ->
      if res.status == 404
        return null
      if not res.ok
        throw new Error(
          "WebDAV getLastCommit failed: " + res.status)
      res.text()
    ).then((text) ->
      commitId = text?.trim() || null
      if commitId and not /^[a-zA-Z0-9]+$/.test(commitId)
        throw new Error("Remote " + COMMIT_FILENAME +
          " contains illegal characters")
      commitId
    )

  getOptions: (commitId) ->
    @_fetch(@baseUri + @_optionFilename(commitId)).then((res) ->
      if not res.ok
        throw new Error(
          "WebDAV getOptions failed: " + res.status)
      res.json()
    ).then((options) ->
      return {options, commitId}
    )

  pushOptions: (options, previousCommitId) ->
    newCommitId = @_generateCommitId()
    filename = @_optionFilename(newCommitId)
    jsonContent = JSON.stringify(options, null, 4)

    uploadOptions = @_fetch(@baseUri + filename, {
      method: "PUT"
      body: jsonContent
    }).then((res) ->
      if not res.ok
        throw new Error(
          "WebDAV pushOptions upload failed: " + res.status)
    )

    updateCommit = uploadOptions.then( =>
      @_fetch(@baseUri + COMMIT_FILENAME, {
        method: "PUT"
        body: newCommitId
      })
    ).then((res) ->
      if not res.ok
        throw new Error("WebDAV pushOptions commit " +
          "update failed: " + res.status)
    )

    cleanup = updateCommit.then( =>
      if previousCommitId
        @_fetch(@baseUri + OPTION_FILE_PREFIX + \
          previousCommitId + OPTION_FILE_SUFFIX, {
          method: "DELETE"
        }).catch(-> return)
    )

    cleanup.then( ->
      return {commitId: newCommitId}
    )

  _generateCommitId: ->
    chars = '0123456789abcdef'
    result = ''
    arr = new Uint8Array(20)
    crypto.getRandomValues(arr)
    for byte in arr
      result += chars[byte % 16]
    return result

module.exports = WebDavSyncImpl
