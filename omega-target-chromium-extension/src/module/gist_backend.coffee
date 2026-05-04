SyncBackend = require('./sync_backend')

mainLetters = ['Z','e', 'r', 'o', 'O', 'm','e', 'g', 'a']
optionFilename = mainLetters.concat(['.json']).join('')

class GistBackend extends SyncBackend
  constructor: ->
    @gistId = ''
    @gistToken = ''
    @gistHost = 'https://api.github.com'

  init: (config) ->
    gistId = config.uri || ''
    if gistId.indexOf('/') >= 0
      gistId = gistId.replace(/\/+$/, '')
      gistId = gistId.split('/')
      gistId = gistId[gistId.length - 1]
    @gistId = gistId
    @gistToken = config.token
    return Promise.resolve()

  _headers: ->
    {
      "Accept": "application/vnd.github+json"
      "Authorization": "Bearer " + @gistToken
      "X-GitHub-Api-Version": "2022-11-28"
    }

  getLastCommit: ->
    fetch(@gistHost + '/gists/' + @gistId + '/commits?per_page=1', {
      headers: @_headers()
    }).then((res) -> res.json()).then (data) ->
      if data.message
        throw data.message
      return data[0]?.version

  getOptions: (commitId) ->
    fetch(@gistHost + '/gists/' + @gistId, {
      headers: @_headers()
    }).then((res) -> res.json()).then (data) ->
      if data.message
        throw data.message
      optionsStr = data.files[optionFilename]?.content
      options = JSON.parse(optionsStr)
      actualCommitId = data.history[0]?.version
      return {options, commitId: actualCommitId}

  pushOptions: (options, previousCommitId) ->
    postBody = {
      description: mainLetters.concat([' Sync']).join('')
      files: {}
    }
    postBody.files[optionFilename] = {
      content: JSON.stringify(options, null, 4)
    }
    fetch(@gistHost + '/gists/' + @gistId, {
      headers: @_headers()
      method: "PATCH"
      body: JSON.stringify(postBody)
    }).then((res) ->
      res.json()
    ).then (data) ->
      if data.status is "404"
        throw new Error(
          "The token with Gist permission is required.")
      if data.message
        throw data.message
      return {commitId: data.history[0]?.version}

module.exports = GistBackend
