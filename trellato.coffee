storyRegex = /Sprint \d+$/
boardUrlRegex = /^https:\/\/trello.com\/\S+\/\S+\//
boardParams = 'lists=open&list_fields=name,pos&cards=open&card_fields=all'
shortUrlOf = (url) -> (boardUrlRegex.exec(url) || [''])[0]
dictOf = (collection, key, values) -> _(collection).indexBy(key).mapValues(values).value()


trellato = (angular.module 'trellato', [])

trellato.value('global', {
  taskLists: ['not started', 'in progress', 'ready for dev review', 'outstanding bugs', 'ready to test', 'done'] })

trellato.factory 'getConfig', ($http, $q, global) ->
	deferred = $q.defer()
	($http.get 'trellato.config.js')
		.then((response) -> 
			global.orgId = response.data.orgId
			deferred.resolve response.data
		)
		.catch( -> window.alert "There was an error loading trellato.config.js. Copy and modify from trellato.config_example.js.")
	deferred.promise

trellato.factory 'loadTrello', (getConfig, $q) ->
	deferredTrello = $q.defer()	
	getConfig.then (config) ->
		window.require ["https://api.trello.com/1/client.js?key=#{ config.trelloApiKey }"], ->
			deferredTrello.resolve window.Trello
	deferredTrello.promise

trellato.service 'trello', ($q, loadTrello) -> 
	(apiUrl) -> 
		deferred = $q.defer()
		loadTrello.then (trello) -> trello.get apiUrl, (data) -> deferred.resolve data
		deferred.promise

	
#	(url) -> deferredTrello.promise.then (resolvedTrello) ->
#		deferredGet = $q.defer()		
#		resolvedTrello.get url, (data) -> deferredGet.resolve data
#		deferredGet.promise

trellato.controller 'mainCtrl', ($scope, loadTrello, trello, global) ->
	onSuccess = -> 
		$scope.isLoggedIn = true
		(trello "organizations/#{ global.orgId }/boards").then((boards) ->
			
			# populate the sprintBoards combo
			$scope.sprintBoards = for b in boards when storyRegex.test b.name
				{id: b.id, name: b.name}
			
			_.each boards, (board) -> board.url = shortUrlOf board.url      
			$scope.boardIds = dictOf boards, 'url', 'id'

			# select the latest sprint board
			$scope.selectBoard $scope.selectedBoard = 
				$scope.sprintBoards[-1..][0].id
		)

	$scope.login = -> 
		loadTrello.then((Trello) -> Trello.authorize {type: 'popup', success: -> $scope.$apply onSuccess })

	$scope.selectBoard = (boardId) -> 
		Trello.get "boards/#{ boardId }?#{ boardParams }&members=all", (board) ->
			$scope.storyLists = for list in _.sortBy board.lists, 'pos'
				list.storyCards = for card in board.cards when card.idList == list.id
					card.boardId = $scope.boardIds[shortUrlOf(card.desc)] if card.desc?
					card
				list
			global.members = _.indexBy board.members, 'id'
			$scope.$apply()

	$scope.global = global

	# try to automatically connect to trello with saved cookie
	loadTrello.then (Trello) -> 
		Trello.authorize {interactive: false, success: onSuccess}
trellato.directive('trellable', () -> {
  template: 
    '''
      <tr>
        <th></th>
        <th ng-repeat='list in global.taskLists' ng-bind='list'></th>
      </tr>
      <tr ng-repeat-start='list in storyLists'>
        <th>{{list.name}} ({{list.storyCards.length}})</th>
      </tr>
      <tr ng-repeat='story in list.storyCards'
        story='story'
      ></tr>
      <tr ng-repeat-end></tr>
    '''  
})

trellato.directive('story', () -> {
  scope: { story: '=' }
  template: 
    '''
      <td><div card='story'></div></td>
      <td ng-repeat='list in global.taskLists'>
        <div ng-repeat='task in tasks[list]' card='task'></div>
      </td>
    '''
  controller: ($scope, global) ->
    $scope.global = global
    if $scope.story.boardId
      Trello.get "boards/#{ $scope.story.boardId }?#{ boardParams }", (storyBoard) ->
        taskLists = dictOf storyBoard.lists, 'id', 'name'
        global.taskLists = _.union global.taskLists, _.values(taskLists)          
        $scope.tasks = _.groupBy storyBoard.cards, (card) -> 
          card.list = taskLists[card.idList]
        $scope.$apply()
})

trellato.directive('card', () -> {
  scope: { card: '=' }
  replace: 'element'
  template: '''
    <div class="card" ng-class="labels" ng-click="click()">
      <div><a ng-href="{{card.url}}" target="_blank">{{card.name}}</a></div>
      <div class='members'>
        <span ng-repeat='member in members' class='member' 
        title='{{member.fullName}}'
        ng-bind='member.initials'></span>
      </div>
    </div>'''
  controller: ($scope, global) ->
    $scope.labels = (l.color for l in $scope.card.labels)
    $scope.members = (global.members[id] for id in $scope.card.idMembers)
    $scope.click = -> 
      console.log $scope.card
})








angular.element(window.document).ready ->
	angular.bootstrap window.document, ['trellato']