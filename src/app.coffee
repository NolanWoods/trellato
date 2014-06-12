storyRegex = /Sprint \d+$/
boardUrlRegex = /^https:\/\/trello.com\/\S+\/\S+\//
boardParams = 'lists=open&list_fields=name,pos&cards=open&card_fields=all'
shortUrlOf = (url) -> (boardUrlRegex.exec(url) || [''])[0]

dictOf = (collection, key, values) ->
    _(collection).indexBy(key).mapValues(values).value()

showCard = (global) -> (card) ->
    not global.options.hideTestTasks or
        card.labels.every (label) -> label.color != 'blue'

trellato = angular.module 'trellato', ['angularLocalStorage']

trellato.value 'global', {}

trellato.service 'trello', ($q, $rootScope, $window) -> 
    trelloApi = $window.Trello
    delete $window.Trello

    trello =
        isLoggedIn: false
        authorize: (isAutomatic, onSuccess) ->            
            success = ->
                trello.isLoggedIn = true
                onSuccess() if onSuccess?

            if isAutomatic 
                trelloApi.authorize {interactive: false, success: success }
            else 
                trelloApi.authorize {type: 'popup', success: -> $rootScope.$apply success }

        deauthorize: ->
            trelloApi.deauthorize()
            trello.isLoggedIn = false

        get: (apiUrl, onSuccess) ->
            deferred = $q.defer()
            trelloApi.get apiUrl, 
                (data) -> deferred.resolve data
                (err) -> 
                    console.log 'Trello API Error', err
                    if err.status == 401
                        $rootScope.$apply () -> trello.deauthorize
            if onSuccess
                deferred.promise.then onSuccess
            else deferred.promise

trellato.factory 'getLists', (global) -> (board) ->
    for list in _.sortBy board.lists, 'pos'
        list.cards = for card in board.cards when card.idList == list.id
            card.boardId = global.boardIds[shortUrlOf(card.desc)] if card.desc?
            card
        list

trellato.controller 'mainCtrl', ($scope, trello, global, getLists, storage, $rootScope) ->
    $scope.trello = trello

    loadBoards = ->
        trello.get "organizations/#{ window.orgId }/boards", (boards) ->
            # populate the sprintBoards combo
            $scope.sprintBoards = for b in boards when storyRegex.test b.name
                {id: b.id, name: b.name}

            _.each boards, (board) -> board.url = shortUrlOf board.url
            global.boardIds = dictOf boards, 'url', 'id'

            # select the latest sprint board
            $scope.selectBoard $scope.selectedBoard = $scope.sprintBoards[-1..][0].id

    $scope.login = -> trello.authorize false, loadBoards
    $scope.logout = trello.deauthorize

    $scope.selectBoard = (boardId) ->
        trello.get "boards/#{ boardId }?#{ boardParams }&members=all", (board) ->
            $scope.storyLists = getLists board
            global.members = _.indexBy board.members, 'id'

    storage.bind $scope, 'options', { defaultValue: {enableStacking: true} }
    global.options = $scope.options
    $scope.global = global
    $scope.showCard = showCard global

    $rootScope.maxCols = 3
    $rootScope.$watch 'maxCols', (maxCols) ->
        $scope.colwidth = 100 / maxCols + '%'
        $scope.cols = [1..maxCols-1]


    # try to automatically connect to trello with saved cookie
    trello.authorize true, loadBoards
    #Trello.authorize {interactive: false, success: onSuccess}

    #onSuccess()

trellato.directive 'listname', () ->
    restrict: 'E'
    replace: 'element'
    template: '''
            <div class='listname'>{{list.name}}
                <span ng-show='list.cards.length > 0'>({{list.cards.length}})</span>
            </div>'''


trellato.directive 'story', () ->
    controller: ($scope, getLists, $rootScope, trello) ->
        if $scope.story.boardId
            trello.get "boards/#{ $scope.story.boardId }?#{ boardParams }", 
                (storyBoard) ->
                    $scope.taskLists = getLists storyBoard
                    $rootScope.maxCols = $scope.taskLists.length + 
                        1 if $scope.taskLists.length + 1 > $rootScope.maxCols


trellato.directive 'tasklist', () ->
    scope: true,
    controller: ($scope, $timeout, global) ->
        collapsing = false
        $scope.expand = ->
            if collapsing then $timeout.cancel collapsing
            $scope.expanded = true
        $scope.collapse = ->
            collapsing = $timeout((-> $scope.expanded = false), 500)
        $scope.showCard = showCard global
    template: '''
        <div class='tasklist' ng-mouseenter='expand()' ng-mouseleave='collapse()'
                ng-class='{stackable: options.enableStacking}'>
            <listname></listname>
            <div class='listcards' ng-class='{stacked: !expanded && options.enableStacking}'>
                <div ng-repeat='card in list.cards | filter:showCard' card='card'></div>
            </div>
            <div style="height: 1px; width: 100%;"></div>
        </div>
        '''


trellato.directive 'card', () ->
    scope: { card: '=' }
    replace: 'element'
    template: '''
        <div class="card" ng-class="labels" ng-click="click()">
            <span class='members'>
                <span ng-repeat='member in members'
                      class='member' title='{{member.fullName}}'>
                    {{member.initials}}
                </span>
            </span>
            <div title='{{card.name}}'>
                <a href='{{url}}' target='_blank'>{{card.name}}</a>
            </div>
        </div>'''
    controller: ($scope, global) ->
        $scope.labels = (l.color for l in $scope.card.labels)
        $scope.members = (global.members[id] for id in $scope.card.idMembers)
        $scope.url =
            if $scope.card.boardId then $scope.card.desc else $scope.card.url
        $scope.click = -> console.log $scope.card