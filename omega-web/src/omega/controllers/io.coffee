angular.module('omega').controller 'IoCtrl', (
  $scope, $rootScope, $window, $http, omegaTarget, downloadFile
) ->

  $scope.useBuiltInSync = true
  $scope.syncBackendType = 'gist'
  $scope.syncBackendTypeManuallySet = false
  $scope.backendTypes = [
    {id: 'gist', label: 'options_syncBackendGist'}
    {id: 'webdav', label: 'options_syncBackendWebdav'}
  ]
  getGistId = (gistUrl = '') ->
    # get gistId from url `https://gist.github.com/{username}/{gistId}`
    # or directly gistId
    gistId = gistUrl.replace(/\/+$/, '')
    gistId = gistId.split('/')
    gistId = gistId[gistId.length - 1]
    return gistId

  detectBackendType = (uri) ->
    if uri and uri.indexOf('https://gist.github.com/') is 0
      return 'gist'
    if uri and (uri.indexOf('http://') is 0 or uri.indexOf('https://') is 0)
      return 'webdav'
    return 'gist'

  omegaTarget.state([
    'web.restoreOnlineUrl',
    'gistId',
    'gistToken',
    'syncUsername',
    'syncBackendType',
    'lastGistSync',
    'lastGistState'
  ]).then ([
    url, gistId, gistToken, syncUsername, syncBackendType, lastGistSync,
    lastGistState
  ]) ->
    if url
      $scope.restoreOnlineUrl = url
    if gistId
      $scope.gistId = gistId
      if gistId.indexOf('https://gist.github.com/') is 0
        $scope.gistUrl = gistId
      else if gistId.indexOf('http') is 0
        $scope.gistUrl = gistId
      else
        $scope.gistUrl = "https://gist.github.com/" + getGistId(gistId)
    if gistToken
      $scope.gistToken = gistToken
    $scope.syncUsername = syncUsername || ''
    $scope.syncBackendType = syncBackendType or detectBackendType(gistId || '')
    $scope.lastGistSync = new Date(lastGistSync or Date.now())
    $scope.lastGistState = lastGistState or ''

  $scope.$watch 'gistId', (newVal, oldVal) ->
    if newVal != oldVal and not $scope.syncBackendTypeManuallySet
      $scope.syncBackendType = detectBackendType(newVal || '')

  $scope.onBackendTypeManualChange = ->
    $scope.syncBackendTypeManuallySet = true

  $scope.exportOptions = ->
    $rootScope.applyOptionsConfirm().then ->
      plainOptions = angular.fromJson(angular.toJson($rootScope.options))
      content = JSON.stringify(plainOptions)
      blob = new Blob [content], {type: "text/plain;charset=utf-8"}
      filename = """ZeroOmegaOptions-#{new Date().toISOString()}.bak"""
      downloadFile(blob, filename)

  $scope.importSuccess = ->
    $rootScope.showAlert(
      type: 'success'
      i18n: 'options_importSuccess'
      message: 'Options imported.'
    )

  $scope.restoreLocal = (content) ->
    $scope.restoringLocal = true
    $rootScope.resetOptions(content).then(( ->
      $scope.importSuccess()
    ), -> $scope.restoreLocalError()).finally ->
      $scope.restoringLocal = false

  $scope.restoreLocalError = ->
    $rootScope.showAlert(
      type: 'error'
      i18n: 'options_importFormatError'
      message: 'Invalid backup file!'
    )
  $scope.downloadError = ->
    $rootScope.showAlert(
      type: 'error'
      i18n: 'options_importDownloadError'
      message: 'Error downloading backup file!'
    )
  $scope.triggerFileInput = ->
    angular.element('#restore-local-file').click()
    return
  $scope.restoreOnline = ->
    omegaTarget.state('web.restoreOnlineUrl', $scope.restoreOnlineUrl)
    $scope.restoringOnline = true
    $http(
      method: 'GET'
      url: $scope.restoreOnlineUrl
      cache: false
      timeout: 10000
      responseType: "text"
    ).then(((result) ->
      $rootScope.resetOptions(result.data).then (->
        $scope.importSuccess()
      ), -> $scope.restoreLocalError()
    ), $scope.downloadError).finally ->
      $scope.restoringOnline = false

  $scope.enableOptionsSync = (args = {}) ->
    enable = ->
      if !$scope.gistId
        $rootScope.showAlert(
          type: 'error'
          message: 'Sync URI is required'
        )
        return
      if $scope.syncBackendType == 'gist' and !$scope.gistToken
        $rootScope.showAlert(
          type: 'error'
          message: 'Gist Token is required'
        )
        return
      args.gistId = $scope.gistId
      args.gistToken = $scope.gistToken
      args.username = $scope.syncUsername
      args.syncBackendType = $scope.syncBackendType
      args.useBuiltInSync = $scope.useBuiltInSync
      $scope.enableOptionsSyncing = true
      omegaTarget.setOptionsSync(true, args).then( ->
        $window.location.reload()
      ).catch((e) ->
        $scope.enableOptionsSyncing = false
        $rootScope.showAlert(
          type: 'error'
          message: e + ''
        )
        console.log('error:::', e)
      )
    if args?.force
      enable()
    else
      $rootScope.applyOptionsConfirm().then enable

  $scope.cleanInput = (target) ->
    $scope[target] = ''
    omegaTarget.state(target, '')

  $scope.checkOptionsSyncChange = ->
    $scope.enableOptionsSyncing = true
    omegaTarget.checkOptionsSyncChange().then( ->
      $window.location.reload()
    )
  $scope.disableOptionsSync = ->
    omegaTarget.setOptionsSync(false).then ->
      $rootScope.applyOptionsConfirm().then ->
        $window.location.reload()

  $scope.resetOptionsSync = ->
    if !$scope.gistId
      $rootScope.showAlert(
        type: 'error'
        message: 'Sync URI is required'
      )
      return
    if $scope.syncBackendType == 'gist' and !$scope.gistToken
      $rootScope.showAlert(
        type: 'error'
        message: 'Gist Token is required'
      )
      return
    omegaTarget.resetOptionsSync({
      gistId: $scope.gistId
      gistToken: $scope.gistToken
      username: $scope.syncUsername
      syncBackendType: $scope.syncBackendType
    }).then( ->
      $rootScope.applyOptionsConfirm().then ->
        $window.location.reload()
    ).catch((e) ->
      $rootScope.showAlert(
        type: 'error'
        message: e + ''
      )
      console.log('error:::', e)
    )
